class CreateOrders < ActiveRecord::Migration
  def self.up
    create_table :orders do |t|
      t.date :order_date, :null => false
      t.string :order_number, :limit => 18, :null => true      # 20091207-000001-23, can be blank at first...
      t.string :name, :limit => 255, :null => false
      t.string :email, :limit => 255, :null => false
      t.string :billing_address, :limit => 255, :null => false
      t.string :billing_city, :limit => 255, :null => false
      t.string :billing_prov, :limit => 255, :null => false
      t.string :billing_country, :limit => 255, :null => false
      t.string :billing_postal, :limit => 255, :null => false
      t.string :shipping_address, :limit => 255, :null => false
      t.string :shipping_city, :limit => 255, :null => false
      t.string :shipping_prov, :limit => 255, :null => false
      t.string :shipping_country, :limit => 255, :null => false
      t.string :shipping_postal, :limit => 255, :null => false
      t.string :credit_card_last, :limit => 4, :null => false
      t.string :ip_address, :limit => 15, :null => false        # 123.123.123.123
      t.float :order_subtotal, :null => false
      t.float :order_gst, :null => false
      t.float :order_total, :null => false
      t.string :order_status, :limit => 20, :null => false
      t.string :gateway_order_id, :limit => 20, :null => true  # Time.new.to_i + order.id => 1261590187-6323
      t.string :gateway_authorization, :limit => 255, :null => true
      
      t.timestamps
    end
  end

  def self.down
    drop_table :orders
  end
end