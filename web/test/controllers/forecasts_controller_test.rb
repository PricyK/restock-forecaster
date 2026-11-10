# frozen_string_literal: true

require "test_helper"
require "shopify_app/test_helpers/all"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  include ShopifyApp::TestHelpers::ShopifySessionHelper

  SHOP = "test-shop.myshopify.com"
  VARIANT = { id: "gid://shopify/ProductVariant/1", product_title: "Cold Brew Can", variant_title: nil,
              sku: "CB-1", inventory: 6 }.freeze

  setup do
    ShopifyAPI::Context.setup(api_key: "key", api_secret_key: "secret", host: "https://app.test",
      scope: "read_products", is_embedded: true, is_private: false, api_version: "2026-10")
    setup_shopify_session(session_id: "session-1", shop_domain: SHOP).access_token = "token"
    @data = stub(today: Date.new(2026, 11, 10), variants: [VARIANT], units_sold: { VARIANT[:id] => 60 },
      daily_units: { Date.new(2026, 11, 10) => 6 })
    ShopifyStoreData.stubs(:new).returns(@data)
  end

  test "returns forecast rows" do
    get_forecast
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "critical", body["rows"].first["risk"]
    assert_equal 3, body["rows"].first["days_left"]
    assert_equal "2026-11-13", body["rows"].first["run_out_date"]
    assert_equal "2026-11-10", body["generated_on"]
  end

  test "returns 502 when Shopify fails" do
    @data.stubs(:variants).raises(ShopifyStoreData::Error, "Throttled")
    get_forecast
    assert_response 502
    assert_equal "Couldn't load data from Shopify. Try again.", JSON.parse(response.body)["error"]
  end

  test "returns 502 when the Shopify request itself fails" do
    @data.stubs(:variants).raises(http_error(503))
    get_forecast
    assert_response 502
  end

  test "retries once with a fresh token after a 401" do
    ShopifyApp::Auth::TokenExchange.expects(:perform).once
      .returns(ShopifyAPI::Auth::Session.new(shop: SHOP, access_token: "fresh"))
    @data.stubs(:variants).raises(http_error(401)).then.returns([VARIANT])
    get_forecast
    assert_response :success
  end

  test "passes a 30 day window" do
    @data.expects(:units_sold).with(since: Date.new(2026, 10, 12)).returns({})
    get_forecast
    assert_response :success
  end

  test "returns sales history" do
    get_sales_history
    assert_response :success
    ranges = JSON.parse(response.body)["ranges"]
    assert_equal ["7 days", "30 days", "8 weeks"], ranges.map { _1["label"] }
    assert_equal({ "date" => "2026-11-10", "units" => 6 }, ranges.first["points"].last)
  end

  test "sales history reads 8 weeks for the requested variant" do
    @data.expects(:daily_units).with(VARIANT[:id], since: Date.new(2026, 9, 16)).returns({})
    get_sales_history
    assert_response :success
  end

  test "sales history needs a variant_id" do
    get "/api/sales_history"
    assert_response :bad_request
  end

  test "sales history returns 502 when Shopify fails" do
    @data.stubs(:daily_units).raises(ShopifyStoreData::Error, "Throttled")
    get_sales_history
    assert_response 502
    assert_equal "Couldn't load data from Shopify. Try again.", JSON.parse(response.body)["error"]
  end

  private

  def get_sales_history
    get "/api/sales_history", params: { variant_id: VARIANT[:id] }
  end

  def get_forecast
    get "/api/forecast" # session is stubbed by setup_shopify_session, so no session token header
  end

  def http_error(code)
    ShopifyAPI::Errors::HttpResponseError.new(response: ShopifyAPI::Clients::HttpResponse.new(code: code, headers: {}, body: ""))
  end
end
