# frozen_string_literal: true

require "test_helper"

class ForecastTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 11, 10)

  test "seed scenario rows" do
    by_id = seed_rows.index_by { _1[:id] }
    assert_equal ["out_of_stock", 0, TODAY], by_id["A"].values_at(:risk, :days_left, :run_out_date)
    assert_equal ["critical", 3, Date.new(2026, 11, 13)], by_id["B"].values_at(:risk, :days_left, :run_out_date)
    assert_equal ["warning", 13], by_id["C"].values_at(:risk, :days_left)
    assert_equal ["ok", 100, 1.0], by_id["D"].values_at(:risk, :days_left, :daily_rate)
    assert_equal ["no_recent_sales", nil, nil], by_id["E"].values_at(:risk, :days_left, :run_out_date)
  end

  test "sort order" do
    assert_equal %w[A B C D E], seed_rows.map { _1[:id] }
  end

  test "boundaries use floored days" do
    # rate 2/day (60 units); inventory -> expected risk
    { 14 => "critical", 15 => "critical", 16 => "warning", 28 => "warning", 29 => "warning", 30 => "ok" }.each do |inv, risk|
      row = Forecast.call(variants: [v("X", inv)], units_sold: { "X" => 60 }, today: TODAY).first
      assert_equal risk, row[:risk], "inventory #{inv}"
    end
  end

  test "negative inventory is out of stock" do
    row = Forecast.call(variants: [v("X", -3)], units_sold: {}, today: TODAY).first
    assert_equal "out_of_stock", row[:risk]
  end

  test "zero stock and zero sales is out of stock, not no_recent_sales" do
    row = Forecast.call(variants: [v("X", 0)], units_sold: {}, today: TODAY).first
    assert_equal "out_of_stock", row[:risk]
  end

  test "ties sort by product title" do
    rows = Forecast.call(variants: [v("Zeta", 0), v("Alpha", 0)], units_sold: {}, today: TODAY)
    assert_equal %w[Alpha Zeta], rows.map { _1[:product_title] }
  end

  private

  def v(id, inventory)
    { id: id, product_title: id, variant_title: nil, sku: nil, inventory: inventory }
  end

  # Shuffled so the sort test can't pass by keeping input order.
  def seed_rows
    Forecast.call(
      variants: [v("C", 20), v("E", 25), v("A", 0), v("D", 100), v("B", 6)],
      units_sold: { "A" => 10, "B" => 60, "C" => 45, "D" => 30 }, today: TODAY)
  end
end
