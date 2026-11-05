# Restock Forecaster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An embedded Shopify app that lists every product variant in a store with its sales rate, days of stock left, run-out date, and risk level, sorted so at-risk items come first.

**Architecture:** Shopify's Ruby app template (Rails backend + React/Polaris frontend). One authenticated JSON endpoint fetches variants and the last 30 days of orders from the GraphQL Admin API, hands them to a pure-Ruby `Forecast` class, and returns rows. One React page renders them; clicking a risk badge opens a window charting that variant's daily sales for the last 8 weeks, from a second endpoint. A rake task seeds a development store with a fixed scenario. Nothing is stored except the template's sessions.

**Tech Stack:** Ruby, Rails, `shopify_app` gem, Shopify GraphQL Admin API, React, Polaris, App Bridge, Minitest, SQLite, Shopify CLI, macOS.

**Spec:** `docs/superpowers/specs/2026-11-05-restock-forecaster-design.md`

**Execution (chosen 2026-11-05):** Native, with `superpowers:executing-plans`, in one session on the MacBook. Status: Tasks 1 to 6 complete (see the ledger); Task 7 added 2026-11-05.

## Global Constraints

- Done by **Dec 1, 2026**; target finish Nov 19 to 21.
- Cost **$0**. No hosting, no deployment; runs through `shopify app dev`.
- Stack: `Shopify/shopify-app-template-ruby`. Fallback only if it will not run: Rails + `shopify_app` + hand-built React (Vite) with Polaris and App Bridge. Rails must stay.
- GraphQL Admin API only, no REST.
- App scopes: `read_products`, `read_orders`, `read_inventory`; seed adds `write_products`, `write_orders`, `write_inventory`.
- Forecast window **30 days**; critical **≤ 7** days left, warning **> 7 and ≤ 14**, ok **> 14**.
- Sales are filtered by `processed_at`, never `created_at`.
- Seed products carry the tag **`restock-seed`**.
- Claude writes the code. Every task ends by appending a plain-English section to `docs/study-guide.md` and summarizing it in chat.
- No claims in docs or resume that the code does not back up. No invented metrics.
- **Ponytail plugin (Muhammad's request):**
  - Write all code and designs under `ponytail:ponytail` at **ultra** level (Muhammad's request, 2026-11-05; was full): question any part of a request the need does not justify, then the smallest complete change, `shortcut: <limit>, <when to upgrade>` comments on known limits.
  - Run `ponytail:ponytail-review` on each task's commits before the task's Explain step. Fix real findings, or note why one was skipped in the study guide.
  - Run `ponytail:ponytail-audit` on the whole repo in Task 8.
  - Use `ponytail:ponytail-debt` output as the source of the README's known-limitations list in Task 9.
- **GitHub (Muhammad's request):** the repo `PricyK/restock-forecaster` is created in Task 1, and every task ends with `git push` so progress shows in real time. Ask Muhammad public or private before creating it. Before every push, check `git status` and the diff for secrets: no `.env`, API secret, access tokens, or SQLite database files.
- **Branches (Muhammad's request, 2026-11-05):** all work is committed on `dev` and pushed there after every task. `dev` merges into `main` only after the task's checks pass: full `bin/rails test` green, `ponytail:ponytail-review` findings fixed or noted, the secret check above, and, where the task has one, the manual check on the dev store. Merge with `git merge --no-ff dev` on `main`, then push `main`.
- **Machine:** Muhammad's MacBook. Work happens in a clone of `PricyK/restock-forecaster` (created on 2026-11-05 with only these docs). All commands below run in Terminal from `web/` unless stated.

## Review Focus

1. **Stores bigger than one API page** (over 250 variants, or many orders): every variant and every sale must be counted. Pinned by `test_follows_pagination` in Task 4.
2. **Cancelled orders**: must not count as sales. Pinned by `test_skips_cancelled_orders` in Task 4.
3. **Line items with no variant** (custom items, deleted products, old seed orders): skipped, no crash. Pinned by `test_skips_line_items_without_variant` in Task 4.
4. **Variants that do not track inventory**: their stock number is meaningless, so they are left out of the table. Pinned by `test_skips_untracked_variants` in Task 4.
5. **Single-variant products** show Shopify's placeholder `"Default Title"` as the variant name: show `nil` instead so the table reads cleanly. Pinned by `test_default_title_becomes_nil` in Task 4.
6. **Sales late in the shop's evening** (already the next day in UTC): the chart counts them on the shop's date. Pinned by "daily units are counted per shop-local day" in Task 7.
7. **Days with no sales**: shown as zero, so the line has no gaps. Pinned by "daily points end today and fill missing days with zero" in Task 7.

---

## File Map

| File | Responsibility |
|---|---|
| `web/app/services/forecast.rb` | Pure forecast math and sorting. No Shopify code. |
| `web/app/services/shopify_store_data.rb` | GraphQL queries and pagination; turns API responses into plain hashes. |
| `web/app/services/seed_scenario.rb` | The fixed demo scenario as plain data (products, orders). |
| `web/lib/tasks/restock.rake` | `restock:seed` task that writes the scenario to a store. |
| `web/app/controllers/forecasts_controller.rb` | `GET /api/forecast`. |
| `web/config/routes.rb` | Add the route. |
| `web/frontend/pages/index.jsx` | The at-risk table page (replaces the template home page). |
| `web/app/services/sales_history.rb` | Pure grouping of one variant's daily sales into the 7-day, 30-day and 8-week ranges. |
| `web/frontend/components/SalesHistoryModal.jsx`, `SalesChart.jsx`, `web/frontend/utils/fetchJson.js` | The sales history window, its SVG chart, and the shared fetch helper. |
| `web/test/services/*_test.rb`, `web/test/controllers/forecasts_controller_test.rb` | Tests. |
| `shopify.app.toml` | Scopes. |
| `README.md`, `docs/architecture.md`, `docs/study-guide.md`, `docs/demo/` | Docs and demo. |

---

### Task 1: Environment, scaffold, and first install

Muhammad does the steps marked **(you)**; Claude guides and does the rest.

**Files:**
- Create: everything from the template, moved into the repo root
- Create: `docs/study-guide.md`, `.gitignore` (template's)

**Interfaces:**
- Produces: a template app that opens inside the dev store admin; `bin/rails test` runs green.

- [ ] **Step 1 (you): Mac basics.** `xcode-select --install`, install Homebrew, `brew install gh`, `gh auth login` as `PricyK`, set `git config --global user.name` and `user.email`, then `gh repo clone PricyK/restock-forecaster`.
- [ ] **Step 2: Install tools.** Ruby at the version in the template's `.ruby-version` (via `mise`; never the macOS system Ruby), Node LTS, `npm i -g @shopify/cli`, `brew install ffmpeg`.
  Verify: `ruby -v` (not `/usr/bin/ruby`), `node -v`, `shopify version` all print versions.
- [ ] **Step 3 (you): Create a Shopify Partner account and a development store** (no test data option needed). Note the `*.myshopify.com` domain.
- [ ] **Step 4: Scaffold.** `shopify app init --template=https://github.com/Shopify/shopify-app-template-ruby --name restock-forecaster` into a temp folder, then move its contents into the repo root (keep `docs/`). Set scopes in `shopify.app.toml` to `read_products,read_orders,read_inventory,write_products,write_orders,write_inventory`.
- [ ] **Step 5: Install dependencies and set up the database** following the template README (`bundle install`, `npm install` in `web/frontend`, `bin/rails db:create db:migrate`).
- [ ] **Step 6 (you + Claude): First run.** From repo root: `shopify app dev`, log in, pick the dev store, open the install link.
  Expected: the template's home page loads inside the Shopify admin.
- [ ] **Step 7: Check the API version** the template uses (`config/initializers/shopify_app.rb`). If the newest stable version works, use it; otherwise keep the template's. Write the choice in `docs/study-guide.md`.
- [ ] **Step 8: Run template tests.** `bin/rails test` → all pass.
- [ ] **Step 9: Commit.** `git add -A`, `git commit -m "chore: scaffold from Shopify Ruby app template"`.
- [ ] **Step 10: Explain.** Start `docs/study-guide.md` with: what Ruby version managers, Rails, the Shopify CLI, and the template each do; how OAuth install works at a high level; the folder layout. Commit.
- [ ] **Step 11: Push.** Confirm `.gitignore` excludes `.env`, `*.sqlite3`, `node_modules`, `log/`, `tmp/`, then `git push`. The repo is already public.
  Expected: the scaffold shows on GitHub.

**Every later task's last step is `git push`** (not repeated below).

**Fallback trigger:** if Step 6 cannot be made to work within one day, switch to the fallback stack from Global Constraints and note why in the study guide.

---

### Task 2: Forecast class (pure logic)

**Files:**
- Create: `web/app/services/forecast.rb`
- Test: `web/test/services/forecast_test.rb`

**Interfaces:**
- Produces:
  - `Forecast::WINDOW_DAYS = 30`
  - `Forecast.call(variants:, units_sold:, today:) -> Array<Hash>`
    - `variants`: `[{ id: String, product_title: String, variant_title: String|nil, sku: String|nil, inventory: Integer }]`
    - `units_sold`: `{ variant_id(String) => Integer }` (missing key = 0)
    - `today`: `Date`
    - Each returned row: the variant's keys plus `daily_rate: Float` (rounded to 2 places), `days_left: Integer|nil`, `run_out_date: Date|nil`, `risk: String` in `"out_of_stock" | "critical" | "warning" | "ok" | "no_recent_sales"`.
  - Rules: `daily_rate = units / 30.0`; `days_left = (inventory / daily_rate).floor` when rate > 0 and inventory > 0; `run_out_date = today + days_left`; risk uses the floored `days_left`; out of stock (inventory ≤ 0) gives `days_left: 0`, `run_out_date: today`.
  - Sort: out_of_stock first, then `days_left` ascending, then no_recent_sales last; ties by `product_title`.

- [ ] **Step 1: Write the failing tests.** Helper `v(id, inventory)` builds a variant hash with `product_title: id`.

```ruby
TODAY = Date.new(2026, 11, 10)

test "seed scenario rows" do
  rows = Forecast.call(
    variants: [v("A", 0), v("B", 6), v("C", 20), v("D", 100), v("E", 25)],
    units_sold: { "A" => 10, "B" => 60, "C" => 45, "D" => 30 }, today: TODAY)
  by_id = rows.index_by { _1[:id] }
  assert_equal ["out_of_stock", 0], by_id["A"].values_at(:risk, :days_left)
  assert_equal ["critical", 3, Date.new(2026, 11, 13)], by_id["B"].values_at(:risk, :days_left, :run_out_date)
  assert_equal ["warning", 13], by_id["C"].values_at(:risk, :days_left)
  assert_equal ["ok", 100, 1.0], by_id["D"].values_at(:risk, :days_left, :daily_rate)
  assert_equal ["no_recent_sales", nil, nil], by_id["E"].values_at(:risk, :days_left, :run_out_date)
end

test "sort order" do
  # same input as above
  assert_equal %w[A B C D E], rows.map { _1[:id] }
end

test "boundaries use floored days" do
  # rate 2/day (60 units); inventory -> expected risk
  { 14 => "critical", 15 => "critical", 16 => "warning", 28 => "warning", 29 => "warning", 30 => "ok" }.each do |inv, risk|
    row = Forecast.call(variants: [v("X", inv)], units_sold: { "X" => 60 }, today: TODAY).first
    assert_equal risk, row[:risk], "inventory #{inv}"
  end
end

test "negative inventory is out of stock" do
  row = Forecast.call(variants: [v("X", -3)], units_sold: {}, today: TODAY).first
  assert_equal "out_of_stock", row[:risk]
end

test "zero stock and zero sales is out of stock, not no_recent_sales" do
  row = Forecast.call(variants: [v("X", 0)], units_sold: {}, today: TODAY).first
  assert_equal "out_of_stock", row[:risk]
end

test "ties sort by product title" do
  rows = Forecast.call(variants: [v("Zeta", 0), v("Alpha", 0)], units_sold: {}, today: TODAY)
  assert_equal %w[Alpha Zeta], rows.map { _1[:product_title] }
end
```

- [ ] **Step 2: Run and see them fail.** `bin/rails test test/services/forecast_test.rb` → FAIL, `uninitialized constant Forecast`.
- [ ] **Step 3: Implement `Forecast.call`** in `web/app/services/forecast.rb` per the Interfaces block. Sort with a key array: `[rank_of_risk_group, days_left || 0, product_title]` where out_of_stock = 0, dated risks = 1, no_recent_sales = 2.
- [ ] **Step 4: Run tests.** Same command → all PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: add Forecast with risk rules and sorting"`
- [ ] **Step 6: Explain.** Append "Forecast" section to the study guide: Ruby hashes, `Date`, `.floor`, `sort_by`, why the math is isolated from Shopify (easy to test). Commit.

---

### Task 3: Seed scenario and `restock:seed` task

Do this before the API reader so the risky Shopify assumptions (backdated `processedAt`, order rate limit, inventory behaviour) get proven early.

**Files:**
- Create: `web/app/services/seed_scenario.rb`
- Create: `web/lib/tasks/restock.rake`
- Test: `web/test/services/seed_scenario_test.rb`

**Interfaces:**
- Produces:
  - `SeedScenario::TAG = "restock-seed"`
  - `SeedScenario.products -> Array<{ key: String, title: String, inventory: Integer }>`:
    A `"Oat Milk 1L"` 0, B `"Cold Brew Can"` 6, C `"Dark Roast Beans 340g"` 20, D `"Ceramic Mug"` 100, E `"Pour-Over Kettle"` 25.
  - `SeedScenario.orders(now:) -> Array<{ processed_at: Time, lines: Array<{ key: String, quantity: Integer }> }>`:
    10 orders at `now - (3*i + 1.5) days` for i in 0..9. Per order: A 1 qty for 10 orders = 10 total; B 6; C alternates 4 and 5 (45 total); D 3. E never appears.
  - `rake restock:seed SHOP=<domain>.myshopify.com`

- [ ] **Step 1: Write the failing tests.**

```ruby
NOW = Time.utc(2026, 11, 10, 12)

test "orders total match the scenario" do
  totals = SeedScenario.orders(now: NOW).flat_map { _1[:lines] }
    .group_by { _1[:key] }.transform_values { |ls| ls.sum { _1[:quantity] } }
  assert_equal({ "A" => 10, "B" => 60, "C" => 45, "D" => 30 }, totals)
end

test "all orders fall inside the 30 day window" do
  SeedScenario.orders(now: NOW).each do |o|
    assert o[:processed_at] > NOW - 30.days
    assert o[:processed_at] < NOW
  end
end

test "every product has a unique key" do
  assert_equal %w[A B C D E], SeedScenario.products.map { _1[:key] }
end
```

- [ ] **Step 2: Run and see them fail.** `bin/rails test test/services/seed_scenario_test.rb` → FAIL.
- [ ] **Step 3: Implement `SeedScenario`** per the Interfaces block.
- [ ] **Step 4: Run tests** → PASS.
- [ ] **Step 5: Implement `restock:seed`** in `web/lib/tasks/restock.rake`:
  1. Load the shop's stored token from the template's `Shop` model by `SHOP`; build a `ShopifyAPI::Auth::Session` and a GraphQL Admin client. Abort with a clear message if the shop is not installed.
  2. Delete products matching `tag:restock-seed` (`productDelete`).
  3. Create each scenario product with one variant, inventory tracked, quantity set at the store's first location (`productSet` or `productCreate` + `inventorySetQuantities`).
  4. Create each scenario order with `orderCreate`: `processedAt`, line items by variant id, a test/manual transaction marked paid, **inventory behaviour that does not change stock** (bypass).
  5. Sleep between orders to stay under the dev store rate limit; on a throttle error, wait and retry the same order. Print progress.
  `shortcut:` comment on the retry: fixed wait, not exponential; fine for 10 orders.
- [ ] **Step 6: Run against the dev store.** `SHOP=<domain> bin/rails restock:seed`.
  Expected: 5 products in admin with stock 0/6/20/100/25; 10 orders in admin with dates spread over the last 30 days; stock unchanged after orders. If `processedAt` is ignored or stock changes, stop and record what happened in the study guide before adjusting.
- [ ] **Step 7: Run it a second time.** Expected: still exactly 5 seed products (old ones deleted, recreated).
- [ ] **Step 8: Commit.** `git commit -m "feat: add demo seed scenario and restock:seed task"`
- [ ] **Step 9: Explain.** Study guide section: GraphQL mutations, why orders are backdated, why stock is bypassed, the rate limit. Commit.

---

### Task 4: ShopifyStoreData (reading the store)

**Files:**
- Create: `web/app/services/shopify_store_data.rb`
- Test: `web/test/services/shopify_store_data_test.rb`

**Interfaces:**
- Consumes: a GraphQL client responding to `query(query:, variables:)` and returning an object with `.body` (Hash), as `ShopifyAPI::Clients::Graphql::Admin` does.
- Produces:
  - `ShopifyStoreData.new(client)`
  - `#variants -> Array<Hash>` in the exact shape `Forecast.call` expects for `variants:`. Fields queried: variant `id`, `title`, `sku`, `inventoryQuantity`, `inventoryItem { tracked }`, `product { title }`. Page size 250, follow `pageInfo { hasNextPage endCursor }`.
  - `#units_sold(since:) -> Hash<String, Integer>` keyed by variant gid. Orders query `processed_at:>=<since ISO date>`; fields `cancelledAt`, `lineItems { quantity variant { id } }`. Page size 250 orders, line items up to 250 per order. Skips cancelled orders and line items with `variant: nil`.
  - `ShopifyStoreData::Error < StandardError`, raised when the response has top-level GraphQL `errors`.
  - `shortcut:` comments: refunds are not subtracted; line items beyond 250 per order are ignored.

- [ ] **Step 1: Write the failing tests** with a `FakeClient` that returns queued response bodies and records the variables it received.

```ruby
test "maps variants to forecast input" do
  # one tracked variant: id "gid://shopify/ProductVariant/1", title "Large", sku "CB-1",
  # inventoryQuantity 6, product title "Cold Brew Can"
  assert_equal [{ id: "gid://shopify/ProductVariant/1", product_title: "Cold Brew Can",
                  variant_title: "Large", sku: "CB-1", inventory: 6 }], data.variants
end

test "default title becomes nil" do
  # variant title "Default Title"
  assert_nil data.variants.first[:variant_title]
end

test "skips untracked variants" do
  # inventoryItem.tracked false
  assert_empty data.variants
end

test "follows pagination" do
  # page 1: hasNextPage true, endCursor "c1"; page 2: hasNextPage false
  assert_equal 2, data.variants.size
  assert_equal "c1", client.calls.last[:variables][:after]
end

test "sums units per variant across orders" do
  # two orders, variant 1 qty 2 and 3
  assert_equal({ "gid://shopify/ProductVariant/1" => 5 }, data.units_sold(since: Date.new(2026, 10, 11)))
end

test "skips cancelled orders" do
  # second order has cancelledAt set
  assert_equal({ "gid://shopify/ProductVariant/1" => 2 }, data.units_sold(since: Date.new(2026, 10, 11)))
end

test "skips line items without variant" do
  # line item variant nil
  assert_equal({}, data.units_sold(since: Date.new(2026, 10, 11)))
end

test "filters orders by processed_at" do
  data.units_sold(since: Date.new(2026, 10, 11))
  assert_includes client.calls.last[:variables][:query], "processed_at:>=2026-10-11"
end

test "raises on GraphQL errors" do
  # body { "errors" => [{ "message" => "Throttled" }] }
  assert_raises(ShopifyStoreData::Error) { data.variants }
end
```

- [ ] **Step 2: Run and see them fail.** `bin/rails test test/services/shopify_store_data_test.rb` → FAIL.
- [ ] **Step 3: Implement `ShopifyStoreData`** per the Interfaces block. Queries are heredoc strings in the class.
- [ ] **Step 4: Run tests** → PASS.
- [ ] **Step 5: Live check** in `bin/rails console` with the dev store session: `units_sold(since: 30.days.ago.to_date)` matches the seed (A 10, B 60, C 45, D 30 by variant).
- [ ] **Step 6: Commit.** `git commit -m "feat: read variants and recent sales from GraphQL Admin API"`
- [ ] **Step 7: Explain.** Study guide: GraphQL queries vs REST, cursor pagination, gids, why cancelled orders are skipped. Commit.

---

### Task 5: `GET /api/forecast` endpoint

**Files:**
- Create: `web/app/controllers/forecasts_controller.rb`
- Modify: `web/config/routes.rb` (add `get "/api/forecast", to: "forecasts#show"` next to the template's existing `/api` routes)
- Test: `web/test/controllers/forecasts_controller_test.rb`

**Interfaces:**
- Consumes: `ShopifyStoreData` (Task 4), `Forecast` (Task 2).
- Produces: `GET /api/forecast` → `200 { generated_on: "YYYY-MM-DD", rows: [ ...Forecast rows, dates as ISO strings ] }`; on `ShopifyStoreData::Error` or `ShopifyAPI::Errors::HttpResponseError` → `502 { error: "Couldn't load data from Shopify. Try again." }`.
- Inherits from the same authenticated base controller the template's example `ProductsController` uses, and builds its GraphQL client the same way.
- `today = Date.current`. `shortcut:` comment: uses server time zone, not the shop's; fine for a demo.

- [ ] **Step 1: Write the failing tests.** Follow the template's existing controller test for authentication setup. Stub `ShopifyStoreData.new` to return a double.

```ruby
test "returns forecast rows" do
  # double: variants [B-like variant, inventory 6], units_sold { id => 60 }
  get "/api/forecast"
  assert_response :success
  body = JSON.parse(response.body)
  assert_equal "critical", body["rows"].first["risk"]
  assert_equal 3, body["rows"].first["days_left"]
  assert body["generated_on"].match?(/\A\d{4}-\d{2}-\d{2}\z/)
end

test "returns 502 when Shopify fails" do
  # double raises ShopifyStoreData::Error
  get "/api/forecast"
  assert_response 502
  assert_equal "Couldn't load data from Shopify. Try again.", JSON.parse(response.body)["error"]
end

test "passes a 30 day window" do
  # assert double received units_sold(since: Date.current - 30)
end
```

- [ ] **Step 2: Run and see them fail.** `bin/rails test test/controllers/forecasts_controller_test.rb` → FAIL.
- [ ] **Step 3: Implement** the controller and route.
- [ ] **Step 4: Run all tests.** `bin/rails test` → all PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: add /api/forecast endpoint"`
- [ ] **Step 6: Explain.** Study guide: routes → controller → services → JSON; how the session token authenticates the request; why 502. Commit.

---

### Task 6: The at-risk page

**Files:**
- Modify: `web/frontend/pages/index.jsx` (replace template content)
- Delete: template example UI that nothing uses anymore (for example the product-counter card and its `/api/products` route and controller), only if nothing else references them.

**Interfaces:**
- Consumes: `GET /api/forecast` (Task 5), fetched with the template's authenticated query hook (as the template's example card does).
- Produces: the app's home page.

- [ ] **Step 1: Build the page** with Polaris `Page` (title "Restock Forecaster", primary action "Refresh" that refetches), a summary line ("2 critical · 1 warning · 1 out of stock"), and an `IndexTable` (or `DataTable`) with columns Product, Variant, SKU, Stock, Sold/day, Days left, Runs out, Risk. Risk uses `Badge`: out_of_stock `critical` tone "Out of stock", critical `critical` "Critical", warning `warning` "Warning", ok `success` "OK", no_recent_sales no tone "No recent sales". Rows keep the API's order.
  States: loading → `SkeletonBodyText` or spinner; error → `Banner` tone critical with the API's error text and a retry; empty rows → `EmptyState` "No products yet".
- [ ] **Step 2: Manual check** with `shopify app dev`: seeded store shows rows A, B, C, D, E in that order with the expected values from the spec's seed table; Refresh refetches.
- [ ] **Step 3: Remove unused template example code** (if any), run `bin/rails test` → PASS.
- [ ] **Step 4: Commit.** `git commit -m "feat: add at-risk products page"`
- [ ] **Step 5: Explain.** Study guide: React components, props, hooks, how Polaris and App Bridge fit, how the page talks to Rails. Commit.

---

### Task 7: Sales history window

Spec: "Sales history window", the seed bullet about the 6 older orders, and the 30-day definition under "Data".

**Files:**
- Create: `web/app/services/sales_history.rb`, `web/test/services/sales_history_test.rb`
- Create: `web/frontend/utils/fetchJson.js`, `web/frontend/components/SalesChart.jsx`, `web/frontend/components/SalesHistoryModal.jsx`
- Modify: `web/app/services/shopify_store_data.rb`, `web/test/services/shopify_store_data_test.rb`
- Modify: `web/app/controllers/forecasts_controller.rb`, `web/config/routes.rb`, `web/test/controllers/forecasts_controller_test.rb`
- Modify: `web/app/services/seed_scenario.rb`, `web/test/services/seed_scenario_test.rb`, `web/lib/tasks/restock.rake` (its throttle `shortcut:` comment says "10 orders"; make it 16)
- Modify: `web/frontend/pages/index.jsx`, `web/frontend/components/index.js`

**Interfaces:**
- Consumes: `ShopifyStoreData` (Task 4), `ForecastsController` and its tests (Task 5), `Forecast::WINDOW_DAYS` (Task 2), the page (Task 6), `SeedScenario.orders(now:)` (Task 3).
- Produces:
  - `ShopifyStoreData#daily_units(variant_id, since:) -> Hash{Date => Integer}`: one variant's units per shop-local day of the order's `processedAt`. Cancelled orders and lines without a variant are skipped by one private method that `units_sold` also uses. The method looks up the time zone before it reads orders. `units_sold` never looks up the time zone, because its tests queue only order pages. The time zone is memoized (`@time_zone ||=`) and shared with `today`.
  - `SalesHistory.call(daily_units:, today:) -> [{ label: String, points: [{ date: Date, units: Integer }] }]`, with `SalesHistory::DAYS = 56`:
    - Labels and point counts: `"7 days"` 7, `"30 days"` `Forecast::WINDOW_DAYS`, `"8 weeks"` 8.
    - Each weekly point is a 7-day sum, and its `date` is the first day of that week. The last week ends today.
    - A missing day counts as 0, read with `fetch(date, 0)` so a plain Hash works.
  - `GET /api/sales_history?variant_id=<gid>` → `200 { ranges: [...] }`, with dates as ISO strings. With no `variant_id` → 400, from `params.require`. When Shopify fails → the same 502 body as `/api/forecast`, through one `rescue_from ShopifyStoreData::Error, ShopifyAPI::Errors::HttpResponseError` on `ForecastsController`. The action reads `daily_units(variant_id, since: today - (SalesHistory::DAYS - 1))`.
  - `/api/forecast` now counts sales `since: today - (Forecast::WINDOW_DAYS - 1)`, which is 30 days counting today.
  - `fetchJson(url) -> Promise<body>` (in `web/frontend/utils/fetchJson.js`) throws `Error(body.error || FALLBACK_ERROR)` when the response is not OK. It replaces `fetchForecast`.
  - `SalesChart({ points, description })` and `SalesHistoryModal({ row, onClose })`, where `row` is a forecast row or `null`.

- [ ] **Step 1: Same 30 days for the table and the chart.** In `forecasts_controller_test.rb`, change "passes a 30 day window" to expect `since: Date.new(2026, 10, 12)`. Run `bin/rails test test/controllers/forecasts_controller_test.rb` → 1 failure (it gets Oct 11). Change the controller to `since: today - (Forecast::WINDOW_DAYS - 1)`. Run again → PASS.

- [ ] **Step 2: Write the `SalesHistory` tests** in `web/test/services/sales_history_test.rb`, with `TODAY = Date.new(2026, 11, 10)` and the helper `def range(label, daily) = SalesHistory.call(daily_units: daily, today: TODAY).find { _1[:label] == label }[:points]`:

```ruby
test "has three ranges of 7, 30 and 8 points" do
  ranges = SalesHistory.call(daily_units: {}, today: TODAY)
  assert_equal ["7 days", "30 days", "8 weeks"], ranges.map { _1[:label] }
  assert_equal [7, 30, 8], ranges.map { _1[:points].size }
end

test "daily points end today and fill missing days with zero" do
  week = range("7 days", { TODAY => 4, TODAY - 2 => 1 })
  assert_equal TODAY - 6, week.first[:date]
  assert_equal [0, 0, 0, 0, 1, 0, 4], week.map { _1[:units] }
end

test "30 day range starts 29 days before today" do
  assert_equal Date.new(2026, 10, 12), range("30 days", {}).first[:date]
end

test "weeks are 7 day totals and the last one ends today" do
  weeks = range("8 weeks", { TODAY => 2, TODAY - 6 => 3, TODAY - 7 => 5, TODAY - 55 => 1, TODAY - 56 => 100 })
  assert_equal({ date: TODAY - 6, units: 5 }, weeks.last)
  assert_equal 5, weeks[-2][:units]
  assert_equal({ date: TODAY - 55, units: 1 }, weeks.first)
  assert_equal 11, weeks.sum { _1[:units] } # TODAY - 56 is outside the 8 weeks
end
```

- [ ] **Step 3: Run them.** `bin/rails test test/services/sales_history_test.rb` → FAIL (`NameError: uninitialized constant SalesHistory`).
- [ ] **Step 4: Implement `SalesHistory < ApplicationService`** in `web/app/services/sales_history.rb`, with no Shopify code (like `Forecast`). Run again → 4 PASS.

- [ ] **Step 5: Write the `daily_units` tests** in `shopify_store_data_test.rb`. Give the `order` helper a `processed_at: "2026-11-05T15:00:00Z"` keyword that it puts under `"processedAt"`. Add `SHOP_NY = { "data" => { "shop" => { "ianaTimezone" => "America/New_York" } } }` and reuse it in the existing "today" test.

```ruby
test "daily units are counted per shop-local day" do
  use SHOP_NY, orders_page([order([[V1, 2]], processed_at: "2026-11-06T02:00:00Z"), # 9 p.m. Nov 5 in New York
                            order([[V1, 1], [V2, 7]])])
  assert_equal({ Date.new(2026, 11, 5) => 3 }, data.daily_units(V1, since: SINCE))
end

test "daily units skip cancelled orders" do
  use SHOP_NY, orders_page([order([[V1, 2]], cancelled_at: "2026-11-05T16:00:00Z")])
  assert_equal({}, data.daily_units(V1, since: SINCE))
end

test "looks up the time zone once" do
  use SHOP_NY, orders_page([])
  store = data
  store.today
  store.daily_units(V1, since: SINCE)
  assert_equal 1, client.calls.count { _1[:query].include?("ianaTimezone") }
end
```

- [ ] **Step 6: Run them.** `bin/rails test test/services/shopify_store_data_test.rb` → the 3 new tests FAIL (`NoMethodError: daily_units`).
- [ ] **Step 7: Implement** per the Interfaces block:
  - Add `processedAt` to `ORDERS_QUERY`'s order nodes.
  - Add the shared private method that returns the sold lines.
  - Memoize the time zone.
  - Give `daily_units` this comment: `# shortcut: reads every order since \`since\` to chart one variant, filter or cache if order volume grows.`

  Run the file again → all PASS, the old tests included.

- [ ] **Step 8: Write the endpoint tests** in `forecasts_controller_test.rb`. The setup's `@data` stub gains `daily_units: { Date.new(2026, 11, 10) => 6 }`.

```ruby
test "returns sales history" do
  get "/api/sales_history", params: { variant_id: VARIANT[:id] }
  assert_response :success
  ranges = JSON.parse(response.body)["ranges"]
  assert_equal ["7 days", "30 days", "8 weeks"], ranges.map { _1["label"] }
  assert_equal({ "date" => "2026-11-10", "units" => 6 }, ranges.first["points"].last)
end

test "sales history reads 8 weeks for the requested variant" do
  @data.expects(:daily_units).with(VARIANT[:id], since: Date.new(2026, 9, 16)).returns({})
  get "/api/sales_history", params: { variant_id: VARIANT[:id] }
  assert_response :success
end

test "sales history needs a variant_id" do
  get "/api/sales_history"
  assert_response :bad_request
end

test "sales history returns 502 when Shopify fails" do
  @data.stubs(:daily_units).raises(ShopifyStoreData::Error, "Throttled")
  get "/api/sales_history", params: { variant_id: VARIANT[:id] }
  assert_response 502
  assert_equal "Couldn't load data from Shopify. Try again.", JSON.parse(response.body)["error"]
end
```

- [ ] **Step 9: Run them.** `bin/rails test test/controllers/forecasts_controller_test.rb` → the 4 new tests FAIL, because there is no route yet and the catch-all route answers instead.
- [ ] **Step 10: Implement:**
  - Add `get "/sales_history", to: "forecasts#sales_history"` inside the `scope path: :api` block.
  - Add a `sales_history` action whose Shopify calls sit inside `with_token_refetch`.
  - Add a private `store_data` that builds the client for both actions.
  - Replace the `rescue` in `show` with `rescue_from ... with: :shopify_failed`.

  Run the file again → all PASS, including the old 502 and 401-retry tests.

- [ ] **Step 11: Seed the older orders.** In `seed_scenario_test.rb`:
  - Add a helper `recent(orders)` that keeps orders whose `processed_at.to_date >= NOW.to_date - (Forecast::WINDOW_DAYS - 1)`.
  - Add a `totals(orders)` helper, made from the existing group-and-sum code.
  - Change the tests as below.
  - "seeded stock and sales give the spec's forecast" now sums `recent(...)` only.

```ruby
test "orders total match the scenario" do
  orders = SeedScenario.orders(now: NOW)
  assert_equal({ "A" => 10, "B" => 60, "C" => 45, "D" => 30 }, totals(recent(orders)))
  assert_equal({ "A" => 16, "B" => 78, "C" => 63, "D" => 48, "E" => 12 }, totals(orders))
end

test "10 orders in the 30 day window and 6 older ones inside 8 weeks" do # replaces "all orders fall inside the 30 day window"
  orders = SeedScenario.orders(now: NOW)
  assert_equal [10, 16], [recent(orders).size, orders.size]
  assert(orders.all? { _1[:processed_at].to_date >= NOW.to_date - (SalesHistory::DAYS - 1) && _1[:processed_at] < NOW })
end
```

  Run `bin/rails test test/services/seed_scenario_test.rb` → FAIL (the 8-week totals are missing). Then:
  - Add 6 orders to `SeedScenario.orders`, at `now - (33.5 + 4 * j).days` for `j` = 0 to 5, with lines A 1, B 3, C 3, D 3, E 2.
  - Fix its comments ("E" now sells only in the older orders).
  - Change the rake comment to 16 orders.

  Run again → PASS.

- [ ] **Step 12: Full suite.** `bin/rails test` → 44 runs, 0 failures. Commit: `git commit -m "feat: add /api/sales_history endpoint"`.

- [ ] **Step 13: Frontend.** Read the `dataviz` skill before writing the chart.
  - `utils/fetchJson.js`: move `FALLBACK_ERROR`, the App Bridge comment, and the body of `fetchForecast` here as `export async function fetchJson(url)`. `index.jsx` uses `queryFn: () => fetchJson("/api/forecast")`.
  - `components/SalesChart.jsx` is an inline SVG with no chart library:
    - Attributes: `viewBox`, `width="100%"`, `role="img"`, `aria-label={description}`.
    - One line through all the points.
    - Y-axis labels at 0 and at the top value.
    - X-axis labels at the first, middle and last dates ("Oct 30"), formatted in UTC like `formatDate`.
    - Every colour is a Polaris CSS variable, so a dark theme only has to swap the variables: `var(--p-interactive)` for the line, `var(--p-text-subdued)` for the labels, `var(--p-border-subdued)` for the gridlines. No hex values.
  - `components/SalesHistoryModal.jsx` is a Polaris `Modal`:
    - Props: `small`, `open={Boolean(row)}`, and a title of the product title, plus " – <variant title>" when there is one.
    - Data: `useQuery(["sales_history", row?.id], () => fetchJson(...), { enabled: Boolean(row), retry: false, refetchOnWindowFocus: false })`, with the variant id passed through `encodeURIComponent`.
    - States: loading shows `SkeletonBodyText`. An error shows a critical `Banner` with the message and Retry.
    - With data: a `Text` line "Sold: 12 in 7 days · 60 in 30 days · 78 in 8 weeks" (the sum of each range), Polaris `Tabs` with the three labels, and a `SalesChart` for the selected tab. Its description reads "Units sold per day, Oct 30 to Nov 5: 12 in total." and says "per week" on the 8-week tab.
  - `components/index.js` exports both components.
  - `index.jsx`:
    - Wrap each badge in `UnstyledButton` with `accessibilityLabel={`${badge.label}: sales history for ${row.product_title}`}`. The label keeps the risk word, which `aria-label` would otherwise hide.
    - Clicking the button calls an `onSelect(row)` prop on `ForecastTable`.
    - `HomePage` keeps `selected` in `useState(null)` and renders `<SalesHistoryModal row={selected} onClose={() => setSelected(null)} />`.
  - Verify from `web/frontend`: `npm run build` → builds, and `npx prettier --check pages components utils` → clean. Commit: `git commit -m "feat: add sales history window"`.

- [ ] **Step 14: Manual check (Muhammad).**
  - Claude first re-seeds: `env $(shopify app env show | grep =) bin/rails restock:seed SHOP=ridgeline-coffee-co-3j14nuup.myshopify.com`. That's 16 orders, about 4 minutes.
  - Muhammad then opens the app with `shopify app dev` and checks:
    - The table still matches the spec's seed table.
    - Cold Brew Can's badge opens a "Cold Brew Can" window reading "Sold: 12 in 7 days · 60 in 30 days · 78 in 8 weeks", and its 8-week line rises.
    - Pour-Over Kettle's window reads "Sold: 0 in 7 days · 0 in 30 days · 12 in 8 weeks", and its 8-week line ends at zero.
    - Each of the three tabs switches the chart.
    - The X and the Escape key both close the window.
    - The Tab key reaches a badge, and Enter opens it.
  - These values hold on the seed day only.

- [ ] **Step 15: Review and explain.**
  - Run `ponytail:ponytail-review` on the task's commits.
  - Add a study guide section covering:
    - the second action and `rescue_from`
    - `SalesHistory`
    - the time-zone memo
    - why 8 weeks (the 60-day order limit)
    - how the SVG chart turns numbers into positions
    - the modal and tabs
    - `fetchJson`
  - Commit, push `dev`, and merge per Global Constraints.

---

### Task 8: Dev testing on the store

**Files:**
- Create: `docs/testing.md` (checklist with results and date)

- [ ] **Step 1: Fresh install.** Uninstall and reinstall the app on the dev store; run `restock:seed`. Expected: table matches the spec's seed table, and Cold Brew's sales window reads "Sold: 12 in 7 days · 60 in 30 days · 78 in 8 weeks".
- [ ] **Step 2: Live sale.** In admin, create an order for 3 × "Cold Brew Can" and mark it paid. Refresh. Expected: stock 3, sold/day 2.1, days left 1, still critical; its sales window shows 15 in 7 days.
- [ ] **Step 3: Restock.** Set "Dark Roast Beans 340g" stock to 100. Refresh. Expected: risk changes from warning to ok.
- [ ] **Step 4: Empty state.** On a second dev store with no products, install and open. Expected: "No products yet".
- [ ] **Step 5: Error state.** Temporarily make the endpoint raise (or stop the backend). Expected: error banner, no crash; then revert.
- [ ] **Step 6: Full test suite.** `bin/rails test` → all PASS. Record counts in `docs/testing.md`.
- [ ] **Step 7: Whole-repo audit.** Run `ponytail:ponytail-audit`. Record findings and decisions in `docs/testing.md`.
- [ ] **Step 8: Fix** anything that failed or that the audit found, with a regression test where the fix touches Ruby code. Re-run `bin/rails test` → PASS. Commit: `git commit -m "test: record dev testing and audit results"`.

---

### Task 9: Documentation

**Files:**
- Create/replace: `README.md`
- Create: `docs/architecture.md`
- Finish: `docs/study-guide.md`

- [ ] **Step 1: README** with: one-paragraph pitch (the store-manager story), GIF placeholder, features, how it works (short flow), forecast rules table, setup from a clean Mac (Homebrew → Ruby via mise → Node → Shopify CLI → Partner account → `shopify app dev` → `restock:seed`), running tests, known limitations (generated from `ponytail:ponytail-debt`, plus no hosting).
- [ ] **Step 2: architecture.md** with: request flow diagram (Mermaid), the two GraphQL queries with their fields, why computed on request (no webhooks or jobs), why 30 days, error handling.
- [ ] **Step 3: Study guide pass.** Reorder sections to follow a request (admin → React page → route → controller → services → Shopify). Add 10 to 15 likely interview questions with answers that point to specific files.
- [ ] **Step 4: Check** every claim in README against the code (no invented numbers). Commit: `git commit -m "docs: README, architecture, study guide"`.

---

### Task 10: Demo

**Files:**
- Create: `docs/demo/script.md`, `docs/demo/demo.gif`
- Video file stays out of git (link from README once uploaded); add its pattern to `.gitignore`.

- [ ] **Step 1: Write `docs/demo/script.md`:** a shot list for 1 to 2 minutes: products page in admin → open app → walk the table top to bottom → click Cold Brew's badge and switch to 8 weeks → create a 3-unit Cold Brew order → Refresh → numbers change → close on the README.
- [ ] **Step 2: Re-seed** on recording day.
- [ ] **Step 3 (you): Record** following the script (macOS Screenshot toolbar, Cmd+Shift+5, "Record Selected Portion").
- [ ] **Step 4: Make the GIF** from the video with `ffmpeg` (about 15 seconds of the table and refresh, 960 px wide, under 10 MB). Put it in the README. Commit.

---

### Task 11: Publish and update the resume

**Files:**
- Modify: the resume generator script on the Windows PC at `C:\Users\Moe\Documents\Resumes\Muhammad\generator\build2.js` (run `node build2.js "<output>.docx"` there), its output `Muhammad Waheed Resume 2026.docx` and `.pdf`. It holds personal contact info, so it never goes in this public repo. Do this step on the PC, or copy the folder to the Mac privately.

- [ ] **Step 1: Make sure the repo is public** (ask Muhammad first if it was created private); it must be public to link from the resume.
- [ ] **Step 2 (you): Upload the demo video** (YouTube unlisted or similar) and give Claude the link; add it to the README. Commit and push.
- [ ] **Step 3: Resume entry.** Replace "Socket-based Snake Game" with "Restock Forecaster | *Ruby on Rails, React, GraphQL, Polaris, Shopify Admin API* | GitHub", dated Nov 2026. Bullets must only state what the code does, for example: embedded Shopify app forecasting stock-outs from 30-day sales velocity; GraphQL Admin API with cursor pagination; Minitest suite (state the real test count from `docs/testing.md`); seed task that builds a reproducible demo store. Rebuild and export; confirm it is still one page.
- [ ] **Step 4: Show Muhammad** the final resume and README. Done.

---

## Schedule (target)

| Dates | Tasks |
|---|---|
| Nov 5 | 1 to 6 (done) |
| Nov 6 to 13 | 7 |
| Nov 14 to 16 | 8 |
| Nov 17 to 19 | 9, 10 |
| Nov 20 to 21 | 11 |
| Nov 22 to Dec 1 | Buffer |
