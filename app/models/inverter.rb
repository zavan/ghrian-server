# A solar inverter whose live data the agent publishes to MQTT. Inverters are
# shared across the installation (no per-user ownership). This model owns the
# ingestion behavior (no service layer): Inverter.ingest routes an MQTT message,
# and the instance persists a Reading / flips availability and refreshes the
# cached `latest_values` snapshot used by the dashboard and API.
class Inverter < ApplicationRecord
  include Broadcastable

  AVAILABILITY_SUFFIX = "/availability"

  # Force JSON (de)serialization regardless of adapter handling of the column type.
  attribute :latest_values, :json

  has_many :readings, dependent: :delete_all
  has_many :daily_summaries, dependent: :delete_all

  enum :status, { unknown: 0, online: 1, offline: 2 }, default: :unknown

  # Summed energy totals (kWh) over a period, plus derived self-consumption. Money
  # values are computed against a Tariff (see #import_cost etc.).
  EnergyTotals = Struct.new(
    :generation, :feed_in, :import, :consumption, :charge, :discharge,
    keyword_init: true
  ) do
    def self_consumption
      [ generation - feed_in, 0 ].max
    end

    def import_cost(tariff) = tariff.cost(import)
    def export_earnings(tariff) = tariff.earnings(feed_in)

    # Net money: what you earned exporting minus what you paid importing.
    def net(tariff) = (export_earnings(tariff) - import_cost(tariff)).round(2)

    # Money avoided by self-consuming PV instead of importing it.
    def savings(tariff) = tariff.cost(self_consumption)
  end

  validates :name, presence: true
  validates :mqtt_topic, presence: true, uniqueness: true

  # Route one incoming MQTT message to the matching inverter. A topic is either a
  # data topic (exact `mqtt_topic`) or the agent's retained "<topic>/availability".
  # Unknown topics are ignored (an inverter must be added in the admin first).
  def self.ingest(topic:, payload:)
    if topic.end_with?(AVAILABILITY_SUFFIX)
      find_by(mqtt_topic: topic.delete_suffix(AVAILABILITY_SUFFIX))&.apply_availability(payload)
    else
      find_by(mqtt_topic: topic)&.record_reading(payload)
    end
  end

  # The retained availability topic the agent maintains via its MQTT Last Will.
  def availability_topic
    "#{mqtt_topic}#{AVAILABILITY_SUFFIX}"
  end

  # Persist a decoded data message and refresh the cached snapshot + status.
  # Returns the Reading, or nil if the payload was not valid JSON.
  def record_reading(payload)
    parsed = payload.is_a?(String) ? JSON.parse(payload) : payload
    values = parsed["values"] || {}
    recorded_at = parse_time(parsed["timestamp"])

    reading = readings.create!(recorded_at: recorded_at, device_model: parsed["device_model"], data: values)
    update!(
      device_model: parsed["device_model"].presence || device_model,
      latest_values: values,
      last_reading_at: recorded_at,
      last_seen_at: Time.current,
      status: :online
    )
    record_daily_summary(reading)
    broadcast_tile
    reading
  rescue ActiveRecord::RecordNotUnique
    # QoS-1 redelivery of a message we already stored (same inverter + timestamp).
    # The original insert already refreshed the snapshot and summary, so skip it.
    Rails.logger.debug("[ingest] duplicate reading on #{mqtt_topic} at #{recorded_at}; skipped")
    nil
  rescue JSON::ParserError => e
    Rails.logger.warn("[ingest] invalid JSON on #{mqtt_topic}: #{e.message}")
    nil
  end

  # Roll a reading's cumulative `today_*` counters into its day's summary. The
  # counters are monotonic within a day, so we keep the running max per column.
  def record_daily_summary(reading)
    date = reading.recorded_at.in_time_zone.to_date
    summary = daily_summaries.find_or_initialize_by(date: date)
    DailySummary::METRICS.each do |column, key|
      value = reading.value_for(key)
      summary[column] = [ summary[column] || 0.0, value.to_f ].max if value.is_a?(Numeric)
    end
    summary.save! if summary.changed?
    summary
  end

  # Recompute every DailySummary from stored readings (e.g. after a backfill).
  def rebuild_daily_summaries!
    daily_summaries.delete_all
    readings.chronological.each { |reading| record_daily_summary(reading) }
  end

  # Mirror the agent's retained availability ("online"/"offline") into status.
  def apply_availability(payload)
    online = payload.to_s.strip.casecmp?("online")
    update!(status: online ? :online : :offline, last_seen_at: Time.current)
    broadcast_tile
  end

  # Latest value/unit for a metric from the cached snapshot (defensive).
  def current_value(key)
    latest_values&.dig(key.to_s, "value")
  end

  def current_unit(key)
    latest_values&.dig(key.to_s, "unit")
  end

  # Display-ready live overview (power flow, battery/grid state, today energy).
  def snapshot
    Snapshot.new(latest_values)
  end

  # Intraday time-series for the dashboard chart. Returns power series (kW) for
  # PV/Grid/Load/Battery plus a separate SOC series (%), built from stored readings.
  INTRADAY_POWER = {
    "PV" => "total_dc_output_power",
    "Grid" => "inverter_ac_grid_port_power",
    "Load" => "household_load_power",
    "Battery" => "battery_power"
  }.freeze

  def intraday_series(date: Date.current)
    rows = readings.where(recorded_at: date.all_day).chronological.to_a

    power = INTRADAY_POWER.map do |name, key|
      data = rows.filter_map do |reading|
        value = reading.value_for(key)
        [ reading.recorded_at, (value / 1000.0).round(3) ] if value.is_a?(Numeric)
      end
      { name: name, data: data }
    end

    soc = rows.filter_map do |reading|
      value = reading.value_for("battery_soc")
      [ reading.recorded_at, value ] if value.is_a?(Numeric)
    end

    { power: power, soc: [ { name: "SOC", data: soc } ] }
  end

  # Energy totals (kWh) over a date range, as an EnergyTotals value object.
  def totals_between(range)
    sums = daily_summaries.between(range).totals
    EnergyTotals.new(
      generation: sums[:generation_kwh],
      feed_in: sums[:feed_in_kwh],
      import: sums[:import_kwh],
      consumption: sums[:consumption_kwh],
      charge: sums[:charge_kwh],
      discharge: sums[:discharge_kwh]
    )
  end

  private
    def parse_time(raw)
      raw.present? ? Time.zone.parse(raw.to_s) : Time.current
    rescue ArgumentError, TypeError
      Time.current
    end
end
