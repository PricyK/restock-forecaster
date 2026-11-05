# frozen_string_literal: true

require "test_helper"

# Guards the gem set: unpinned upgrades broke this path twice (ostruct missing, json 3 vs Rails 7.1).
class ShopifyApiLoadTest < ActiveSupport::TestCase
  test "a GraphQL request round-trips through shopify_api" do
    ShopifyAPI::Context.setup(api_key: "key", api_secret_key: "secret", host: "https://app.test",
      scope: "read_products", is_embedded: true, is_private: false, api_version: "2026-10")
    session = ShopifyAPI::Auth::Session.new(shop: "test-shop.myshopify.com", access_token: "token")
    stub_request(:post, "https://test-shop.myshopify.com/admin/api/2026-10/graphql.json")
      .to_return(body: { data: { shop: { name: "Test" } } }.to_json, headers: { "Content-Type" => "application/json" })

    response = ShopifyAPI::Clients::Graphql::Admin.new(session: session).query(query: "{ shop { name } }")

    assert_equal "Test", response.body.dig("data", "shop", "name")
  end
end
