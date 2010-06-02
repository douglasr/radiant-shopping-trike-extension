# Uncomment this if you reference any of your controllers in activate
#require_dependency 'application'

class ShoppingTrikeExtension < Radiant::Extension
  version "0.2.0"
  description "A simple cart for RadiantCMS"
  url "http://github.com/douglasr/radiant-shopping-trike-extension"
  
  define_routes do |map|
    # map.connect 'admin/store/:action', :controller => 'store'
    # Product Routes
    
    map.namespace :admin, :member => { :remove => :get } do |admin|
      admin.resources :products, :member => { :remove => :get }, :has_many => [:product_prices, :coupons]
      admin.resources :product_prices, :member => { :remove => :get }
      admin.resources :coupons, :member => { :remove => :get }
      admin.resources :orders, :member => { :remove => :get }
    end
    
    map.with_options(:controller => 'admin/products') do |product|
      product.update_ccy     'admin/products/ccy/edit/:ccy', :action => 'update_ccy', :ccy => /[a-z]{3}-[a-z]{3}/
    end

    #map.connect '/store/cart/:action', :controller => 'cart'
    map.connect '/merchant/:action', :controller => 'cart'
    map.connect '/shopping_trike/cart/:action', :controller => 'cart'
    map.connect '/store/orders/search', :controller => 'orders', :action => 'search'
    map.connect '/store/orders/:order_number', :controller => 'orders', :action => 'show'
    map.connect '/store/orders/:order_number/download/:code', :controller => 'orders', :action => 'download'
    map.connect '/store/orders/:order_number/:action', :controller => 'orders'
    map.connect '/store/thanks', :controller => 'orders', :action => 'thanks'
  end
  
  def activate
    StorePage
    SiteController.class_eval do
      session :disabled => false
    end

    SiteController.send :include, InPlaceEditing

    admin.tabs.add "Products", "/admin/products", :after => "Layouts", :visibility => [:all]
    admin.tabs.add "Orders", "/admin/orders", :after => "Layouts", :visibility => [:all]
  end
  
  def deactivate
    admin.tabs.remove "Orders"
    admin.tabs.remove "Products"
  end
end
