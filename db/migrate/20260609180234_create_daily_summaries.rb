class CreateDailySummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_summaries do |t|
      t.references :inverter, null: false, foreign_key: true, index: false
      t.date :date, null: false
      t.float :generation_kwh, default: 0, null: false
      t.float :feed_in_kwh, default: 0, null: false
      t.float :import_kwh, default: 0, null: false
      t.float :consumption_kwh, default: 0, null: false
      t.float :charge_kwh, default: 0, null: false
      t.float :discharge_kwh, default: 0, null: false

      t.timestamps
    end
    # Unique per inverter/day; also serves range + grouping queries for aggregates.
    add_index :daily_summaries, [ :inverter_id, :date ], unique: true
  end
end
