// Renders the page and the chart to HTML outside the browser and checks what comes out.
// It catches crashes while drawing (a blank page in the admin) that `npm run build` can't see.
// Run with `npm run smoke`. It is not part of the website, so it doesn't affect load speed.
import assert from "node:assert/strict";
import { renderToStaticMarkup } from "react-dom/server";
import { AppProvider } from "@shopify/polaris";
import en from "@shopify/polaris/locales/en.json";
import { QueryClient, QueryClientProvider } from "react-query";

import HomePage from "../pages/index.jsx";
import { SalesChart } from "../components/SalesChart.jsx";
import { stockLeft } from "../components/SalesHistoryModal.jsx";

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
assert.ok(
  text(page).includes(" Dark mode "),
  "the dark mode toggle is on the page",
);
assert.equal(count(page, "summary-button"), 3);
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
assert.ok(text(chart).includes("21 sold in the last 7 days"));
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

// The days-left sentence in the sales window.
assert.equal(
  stockLeft(row("B", "Coffee", 3, "critical")),
  "About 3 days of stock left.",
);
assert.equal(
  stockLeft(row("B", "Coffee", 1, "critical")),
  "About 1 day of stock left.",
);
assert.equal(
  stockLeft(row("B", "Coffee", 0, "critical")),
  "Less than a day of stock left.",
);
assert.equal(
  stockLeft(row("A", "Milk", 0, "out_of_stock")),
  "Out of stock now.",
);
assert.equal(
  stockLeft(row("E", "Equipment", null, "no_recent_sales")),
  "No sales in the last 30 days, so no run-out estimate.",
);

console.log("smoke: all checks passed");
process.exit(0); // react-query keeps a timer running that would hold the process open
