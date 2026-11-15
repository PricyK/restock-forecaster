# Testing record

How the app was checked on a real development store, and what the automated tests cover. Dates are 2026.

- **Store:** `ridgeline-coffee-co-3j14nuup.myshopify.com` (a Shopify Partner development store, America/New_York time zone)
- **Versions:** Ruby 3.3.0, Rails 7.1.6, Node 26.13.0, Admin API `2026-10`, Polaris 10.50
- **Seed:** `bin/rails restock:seed` creates 13 products and 38 backdated orders (see the spec's seed tables)

## Dev-store checks (Nov 10)

| # | Check | Expected | Result |
|---|---|---|---|
| 1a | Uninstall the app from the admin | Shopify sends `app/uninstalled`; the app deletes the store's saved login | Pass. The store's record (#1, created Nov 5) was gone; 0 records left. |
| 1b | Reinstall (restart `shopify app dev`, open the app, install) | A fresh login record with all three scopes and a 1-hour token that refreshes itself | Pass. Record #2 was created at 16:17 UTC with `write_inventory, write_orders, write_products` and a token expiring at 17:17 UTC. Note: after the uninstall, the admin showed "There's no page at this address" until `shopify app dev` was restarted. |
| 1c | Seed after the fresh install | Table matches the spec's seed tables; Cold Brew's window reads 20 / 60 / 84 | Pending |
| 2 | Live sale: an order for 3 × Cold Brew Can, marked paid | Stock 3, still Critical, "About 1 day of stock left", "23 sold in the last 7 days" | Pending |
| 3 | Restock: Dark Roast Beans (340g) set to 100 | Warning changes to OK | Pending |
| 4 | Empty state on a second store with no products | "No products yet" | Pending |
| 5 | Error state: the endpoint fails on purpose | Red banner with "Couldn't load data from Shopify. Try again."; no crash | Pending |

## Automated tests (Nov 10)

| Suite | Command | Result |
|---|---|---|
| Ruby (Minitest) | `cd web && bin/rails test` | 47 runs, 96 assertions, 0 failures |
| Frontend smoke test | `cd web/frontend && npm run smoke` | All checks pass |
| Style (RuboCop, Shopify rules) | `cd web && bundle exec rubocop` | 57 files, no offenses |

What they cover:

- **Forecast math** (`test/services/forecast_test.rb`): each risk level, the 7- and 14-day boundaries, zero sales, zero and negative stock, sort order.
- **Reading the store** (`test/services/shopify_store_data_test.rb`): pagination, cancelled orders, lines without a variant, untracked variants, active products only, the shop's time zone, daily sales by local day.
- **Sales history** (`test/services/sales_history_test.rb`): range lengths, empty days as 0, weekly totals ending today.
- **Endpoints** (`test/controllers/forecasts_controller_test.rb`): JSON shape, the 30-day and 8-week windows, 400 without `variant_id`, 502 when Shopify fails, one retry after a 401.
- **Seed scenario** (`test/services/seed_scenario_test.rb`): totals, one order a day, Cold Brew's chart, every risk level from the seeded data.
- **Webhooks** (`test/integration/webhooks_test.rb`): all five accept a signed request and reject an unsigned one.
- **Smoke test** (`web/frontend/test/smoke.jsx`): the page, the summary boxes, the chart, the days-left sentences, the "Not found" page, Polaris's English text, and the friendly error when a request fails. Each check was proved by breaking the code and watching it fail.

## Whole-repo audit (Nov 10)

`ponytail:ponytail-audit`, assuming one development store and one person demoing. Five findings, all fixed; one more found while fixing:

1. Archived and draft products appeared in the table: the variants query now asks for active products only.
2. An unused translation system (227 lines, 7 packages) could leave the page blank if it failed to load: removed.
3. Three unused test packages and a broken `npm run coverage` script: removed.
4. A dropped connection showed Safari's raw "Load failed": now the friendly message.
5. RuboCop's settings file wasn't being picked up, and one style issue: renamed to `.rubocop.yml`, fixed.
6. (Found while fixing) `package-lock.json` was ignored by git, so a fresh clone could install different versions: now committed.

Left alone on purpose:
- the template's Rails gems that Shopify's login pages may use (importmap, Turbo, Stimulus);
- the unused `User` model;
- the API's `generated_on` field;
- the decisions marked `shortcut:` in the code (refunds still count as sales, orders over 250 lines are cut off, every click reads all recent orders, and the seed's fixed retry wait).
