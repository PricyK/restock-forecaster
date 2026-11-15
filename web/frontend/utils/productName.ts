import type { ForecastRow } from "../types";

// "T-Shirt – Large", or just "T-Shirt" when the product has no variants.
export const productName = (row: ForecastRow) =>
  [row.product_title, row.variant_title].filter(Boolean).join(" – ");
