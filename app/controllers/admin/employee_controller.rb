class Admin::EmployeeController <  Admin::BaseController
private
  def calculate
    if params[:id] and params[:id] != @user.id
      @user = User.find(params[:id])
    end

    if @permissions.include?('Super')
      @employees = User.find(:all, :conditions => 'commission IS NOT NULL', :order => 'name')
      unless @user.commission
        @user = @employees.first
      end
    end

    @closed_orders = @user.orders.find(:all, :order => 'orders.id DESC',
                                :include => :tasks_active,
                                :conditions => "closed AND NOT orders.settled AND order_tasks.type = 'CompleteOrderTask'")

    @total_profit = @closed_orders.inject(Money.new(0)) do |m, o|
      m += o.total_price_cache - o.total_cost_cache
      m
    end

    @commissions = @user.commissions
#    @total_settled = @commissions.inject(Money.new(0)) { |m, c| m += c.settled; m }
    @total_payed = @commissions.inject(Money.new(0)) { |m, c| m += c.payed; m }

#    @pending_settle = @total_profit - @total_settled
#    @pending_pay = (@pending_settle * (@user.commission || 0)).round_cents
  end

public
  def commission
    @title = "Commissions"
    calculate
    @acknowledged_orders = @user.orders.find(:all, :order => 'orders.id DESC',
                                :include => :tasks_active,
                                :conditions => "NOT orders.closed AND order_tasks.type = 'AcknowledgeOrderTask'")
    @acknowledged_orders -= @closed_orders

    @payed_orders = @user.orders.find(:all, :order => 'orders.id DESC',
                                     :conditions => "settled AND orders.updated_at > NOW() - '3 months'::interval")
  end

  def apply_commission
    calculate
    pay = Money.new(Float(params[:commission][:payed]))

    Commission.transaction do
      @user.commissions.create(:payed => pay,
                               :comment => params[:commission][:comment] || '')

      @closed_orders.reverse.each do |order|
        p = [order.payable - order.payed, pay].min
        pay -= p
        order.payed += p
        order.settled = (order.payed == order.payable)
        order.commission = order.commission
        order.save!
        break if pay.zero?
      end

      raise "Overpaying" unless pay.zero?
    end

    redirect_to :action => :commission
  end
end
