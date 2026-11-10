# Restock Forecaster: Design

Date: 2026-11-05
Owner: Muhammad F. Waheed
Status: Approved 2026-11-05

## 1. Intent

A small embedded Shopify app that tells a store manager which products are about to run out. It reads recent sales and current stock from a Shopify store, works out how fast each product variant sells, and lists the variants at risk, sorted by how soon they run out.

### Why

This is a portfolio project for the Shopify Software Engineering internship postings expected in early December 2026. It exists to:

- Back up the Rails, React, and GraphQL skills on the resume with real, explainable work.
- Tie into Muhammad's own story: he managed a retail store (Underground Vapes, Oct 2024 to Mar 2025) on Shopify POS, where running out of popular products is a real problem.
- Produce a GitHub repo, a demo video, and a resume bullet by **Dec 1, 2026**.

Success means an interviewer can watch a 1 to 2 minute demo, open the repo, read a clear README, and Muhammad can explain every part of the code himself.

## 2. Goals

1. An embedded app that opens inside the Shopify admin of a development store.
2. One page: an "at-risk products" table showing, per variant, its category, SKU, stock on hand, and a risk badge. (Changed 2026-11-05 at Muhammad's request: the sold/day, run-out date and days-left columns were removed as clutter, and a Category column was added. The forecast still computes all three, and the risk badge is based on days left.)
3. Data comes live from the Shopify GraphQL Admin API each time the page loads or the user presses Refresh.
4. A repeatable seed script that fills a development store with products and backdated orders forming a known scenario, so the demo always shows a mix of risk levels.
5. Automated tests for the forecasting logic and the API endpoint.
6. Documentation: README, architecture notes, a demo video, and a GIF in the README.
7. Clicking a row's risk badge opens a small window with that variant's units sold over the last 7 days, 30 days and 8 weeks, as a line chart (added 2026-11-05 at Muhammad's request; see "Sales history window").
8. (Dropped 2026-11-10 at Muhammad's request: a dark mode toggle was built, then removed before merging.)

## 3. Non-goals (agreed cuts)

- No paid hosting and no production deployment. The app runs locally through the Shopify CLI tunnel. "Prod testing" from the original request is dropped by agreement.
- No reorder list or supplier purchase orders.
- No webhooks, background jobs, or stored forecasts. Forecasts are computed on request.
- No Shopify App Store listing, billing, or multi-merchant support.
- No supplier lead times, email digests, or Shopify POS UI extension.

## 4. Anti-goals (would make this a failure even if it works)

- Code Muhammad cannot explain line by line in an interview. He has little or no prior Ruby, Rails, or React experience.

### How the code gets written (decided by Muhammad)

Claude writes the code. Muhammad studies it afterwards. So:

- Each completed task ends with a short plain-English explanation of what was added and why, covering any Ruby, Rails, React, or Shopify concept it introduces.
- The repo includes `docs/study-guide.md`: a walkthrough of every file Claude wrote or changed, in the order a request flows through the app, plus likely interview questions with answers grounded in this code.
- Code stays simple enough to study: small files, clear names, no clever tricks.
- A demo that depends on luck, such as an empty store or random data that shows nothing at risk.
- Claims in the README or resume that the code does not back up, such as "production-grade", "scalable", or invented metrics.
- Over-engineering: abstractions, configuration, or features beyond the one page above.

## 5. Constraints

- **Deadline:** working, documented, and recorded by Dec 1, 2026. Target finish around Nov 19 to 21, leaving a buffer.
- **Cost:** $0. Shopify Partner account and development stores are free.
- **Machine:** Muhammad's MacBook (moved from the Windows PC on 2026-11-05). Assume nothing is installed yet.
- **Stack (decided):** Shopify's official Ruby app template (`Shopify/shopify-app-template-ruby`): Rails backend using the `shopify_app` gem, React frontend with Polaris and App Bridge, SQLite for session storage. Checked on 2026-11-05 through the GitHub API: neither repo is archived, the template was last pushed 2026-10-30 and the gem 2026-11-02.
- **Fallback if the template will not run** with the current Shopify CLI: keep Rails and the `shopify_app` gem, and drop the template's wiring in favour of a small hand-built React (Vite) frontend with Polaris and App Bridge. If the latest API version breaks the template, use the newest version the template supports. Rails must stay, because the resume needs it.
- **API:** Shopify GraphQL Admin API only (no REST), using a current stable API version.

## 6. How it works

### Data

- **Stock:** for each product variant, total `inventoryQuantity` (summed across locations).
- **Sales:** units sold per variant in the last 30 days, from orders' line items. "Last 30 days" means today and the 29 days before it, so the table and the sales history window count the same days.
- **Category:** the product's Shopify product type (`productType`), shown as "—" when the merchant set none.
- **Access scopes:** `read_products`, `read_orders`, `read_inventory` for the app; `write_products`, `write_orders`, `write_inventory` only as needed by the seed script.

### Forecast rules

All values are per variant.

- `daily_rate = units_sold_last_30_days / 30`
- `days_left = inventory / daily_rate` (only when `daily_rate > 0`)
- `run_out_date = today + days_left`, rounded down to a whole day
- Risk:
  - **Out of stock:** inventory is 0 or less
  - **Critical:** days_left is 7 or less
  - **Warning:** days_left is more than 7 and up to 14
  - **OK:** days_left is more than 14
  - **No recent sales:** daily_rate is 0 and inventory is more than 0 (no run-out date)
- Sort: out of stock first, then by days_left ascending, then no recent sales last.

The forecasting logic lives in one plain Ruby class with no Shopify dependency, so it can be unit-tested with plain inputs.

### Request flow

1. Merchant opens the app in the Shopify admin. The template handles OAuth and the session.
2. The React page calls the app's backend endpoint (for example `GET /api/forecast`) through the template's authenticated fetch.
3. The Rails controller queries the GraphQL Admin API for variants with inventory and for orders from the last 30 days, passes the results to the forecast class, and returns JSON.
4. The page renders a Polaris table with risk badges and a Refresh button, plus loading, empty, and error states.

The table shows every variant, not only at-risk ones, so the sort order puts the at-risk rows on top. The empty state means "this store has no products". Above the table, three equal boxes show how many rows are out of stock, critical and warning, in that order, each under the same badge the table uses (changed 2026-11-05 at Muhammad's request; it replaced a one-line summary). "Out of stock" uses Polaris's strong red so it stands apart from "Critical". Hovering a badge deepens its colour. Clicking a box shows only that risk's rows, and clicking it again shows all. A box with a count of 0 can't be clicked. If a refresh drops the selected risk's count to 0, the filter clears, so the table never shows empty.

### Sales history window

What the merchant sees:

- Each risk badge is a button, labelled for screen readers with its risk and product, for example "Critical: sales history for Cold Brew Can" (the label replaces the badge text, so it must keep the risk word).
- Clicking it opens a small Polaris `Modal` titled with the product (and variant) name. The modal's X and the Escape key close it. An expand / shrink icon button beside the X (two corner triangles, like the macOS full-screen button) switches between Polaris's small and large sizes (added 2026-11-05 at Muhammad's request); the large size redraws the chart in a wider drawing area, so labels keep their size.
- The window's first line gives the forecast's days left in words: "About 3 days of stock left.", "Less than a day of stock left.", "Out of stock now.", or "No sales in the last 30 days, so no run-out estimate." (added 2026-11-05, since the table has no Days left column). It sits in a bubble of the row's risk colour, the same badge the table shows (2026-11-10).
- Under the chart, the selected tab's total, for example "19 sold in the last 7 days" (changed 2026-11-05 at Muhammad's request; it replaced a line listing all three totals).
- Three tabs, **7 days**, **30 days** and **8 weeks**, switch a line chart: dates on the x-axis, units sold on the y-axis. The 7- and 30-day tabs have one point per day. The 8-week tab has one point per week, and each week is a full 7 days ending today.
- The chart's last point is today (or the week that includes today), which is still counting, so its segment is dashed and its tooltip says "so far".
- The chart is a small SVG drawing written in the app, with no chart library. It has `role="img"` and a one-sentence description (range and total) for screen readers.
- While loading, the modal shows a placeholder. On failure it shows the error message and a Retry button.

How it works:

- `GET /api/sales_history?variant_id=<variant gid>` is a second action on `ForecastsController`. Both actions share one `rescue_from` that returns the same 502 and message as the forecast. A missing `variant_id` gets Rails' standard 400 via `params.require`. The id is not format-checked, because it is only compared against ids that Shopify returns and is never sent anywhere. An unknown id gives all zeros.
- `ShopifyStoreData` gains a method that returns one variant's units per day, using the shop's time zone and the order's `processedAt`. It shares one private method with `units_sold`, so both apply the same rules (skip cancelled orders and lines without a variant). The shop's time zone is looked up once per request and reused.
- A small plain Ruby class, `SalesHistory`, turns those daily counts into the three ranges and fills days with no sales with zero. Like `Forecast`, it has no Shopify dependency.
- Response:

  ```json
  { "ranges": [
    { "label": "7 days",  "points": [{ "date": "2026-10-30", "units": 0 }] },
    { "label": "30 days", "points": [{ "date": "2026-10-07", "units": 6 }] },
    { "label": "8 weeks", "points": [{ "date": "2026-09-11", "units": 9 }] }
  ] }
  ```

  The 7-day range has 7 points and the 30-day range has 30. The 8-week range has 8 points, and each point's `date` is the first day of its week. The frontend adds up the selected range for the line under the chart.
- Each click fetches every order from the last 8 weeks and keeps only that variant's lines. The code marks this as a `shortcut:` comment (fine for a development store; filter or cache if order volume grows).
- The longest range is 8 weeks, not a year, because `read_orders` only returns the last 60 days. A year would need the `read_all_orders` scope, which needs Shopify's approval for Partner apps. Muhammad chose not to request it (2026-11-05).

### Seed scenario

A script, run against the development store, creates a small product set and backdated orders (`processedAt` in the past) so the results are predictable. At minimum:

| Variant | Stock | Units sold in last 30 days | Expected result |
|---|---|---|---|
| A | 0 | any | Out of stock |
| B | 6 | 60 (2/day) | Critical, 3 days left |
| C | 20 | 45 (1.5/day) | Warning, 13 days left |
| D | 100 | 30 (1/day) | OK, 100 days left |
| E | 25 | 0 | No recent sales |

Categories (product types): A Milk, B and C Coffee, D and E Equipment.

Extra products, so each risk level has two or three rows in the demo (added 2026-11-05 at Muhammad's request). They sell evenly every day:

| Product | Category | Stock | Units sold in last 30 days | Expected result |
|---|---|---|---|---|
| F Almond Milk 1L | Milk | 0 | 24 | Out of stock |
| G Espresso Beans 1kg | Coffee | 5 | 30 | Critical, 5 days left |
| H Paper Filters 100 Pack | Equipment | 12 | 60 | Critical, 6 days left |
| I Earl Grey Tea 20 Bags | Tea | 10 | 30 | Warning, 10 days left |
| J Barista Oat Milk 1L | Milk | 18 | 45 | Warning, 12 days left |
| K Travel Tumbler | Equipment | 40 | 30 | OK, 40 days left |
| L Decaf Beans 340g | Coffee | 30 | 15 | OK, 60 days left |
| M Milk Frother | Equipment | 8 | 0 (sold only in the older orders) | No recent sales |

The summary boxes read Out of stock 2, Critical 3, Warning 3. The same tables double as the expected values for a manual check.

Seed details:

- One order on each of the 30 days in the window: at noon shop time, and today's at midnight so it is never in the future. Each product's units per day are fixed in `SeedScenario::DAILY`: Cold Brew climbs, Dark Roast has a weekly hump, the mug is flat, and Oat Milk climbs then drops to zero when it sold out. Their totals give the table above. Fixed times mean the day each sale lands on never depends on when the seed runs, and selling today keeps the charts from ending in a drop to 0. Backdated sales age out of the window, so the expected values only hold on the day of seeding. Re-seed on testing and recording days.
- For the 8-week chart, the seed also creates 8 older orders, two a week from 54 to 30 days back, with A 4, B 3, C 3, D 3 and E 2 units each. They fall outside the 30-day window, so the table above does not change. Pour-Over Kettle (E) only sells in these older orders, so its "No recent sales" chart shows sales that stopped. Expected totals for 7 days / 30 days / 8 weeks: Cold Brew 20 / 60 / 84 (weekly 6, 6, 6, 8, 9, 13, 16, 20), Pour-Over Kettle 0 / 0 / 16. The seed creates 38 orders and takes about 8 minutes.
- Repeatable means: the seed first deletes the products it created before (identified by a product tag, for example `restock-seed`), then recreates them. Old seed orders stay in the store, but they point at deleted variants, so the forecast ignores them. No order cleanup needed.
- Use quantities above 1 per order and throttle requests. Development stores rate-limit order creation (roughly 5 orders a minute; check the current limit).
- `orderCreate` accepts `processedAt`, but `createdAt` is the seed time. The forecast's order query must filter on `processed_at`, not `created_at`.
- `read_orders` returns the last 60 days of orders, which covers the 30-day window and the 8-week chart.

## 7. Testing

### Dev testing (automated)

- Unit tests (the template's Minitest) for the forecast class: each risk level, the boundary values 7 and 14, zero sales, zero and negative stock, and sort order.
- A controller or request test with the Shopify GraphQL call stubbed, checking the JSON shape and the error response when Shopify fails.
- Sales history: `SalesHistory` (zero-filled days, range lengths, weekly totals, weeks ending today), the daily-units method (shop time zone, cancelled orders skipped, other variants ignored), and the new action (JSON shape, 400 without `variant_id`, 502 when Shopify fails). The seed tests cover the older orders staying outside the 30-day window.

### Dev testing (manual, on the development store)

- Install the app on a fresh development store, run the seed script, and confirm the table matches the seed scenario table.
- Record a new sale for a variant in the admin, press Refresh, and confirm its numbers change.
- Check the empty state (store with no products) and the error state (for example, a revoked token).
- Open the sales history window for Cold Brew and Pour-Over Kettle, switch all three tabs, and confirm the totals match the seed.

## 8. Documentation and demo

- **README:** what it does and why, the GIF, how it works (one diagram or short flow), forecast rules, setup and run steps from a clean Mac, how to run tests, known limitations.
- **docs/architecture.md:** request flow, GraphQL queries used, and the reasons behind key choices (computed on request, no webhooks, 30-day window).
- **Demo video, 1 to 2 minutes:** the store's products, opening the app, the sorted at-risk list, one item's sales history window, making a sale, Refresh showing the change. Plus a short GIF for the README.
- **docs/study-guide.md:** see section 4.
- **GitHub:** a repo on Muhammad's account `PricyK` (gh CLI is logged in). Claude asks before the first push and before making the repo public.
- **Resume:** add the project to "Projects / Open Source" in the existing resume generator, with the repo link, likely replacing the Socket-based Snake Game.

## 9. Left to the builder

- Development environment setup on macOS. Default: Homebrew, Ruby via a version manager (not the system Ruby).
- Exact GraphQL queries, pagination approach, and API version.
- How the seed script authenticates (for example, a Rails task using the stored session).
- Polaris component choice for the table and badges.
- Screen recording and GIF tools.
- Commit structure and order of work.

## 10. Calls made by Claude (not explicitly agreed by Muhammad)

- 30-day sales window, and 7 and 14 day risk thresholds.
- Per-variant results, with stock summed across all locations.
- Forecasts computed on request; no database tables beyond the template's session storage.
- Frontend tests: one smoke test (`npm run smoke` in `web/frontend`) renders the page and the chart outside the browser and checks the output. It was added 2026-11-05, after a crash while drawing left a blank page that the build could not see. Everything else in the frontend is checked by hand and in the demo.
- The public GitHub repo for this project gets linked from the resume, even though the resume currently omits a personal GitHub profile.
- The table shows all variants, sorted with at-risk ones on top.
- The seed resets by deleting its own tagged products, and is re-run on testing and recording days.
- The fallback stack above, if the template will not run.
- A variant shows inside the Product column ("T-Shirt – Large") instead of its own column.
- Sales history: 8 full weeks as the longest range, rather than 60 days split into weeks. The chart is drawn in SVG with no library; hovering over a date shows its value through the browser's built-in SVG tooltip (no custom tooltip). "Sales" means units sold. The 30-day window counts today and the 29 days before it.
