// Renders the page and the chart to HTML outside the browser and checks what comes out.
// It catches crashes while drawing (a blank page in the admin) that `npm run build` can't see.
// Run with `npm run smoke`. It is not part of the website, so it doesn't affect load speed.
import assert from "node:assert/strict";
import { renderToStaticMarkup } from "react-dom/server";
import { AppProvider, Pagination } from "@shopify/polaris";
import en from "@shopify/polaris/locales/en.json";
import { QueryClient, QueryClientProvider } from "react-query";

import HomePage from "../pages/index.jsx";
import { SalesChart, rangeTotal } from "../components/SalesChart.jsx";
import { stockLeft } from "../components/SalesHistoryModal.jsx";
import { RiskBadge } from "../components/RiskBadge.jsx";
import NotFound from "../pages/NotFound.jsx";
import { PolarisProvider } from "../components/providers/PolarisProvider.jsx";
import { fetchJson } from "../utils/fetchJson.js";

const row = (sku, category, days_left, risk, variant_title = null) => ({
  id: `gid://shopify/ProductVariant/${sku}`,
  product_title: `Product ${sku}`,
  variant_title,
  category,
  sku,
  inventory: 5,
  daily_rate: 1,
  days_left,
  run_out_date: null,
  risk,
});

function renderPage(rows) {
  const client = new QueryClient();
  client.setQueryData(["forecast"], { generated_on: "2026-11-05", rows }); // the page reads this instead of fetching
  return renderToStaticMarkup(
    <AppProvider i18n={en}>
      <QueryClientProvider client={client}>
        <HomePage />
      </QueryClientProvider>
    </AppProvider>,
  );
}

const count = (html, text) => html.split(text).length - 1;
// Summary boxes marked disabled (the table's own scroll buttons are disabled too, so match the class).
const disabledBoxes = (html) =>
  (html.match(/<button[^>]*summary-button[^>]*aria-disabled="true"/g) || [])
    .length;
const text = (html) => html.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ");

// The page draws the boxes, the five columns and a badge button per row.
const page = renderPage([
  row("A", "Milk", 0, "out_of_stock"),
  row("B", "Coffee", 3, "critical", "Large"),
  row("C", null, 13, "warning"),
  row("D", "Equipment", 100, "ok"),
  row("E", "Equipment", null, "no_recent_sales"),
]);
for (const heading of ["Product", "Category", "SKU", "Stock", "Risk"]) {
  assert.ok(text(page).includes(` ${heading} `), `missing column ${heading}`);
}
assert.ok(
  text(page).includes("Product B – Large"),
  "variant goes in the product name",
);
assert.ok(text(page).includes(" — "), "a blank category shows —");
assert.equal(count(page, "summary-button"), 3);
// Refresh is a round icon button (class refresh-button) with a label for screen readers, not a text button.
assert.ok(
  /<button[^>]*refresh-button[^>]*aria-label="Refresh"|<button[^>]*aria-label="Refresh"[^>]*refresh-button/.test(
    page,
  ),
);
assert.equal(count(page, "badge-button"), 5);
assert.equal(count(page, "badge-strong"), 2); // out of stock in the summary and in the table
assert.equal(disabledBoxes(page), 0);

// A summary box with no rows can't be clicked.
assert.equal(disabledBoxes(renderPage([row("D", "Equipment", 100, "ok")])), 3);

// The chart's total and its screen-reader sentence.
const week = [
  "10-30",
  "10-31",
  "11-01",
  "11-02",
  "11-03",
  "11-04",
  "11-05",
].map((day, i) => ({ date: `2026-${day}`, units: i }));
const chart = renderToStaticMarkup(
  <AppProvider i18n={en}>
    <SalesChart range={{ label: "7 days", points: week }} />
  </AppProvider>,
);
assert.equal(rangeTotal({ label: "7 days", points: week }), 21); // the window shows this under the chart
// The last point is today (still counting): its segment is dashed and its tooltip says "so far".
assert.equal(count(chart, "stroke-dasharray"), 1);
assert.equal(count(chart, 'fill="var(--p-surface)"'), 1); // hollow end dot: still visible when 30 points make the dashes too short
assert.ok(chart.includes("<title>Nov 5: 6 sold so far</title>"));
assert.ok(chart.includes("<title>Nov 4: 5 sold</title>"));
assert.ok(
  chart.includes(
    'aria-label="Units sold per day, Oct 30 to Nov 5: 21 in total."',
  ),
);

// The expanded window redraws the chart wider instead of scaling it, so labels keep their size.
assert.ok(chart.includes('viewBox="0 0 340 160"'));
const wide = renderToStaticMarkup(
  <AppProvider i18n={en}>
    <SalesChart range={{ label: "7 days", points: week }} wide />
  </AppProvider>,
);
assert.ok(wide.includes('viewBox="0 0 680 220"'));

// A weekly point is dated by its first day, so the sentence ends 6 days later.
const weeks = [
  { date: "2026-10-23", units: 4 },
  { date: "2026-10-30", units: 6 },
];
const weekly = renderToStaticMarkup(
  <AppProvider i18n={en}>
    <SalesChart range={{ label: "8 weeks", points: weeks }} />
  </AppProvider>,
);
assert.ok(
  weekly.includes("Units sold per week, Oct 23 to Nov 5: 10 in total."),
);

// The window's days-left sentence sits in the same coloured bubble as the row's risk badge.
const bubble = (risk) =>
  renderToStaticMarkup(
    <AppProvider i18n={en}>
      <RiskBadge risk={risk}>About 3 days of stock left</RiskBadge>
    </AppProvider>,
  );
assert.ok(bubble("critical").includes("Polaris-Badge--statusCritical"));
assert.ok(text(bubble("critical")).includes("About 3 days of stock left"));
assert.ok(bubble("out_of_stock").includes("badge-strong"));
assert.ok(!bubble("critical").includes("badge-strong"));

// The days-left sentence in the sales window.
assert.equal(
  stockLeft(row("B", "Coffee", 3, "critical")),
  "About 3 days of stock left",
);
assert.equal(
  stockLeft(row("B", "Coffee", 1, "critical")),
  "About 1 day of stock left",
);
assert.equal(
  stockLeft(row("B", "Coffee", 0, "critical")),
  "Less than a day of stock left",
);
assert.equal(
  stockLeft(row("A", "Milk", 0, "out_of_stock")),
  "Out of stock now",
);
assert.equal(
  stockLeft(row("E", "Equipment", null, "no_recent_sales")),
  "No sales in the last 30 days, so no run-out estimate",
);

// The "Not found" page has its words without any translation setup.
const notFound = renderToStaticMarkup(
  <AppProvider i18n={en}>
    <NotFound />
  </AppProvider>,
);
assert.ok(text(notFound).includes("There is no page at this address"));

// The app's own Polaris wrapper gives Polaris its English text (Pagination's "Next" label comes from it).
const wrapped = renderToStaticMarkup(
  <PolarisProvider>
    <Pagination hasNext />
  </PolarisProvider>,
);
assert.ok(wrapped.includes('aria-label="Next"'));

// A request that never reaches the server shows the friendly message, not the browser's own.
globalThis.fetch = () => Promise.reject(new TypeError("Load failed"));
fetchJson("/api/forecast")
  .then(
    () => assert.fail("expected fetchJson to throw"),
    (error) =>
      assert.equal(
        error.message,
        "Couldn't load data from Shopify. Try again.",
      ),
  )
  .then(() => {
    console.log("smoke: all checks passed");
    process.exit(0); // react-query keeps a timer running that would hold the process open
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
