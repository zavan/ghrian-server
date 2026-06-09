json.inverter_id @inverter.id
json.metric @metric if @metric

json.readings @readings do |reading|
  json.recorded_at reading.recorded_at
  if @metric
    # Single-metric series: compact { recorded_at, value, unit }.
    json.value reading.value_for(@metric)
    json.unit reading.unit_for(@metric)
  else
    json.device_model reading.device_model
    json.values reading.data || {}
  end
end
