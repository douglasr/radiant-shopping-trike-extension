class CreateOrderItems < ActiveRecord::Migration
  def self.up
    create_table :order_items do |t|
      t.integer :order_id, :null => false
      t.string :item_name, :limit => 145, :null => false
      t.string :item_code, :limit => 40, :null => false
      t.float :item_price, :null => false
      t.integer :quantity, :null => false
    end
  end

  def self.down
    drop_table :order_items
  end
end