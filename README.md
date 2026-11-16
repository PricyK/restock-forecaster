# Restock Forecaster

A Shopify app that tells a store owner which products are about to run out.

Picture a small coffee shop that sells online through Shopify. The owner reorders every week or two, and the costly mistake is finding out too late that the cold brew is nearly gone. Restock Forecaster opens inside the Shopify admin, reads the store's stock and the last 30 days of sales, and labels every product Out of stock, Critical, Warning, OK, or No recent sales. Clicking a product's badge shows its sales over the last week, month and 8 weeks, and roughly how many days of stock it has left.

<!-- Demo GIF goes here (added with the demo recording). -->

## Features

- An at-risk table of every product that tracks inventory, with its category, SKU, stock and a coloured risk badge. The most urgent rows come first.
- Summary boxes that count the Out of stock, Critical and Warning products. Clicking a box filters the table to those rows.
- A sales history window for each product. It opens with a line like "About 3 days of stock left" in the risk's colour, then charts units sold over the last 7 days, 30 days or 8 weeks. The app draws the chart itself in SVG, with descriptions for screen readers, and hovering a point shows its value. Today's point is hollow and joined by a dashed line, since the day isn't over yet.
- Live data. The page reads everything from Shopify's GraphQL Admin API when it loads or when you press Refresh, and the app keeps no copy of the sales.
- Demo data in one command: `bin/rails restock:seed` fills a development store with 13 products and 38 backdated orders that cover every risk level.

## How it works

1. The app opens inside the Shopify admin. Shopify's App Bridge gives the page a session token that proves which store is asking.
2. The React page calls the Rails endpoint `GET /api/forecast`.
3. Rails asks Shopify's GraphQL Admin API for every active product variant that tracks inventory, and for the orders of the last 30 days, page by page.
4. A plain Ruby class, `Forecast`, works out each variant's daily sales rate, days of stock left and risk level, and the page draws the table.
5. Clicking a badge calls `GET /api/sales_history`, which groups one variant's sales by day in the store's time zone.

[docs/architecture.md](docs/architecture.md) has a diagram of this flow and the exact GraphQL queries.

### The forecast rules

| Step | Rule |
|---|---|
| Daily rate | Units sold in the last 30 days (today and the 29 days before it) ÷ 30 |
| Days left | Stock ÷ daily rate, rounded down |
| Out of stock | Stock is 0 or less |
| Critical | 7 days left or fewer |
| Warning | 8 to 14 days left |
| OK | More than 14 days left |
| No recent sales | Nothing sold in 30 days, so there's no estimate |

## Tech stack

- Backend: Ruby 3.3, Ruby on Rails 7.1, the `shopify_app` gem, Shopify GraphQL Admin API (version `2026-10`), and SQLite, which only holds the store's login session
- Frontend: React 18, TypeScript in strict mode, Shopify Polaris, App Bridge, react-query, Vite
- Tests: Minitest with mocha and webmock, a smoke test that renders the page, `tsc` type checking, and RuboCop with Shopify's rules

The project started from Shopify's official [Ruby app template](https://github.com/Shopify/shopify-app-template-ruby).

## Running it locally

You need a Mac (these steps were written on one), a free [Shopify Partner account](https://partners.shopify.com/signup), and a development store created from it.

1. Install [Homebrew](https://brew.sh), then the tools:

   ```sh
   brew install mise
   echo 'eval "$(mise activate zsh)"' >> ~/.zshrc   # then open a new Terminal window
   mise use --global ruby@3.3.0 node@lts
   npm install -g @shopify/cli@latest
   ```

2. Get the code and install its libraries:

   ```sh
   git clone https://github.com/PricyK/restock-forecaster.git
   cd restock-forecaster/web
   bundle install
   bin/rails db:create db:migrate
   (cd frontend && npm install)
   cd ..
   ```

3. Start the app from the repository's root folder:

   ```sh
   shopify app dev
   ```

   The first time, the CLI asks you to log in, choose your Partner organization, create the app and pick your development store. When it's ready, press `p` to open the app in your store's admin and install it.

4. Let the app read orders. Orders contain customer details, so Shopify only allows it after the developer says why the app needs them. In the Partner Dashboard, open the app's API access requests, then Protected customer data access, and declare that the app reads order data.

5. Fill the store with demo data. With the app installed, run this from the `web` folder. It takes about 8 minutes, because development stores accept about 5 new orders a minute.

   ```sh
   env $(cd .. && shopify app env show | grep =) bin/rails restock:seed SHOP=your-store.myshopify.com
   ```

   The sales are backdated from the day you run it, so the numbers drift as the days pass. Run it again whenever you want a fresh demo.

## Tests and checks

From the `web` folder:

```sh
bin/rails test              # 47 Ruby tests: forecast math, Shopify reading, endpoints, seed, webhooks
bundle exec rubocop         # Shopify's Ruby style rules
cd frontend
npm run typecheck           # TypeScript in strict mode
npm run smoke               # draws the page and chart outside the browser and checks the result
```

[docs/testing.md](docs/testing.md) records how I tested the app on a real development store, step by step, with the results.

## Known limitations

- There's no hosting. The app runs from a laptop through `shopify app dev`, it isn't on the Shopify App Store, and I've only tested it with one store at a time.
- The forecast is a simple average, so it assumes steady demand. A product whose sales are climbing will run out sooner than shown. It doesn't know supplier lead times either, and days when a product was out of stock count as zero sales, which drags its average down.
- Refunded sales still count, so a returned item still raises the rate.
- The chart goes back 8 weeks rather than a year, because apps can only read the last 60 days of orders unless Shopify approves the `read_all_orders` permission.
- Each click on a badge reads every order from the last 8 weeks and keeps one product's lines. A small store handles that easily; a large one would need a narrower query or a cache.
- Line items after the 250th in a single order are ignored.
- When the seed task hits Shopify's rate limit, it waits a fixed 60 seconds and tries up to 3 times.

## How it was built

I built this with [Claude Code](https://claude.com/claude-code) as an AI pair programmer. I made the product and design decisions, checked every feature in the Shopify admin, and tested it on a real development store. The design spec and the step-by-step plan are in [docs/superpowers](docs/superpowers), and [docs/study-guide.md](docs/study-guide.md) explains every file and decision in plain English.

## License

[MIT](LICENSE).
