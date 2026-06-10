totals = @summary.totals

json.inverter_id @inverter.id if @inverter
json.period @summary.period
json.date @summary.date.to_s
json.label @summary.label

json.range do
  json.from @summary.range.begin.to_s
  json.to @summary.range.end.to_s
end

json.currency @tariff.currency
json.tariff_configured @tariff.configured?

# Energy in kWh.
json.totals do
  json.generation totals.generation
  json.self_consumption totals.self_consumption
  json.feed_in totals.feed_in
  json.import totals.import
  json.consumption totals.consumption
  json.charge totals.charge
  json.discharge totals.discharge
end

# Money in the tariff's currency.
json.costs do
  json.import_cost totals.import_cost(@tariff)
  json.export_earnings totals.export_earnings(@tariff)
  json.net totals.net(@tariff)
  json.savings totals.savings(@tariff)
end

# Column-chart breakdown for month/year/lifetime; null for "day" (use /intraday there).
if @summary.breakdown
  json.breakdown_unit @summary.breakdown_unit
  json.breakdown @summary.breakdown do |label, value|
    json.label label
    json.value value
  end
else
  json.breakdown nil
end
