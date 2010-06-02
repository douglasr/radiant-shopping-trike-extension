class AddShippingCostToOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :order_shipping_cost, :float
    
    execute <<-SQLEND
      UPDATE orders SET order_shipping_cost=0.0;
      ALTER TABLE orders ALTER COLUMN order_shipping_cost SET NOT NULL;
    SQLEND
  end

  def self.down
    remove_column :orders, :order_shipping_cost
  end
end