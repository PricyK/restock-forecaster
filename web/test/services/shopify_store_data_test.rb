# frozen_string_literal: true

require "test_helper"

class ShopifyStoreDataTest < ActiveSupport::TestCase
  V1 = "gid://shopify/ProductVariant/1"
  V2 = "gid://shopify/ProductVariant/2"
  SINCE = Date.new(2026, 10, 11)
  SHOP_NY = { "data" => { "shop" => { "ianaTimezone" => "America/New_York" } } }.freeze

  # Stands in for ShopifyAPI::Clients::Graphql::Admin: returns queued bodies, records each call.
  class FakeClient
    Response = Struct.new(:body)
    attr_reader :calls

    def initialize(*bodies)
      @bodies = bodies
      @calls = []
    end

    def query(query:, variables: nil)
      @calls << { query: query, variables: variables }
      Response.new(@bodies.shift)
    end
  end

  test "maps variants to forecast input" do
    use variants_page([variant(V1, title: "Large", sku: "CB-1", inventory: 6, product: "Cold Brew Can", type: "Coffee")])
    assert_equal [{ id: V1, product_title: "Cold Brew Can", variant_title: "Large", category: "Coffee", sku: "CB-1",
                    inventory: 6 }],
      data.variants
  end

  test "blank product type becomes nil" do
    use variants_page([variant(V1, type: "")])
    assert_nil data.variants.first[:category]
  end

  test "default title becomes nil" do
    use variants_page([variant(V1, title: "Default Title")])
    assert_nil data.variants.first[:variant_title]
  end

  test "skips untracked variants" do
    use variants_page([variant(V1, tracked: false)])
    assert_empty data.variants
  end

  test "follows pagination" do
    use variants_page([variant(V1)], next_cursor: "c1"), variants_page([variant(V2)])
    assert_equal 2, data.variants.size
    assert_equal "c1", client.calls.last[:variables][:after]
  end

  test "sums units per variant across orders" do
    use orders_page([order([[V1, 2]]), order([[V1, 3]])])
    assert_equal({ V1 => 5 }, data.units_sold(since: SINCE))
  end

  test "follows order pagination" do
    use orders_page([order([[V1, 2]])], next_cursor: "o1"), orders_page([order([[V1, 3], [V2, 1]])])
    assert_equal({ V1 => 5, V2 => 1 }, data.units_sold(since: SINCE))
    assert_equal "o1", client.calls.last[:variables][:after]
  end

  test "skips cancelled orders" do
    use orders_page([order([[V1, 2]]), order([[V1, 3]], cancelled_at: "2026-10-20T10:00:00Z")])
    assert_equal({ V1 => 2 }, data.units_sold(since: SINCE))
  end

  test "skips line items without variant" do
    use orders_page([order([[nil, 4]])])
    assert_equal({}, data.units_sold(since: SINCE))
  end

  test "filters orders by processed_at" do
    use orders_page([])
    data.units_sold(since: SINCE)
    assert_includes client.calls.last[:variables][:query], "processed_at:>=2026-10-11"
  end

  test "today is the shop's local date" do
    use SHOP_NY
    travel_to(Time.utc(2026, 11, 6, 2)) do # 9 p.m. on Nov 5 in New York, already Nov 6 in UTC
      assert_equal Date.new(2026, 11, 5), data.today
    end
  end

  test "daily units are counted per shop-local day" do
    use SHOP_NY, orders_page([order([[V1, 2]], processed_at: "2026-11-06T02:00:00Z"), # 9 p.m. Nov 5 in New York
                              order([[V1, 1], [V2, 7]])])
    assert_equal({ Date.new(2026, 11, 5) => 3 }, data.daily_units(V1, since: SINCE))
  end

  test "daily units skip cancelled orders" do
    use SHOP_NY, orders_page([order([[V1, 2]], cancelled_at: "2026-11-05T16:00:00Z")])
    assert_equal({}, data.daily_units(V1, since: SINCE))
  end

  test "looks up the time zone once" do
    use SHOP_NY, orders_page([])
    store = data
    store.today
    store.daily_units(V1, since: SINCE)
    assert_equal 1, client.calls.count { _1[:query].include?("ianaTimezone") }
  end

  test "raises on GraphQL errors" do
    use({ "errors" => [{ "message" => "Throttled" }] })
    assert_raises(ShopifyStoreData::Error) { data.variants }
  end

  private

  attr_reader :client

  def use(*bodies)
    @client = FakeClient.new(*bodies)
  end

  def data
    ShopifyStoreData.new(client)
  end

  def variant(id, title: "Default Title", sku: nil, inventory: 1, tracked: true, product: "Product", type: "")
    { "id" => id, "title" => title, "sku" => sku, "inventoryQuantity" => inventory,
      "inventoryItem" => { "tracked" => tracked }, "product" => { "title" => product, "productType" => type } }
  end

  def order(lines, cancelled_at: nil, processed_at: "2026-11-05T15:00:00Z")
    { "cancelledAt" => cancelled_at, "processedAt" => processed_at,
      "lineItems" => { "nodes" => lines.map { |id, qty| { "quantity" => qty, "variant" => id && { "id" => id } } } } }
  end

  def variants_page(nodes, next_cursor: nil) = page("productVariants", nodes, next_cursor)
  def orders_page(nodes, next_cursor: nil) = page("orders", nodes, next_cursor)

  def page(root, nodes, next_cursor)
    { "data" => { root => { "nodes" => nodes,
                            "pageInfo" => { "hasNextPage" => !next_cursor.nil?, "endCursor" => next_cursor } } } }
  end
end
