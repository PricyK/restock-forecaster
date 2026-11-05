# frozen_string_literal: true

namespace :restock do
  desc "Replace the demo products and backdated orders on a dev store (SHOP=your-store.myshopify.com)"
  task seed: :environment do
    product_delete = <<~GQL
      mutation($input: ProductDeleteInput!) {
        productDelete(input: $input, synchronous: true) { deletedProductId userErrors { field message } }
      }
    GQL
    product_set = <<~GQL
      mutation($input: ProductSetInput!) {
        productSet(input: $input, synchronous: true) { product { variants(first: 1) { nodes { id } } } userErrors { field message } }
      }
    GQL
    # BYPASS keeps stock unchanged, so the scenario's inventory numbers survive the backdated orders.
    order_create = <<~GQL
      mutation($order: OrderCreateOrderInput!, $options: OrderCreateOptionsInput) {
        orderCreate(order: $order, options: $options) { userErrors { field message } }
      }
    GQL

    domain = ENV["SHOP"].presence || abort("Usage: SHOP=your-store.myshopify.com bin/rails restock:seed")
    if ShopifyAPI::Context.api_key.blank?
      abort("Missing app credentials. Run:\n  env $(shopify app env show | grep =) bin/rails restock:seed SHOP=#{domain}")
    end
    shop = Shop.find_by(shopify_domain: domain) ||
      abort("#{domain} has not installed the app. Run `shopify app dev` and open the app in that store first.")

    shop.with_shopify_session do |session|
      client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
      gql = lambda do |query, variables = {}|
        body = client.query(query: query, variables: variables).body
        raise "Shopify error: #{body["errors"].to_json}" if body["errors"]

        user_errors = body["data"].values.first.try(:[], "userErrors")
        raise "Shopify error: #{user_errors.to_json}" if user_errors.present?

        body["data"]
      end

      store = gql.call("{ shop { currencyCode ianaTimezone plan { partnerDevelopment } } locations(first: 1) { nodes { id } } }")
      abort("#{domain} is not a development store; refusing to create fake orders.") unless store.dig("shop", "plan", "partnerDevelopment")
      currency = store.dig("shop", "currencyCode")
      location_id = store.dig("locations", "nodes", 0, "id")

      old = gql.call(%({ products(first: 50, query: "tag:'#{SeedScenario::TAG}'") { nodes { id } } })).dig("products", "nodes")
      old.each { |p| gql.call(product_delete, { input: { id: p["id"] } }) }
      puts "Deleted #{old.size} old seed products"

      variant_ids = SeedScenario.products.to_h do |p|
        data = gql.call(product_set, { input: {
          title: p[:title], tags: [SeedScenario::TAG], status: "ACTIVE",
          productOptions: [{ name: "Title", values: [{ name: "Default Title" }] }],
          variants: [{
            optionValues: [{ optionName: "Title", name: "Default Title" }],
            price: p[:price], sku: "SEED-#{p[:key]}", inventoryItem: { tracked: true },
            inventoryQuantities: [{ locationId: location_id, name: "available", quantity: p[:inventory] }],
          }],
        } })
        puts "Created #{p[:title]} (stock #{p[:inventory]})"
        [p[:key], data.dig("productSet", "product", "variants", "nodes", 0, "id")]
      end

      prices = SeedScenario.products.to_h { [_1[:key], BigDecimal(_1[:price])] }
      zone = store.dig("shop", "ianaTimezone")
      orders = SeedScenario.orders(today: Time.current.in_time_zone(zone).to_date, zone: zone)
      orders.each_with_index do |order, i|
        total = order[:lines].sum { |l| prices[l[:key]] * l[:quantity] }
        input = {
          processedAt: order[:processed_at].iso8601,
          lineItems: order[:lines].map { |l| { variantId: variant_ids[l[:key]], quantity: l[:quantity] } },
          transactions: [{ kind: "SALE", status: "SUCCESS", amountSet: { shopMoney: { amount: total.to_s("F"), currencyCode: currency } } }],
        }
        attempts = 0
        begin
          gql.call(order_create, { order: input, options: { inventoryBehaviour: "BYPASS", sendReceipt: false } })
        rescue RuntimeError => e
          # shortcut: fixed 60 s wait, 3 tries, not exponential backoff; fine for 37 orders.
          raise unless e.message.match?(/throttl|too many|limit/i) && (attempts += 1) < 3

          puts "Rate limited, waiting 60 s..."
          sleep(60)
          retry
        end
        puts "Order #{i + 1}/#{orders.size} (#{order[:processed_at].to_date})"
        sleep(12) unless i == orders.size - 1 # dev stores accept about 5 new orders a minute
      end
    end
  end
end
