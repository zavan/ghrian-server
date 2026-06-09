# One day's energy totals for an inverter (kWh), rolled up from the agent's
# cumulative `today_*` counters. Maintained on each reading (see
# Inverter#record_daily_summary) and summed for month/year/lifetime aggregates.
class DailySummary < ApplicationRecord
  belongs_to :inverter

  # Maps a summary column to the agent payload key it rolls up.
  METRICS = {
    generation_kwh: "today_energy_generation",
    feed_in_kwh: "today_energy_fed_into_grid",
    import_kwh: "today_energy_imported_from_grid",
    consumption_kwh: "today_load_energy_consumption",
    charge_kwh: "today_battery_charge_energy",
    discharge_kwh: "today_battery_discharge_energy"
  }.freeze

  SUM_COLUMNS = METRICS.keys.freeze

  scope :between, ->(range) { where(date: range) }
  scope :chronological, -> { order(:date) }

  # Summed columns over the current relation as a { column => Float } hash.
  def self.totals
    selects = SUM_COLUMNS.map { |col| "COALESCE(SUM(#{col}), 0) AS #{col}" }
    row = select(selects.join(", ")).take
    SUM_COLUMNS.index_with { |col| row[col].to_f }
  end
end
