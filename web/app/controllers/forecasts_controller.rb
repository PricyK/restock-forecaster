# frozen_string_literal: true

class ForecastsController < AuthenticatedController
  # GET /api/forecast
  def show
    today = Date.current # shortcut: server time zone, not the shop's; use the shop's ianaTimezone if stores span zones.
    rows = with_token_refetch(current_shopify_session, shopify_id_token) do
      data = ShopifyStoreData.new(ShopifyAPI::Clients::Graphql::Admin.new(session: current_shopify_session))
      Forecast.call(variants: data.variants, units_sold: data.units_sold(since: today - Forecast::WINDOW_DAYS), today: today)
    end
    render(json: { generated_on: today, rows: rows })
  rescue ShopifyStoreData::Error, ShopifyAPI::Errors::HttpResponseError => e
    logger.error("Forecast failed: #{e.message}")
    render(json: { error: "Couldn't load data from Shopify. Try again." }, status: :bad_gateway)
  end
end
