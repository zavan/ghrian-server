class CreateReadings < ActiveRecord::Migration[8.1]
  def change
    create_table :readings do |t|
      t.references :inverter, null: false, foreign_key: true, index: false
      t.datetime :recorded_at
      t.string :device_model
      t.json :data

      t.timestamps
    end
    add_index :readings, [ :inverter_id, :recorded_at ]
  end
end
