class CreateMqttConfigs < ActiveRecord::Migration[8.1]
  def change
    create_table :mqtt_configs do |t|
      t.string :host, default: "localhost", null: false
      t.integer :port, default: 1883, null: false
      t.string :username
      t.text :password
      t.string :client_id
      t.string :base_topic, default: "solar", null: false
      t.boolean :use_tls, default: false, null: false

      t.timestamps
    end
  end
end
