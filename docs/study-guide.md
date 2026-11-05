# Study Guide

A plain-English walkthrough of this app, written as it gets built. Each task adds a section. Task 8 reorders everything to follow one request through the app and adds interview questions.

## Task 1: Tools, the template, and the first install

### The tools

- **Homebrew** (`brew`) installs command-line programs on a Mac.
- **mise** is a version manager. macOS comes with an old Ruby (2.6) that Apple uses for itself, and you should never install gems into it. mise installs a separate Ruby (3.3.0 here, the version in the template's `.ruby-version` file) and Node, and puts them first on your `PATH`. The line `eval "$(mise activate zsh)"` in `~/.zshrc` is what makes every new Terminal window use them. `which ruby` should show a path under `~/.local/share/mise/`, not `/usr/bin/ruby`.
- **Ruby** is the language of the backend. **Bundler** (`bundle`) installs the Ruby libraries ("gems") listed in `web/Gemfile`, and writes the exact versions it picked into `web/Gemfile.lock`.
- **Node and npm** run the frontend tooling. `npm install` reads `web/frontend/package.json` and fills `node_modules/`.
- **Rails** is the backend web framework. It maps URLs to Ruby code (routes → controllers), talks to the database (models), and runs tests (`bin/rails test`).
- **Shopify CLI** (`shopify`) runs the app in development. `shopify app dev` starts Rails and the frontend dev server together, opens a public tunnel (the `trycloudflare.com` URL) so Shopify can reach your laptop, and keeps the app's settings in your Partner account in sync with `shopify.app.toml`.

### The template

The app started from Shopify's official Ruby app template (`Shopify/shopify-app-template-ruby`). It gives a working embedded app out of the box:

- the `shopify_app` gem, which handles installing the app on a store and checking every request is really from Shopify;
- the `shopify_api` gem, which gives a GraphQL client for the Shopify Admin API;
- a React frontend with Polaris (Shopify's UI components, so the app looks like the admin) and App Bridge (lets the app, which runs in an iframe inside the admin, talk to the admin around it);
- SQLite, a database stored in one file, used only to remember which stores installed the app and their access tokens.

### How install and login work

"Embedded" means the app's page loads inside the Shopify admin, in an iframe. When a merchant opens it:

1. The admin loads the app's URL and adds an `id_token` (a "session token") to the request. It is a short-lived signed token that says "this request is from store X". The app checks the signature with its API secret.
2. The first time, the app has no access token for that store. `shopify_app` performs a **token exchange**: it sends the session token to Shopify and gets back an access token for the Admin API. You can see this in the logs as `Performing Token Exchange`.
3. The access token is saved in the `shops` table (`web/app/models/shop.rb`). This app's tokens expire after an hour and come with a refresh token, which the gem uses to get a new one.
4. Later API calls use the saved token. `AuthenticatedController` (`include ShopifyApp::EnsureHasSession`) is the base for every `/api` controller; it refuses requests without a valid session token.

Permissions ("access scopes") are listed in `shopify.app.toml`. The merchant approves them on install. This app asks for `read_products`, `read_orders` and `read_inventory`, plus the `write_` versions for the seed task. Shopify stores only the `write_` ones, because each `write_` scope includes its `read_` partner.

### Folder layout

```
shopify.app.toml        app settings synced to Shopify: client id, scopes, webhooks
web/                    the Rails app
  Gemfile, Gemfile.lock Ruby gems and their exact versions
  app/controllers/      code that answers requests (home page, /api/...)
  app/services/         plain Ruby classes doing one job (this app's forecast code goes here)
  app/models/shop.rb    one row per installed store, with its access token
  config/routes.rb      which URL goes to which controller
  config/initializers/shopify_app.rb   app name, scopes, API version
  db/                   SQLite database files (not in git) and migrations
  test/                 Minitest tests, run with `bin/rails test`
  frontend/             the React app (pages/, components/), built by Vite
docs/                   spec, plan, and this guide
```

### API version

Shopify releases a new Admin API version every three months and supports each one for about a year. The template used `2025-10`. This app uses `2026-10`, the newest stable version the installed `shopify_api` gem (16.3.1) knows. It is set in `web/config/initializers/shopify_app.rb` (`config.api_version`), and webhooks use the same version in `shopify.app.toml`. It was checked on the dev store: the template's product counter makes a GraphQL call and got `200 OK`. The log notes that `shopify_api` has no REST helper classes for `2026-10`; that doesn't matter, since this app uses GraphQL only.

### What broke on the first run, and why

The template doesn't commit `Gemfile.lock`, so `bundle install` picked the newest version of every gem allowed by the Gemfile, not the versions the template was tested with. Three of them didn't fit Rails 7.1:

1. **`OpenStruct` not found.** `shopify_api` uses Ruby's `OpenStruct` class but never loads it. Older gem versions happened to load it for it. Fix: `gem "ostruct"` in the Gemfile (Rails loads every gem listed there at startup).
2. **Tests wouldn't start.** `minitest` 6 changed how tests are run, and Rails 7.1's test runner wasn't written for it. Fix: `gem "minitest", "~> 5.25"`. The `~>` means "5.25 or newer, but below 6".
3. **`unknown keyword: quirks_mode`.** `json` 3 removed an option that Rails 7.1 passes when turning data into JSON. Fix: `gem "json", "~> 2.7"`.

The lasting fix is committing `Gemfile.lock`, so every machine installs the same versions. `web/test/integration/shopify_api_load_test.rb` sends a fake GraphQL request through `shopify_api` (webmock intercepts it, so nothing goes to the internet) and would fail if any of these came back.

Two other things the CLI did: when it created the app it rewrote `shopify.app.toml` and emptied `scopes`, and set the webhook API version to `2027-01`, which is a release candidate, not a stable version. Both were put back by hand. The `client_id` it added is public and safe to commit; the secret stays in Shopify and in environment variables the CLI sets.

The template also shipped a `.github/` folder with Shopify's own repo tools (CLA bot, issue bots, a style-check workflow). It was removed: none of it applies here, and pushing workflow files needs an extra GitHub permission.

## Task 2: The forecast math (`web/app/services/forecast.rb`)

This class answers one question per product variant: "at the current sales rate, when does it run out?" It knows nothing about Shopify. It takes plain Ruby data in and gives plain Ruby data back.

### What goes in and what comes out

```ruby
Forecast.call(
  variants:   [{ id: "gid://shopify/ProductVariant/1", product_title: "Cold Brew Can",
                 variant_title: nil, sku: "CB-1", inventory: 6 }],
  units_sold: { "gid://shopify/ProductVariant/1" => 60 },
  today:      Date.new(2026, 11, 10),
)
# => [{ id: "...", product_title: "Cold Brew Can", variant_title: nil, sku: "CB-1", inventory: 6,
#       daily_rate: 2.0, days_left: 3, run_out_date: Date(2026-11-13), risk: "critical" }]
```

- `{ id: "...", inventory: 6 }` is a **hash**: a set of key → value pairs. `id:` is a **symbol** key (a fixed name, cheaper than a string). `variant[:inventory]` reads a value. `units_sold` uses string keys (the variant ids), so `@units_sold.fetch(variant[:id], 0)` reads one and falls back to `0` when the variant had no sales.
- `variant.merge(daily_rate: ..., risk: ...)` returns a **new** hash with the extra keys added. The input is not changed.
- `Date.new(2026, 11, 10) + 3` is November 13. Adding a number to a `Date` adds days.

### The rules, line by line

- `rate = units / 30.0`: units sold per day over the 30-day window (`WINDOW_DAYS`). Writing `30.0` (or `.to_f`) matters. In Ruby, `60 / 30` is integer division and `45 / 30` would give `1`, not `1.5`.
- `days_left = (inventory / rate).floor`: `.floor` rounds **down** to a whole day. 20 in stock at 1.5 a day is 13.3 days, which becomes 13. Rounding down is the cautious choice: it never promises a day of stock that isn't there.
- Days left uses the exact rate. Only the `daily_rate` shown in the table is rounded to 2 decimals. Rounding first would skew slow sellers: 1 sale in 30 days is 0.0333/day, and 10 in stock is 300 days, but with the rounded 0.03 it would be 333.
- Risk, checked in this order:
  1. stock 0 or less → `out_of_stock` (with `days_left: 0` and `run_out_date: today`, since it already ran out);
  2. no sales in 30 days → `no_recent_sales` (no date, because it isn't running out);
  3. 7 days or fewer → `critical`; 8 to 14 → `warning`; more than 14 → `ok`.
- `run_out_date: days_left && @today + days_left`: `&&` returns the right side only when the left side is "truthy". In Ruby only `nil` and `false` are falsy, **`0` is truthy**. So out-of-stock rows (`days_left` 0) get today's date, and no-recent-sales rows (`nil`) get `nil`.

### Sorting

```ruby
.sort_by { |r| [SORT_GROUP.fetch(r[:risk], 1), r[:days_left] || 0, r[:product_title]] }
```

`sort_by` sorts by whatever the block returns. Returning an **array** sorts by the first item, then breaks ties with the second, then the third, like sorting by last name and then first name. Here:

1. the group: out of stock = 0, anything with a date = 1, no recent sales = 2;
2. days left, smallest first (`|| 0` replaces `nil`, because Ruby can't compare `nil` with a number);
3. the product title, alphabetically, so ties always come out in the same order.

### Why the math is separate from Shopify

Because `Forecast` only takes hashes, its tests (`web/test/services/forecast_test.rb`) build tiny inputs by hand and run in milliseconds, with no store, network or login. They pin each risk level, the 7- and 14-day boundaries (for example, 15 in stock at 2 a day is 7.5 days, floored to 7, so critical), zero and negative stock, and the sort order. The code that talks to Shopify (Task 4) only has to produce the input in this shape.

`Forecast < ApplicationService` follows the template's pattern (see `product_counter.rb`): `Forecast.call(...)` is short for `Forecast.new(...).call`.

## Task 3: The demo seed (`web/app/services/seed_scenario.rb`, `web/lib/tasks/restock.rake`)

The demo has to show every risk level every time, so the store is filled with a fixed, known scenario instead of random data.

### The scenario

`SeedScenario` is a **module**: a named box of constants and functions, with no objects to create. `module_function` lets you call `SeedScenario.orders(now: ...)` directly.

| Key | Product | Stock | Sold in 10 orders | Forecast |
|---|---|---|---|---|
| A | Oat Milk 1L | 0 | 10 | Out of stock |
| B | Cold Brew Can | 6 | 60 (2/day) | Critical, 3 days |
| C | Dark Roast Beans 340g | 20 | 45 (1.5/day) | Warning, 13 days |
| D | Ceramic Mug | 100 | 30 (1/day) | OK, 100 days |
| E | Pour-Over Kettle | 25 | 0 | No recent sales |

`orders(now:)` builds 10 orders, one every 3 days, from 1.5 to 28.5 days ago (`now - (3 * i + 1.5).days`). `10.times.map { |i| ... }` runs the block for i = 0 to 9 and collects the results. Dark Roast alternates 4 and 5 per order (`i.even? ? 4 : 5` reads "if i is even then 4, else 5").

`now:` is passed in rather than read from the clock inside, so the tests can use a fixed time and get the same answer every run. One test feeds the scenario through `Forecast` and checks it gives the table above, so the demo data and the math can't drift apart.

### Rake tasks

A **rake task** is a named command for maintenance jobs. `bin/rails restock:seed` runs the block in `restock.rake`. `task seed: :environment` means "load the Rails app first", so the task can use `Shop` and the Shopify gems. Run it like this, from `web/`:

```
env $(shopify app env show | grep =) bin/rails restock:seed SHOP=ridgeline-coffee-co-3j14nuup.myshopify.com
```

`shopify app env show` prints the app's API key and secret. `env $(...)` passes them to the command as environment variables, the same way `shopify app dev` passes them to the server. Without them the `shopify_api` gem isn't set up, and the task stops with that command as its message.

### What the task does, in order

1. Finds the store in the `shops` table and opens a session with `shop.with_shopify_session`, which first swaps an expired access token (they last one hour) for a fresh one using the saved refresh token.
2. Checks the store is a **development store** (`shop.plan.partnerDevelopment`) and refuses otherwise, so it can never put fake orders into a real shop.
3. Deletes products tagged `restock-seed` (`productDelete`). That's what makes it safe to run again.
4. Creates each product with `productSet`: one variant, a price, a SKU like `SEED-B`, inventory tracked, and the stock quantity at the store's location.
5. Creates each order with `orderCreate`.

### GraphQL mutations

A **query** reads data. A **mutation** changes it. Both are sent as a text document plus a set of **variables**:

```graphql
mutation($input: ProductSetInput!) {
  productSet(input: $input, synchronous: true) { product { ... } userErrors { field message } }
}
```

`$input` is filled from a Ruby hash. The `!` means "required". The part in `{ }` after the mutation says what you want back. There are two kinds of failure: top-level `errors` (bad query, no permission, throttled) and `userErrors` (the request was understood, but the data was rejected, for example an invalid price). The task's `gql` helper raises on either, so nothing fails silently.

The exact field names were checked against the live `2026-10` schema with an **introspection** query, which asks the API to describe its own types.

### Why the orders are backdated, and why stock is bypassed

- **Backdated:** the forecast counts sales in the last 30 days. Orders created today would all land on one day. `processedAt` sets the date the sale happened. Shopify still records `createdAt` as the moment the seed ran, which is why the app must filter on `processed_at`. On the dev store, the 10 orders show `processed_at` spread from Oct 8 to Nov 4, while all of them were created on Nov 5.
- **Stock bypassed:** a real order lowers stock. Here the scenario's stock numbers (0, 6, 20, 100, 25) are the "now" picture, and the orders are history leading up to it. `inventoryBehaviour: BYPASS` records the sale without touching stock.
- Because sales are dated relative to the seed day, the numbers only match the table on that day. After a few days the oldest orders leave the 30-day window. Re-seed on testing and recording days.
- Re-seeding deletes the products, not the old orders. Old orders then point at deleted variants, and the forecast skips line items with no variant (Task 4).

### Rate limit

Development stores accept about 5 new orders a minute. The task waits 12 seconds between orders, so a full run takes about 2 minutes. If Shopify still says it is throttled, the task waits 60 seconds and retries the same order, up to 3 times. That's marked as a `shortcut:` in the code: a fixed wait is fine for 10 orders, and a bigger job would back off longer each time.

### Protected customer data

Orders hold customer details, so Shopify only lets an app read order fields after the developer declares why the app needs them ("protected customer data access" in the app's settings). Without that, `orderCreate` still creates the order, but asking for the new order's `id` back is refused. The task doesn't need the id, so it only asks for `userErrors`. Reading orders in Task 4 does need the access.
