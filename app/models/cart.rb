class Cart
  attr_reader :items
  attr_accessor :id
  attr_accessor :gst_charged
  attr_accessor :currency
  
  def initialize(currency = 'USD', options = {:gst_charged => true})
    @currency = currency
    @items = []
    options.each_pair {|k, v| self.send(:"#{k}=", v) }
  end
  
  def add_product_or_increase_quantity(product, quantity, upgrade = false)
    if product.is_a?(Coupon)
      matching_product = cart_item_for_product( product.product )
      if coupon || (quantity > 1)
        raise(ArgumentError, "You can only add one Coupon per order")
      elsif matching_product.nil? 
        raise(ArgumentError, "Invalid coupon (no matching products in your cart)")
      elsif !product.current?
        raise(ArgumentError, "Coupon has expired or is otherwise not valid")
      else
        matching_product.apply_coupon(product)
      end
    else # product is a Product
      current_item = cart_item_for_product( product )
      if current_item
        current_item.quantity += quantity
      else
        current_item = CartItem.new(product, quantity, upgrade)
        @items << current_item
      end
    end
    tidy
  end
  
  def set_quantity(product, quantity)
    current_item = cart_item_for_product( product )
    current_item.quantity = quantity
    tidy
  end
  
  def override_with_product_quantity(product, quantity)
    current_item = CartItem.new(product, quantity)
    @items = [ current_item ]
    tidy
  end
  
  def remove_product( product )
    item = cart_item_for_product( product )
    @items.delete( item ) if item
  end
  
  def quantity_of_product( product )
    item = cart_item_for_product( product )
    item.quantity if item
  end
  
  def gst_charged?
    @gst_charged
  end
  
  def ex_gst_total
    grand_total = 0
    items.each do |item|
      grand_total += item.subtotal(@currency, false)
    end
    grand_total
  end

  def shipping_total(country_iso = nil)
    shipping_total = 0.0
    num_shippable_items = self.number_of_shippable_items
    if (!country_iso.blank? && num_shippable_items > 0) then
      # get the cost for the first item
      config_value = Radiant::Config["shopping.shipping_cost.first.#{country_iso}"]
      if (config_value == nil) then
        config_value = Radiant::Config["shopping.shipping_cost.first.XX"]        
      end
      shipping_total += config_value.to_f unless config_value.blank?

      # now get the cost for each additional item
      if (num_shippable_items > 1) then
        config_value = Radiant::Config["shopping.shipping_cost.additional.#{country_iso}"]
        if (config_value == nil) then
          config_value = Radiant::Config["shopping.shipping_cost.additional.XX"]        
        end
        shipping_total += (config_value.to_f * (items.length-1)) unless config_value.blank?     
      end
    end
    shipping_total
  end

  def total(country_iso = nil)
    grand_total = 0
    items.each do |item|
      grand_total += item.subtotal(@currency, @gst_charged)
    end
    tmp_ship_costs =  shipping_total(country_iso)
    grand_total += tmp_ship_costs + (tmp_ship_costs * 0.05).round(2)
    grand_total
  end

  def gst_amount(country_iso = nil)
    total(country_iso) - ex_gst_total - shipping_total(country_iso)
  end

  def number_of_shippable_items
    count = 0
    for item in items do
       count += 1 unless (item.product.is_downloadable)
    end
    count
  end

  private
    def cart_item_for_product( product )
       items.find {|item| item.product == product}
    end
    
    def tidy
      items.each do |item|
        # every item must have a quantity of at least one
        remove_product( item.product ) if item.quantity < 1
      end
    end

    def coupon
      item = items.select {|item| item.coupon? }.first
      item.product if item
    end

end
