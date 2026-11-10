# frozen_string_literal: true

require "test_helper"

class SeedScenarioTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 11, 10)
  ZONE = "America/New_York"

  test "orders total match the scenario" do
    assert_equal({ "A" => 62, "B" => 60, "C" => 45, "D" => 30 }, totals(recent(orders)).slice("A", "B", "C", "D", "E"))
    assert_equal({ "A" => 94, "B" => 84, "C" => 69, "D" => 54, "E" => 16 }, totals(orders).slice("A", "B", "C", "D", "E"))
  end

  test "one order on each of the 30 days in the window, 8 older ones inside 8 weeks" do
    assert_equal ((TODAY - 29)..TODAY).to_a, recent(orders).map { _1[:processed_at].to_date }
    assert_equal 38, orders.size
    assert(orders.all? { _1[:processed_at].to_date >= TODAY - (SalesHistory::DAYS - 1) })
    assert(orders[0..-2].all? { _1[:processed_at].hour == 12 })
    assert_equal TODAY.in_time_zone(ZONE), orders.last[:processed_at] # today's is at midnight, never in the future
  end

  test "Cold Brew's chart climbs week by week" do
    daily = orders.each_with_object(Hash.new(0)) do |order, days|
      order[:lines].each { |l| days[order[:processed_at].to_date] += l[:quantity] if l[:key] == "B" }
    end
    ranges = SalesHistory.call(daily_units: daily, today: TODAY)
    assert_equal [20, 60, 84], ranges.map { |r| r[:points].sum { _1[:units] } }
    assert_equal [6, 6, 6, 8, 9, 13, 16, 20], ranges.last[:points].map { _1[:units] }
    assert_equal 3, ranges.first[:points].last[:units] # today sells too, so the line doesn't dive to 0
  end

  test "every product has a unique key and a category" do
    assert_equal %w[A B C D E F G H I J K L M], SeedScenario.products.map { _1[:key] }
    assert_equal %w[Milk Coffee Coffee Equipment Equipment Milk Coffee Equipment Tea Milk Equipment Coffee Equipment],
      SeedScenario.products.map { _1[:type] }
  end

  test "seeded stock and sales give the spec's forecast" do
    products = SeedScenario.products
    rows = Forecast.call(
      variants: products.map { |p| { id: p[:key], product_title: p[:title], variant_title: nil, sku: nil, inventory: p[:inventory] } },
      units_sold: totals(recent(orders)), today: TODAY)
    assert_equal %w[F A B G H I J C K L D M E], rows.map { _1[:id] }
    assert_equal %w[out_of_stock out_of_stock critical critical critical warning warning warning ok ok ok
                    no_recent_sales no_recent_sales], rows.map { _1[:risk] }
    assert_equal [0, 0, 3, 5, 6, 10, 12, 13, 40, 60, 100, nil, nil], rows.map { _1[:days_left] }
  end

  private

  def orders = SeedScenario.orders(today: TODAY, zone: ZONE)

  # Orders inside the forecast's 30 days (today and the 29 days before it).
  def recent(orders) = orders.select { _1[:processed_at].to_date >= TODAY - (Forecast::WINDOW_DAYS - 1) }

  def totals(orders)
    orders.flat_map { _1[:lines] }.group_by { _1[:key] }.transform_values { |lines| lines.sum { _1[:quantity] } }
  end
end
