# frozen_string_literal: true

class ForecastsController < AuthenticatedController
  # GET /api/forecast
  def show
    body = with_token_refetch(current_shopify_session, shopify_id_token) do
      data = ShopifyStoreData.new(ShopifyAPI::Clients::Graphql::Admin.new(session: current_shopify_session))
      today = data.today
      units = data.units_sold(since: today - Forecast::WINDOW_DAYS)
      { generated_on: today, rows: Forecast.call(variants: data.variants, units_sold: units, today: today) }
    end
    render(json: body)
  rescue ShopifyStoreData::Error, ShopifyAPI::Errors::HttpResponseError => e
    logger.error("Forecast failed: #{e.message}")
    render(json: { error: "Couldn't load data from Shopify. Try again." }, status: :bad_gateway)
  end
end
