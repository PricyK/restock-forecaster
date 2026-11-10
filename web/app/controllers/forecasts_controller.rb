# frozen_string_literal: true

class ForecastsController < AuthenticatedController
  rescue_from ShopifyStoreData::Error, ShopifyAPI::Errors::HttpResponseError, with: :shopify_failed

  # GET /api/forecast
  def show
    body = with_token_refetch(current_shopify_session, shopify_id_token) do
      data = store_data
      today = data.today
      units = data.units_sold(since: today - (Forecast::WINDOW_DAYS - 1)) # 30 days counting today
      { generated_on: today, rows: Forecast.call(variants: data.variants, units_sold: units, today: today) }
    end
    render(json: body)
  end

  # GET /api/sales_history?variant_id=gid://shopify/ProductVariant/1
  def sales_history
    variant_id = params.require(:variant_id) # only compared with ids from Shopify, so no format check
    body = with_token_refetch(current_shopify_session, shopify_id_token) do
      data = store_data
      today = data.today
      daily = data.daily_units(variant_id, since: today - (SalesHistory::DAYS - 1))
      { ranges: SalesHistory.call(daily_units: daily, today: today) }
    end
    render(json: body)
  end

  private

  def store_data
    ShopifyStoreData.new(ShopifyAPI::Clients::Graphql::Admin.new(session: current_shopify_session))
  end

  def shopify_failed(error)
    logger.error("Shopify request failed: #{error.message}")
    render(json: { error: "Couldn't load data from Shopify. Try again." }, status: :bad_gateway)
  end
end
