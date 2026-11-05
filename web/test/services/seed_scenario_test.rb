# frozen_string_literal: true

require "test_helper"

class SeedScenarioTest < ActiveSupport::TestCase
  NOW = Time.utc(2026, 11, 10, 12)

  test "orders total match the scenario" do
    totals = SeedScenario.orders(now: NOW).flat_map { _1[:lines] }
      .group_by { _1[:key] }.transform_values { |ls| ls.sum { _1[:quantity] } }
    assert_equal({ "A" => 10, "B" => 60, "C" => 45, "D" => 30 }, totals)
  end

  test "all orders fall inside the 30 day window" do
    SeedScenario.orders(now: NOW).each do |o|
      assert o[:processed_at] > NOW - 30.days
      assert o[:processed_at] < NOW
    end
  end

  test "every product has a unique key" do
    assert_equal %w[A B C D E], SeedScenario.products.map { _1[:key] }
  end

  test "seeded stock and sales give the spec's forecast" do
    products = SeedScenario.products
    units = SeedScenario.orders(now: NOW).flat_map { _1[:lines] }
      .each_with_object(Hash.new(0)) { |l, h| h[l[:key]] += l[:quantity] }
    rows = Forecast.call(
      variants: products.map { |p| { id: p[:key], product_title: p[:title], variant_title: nil, sku: nil, inventory: p[:inventory] } },
      units_sold: units, today: NOW.to_date)
    assert_equal %w[out_of_stock critical warning ok no_recent_sales], rows.map { _1[:risk] }
    assert_equal [0, 3, 13, 100, nil], rows.map { _1[:days_left] }
  end
end
