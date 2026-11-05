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

  # 10 orders, one every 3 days from 1.5 to 28.5 days ago, set the forecast. "E" sells none of them.
  # 6 older orders, 33.5 to 53.5 days ago, only show on the 8-week chart: B sold half as much, E sold then stopped.
  def orders(now:)
    recent = 10.times.map do |i|
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
    older = 6.times.map do |j|
      {
        processed_at: now - (33.5 + 4 * j).days,
        lines: [
          { key: "A", quantity: 1 },
          { key: "B", quantity: 3 },
          { key: "C", quantity: 3 },
          { key: "D", quantity: 3 },
          { key: "E", quantity: 2 },
        ],
      }
    end
    recent + older
  end
end
