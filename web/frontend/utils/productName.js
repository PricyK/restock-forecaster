// "T-Shirt – Large", or just "T-Shirt" when the product has no variants.
export const productName = (row) =>
  [row.product_title, row.variant_title].filter(Boolean).join(" – ");
