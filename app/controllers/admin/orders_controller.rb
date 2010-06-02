class Admin::OrdersController < Admin::ResourceController
  model_class Order

  def show
    @order = Order.find(params[:id])
  end

protected

  def load_models
    # Sort the orders with the most recent at the top
    self.models = model_class.all(:order => 'id desc')
  end

end
