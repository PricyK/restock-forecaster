# frozen_string_literal: true

# Reads stock and recent sales from the GraphQL Admin API and returns plain hashes for Forecast.
class ShopifyStoreData
  class Error < StandardError; end

  VARIANTS_QUERY = <<~GQL
    query($after: String) {
      productVariants(first: 250, after: $after) {
        nodes { id title sku inventoryQuantity inventoryItem { tracked } product { title productType } }
        pageInfo { hasNextPage endCursor }
      }
    }
  GQL

  # shortcut: refunds are not subtracted, so a refunded sale still counts; subtract refundLineItems if returns matter.
  # shortcut: line items beyond 250 per order are ignored; page lineItems if orders ever get that big.
  ORDERS_QUERY = <<~GQL
    query($after: String, $query: String) {
      orders(first: 250, after: $after, query: $query) {
        nodes { cancelledAt processedAt lineItems(first: 250) { nodes { quantity variant { id } } } }
        pageInfo { hasNextPage endCursor }
      }
    }
  GQL

  def initialize(client)
    @client = client
  end

  # The shop's local date, so run-out dates match the merchant's calendar (Rails itself runs in UTC).
  def today
    Time.current.in_time_zone(time_zone).to_date
  end

  # Only variants that track inventory: an untracked variant's stock number means nothing.
  def variants
    all_nodes(VARIANTS_QUERY, "productVariants").filter_map do |v|
      next unless v.dig("inventoryItem", "tracked")

      {
        id: v["id"],
        product_title: v.dig("product", "title"),
        variant_title: (v["title"] unless v["title"] == "Default Title"), # Shopify's name for "no variants"
        category: v.dig("product", "productType").presence, # Shopify sends "" when the merchant set no type
        sku: v["sku"],
        inventory: v["inventoryQuantity"],
      }
    end
  end

  # Units sold per variant id.
  def units_sold(since:)
    sold_lines(since).each_with_object(Hash.new(0)) { |line, totals| totals[line[:variant_id]] += line[:quantity] }
  end

  # One variant's units per day, by the shop's calendar, for the sales history chart.
  # shortcut: reads every order since `since` to chart one variant, filter or cache if order volume grows.
  def daily_units(variant_id, since:)
    zone = time_zone
    sold_lines(since).select { |line| line[:variant_id] == variant_id }
      .each_with_object(Hash.new(0)) { |line, days| days[line[:processed_at].in_time_zone(zone).to_date] += line[:quantity] }
  end

  private

  def time_zone
    @time_zone ||= fetch("{ shop { ianaTimezone } }").dig("shop", "ianaTimezone")
  end

  # Line items of orders since a date, cancelled orders left out.
  # Uses processed_at (when the sale happened), not created_at.
  def sold_lines(since)
    all_nodes(ORDERS_QUERY, "orders", query: "processed_at:>=#{since.iso8601}")
      .reject { |order| order["cancelledAt"] }
      .flat_map do |order|
        order.dig("lineItems", "nodes").map do |line|
          { variant_id: line.dig("variant", "id"), quantity: line["quantity"], processed_at: order["processedAt"] }
        end
      end
      .select { |line| line[:variant_id] } # custom items and deleted products have no variant
  end

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
