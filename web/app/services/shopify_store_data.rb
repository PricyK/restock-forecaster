# frozen_string_literal: true

# Reads stock and recent sales from the GraphQL Admin API and returns plain hashes for Forecast.
class ShopifyStoreData
  class Error < StandardError; end

  VARIANTS_QUERY = <<~GQL
    query($after: String) {
      productVariants(first: 250, after: $after) {
        nodes { id title sku inventoryQuantity inventoryItem { tracked } product { title } }
        pageInfo { hasNextPage endCursor }
      }
    }
  GQL

  # shortcut: refunds are not subtracted, so a refunded sale still counts; subtract refundLineItems if returns matter.
  # shortcut: line items beyond 250 per order are ignored; page lineItems if orders ever get that big.
  ORDERS_QUERY = <<~GQL
    query($after: String, $query: String) {
      orders(first: 250, after: $after, query: $query) {
        nodes { cancelledAt lineItems(first: 250) { nodes { quantity variant { id } } } }
        pageInfo { hasNextPage endCursor }
      }
    }
  GQL

  def initialize(client)
    @client = client
  end

  # The shop's local date, so run-out dates match the merchant's calendar (Rails itself runs in UTC).
  def today
    Time.current.in_time_zone(fetch("{ shop { ianaTimezone } }").dig("shop", "ianaTimezone")).to_date
  end

  # Only variants that track inventory: an untracked variant's stock number means nothing.
  def variants
    all_nodes(VARIANTS_QUERY, "productVariants").filter_map do |v|
      next unless v.dig("inventoryItem", "tracked")

      {
        id: v["id"],
        product_title: v.dig("product", "title"),
        variant_title: (v["title"] unless v["title"] == "Default Title"), # Shopify's name for "no variants"
        sku: v["sku"],
        inventory: v["inventoryQuantity"],
      }
    end
  end

  # Units sold per variant id. Uses processed_at (when the sale happened), not created_at.
  def units_sold(since:)
    all_nodes(ORDERS_QUERY, "orders", query: "processed_at:>=#{since.iso8601}")
      .reject { |order| order["cancelledAt"] }
      .flat_map { |order| order.dig("lineItems", "nodes") }
      .select { |line| line["variant"] } # custom items and deleted products have no variant
      .each_with_object(Hash.new(0)) { |line, totals| totals[line.dig("variant", "id")] += line["quantity"] }
  end

  private

  def fetch(query, variables = {})
    body = @client.query(query: query, variables: variables).body
    raise Error, body["errors"].to_json if body["errors"]

    body["data"]
  end

  def all_nodes(query, root, variables = {})
    nodes = []
    after = nil
    loop do
      page = fetch(query, variables.merge(after: after))[root]
      nodes.concat(page["nodes"])
      break unless page.dig("pageInfo", "hasNextPage")

      after = page.dig("pageInfo", "endCursor")
    end
    nodes
  end
end
