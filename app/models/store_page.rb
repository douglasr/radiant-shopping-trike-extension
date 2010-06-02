class StorePage < Page
  description %{
    A store page provides access to child pages for individual Products, and
    other tags that will prove useful.
  }
  
  attr_accessor :form_errors

  def process( request, response )
    @session = request.session
    super( request, response )
  end
  
  def cache?
    false
  end
  
  include Radiant::Taggable
  
  def find_by_url(url, live = true, clean = false)
    url = clean_url(url) if clean
    
    assess_page_type_from_url_and_load_models(url)

    if @page_type
      self
    else
      super
    end
  end
  
  def tag_part_name(tag)
    case @page_type
    when :product
      tag.attr['part'] || 'product'
    when :ajaxcart
      tag.attr['part'] || 'ajaxcart'
    when :ajaxcheckout
      tag.attr['part'] || 'ajaxcheckout'
    when :eula
      tag.attr['part'] || 'eula'
    else
      tag.attr['part'] || 'body'
    end
  end
  
  # The cart page is rendered via AJAX and inserted into complete pages it
  # must not include a layout.
  def render
    if @page_type == :ajaxcart
      render_part( :ajaxcart )
    else
      super
    end
  end
  
  tag "shopping" do |tag|
    tag.expand
  end
  
  tag "shopping:product" do |tag|
    tag.expand
  end
  
  tag "shopping:product:each" do |tag|
    products = []
    if ! tag.attr['only'].blank?
      products = tag.attr['only'].split(' ').collect { |code| Product.find_by_code(code) }
      products.compact!
    elsif !tag.attr['category'].blank?
      products = Product.find(:all, :conditions => ['product_category = ?',tag.attr['category']], :order => 'code')      
    else
      products = Product.find(:all, :order => 'code')
    end
    result = []
    products.each do |item|
      @product = item
      result << tag.expand
    end
    result
  end
  
  tag "shopping:product:addtocart" do |tag|
    [CartController.form_to_add_or_update_product_in_cart( @product, tag.attr['next_url'], tag.attr['quantity'], tag.attr['src'] )]
  end
  
  tag "shopping:product:expresspurchase" do |tag|
    #img_src = "http://#{tag.render('img_host')}#{tag.attr['src']}"
    #[CartController.form_to_express_purchase_product( @product, tag.attr['next_url'], tag.attr['quantity'], img_src )]
    [CartController.form_to_express_purchase_product( @product, tag.attr['next_url'], tag.attr['quantity'], tag.attr['src'] )]
  end
  
  tag "shopping:product:code" do |tag|
    @product.code
  end
  
  tag "shopping:product:name" do |tag|
    @product.name
  end
  
  tag "shopping:product:description" do |tag|
    @product.description
  end
  
  tag "shopping:product:price" do |tag|
    sprintf('%.2f', @product.price_for_quantity(tag.attr['quantity'] || 1, tag.attr['currency'] || 'USD'))
  end

  tag "shopping:product:link" do |tag|
    store_slug = tag.attr['store_slug'] || slug
    seo_name = ''
    if (!tag.attr['include_name'].blank? && tag.attr['include_name'].downcase == "true") then
      seo_name = "/#{@product.name.downcase.gsub(' ','-')}"
    end
    [link("/#{store_slug}/#{@product.code}#{seo_name}", tag.expand)]
  end

  tag "shopping:cart" do |tag|
    tag.expand
  end

  tag "shopping:cart:form" do |tag|
    result = []
    if @page_type == :ajaxcart
      result << CartController.cart_form_start_fragment
      result << tag.expand
      result << CartController.cart_form_end_fragment
    else
      result << %Q(<div id="#{ CartController.cart_ajaxify_form_div_id }">) 
      
      result << CartController.cart_form_start_fragment
      result << tag.expand
      result << CartController.cart_form_end_fragment
      
      result << "</div>"
      #result << CartController.cart_ajaxify_script( slug )
      result << CartController.cart_ajaxify_script( url )
    end
    result
  end

  tag "shopping:cart:subtotal" do |tag|
    cart = get_or_create_cart
    sprintf('%.2f', cart.ex_gst_total)
  end

  tag "shopping:cart:tax" do |tag|
    cart = get_or_create_cart
    sprintf('%.2f', cart.gst_amount)
  end

  tag "shopping:cart:shipping" do |tag|
    cart = get_or_create_cart
    sprintf('%.2f', cart.shipping_total)
  end

  tag "shopping:cart:total" do |tag|
    cart = get_or_create_cart
    sprintf('%.2f', cart.total)
  end
  
  tag "shopping:cart:empty" do |tag|
    [CartController.cart_form_fragment_to_empty_cart]
  end
  
  tag "shopping:cart:checkout" do |tag|
    cart = get_or_create_cart
    if (cart.items.length > 0) then
      if (tag.attr['image'].blank?) then
        [link("/store/checkout/", "#{tag.attr['name'] || 'checkout'}")]
      else
        [%Q(<a href="#{(!tag.attr['url_prefix'].blank? ? tag.attr['url_prefix'] : '')}/store/checkout/"><img src="#{tag.attr['image']}"></a>)]
      end
    else
      ''
    end
  end

  tag "shopping:checkout:params" do |tag|
    "#{params[tag.attr['name']]}"
  end

  tag "shopping:eula" do |tag|
    tag.expand
  end
  
  tag "shopping:eula:link" do |tag|
    [link("/#{ slug }/eula/", "terms and conditions")]
  end
  
  tag "shopping:cart:update" do |tag|
    [CartController.cart_form_fragment_to_update_cart]
  end
  
  tag "shopping:cart:item" do |tag|
    tag.expand
  end
  
  tag "shopping:cart:item:each" do |tag|
    result = []
    cart = get_or_create_cart
    if cart.items.length > 0
      cart.items.each do |item|
        @cart_item = item
        result << tag.expand
      end
    end
    result
  end

  tag "shopping:cart:item:code" do |tag|
    @cart_item.product.code
  end

  tag "shopping:cart:item:name" do |tag|
    @cart_item.product.name
  end
  
  tag "shopping:cart:item:category" do |tag|
    @cart_item.product.product_category
  end
  
  tag "shopping:cart:item:quantity" do |tag|
    @cart_item.quantity
  end

  tag "shopping:cart:item:unitcost" do |tag|
    sprintf('%4.2f', @cart_item.product.price_for_quantity(@cart_item.quantity, tag.attr['currency']))
  end

  tag "shopping:cart:item:subtotal" do |tag|
    sprintf('%4.2f', @cart_item.product.price_for_quantity(@cart_item.quantity, tag.attr['currency']) * @cart_item.quantity)
  end

  tag "shopping:cart:item:remove" do |tag|
    [CartController.cart_form_fragment_to_remove_an_item_currently_in_cart( @cart_item.product )]
  end

  tag "shopping:cart:item:update" do |tag|
    [CartController.cart_form_fragment_to_alter_an_item_quantity_in_cart( @cart_item.product, @cart_item.quantity )]
  end

  tag "shopping:attempted_url" do |tag|
    CGI.escapeHTML(request.request_uri) unless request.nil?
  end
  
  tag "shopping:checkout" do |tag|
    tag.expand
  end
  
  tag "shopping:checkout:process" do |tag|
    [CartController.form_to_payment_processor( tag.attr['processor_url'], tag.attr['next_url'], tag.expand )]
  end
  
  tag "shopping:form_errors" do |tag|
    form_errors ? "<div class=\"form_errors\"><p>#{form_errors}</p></div>" : ""
  end
  
  tag "shopping:if_order" do |tag|
    @order = Order.find_by_order_number(params[:order_number]) unless (params[:order_number].blank?)
    if (@order != nil) then
      tag.expand
    end    
  end

  tag "shopping:order" do |tag|
    @order = Order.find_by_order_number(params[:order_number]) unless (params[:order_number].blank?)
    if (@order != nil) then
      tag.expand
    end
  end

  tag "shopping:order:order_date" do |tag|
    @order.order_date
  end

  tag "shopping:order:order_number" do |tag|
    @order.order_number
  end

  tag "shopping:order:name" do |tag|
    @order.name
  end

  tag "shopping:order:email" do |tag|
    @order.email
  end

  tag "shopping:order:billing_address" do |tag|
    @order.billing_address
  end

  tag "shopping:order:billing_city" do |tag|
    @order.billing_city
  end

  tag "shopping:order:billing_prov" do |tag|
    @order.billing_prov
  end

  tag "shopping:order:billing_country" do |tag|
    @order.billing_country
  end

  tag "shopping:order:billing_postal" do |tag|
    @order.billing_postal
  end

  tag "shopping:order:shipping_address" do |tag|
    @order.shipping_address
  end

  tag "shopping:order:shipping_city" do |tag|
    @order.shipping_city
  end

  tag "shopping:order:shipping_prov" do |tag|
    @order.shipping_prov
  end

  tag "shopping:order:shipping_country" do |tag|
    @order.shipping_country
  end

  tag "shopping:order:shipping_postal" do |tag|
    @order.shipping_postal
  end

  tag "shopping:order:order_shipping_total" do |tag|
    sprintf('%.2f', @order.order_shipping_cost)
  end

  tag "shopping:order:order_total" do |tag|
    sprintf('%.2f', @order.order_total)
  end

  tag "shopping:order:item" do |tag|
    tag.expand
  end

  tag "shopping:order:item:each" do |tag|
    result = []
    if @order.order_items.length > 0
      @order.order_items.each do |order_item|
        @order_item = order_item
        result << tag.expand
      end
    end
    result
  end
  
  tag "shopping:order:item:code" do |tag|
    @order_item.item_code
  end

  tag "shopping:order:item:name" do |tag|
    @order_item.item_name
  end
  
  tag "shopping:order:item:price" do |tag|
    @order_item.item_price
  end
  
  tag "shopping:order:item:quantity" do |tag|
    @order_item.quantity
  end

  tag "shopping:order:item:if_downloadable" do |tag|
    @product = Product.find_by_code(@order_item.item_code)
    if (@product != nil && @product.is_downloadable) then
      tag.expand
    end
  end

  tag "shopping:order:item:download_href" do |tag|
    "/store/orders/#{@order.order_number}/download/#{@order_item.item_code}"
  end

  tag "shopping:order:item:subtotal" do |tag|
    sprintf('%.2f', @order_item.item_price * @order_item.quantity)
  end


  protected
    def link( url, text )
       %Q(<a href="#{ url }">#{ text }</a>)
    end

    def get_or_create_cart
      @session[:cart] ||= Cart.new
    end

    def assess_page_type_from_url_and_load_models(url)
      if is_a_child_page?(url)
        page_type_and_required_models(url)
      end
    end

    def request_uri
      request.request_uri unless request.nil?
    end

    def is_a_child_page?(url)
      url =~ %r{^#{ self.url }([^/]+)/?[^/]+/?$}
    end

    def page_type_and_required_models(request_uri = self.request_uri)
      code = $1 if request_uri =~ %r{#{self.url}([^/]+)/?[^/]*/?$}
      if code == 'ajaxcart'
        @page_type = :ajaxcart
      elsif code == 'ajaxcheckout'
        @page_type = :ajaxcheckout
      elsif code == 'eula'
        @page_type = :eula
      else
        #@product = Product.new
        #@product.name = parent.url
        @product = Product.find_by_code(code)
        @page_type = :product if @product
      end
    end
  
    def product_or_cart_from_url(url)
      product_or_cart(url)
    end
end
