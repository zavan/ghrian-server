class CreateInverters < ActiveRecord::Migration[8.1]
  def change
    create_table :inverters do |t|
      t.string :name
      t.string :device_model
      t.string :mqtt_topic
      t.string :serial_number
      t.integer :status, default: 0, null: false
      t.datetime :last_reading_at
      t.datetime :last_seen_at
      t.json :latest_values

      t.timestamps
    end
    add_index :inverters, :mqtt_topic, unique: true
  end
end
