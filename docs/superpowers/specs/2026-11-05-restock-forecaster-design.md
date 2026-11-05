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
2. One page: an "at-risk products" table showing, per variant, stock on hand, daily sales rate, days of stock left, projected run-out date, and a risk badge.
3. Data comes live from the Shopify GraphQL Admin API each time the page loads or the user presses Refresh.
4. A repeatable seed script that fills a development store with products and backdated orders forming a known scenario, so the demo always shows a mix of risk levels.
5. Automated tests for the forecasting logic and the API endpoint.
6. Documentation: README, architecture notes, a demo video, and a GIF in the README.

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
- **Sales:** units sold per variant in the last 30 days, from orders' line items.
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

The table shows every variant, not only at-risk ones, so the sort order puts the at-risk rows on top. The empty state means "this store has no products". An optional summary line (for example "2 critical, 1 warning") sits above the table.

### Seed scenario

A script, run against the development store, creates a small product set and backdated orders (`processedAt` in the past) so the results are predictable. At minimum:

| Variant | Stock | Units sold in last 30 days | Expected result |
|---|---|---|---|
| A | 0 | any | Out of stock |
| B | 6 | 60 (2/day) | Critical, 3 days left |
| C | 20 | 45 (1.5/day) | Warning, 13 days left |
| D | 100 | 30 (1/day) | OK, 100 days left |
| E | 25 | 0 | No recent sales |

The same table doubles as the expected values for a manual check.

Seed details:

- Sales for each variant are spread evenly over the last 30 days. Backdated sales age out of the window, so the expected values only hold on the day of seeding. Re-seed on testing and recording days.
- Repeatable means: the seed first deletes the products it created before (identified by a product tag, for example `restock-seed`), then recreates them. Old seed orders stay in the store, but they point at deleted variants, so the forecast ignores them. No order cleanup needed.
- Use quantities above 1 per order and throttle requests. Development stores rate-limit order creation (roughly 5 orders a minute; check the current limit).
- `orderCreate` accepts `processedAt`, but `createdAt` is the seed time. The forecast's order query must filter on `processed_at`, not `created_at`.
- `read_orders` returns the last 60 days of orders, which covers the 30-day window.

## 7. Testing

### Dev testing (automated)

- Unit tests (the template's Minitest) for the forecast class: each risk level, the boundary values 7 and 14, zero sales, zero and negative stock, and sort order.
- A controller or request test with the Shopify GraphQL call stubbed, checking the JSON shape and the error response when Shopify fails.

### Dev testing (manual, on the development store)

- Install the app on a fresh development store, run the seed script, and confirm the table matches the seed scenario table.
- Record a new sale for a variant in the admin, press Refresh, and confirm its numbers change.
- Check the empty state (store with no products) and the error state (for example, a revoked token).

## 8. Documentation and demo

- **README:** what it does and why, the GIF, how it works (one diagram or short flow), forecast rules, setup and run steps from a clean Mac, how to run tests, known limitations.
- **docs/architecture.md:** request flow, GraphQL queries used, and the reasons behind key choices (computed on request, no webhooks, 30-day window).
- **Demo video, 1 to 2 minutes:** the store's products, opening the app, the sorted at-risk list, making a sale, Refresh showing the change. Plus a short GIF for the README.
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
- No frontend (React) automated tests; the frontend is verified manually and in the demo.
- The public GitHub repo for this project gets linked from the resume, even though the resume currently omits a personal GitHub profile.
- The table shows all variants, sorted with at-risk ones on top.
- The seed resets by deleting its own tagged products, and is re-run on testing and recording days.
- The fallback stack above, if the template will not run.
