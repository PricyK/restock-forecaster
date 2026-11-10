# frozen_string_literal: true

# The fixed demo store: five products and backdated orders that give one of each risk level.
module SeedScenario
  TAG = "restock-seed"

  PRODUCTS = [
    { key: "A", title: "Oat Milk 1L", type: "Milk", inventory: 0, price: "4.99" },
    { key: "B", title: "Cold Brew Can", type: "Coffee", inventory: 6, price: "3.50" },
    { key: "C", title: "Dark Roast Beans 340g", type: "Coffee", inventory: 20, price: "16.00" },
    { key: "D", title: "Ceramic Mug", type: "Equipment", inventory: 100, price: "12.00" },
    { key: "E", title: "Pour-Over Kettle", type: "Equipment", inventory: 25, price: "45.00" },
    # Extra products so each risk level has two or three rows in the demo.
    { key: "F", title: "Almond Milk 1L", type: "Milk", inventory: 0, price: "5.49" },
    { key: "G", title: "Espresso Beans 1kg", type: "Coffee", inventory: 5, price: "32.00" },
    { key: "H", title: "Paper Filters 100 Pack", type: "Equipment", inventory: 12, price: "6.00" },
    { key: "I", title: "Earl Grey Tea 20 Bags", type: "Tea", inventory: 10, price: "7.50" },
    { key: "J", title: "Barista Oat Milk 1L", type: "Milk", inventory: 18, price: "5.99" },
    { key: "K", title: "Travel Tumbler", type: "Equipment", inventory: 40, price: "24.00" },
    { key: "L", title: "Decaf Beans 340g", type: "Coffee", inventory: 30, price: "16.50" },
    { key: "M", title: "Milk Frother", type: "Equipment", inventory: 8, price: "29.00" },
  ].freeze

  class << self
    # Spreads a 30-day total as evenly as whole units allow (neighbouring days differ by at most 1).
    def even(total) = Array.new(30) { |i| ((i + 1) * total / 30) - (i * total / 30) }
  end

  module_function

  def products
    PRODUCTS
  end

  # Units sold per day for the 30 days of the forecast window (29 days ago to today), oldest first. Their totals set the forecast:
  # A climbs then sells out, B climbs, C has a weekly hump, D is flat, the extras sell evenly. E and M sell none.
  DAILY = {
    "A" => [1, 1, 2, 1, 2, 2, 2, 2, 3, 2, 2, 3, 3, 2, 3, 3, 3, 4, 3, 3, 4, 4, 3, 4, 0, 0, 0, 0, 0, 0],
    "B" => [1, 1, 1, 1, 1, 2, 1, 1, 2, 2, 1, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 2, 3, 2, 3, 3, 3, 3, 3, 3],
    "C" => [0, 1] + [1, 1, 2, 3, 2, 1, 1] * 4,
    "D" => [1] * 30,
    "F" => even(24), "G" => even(30), "H" => even(60), "I" => even(30), "J" => even(45), "K" => even(30), "L" => even(15),
  }.freeze

  # Older orders, outside the 30 days, that only show on the 8-week chart. E and M sold back then and stopped.
  OLDER_DAYS_AGO = [54, 51, 47, 44, 40, 37, 33, 30].freeze
  OLDER_LINES = [
    { key: "A", quantity: 4 },
    { key: "B", quantity: 3 },
    { key: "C", quantity: 3 },
    { key: "D", quantity: 3 },
    { key: "E", quantity: 2 },
    { key: "F", quantity: 2 }, { key: "G", quantity: 2 }, { key: "H", quantity: 4 }, { key: "I", quantity: 2 },
    { key: "J", quantity: 3 }, { key: "K", quantity: 2 }, { key: "L", quantity: 1 }, { key: "M", quantity: 1 },
  ].freeze

  # Orders are at noon shop time, so which day they land on never depends on when the seed runs.
  # Today's is at midnight instead, so it is never in the future.
  def orders(today:, zone:)
    at = lambda do |days_ago|
      day = (today - days_ago).in_time_zone(zone)
      days_ago.zero? ? day : day.change(hour: 12) # change, not + 12.hours: DST days are 23 or 25 hours
    end
    older = OLDER_DAYS_AGO.map { |days_ago| { processed_at: at.call(days_ago), lines: OLDER_LINES } }
    recent = 30.times.map do |i|
      lines = DAILY.filter_map { |key, units| { key: key, quantity: units[i] } if units[i].positive? }
      { processed_at: at.call(29 - i), lines: lines }
    end
    older + recent
  end
end
