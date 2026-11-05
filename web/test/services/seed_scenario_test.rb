# frozen_string_literal: true

require "test_helper"

class SeedScenarioTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 11, 10, 12)

  test "orders total match the scenario" do
    orders = SeedScenario.orders(now: NOW)
    assert_equal({ "A" => 10, "B" => 60, "C" => 45, "D" => 30 }, totals(recent(orders)))
    assert_equal({ "A" => 16, "B" => 78, "C" => 63, "D" => 48, "E" => 12 }, totals(orders))
  end

  test "10 orders in the 30 day window and 6 older ones inside 8 weeks" do
    orders = SeedScenario.orders(now: NOW)
    assert_equal [10, 16], [recent(orders).size, orders.size]
    assert(orders.all? { _1[:processed_at].to_date >= NOW.to_date - (SalesHistory::DAYS - 1) && _1[:processed_at] < NOW })
  end

  test "every product has a unique key" do
    assert_equal %w[A B C D E], SeedScenario.products.map { _1[:key] }
  end

  test "seeded stock and sales give the spec's forecast" do
    products = SeedScenario.products
    rows = Forecast.call(
      variants: products.map { |p| { id: p[:key], product_title: p[:title], variant_title: nil, sku: nil, inventory: p[:inventory] } },
      units_sold: totals(recent(SeedScenario.orders(now: NOW))), today: NOW.to_date)
    assert_equal %w[out_of_stock critical warning ok no_recent_sales], rows.map { _1[:risk] }
    assert_equal [0, 3, 13, 100, nil], rows.map { _1[:days_left] }
  end

  private

  # Orders inside the forecast's 30 days (today and the 29 days before it).
  def recent(orders) = orders.select { _1[:processed_at].to_date >= NOW.to_date - (Forecast::WINDOW_DAYS - 1) }

  def totals(orders)
    orders.flat_map { _1[:lines] }.group_by { _1[:key] }.transform_values { |lines| lines.sum { _1[:quantity] } }
  end
end
