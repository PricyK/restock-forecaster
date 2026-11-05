# frozen_string_literal: true

# Turns stock levels and recent sales into run-out forecasts. Plain Ruby, no Shopify calls.
class Forecast < ApplicationService
  WINDOW_DAYS = 30
  SORT_GROUP = { "out_of_stock" => 0, "no_recent_sales" => 2 }.freeze # every dated risk is group 1

  def initialize(variants:, units_sold:, today:)
    super
    @variants = variants
    @units_sold = units_sold
    @today = today
  end

  def call
    @variants.map { |variant| row(variant) }
      .sort_by { |r| [SORT_GROUP.fetch(r[:risk], 1), r[:days_left] || 0, r[:product_title]] }
  end

  private

  def row(variant)
    rate = @units_sold.fetch(variant[:id], 0) / WINDOW_DAYS.to_f
    inventory = variant[:inventory]
    days_left =
      if inventory <= 0 then 0
      elsif rate.positive? then (inventory / rate).floor
      end

    variant.merge(
      daily_rate: rate.round(2),
      days_left: days_left,
      run_out_date: days_left && @today + days_left,
      risk: risk(inventory, days_left),
    )
  end

  def risk(inventory, days_left)
    return "out_of_stock" if inventory <= 0
    return "no_recent_sales" if days_left.nil?
    return "critical" if days_left <= 7
    return "warning" if days_left <= 14

    "ok"
  end
end
