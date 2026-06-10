json.inverter_id @inverter.id
json.date @date.to_s

# power: one named series per element (PV/Grid/Load/Battery), each `data` a list of
# [recorded_at, kW] pairs. soc: a single [recorded_at, percent] series. Times serialize
# as ISO8601; values are already kW / % from Inverter#intraday_series.
json.power @series[:power]
json.soc @series[:soc]
