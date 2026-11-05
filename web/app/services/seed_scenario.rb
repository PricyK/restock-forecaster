# frozen_string_literal: true

# The fixed demo store: five products and backdated orders that give one of each risk level.
module SeedScenario
  TAG = "restock-seed"

  PRODUCTS = [
    { key: "A", title: "Oat Milk 1L", inventory: 0, price: "4.99" },
    { key: "B", title: "Cold Brew Can", inventory: 6, price: "3.50" },
    { key: "C", title: "Dark Roast Beans 340g", inventory: 20, price: "16.00" },
    { key: "D", title: "Ceramic Mug", inventory: 100, price: "12.00" },
    { key: "E", title: "Pour-Over Kettle", inventory: 25, price: "45.00" },
  ].freeze

  module_function

  def products
    PRODUCTS
  end

  # Units sold per day for the 29 days before today, oldest first. Their totals set the forecast:
  # A climbs then sells out, B climbs, C has a weekly hump, D is flat. E sells none.
  DAILY = {
    "A" => [1, 1, 2, 1, 2, 2, 2, 2, 3, 2, 2, 3, 3, 2, 3, 3, 3, 4, 3, 3, 4, 4, 3, 4, 0, 0, 0, 0, 0],
    "B" => [1, 1, 1, 1, 1, 2, 1, 1, 2, 2, 1, 2, 2, 2, 2, 2, 2, 2, 3, 2, 2, 3, 3, 3, 3, 3, 3, 4, 3],
    "C" => [1, 1, 2, 3, 2, 1, 1] * 4 + [1],
    "D" => [1] * 28 + [2],
  }.freeze

  # Older orders, outside the 30 days, that only show on the 8-week chart. E sold back then and stopped.
  OLDER_DAYS_AGO = [54, 51, 47, 44, 40, 37, 33, 30].freeze
  OLDER_LINES = [
    { key: "A", quantity: 4 },
    { key: "B", quantity: 3 },
    { key: "C", quantity: 3 },
    { key: "D", quantity: 3 },
    { key: "E", quantity: 2 },
  ].freeze

  # Every order is at noon shop time, so which day it lands on never depends on when the seed runs.
  def orders(today:, zone:)
    noon = ->(days_ago) { (today - days_ago).in_time_zone(zone).change(hour: 12) } # change, not + 12.hours: DST days are 23 or 25 hours
    older = OLDER_DAYS_AGO.map { |days_ago| { processed_at: noon.call(days_ago), lines: OLDER_LINES } }
    recent = 29.times.map do |i|
      lines = DAILY.filter_map { |key, units| { key: key, quantity: units[i] } if units[i].positive? }
      { processed_at: noon.call(29 - i), lines: lines }
    end
    older + recent
  end
end
