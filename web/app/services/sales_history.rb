# frozen_string_literal: true

# Turns one variant's daily sales into the three chart ranges. No Shopify code, like Forecast.
class SalesHistory < ApplicationService
  DAYS = 56 # 8 full weeks, inside the 60 days of orders that read_orders can see

  def initialize(daily_units:, today:)
    super
    @daily_units = daily_units
    @today = today
  end

  def call
    days = ((@today - (DAYS - 1))..@today).map { |date| { date: date, units: @daily_units.fetch(date, 0) } }
    [
      { label: "7 days", points: days.last(7) },
      { label: "30 days", points: days.last(Forecast::WINDOW_DAYS) },
      { label: "8 weeks", points: days.each_slice(7).map { |week| { date: week.first[:date], units: week.sum { _1[:units] } } } },
    ]
  end
end
