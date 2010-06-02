require 'net/https'
require 'uri'
require 'digest/md5'
require 'ostruct'
require 'active_merchant'

class CartController < ActionController::Base

  PRICE_NOT_AVAILABLE = 'N/A'

  def savings_for_product_quantity
    result = PRICE_NOT_AVAILABLE
    begin
      product = Product.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      logger.error("Attempt to lookup invalid savings using product id: #{params[:id]}")
    else
      base_pp = product.first_product_price
      if base_pp
        base_price = base_pp.price
        quantity = params[:quantity].to_i
        this_price = product.price_for_quantity(quantity)
        result = sprintf("%4.2f", (quantity.to_f * (base_price - this_price)))  if this_price
      end
    end
    render :text => result
  end

  def price_for_product_quantity
    result = PRICE_NOT_AVAILABLE
    begin
      product = Product.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      logger.error("Attempt to lookup invalid price using product id: #{params[:id]}")
    else
      quantity = params[:quantity].to_i
      this_price = product.price_for_quantity(quantity)
      result = sprintf("%4.2f", this_price) if this_price
    end
    render :text => result
  end

  def add_or_update_in_cart
    begin
      product = Product.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      logger.error("Attempt to add invalid product to cart using product id: #{params[:id]}")
    else
      @cart = find_cart
      @cart.add_product_or_increase_quantity(product, params[:quantity].to_i)
    end
    redirect_to params[:next_url] ? params[:next_url] : :back
  end

  def expresspurchase
    begin
      product = Product.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      logger.error("Attempt to add invalid product to cart using product id: #{params[:id]}")
    else
      empty_cart
      @cart = find_cart
      @cart.add_product_or_increase_quantity(product, params[:quantity].to_i)
    end
    redirect_to params[:next_url] ? params[:next_url] : :back
  end

  def process_cart_change
    # determine which input was used to submit the cart and update or remove accordingly
    if params[:submit_type] == "update" || params[:submit_type] == "notajax" && params[:update_submit]
      params[:update].each do |k,v|
        update_in_cart( k.to_i, v.to_i )
      end
    elsif params[:submit_type] == "remove" || params[:submit_type] == "notajax" && params[:remove_submit]
      params[:remove_submit].each do |k,v|
        # the key contains the product id inserted into the input tag
        remove_from_cart k.to_i
      end
    elsif params[:submit_type] == "empty" || params[:submit_type] == "notajax" && params[:empty_submit]
      empty_cart
    end
    
    #redirect_to :back
    redirect_to "#{request.env["HTTP_REFERER"]}/ajaxcart"
  end
  
  def summary_shipping_cost
    @cart = find_cart
    render :text => sprintf('%.2f',@cart.shipping_total(params[:country]))
  end

  def summary_tax
    @cart = find_cart
    render :text => sprintf('%.2f',@cart.gst_amount(params[:country]))
  end

  def summary_total
    @cart = find_cart
    render :text => sprintf('%.2f',@cart.total(params[:country]))
  end

  def submit_to_processor
    # do nothing if the user did not accept the eula
    #redirect_to :back and return unless params[:agree]
    #if (!params[:agree]) then

    # check to ensure they entered in all the information
    error_list = Array.new
    error_list.push("you must enter your full name") if (params[:name].blank?)
    error_list.push("you must enter your email address") if (params[:email].blank?)
    error_list.push("you must enter your billing address") if (params[:billing_address].blank?)
    error_list.push("you must enter your billing city") if (params[:billing_city].blank?)
    error_list.push("you must enter your billing state/province") if (params[:billing_prov].blank?)
    error_list.push("you must enter your billing country") if (params[:billing_country].blank?)
    error_list.push("you must enter your billing postal code") if (params[:billing_postal].blank?)
    error_list.push("you must enter your shipping address") if (params[:shipping_address].blank?)
    error_list.push("you must enter your shipping city") if (params[:shipping_city].blank?)
    error_list.push("you must enter your shipping state/province") if (params[:shipping_prov].blank?)
    error_list.push("you must enter your shipping country") if (params[:shipping_country].blank?)
    error_list.push("you must enter your shipping postal code") if (params[:shipping_postal].blank?)
    error_list.push("you must select your credit card type") if (params[:card_type].blank?)
    error_list.push("you must enter your credit card number") if (params[:card_number].blank?)
    error_list.push("you must enter your credit card expiry date") if (params[:cc_exp_month].blank? || params[:cc_exp_year].blank?)
    error_list.push("you must enter your credit card verification number (CVV)") if (params[:card_cvv].blank?)
    
    # now check for valid information in various fields...
    # ... full name shoulf have at least one space
    last_space = params[:name].rindex(' ')
    if (last_space != nil) then
      first_name = params[:name][0,last_space].strip
      last_name = params[:name][last_space,params[:name].length-last_space].strip
    else
      error_list.push("you must enter your first and last name and they should be separated by a space (ie. John Smith)")
    end
    
    # ... email should be valid
    email_regex = /\A[\w\.%\+\-]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|jobs|museum)\z/i
    unless (params[:email].blank?) then
      if (params[:email] !~ email_regex) then
        error_list.push("you must enter a properly formatted, valid email address")
      end
    end
    

    # ... create a new credit card object and check the credit card...
    credit_card = ActiveMerchant::Billing::CreditCard.new(
      :number     => (!params[:card_number].blank? ? params[:card_number].strip : ''),
      :month      => params[:cc_exp_month],
      :year       => params[:cc_exp_year],
      :verification_value => (!params[:card_cvv].blank? ? params[:card_cvv].strip : ''),
      :first_name => first_name,
      :last_name  => last_name
    )
    if (!params[:card_number].blank? && !credit_card.valid?) then
      error_list = error_list + credit_card.errors.full_messages
    end
    
    if (error_list.length > 0) then
      rerender_checkout_page(error_list)
      return
    else
      # build out an Order object (to be used to send the order)
      cart = find_cart
      order = Order.new
      order.order_date = Date.today
      order.name = params[:name].strip
      order.email = params[:email].strip
      order.billing_address = params[:billing_address].strip
      order.billing_city = params[:billing_city].strip
      order.billing_prov = params[:billing_prov].strip
      order.billing_country = params[:billing_country].strip
      order.billing_postal = params[:billing_postal].strip
      order.shipping_address = params[:shipping_address].strip
      order.shipping_city = params[:shipping_city].strip
      order.shipping_prov = params[:shipping_prov].strip
      order.shipping_country = params[:shipping_country].strip
      order.shipping_postal = params[:shipping_postal].strip
      order.credit_card_last = params[:card_number].reverse[0,4]
      order.ip_address = request.remote_ip
      order.order_subtotal = cart.ex_gst_total
      order.order_gst = cart.gst_amount
      order.order_shipping_cost = cart.shipping_total(params[:shipping_country].strip)
      order.order_total = cart.total
      order.order_status = 'Ordered'

      order_items = Array.new      
      for item in cart.items do
        order_item = OrderItem.new
        order_item.item_name = "#{item.product.name} (#{item.product.product_category})"
        order_item.item_code = item.product.code
        order_item.item_price = item.product.price_for_quantity(item.quantity, 'CAD')
        order_item.quantity = item.quantity
        order_items.push(order_item)
      end
      order.order_items = order_items

      assign_cart_id
      unless params[:processor_url].blank?

        if (credit_card.valid?) then
          order.save  # save the order so we have a database id (which we'll use for the gateway order_id)

          order.gateway_order_id = "#{Time.new.to_i}-#{order.id}"

          # Send requests to the gateway's test servers
          ActiveMerchant::Billing::Base.mode = :test
          # Send requests to the gateway's production servers
          #ActiveMerchant::Billing::Base.mode = :production

          # Create a gateway object to the Moneris service
          # for Moneris, login is your Store ID, password is your API Token
          gateway = ActiveMerchant::Billing::MonerisGateway.new(
            :login    => 'gateway-login',
            :password => 'gateway-password'
          )

          # Authorize for the cart total (in the number of cents; $10 == 10*100 == 1000 cents)
          cc_total = (cart.total*100).round.to_i
          #cc_total = 100   # set the charge to one dollar for testing to production
          billing_address = { :name => params[:name], :address1 => params[:billing_address], :city => params[:billing_city], :state => params[:billing_prov], :country => params[:billing_country], :zip => params[:billing_postal]}
          gateway_response = gateway.authorize(cc_total, credit_card, :order_id => order.gateway_order_id, :billing_address => billing_address)

          if gateway_response.success?
            # Capture the money
            order.gateway_authorization = gateway_response.authorization
            gateway.capture(cc_total, gateway_response.authorization, :order_id => order.gateway_order_id)
            # all good on the order so save it to the database
            order.save

            # send email to user...
            @order = order
            @page = Page.find_by_url('/store/checkout')
            request.params[:order_number] = order.order_number
            @page.process(request, response)

            plain_body = (@page.part( :email ) ? @page.render_part( :email ) : @page.render_part( :email_plain ))
            html_body = @page.render_part( :email_html ) || nil

            recipients = params[:email].strip
            from = 'orders@example.com'
            subject = "Sample Company - Order ##{@order.order_number}"
            cc = 'customerservice@example.com'
            headers = ''

            Mailer.deliver_generic_mail(
              :recipients => recipients,
              :from => from,
              :subject => subject,
              :plain_body => plain_body,
              :html_body => html_body,
              :cc => cc,
              :headers => headers
            )

            # and clear the user's cart
            empty_cart
          else
            order.destroy
            rerender_checkout_page(error_list, gateway_response)
            return
          end
        end
      end
      
      redirect_to "#{params[:next_url]}?order_number=#{order.order_number}"  
    end
  end
  
  def rerender_checkout_page(error_list = nil, gateway_response = nil)
    @page = Page.find_by_url('/store/checkout')
    @page.process(request, response)
    if (error_list != nil && error_list.length > 0) then
      error_str = "<ul class='error_list'>#{error_list.map { |error| "<li>#{error}</li>" }}</ul>"
      @page.form_errors = "The following error(s) must be fixed before submitting your order:\n#{error_str}"
    elsif (gateway_response != nil) then
      @page.form_errors = "The credit card processing gateway responded with: <b>#{gateway_response.message}</b>."
    end
    render :text => @page.render
  end
  
  def self.form_to_add_or_update_product_in_cart( product, next_url = nil, quantity = nil, src = nil )
    form_str = %Q( <form action="/shopping_trike/cart/add_or_update_in_cart" method="post"
          onsubmit="new Ajax.Request('/shopping_trike/cart/add_or_update_in_cart',
            {asynchronous:true, evalScripts:true, parameters:Form.serialize(this), onSuccess:cart_update}); return false;">
          <input type="hidden" id="product_id" name="id" value="#{ product.id }" /> )
    if (!next_url.blank?) then
      form_str << %Q( <input id="product_next_url" name="next_url" type="hidden" value="#{next_url}" /> )
    end
    
    if (quantity == nil) then
      form_str << %Q( <input id="product_quantity" name="quantity" size="5" type="text" /> )
    else
      form_str << %Q( <input id="product_quantity" name="quantity" type="hidden" value="#{quantity}"/> )
    end
    
    if (src.blank?) then
      form_str << %Q( <input name="commit" type="submit" value="add to cart" /> )
    else
      form_str << %Q( <input type="image" name="commit" type="submit" src="#{src}" value="add to cart" /> )
    end
    
    form_str << %Q( </form> )
  end
  
  def self.form_to_express_purchase_product( product, next_url, quantity, src )
    quantity_input_type = quantity ? 'hidden' : 'text'
    %Q( <form action="/shopping_trike/cart/expresspurchase" method="post"
          >
          <input type="hidden" id="product_id" name="id" value="#{ product.id }" />
          <input id="product_quantity" name="quantity" size="5" type="#{quantity_input_type}" value="#{quantity}" />
          <input id="product_next_url" name="next_url" type="hidden" value="#{next_url}" />
          <input type="image" name="commit" type="submit" src="#{src}" value="express purchase" />
        </form> )
  end
  
  def self.cart_form_start_fragment
    %Q( <form action="/shopping_trike/cart/process_cart_change" method="post" id="shopping_trike_cart_form" onsubmit="new Ajax.Request('/shopping_trike/cart/process_cart_change',
      {asynchronous:true, evalScripts:true, parameters:Form.serialize(this), onSuccess:cart_update}); return false;">
      <input type="hidden" id="submit_type" name="submit_type" value="notajax" /> )
  end
  
  def self.cart_form_end_fragment
    %Q( </form> )
  end
  
  def self.cart_form_fragment_to_remove_an_item_currently_in_cart( product )
    %Q( <input name="remove_submit[#{ product.id }]" type="submit" value="remove" onclick="Form.getInputs(this.form, null, 'submit_type')[0].value = 'remove'" /> )
  end
  
  def self.cart_form_fragment_to_alter_an_item_quantity_in_cart( product, quantity )
    %Q( <input name="update[#{ product.id }]" type="text" size="5" value="#{ quantity }" /> )
  end
  
  def self.cart_form_fragment_to_empty_cart
    %Q( <input name="empty_submit" type="submit" value="empty" onclick="Form.getInputs(this.form, null, 'submit_type')[0].value = 'empty'" /> )
  end
  
  def self.cart_form_fragment_to_update_cart
    %Q( <input name="update_submit" type="submit" value="update" onclick="Form.getInputs(this.form, null, 'submit_type')[0].value = 'update'"/> )
  end
  
  def self.cart_ajaxify_form_div_id
    "shopping_trike_cart"
  end
  
  def self.form_to_payment_processor( processor_url, next_url, eula_label_text )
    %Q( <form action="/shopping_trike/cart/submit_to_processor" method="post">
          <input type="hidden" name="processor_url" value="#{ processor_url }" />
          <input type="hidden" name="next_url" value="#{ next_url }" />
          <input type="checkbox" name="agree" value="yes" /> #{ eula_label_text }<br/>
          <input id="submit_process" name="submit_process" value="create order" type="submit"/>
        </form>)
  end
  
  def self.cart_ajaxify_script( url_base )
    %Q( <script type="text/javascript">
          function cart_update()
          {
            new Ajax.Updater('shopping_trike_cart', '#{url_base}ajaxcart', { method: 'get' });
          }
        </script> )
  end
  
  
  private
    def update_in_cart( prod_id, quantity )
      cart = find_cart
      product = Product.find_by_id( prod_id )
      cart.set_quantity( product, quantity )
    end
    
    def remove_from_cart( prod_id )
      cart = find_cart
      product = Product.find_by_id( prod_id )
      cart.remove_product( product )
    end
  
    def find_cart
      unless session[:cart]
        session[:cart] = Cart.new
      end
      session[:cart]
    end
  
    def empty_cart
      session[:cart] = Cart.new
    end
    
    def contents_xml
      cart = find_cart
      cart.xml
    end
    
    def assign_cart_id
      cart = find_cart
      cart.id = create_cart_id
    end
    
    # This is similar to how session keys are generated. Use this for unique cart ids and
    # _never_ use the session key as we may open ourselves to fixation attacks.
    def create_cart_id
      md5 = Digest::MD5::new
      now = Time::now
      md5.update(now.to_s)
      md5.update(String(now.usec))
      md5.update(String(rand(0)))
      md5.update(String($$))
      md5.update('foobar')
      md5.hexdigest
    end

end
