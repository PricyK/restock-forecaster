# frozen_string_literal: true

require "test_helper"

# shopify_api 16.3.1 names OpenStruct in a type signature but never requires "ostruct".
class ShopifyApiLoadTest < ActiveSupport::TestCase
  test "shopify_api can build an HTTP response" do
    response = ShopifyAPI::Clients::HttpResponse.new(code: 200, headers: {}, body: "")
    assert_equal 200, response.code
  end
end
