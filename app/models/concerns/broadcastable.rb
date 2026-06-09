# Turbo Stream broadcasting for the dashboard. Kept in one place so models just
# call `broadcast_tile` after a state change. Broadcasts are best-effort: a cable
# failure must never break MQTT ingestion (which runs in a separate process).
#
# Only the inverter's live region is re-broadcast (power flow + battery + today's
# energy); the intraday chart is left to refresh on full page loads to avoid
# resetting it on every reading.
module Broadcastable
  extend ActiveSupport::Concern

  # Stream name the dashboard subscribes to (see dashboards/show view).
  DASHBOARD_STREAM = "dashboard"

  def broadcast_tile
    broadcast_replace_to(
      DASHBOARD_STREAM,
      target: ActionView::RecordIdentifier.dom_id(self, :live),
      partial: "inverters/live",
      locals: { inverter: self }
    )
  rescue => e
    Rails.logger.warn("[broadcast] #{e.class}: #{e.message}")
  end
end
