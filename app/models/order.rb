class Order < ActiveRecord::Base
  has_many :order_items, :dependent => :destroy
  before_save :generate_order_number

protected
  def generate_order_number
    # if we don't have an order number yet, generate one
    if (self.order_number.blank?) then
      # only generate the order number if a CC gateway authorization has been set
      unless (self.gateway_authorization.blank?) then
        curr_date_str = Date.today.strftime('%Y%m%d')
        last_order_number = Order.maximum(:order_number)
        last_order_number =~ /[0-9]+\-([0-9]+)\-[0-9]+/
        next_order_number = ($1.to_i) + 1
        random_digits = rand(100)
        self.order_number = "#{curr_date_str}-#{"%06d" % next_order_number}-#{"%02d" % random_digits}"
      end
    end
  end
  
end
