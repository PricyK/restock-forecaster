# frozen_string_literal: true

require "test_helper"

class WebhooksTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  SECRET = "test-secret"
  WEBHOOKS = {
    "app_uninstalled" => ["app/uninstalled", AppUninstalledJob],
    "app_scopes_update" => ["app/scopes_update", AppScopesUpdateJob],
    "customers_data_request" => ["customers/data_request", CustomersDataRequestJob],
    "customers_redact" => ["customers/redact", CustomersRedactJob],
    "shop_redact" => ["shop/redact", ShopRedactJob],
  }.freeze

  setup do
    @old_secret = ShopifyApp.configuration.secret
    ShopifyApp.configuration.secret = SECRET
  end

  teardown { ShopifyApp.configuration.secret = @old_secret }

  WEBHOOKS.each do |path, (topic, job)|
    test "#{path} webhook is accepted and queues #{job}" do
      body = { shop_domain: "test-shop.myshopify.com", current: ["read_products"] }.to_json
      assert_enqueued_with(job: job) do
        post "/api/webhooks/#{path}", params: body, headers: signed_headers(body, topic)
      end
      assert_response :no_content
    end
  end

  test "unsigned webhook is rejected" do
    post "/api/webhooks/shop_redact", params: "{}", headers: signed_headers("{}", "shop/redact").merge("X-Shopify-Hmac-Sha256" => "bad")
    assert_response :unauthorized
  end

  private

  def signed_headers(body, topic)
    {
      "Content-Type" => "application/json",
      "X-Shopify-Hmac-Sha256" => Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", SECRET, body)),
      "X-Shopify-Topic" => topic,
      "X-Shopify-Shop-Domain" => "test-shop.myshopify.com",
      "X-Shopify-API-Version" => "2026-10",
      "X-Shopify-Webhook-Id" => SecureRandom.uuid,
    }
  end
end
