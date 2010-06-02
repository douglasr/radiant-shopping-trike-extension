class OrdersController < ActionController::Base

  def thanks
    if (params[:order_number].blank?) then
      redirect_to '/store'
      return
    end
    
    @order = Order.find_by_order_number(params[:order_number].strip)
    @page = Page.find_by_url('/store/thanks')
    @page.process(request, response)
    render :text => @page.render
  end

  def search
    if (params[:order_number].blank?) then
      redirect_to '/store/orders'
      return
    end
    
    @order = Order.find_by_order_number(params[:order_number].strip)
    if (@order != nil) then
      redirect_to "/store/orders/#{@order.order_number}"
      return
    end
    
    redirect_to '/store/orders'
  end

  def show
    @page = Page.find_by_url('/store/orders')
    @page.process(request, response)
    render :text => @page.render
  end

  def download
    download_path = Radiant::Config["shopping.download_path"]
    use_xsendfile = Radiant::Config["shopping.use_xsendfile"]
    code = params[:code]
    symlink_path = "#{download_path}/#{code}"
    filename = File.readlink(symlink_path)
    
    # make sure this order has this code in it
    order = Order.find_by_order_number(params[:order_number])
    order_item = OrderItem.find_by_order_id(order.id, :conditions => ['item_code=?',code])
    if (order == nil || order_item == nil) then
      redirect_to '/file_not_found'
      return
    end
    send_file "#{download_path}/#{filename}", :x_sendfile => (use_xsendfile == 'true')
  end

end