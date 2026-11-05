# frozen_string_literal: true

# The fixed demo store: five products and ten backdated orders that give one of each risk level.
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

  # 10 orders, one every 3 days from 1.5 to 28.5 days ago. "E" never sells.
  def orders(now:)
    10.times.map do |i|
      {
        processed_at: now - (3 * i + 1.5).days,
        lines: [
          { key: "A", quantity: 1 },
          { key: "B", quantity: 6 },
          { key: "C", quantity: i.even? ? 4 : 5 },
          { key: "D", quantity: 3 },
        ],
      }
    end
  end
end
