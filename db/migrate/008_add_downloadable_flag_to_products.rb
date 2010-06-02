class AddDownloadableFlagToProducts < ActiveRecord::Migration
  def self.up
    add_column :products, :is_downloadable, :boolean, :default => false
    
    execute <<-SQLEND
      UPDATE products SET is_downloadable=false;
      ALTER TABLE products ALTER COLUMN is_downloadable SET NOT NULL;
    SQLEND
  end

  def self.down
    remove_column :products, :is_downloadable
  end
end
