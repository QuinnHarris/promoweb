class Admin::EmployeeController <  Admin::BaseController
private
  def calculate
    @year = Time.now.year

    @orders = @user.orders.find(:all, :order => 'orders.id DESC',
                                :include => :tasks_active,
                                :conditions => "order_tasks.created_at > '#{@year}-01-01' AND order_tasks.type = 'CompleteOrderTask'")

#    @orders.delete_if { |o| o.task_completed?(CancelOrderTask) }

    @closed_orders = @orders.find_all { |o| o.closed }

    @total_profit = @closed_orders.inject(Money.new(0)) do |m, o|
      m += o.total_price_cache - o.total_cost_cache
      m
    end

    @commissions = @user.commissions
    @total_settled = @commissions.inject(Money.new(0)) { |m, c| m += c.settled; m }
    @total_payed = @commissions.inject(Money.new(0)) { |m, c| m += c.payed; m }

    @pending_settle = @total_profit - @total_settled
    @pending_pay = (@pending_settle * (@user.commission || 0)).round_cents
  end

public
  def commission
    if params[:id] and params[:id] != @user.id
      @user = User.find(params[:id])
    end

    if @permissions.include?('Super')
      @employees = User.find(:all, :conditions => 'commission IS NOT NULL', :order => 'name')
      unless @user.commission
        @user = @employees.first
      end
    end
      
    calculate
    @acknowledged_orders = @user.orders.find(:all, :order => 'orders.id DESC',
                                :include => :tasks_active,
                                :conditions => "NOT orders.closed AND orders.updated_at > '#{@year}-01-01' AND order_tasks.type = 'AcknowledgeOrderTask'")
    @acknowledged_orders -= @orders
  end

  def make_payment
    calculate
    pay = Money.new(Float(params[:amount]))
    raise "Overpaying" if pay.units > @pending_pay.units

    settle = pay / @user.commission    

    @user.commissions.create(:payed => pay,
                             :settled => settle,
                             :comment => params[:comment] || '')

    redirect :action => :commission
  end
end
