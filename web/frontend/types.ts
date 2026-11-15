// The shapes the Rails API sends (web/app/controllers/forecasts_controller.rb).
// Dates arrive as "YYYY-MM-DD" strings.

export type Risk =
  "out_of_stock" | "critical" | "warning" | "ok" | "no_recent_sales";

// One row of GET /api/forecast: a variant with its stock and forecast.
export interface ForecastRow {
  id: string; // e.g. "gid://shopify/ProductVariant/1"
  product_title: string;
  variant_title: string | null; // null when the product has no variants
  category: string | null; // the product type; null when none is set
  sku: string | null;
  inventory: number;
  daily_rate: number;
  days_left: number | null; // null when nothing sold in 30 days
  run_out_date: string | null;
  risk: Risk;
}

export interface ForecastResponse {
  generated_on: string;
  rows: ForecastRow[];
}

// One point on a sales chart: units sold on a day, or in the week starting on that day.
export interface Point {
  date: string;
  units: number;
}

export interface SalesRange {
  label: string; // "7 days", "30 days" or "8 weeks"
  points: Point[];
}

// GET /api/sales_history
export interface SalesHistoryResponse {
  ranges: SalesRange[];
}
