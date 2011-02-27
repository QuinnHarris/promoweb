class Order < ActiveRecord::Base
  belongs_to :customer

  # Tasks
  OrderTask
  include ObjectTaskMixin
  has_tasks
  def tasks_context
    (tasks_active + tasks_dep.find_all { |t| t.is_a?(OrderTask) || t.is_a?(CustomerTask) }).uniq
  end

  # Used by status page
  def tasks_all
    (tasks_dep.find_all { |t| !t.new_record? } +
     customer.tasks_inactive + tasks_inactive + items.collect { |i| i.tasks_inactive }.flatten).uniq.sort_by { |t| t.created_at } 
  end
    
  has_many :items, :class_name => 'OrderItem', :foreign_key => 'order_id', :order => "order_items.id"
  has_many :entries, :class_name => 'OrderEntry', :foreign_key => 'order_id'
  has_many :payment_transactions
  
  has_many :permissions

  validates_each :delivery_date do |record, attr, value|
    if record.send("#{attr}_changed?") && value && value < Date.today+2
      record.errors.add attr, "must be #{Date.today+2} or later"
    end
  end

  def days_to_deliver
    return nil unless delivery_date

    return -1 if delivery_date < Date.today

    days = (delivery_date - Date.today).to_i
    current = Date.today
    while current < delivery_date
      if current.wday == 0
        days -= 1
        current += 6
        next
      end
      days -= 1 if current.wday == 6
      current += 1
    end

    days
  end

  def suppliers
    return @suppliers if @suppliers

    @suppliers = Supplier.find(:all,
                               :conditions =>
      "id IN (SELECT DISTINCT supplier_id FROM products " + 
             "JOIN variants ON products.id = variants.product_id " +
             "JOIN price_groups_variants on variants.id = price_groups_variants.variant_id " +
             "JOIN order_items ON price_groups_variants.price_group_id = order_items.price_group_id " +
             "WHERE order_id = #{id})")
  end
  
  has_many :invoices_ref, :class_name => 'Invoice', :foreign_key => 'order_id', :order => 'invoices.id'
  def invoices
    return @invoices if @invoices
    @invoice_entries = {}
    @invoices = invoices_ref.find(:all, :include => :entries)
    @invoices.each do |invoice|
      invoice.entries.each do |entry|
        id = [entry.class.to_s, entry.entry_id]
        entry.predicesor = invoice_entries[id]
        @invoice_entries[id] = entry
      end
    end
    new_invoice = generate_invoice
    @invoices << new_invoice if new_invoice
    @invoices
  end
  def invoice_entries
    return @invoice_entries if @invoice_entries
    invoices
    @invoice_entries
  end

  def generate_invoice
    included = []
    
    InvoiceEntry
    invoice = Invoice.new(:order => self)
    (items + po_entries + entries).each do |entry|
      invoice_klass = Kernel.const_get(entry.class.reflections[:invoice_entries].class_name)
      entry_last = invoice_entries[[invoice_klass.to_s, entry.id]]
      included << entry_last if entry_last
      total = entry_last ? entry_last.orig_price : Money.new(0)
      if total != entry.total_price
        invoice.entries << invoice_klass.new({
          :invoice => invoice,
          :predicesor => entry_last,
          :entry => entry,
          :description => entry.description,
          :data => entry.respond_to?(:invoice_data) ? entry.invoice_data : nil,
          :total_price => (entry.total_price - total).max,
          :quantity => entry.quantity})
      end
    end
    
    (invoice_entries.values - included).each do |entry|
      if !entry.total_price.zero? and !entry.orig_price.zero?
        invoice.entries << entry.class.new({
          :invoice => invoice,
          :predicesor => entry,
          :entry_id => entry.entry_id,
          :description => entry.description,
          :data => entry.data,
          :total_price => Money.new(0) - entry.orig_price,
          :quantity => entry.quantity})        
      end
    end
        
    invoice.entries.empty? ? nil : invoice
  end
  
  belongs_to :user
  
  def po_entries
    purchase_list = items.collect { |i| i.purchase_id }.compact
    PurchaseEntry.find(:all, :include => :purchase,
      :conditions => ['purchases.id IN (?)', purchase_list])
  end
  
  def total_price
    invoices.inject(Money.new(0)) { |m, i| m += i.total_price}
  end
  
  def total_charge
    total = Money.new(0)
    payment_transactions.each { |t| total += t.amount }
    total
  end
  
  def total_billable
    total_price - total_charge
  end

  %w(price cost).each do |type|
    define_method "save_#{type}!" do
      items.each { |i| i.send("save_#{type}!") }
    end

    define_method "total_item_#{type}" do
      total = MyRange.new(Money.new(0))
      items.each { |i| total += i.new_record? ? Money.new(0) : i.send("total_#{type}") }
      entries.each { |i| total += i.send("total_#{type}") }
      total.single || total
    end
  end
  
  def tasks_dep
    return @tasks_dep if @tasks_dep

    complete_task, task_list = OrderTask.assemble_deps([customer], self, ClosedOrderTask)

    @tasks_dep = TaskSet.order(task_list)
  end
  
  def tasks_allowed(permissions)
    tasks_dep.find_all { |t| t.ready? and t.allowed?(permissions) }
  end
  
  def permissions_for_user(user)
    Permission.find(:all,
      :conditions => ['(order_id IS NULL OR order_id = ?) AND user_id = ?', id, user.id]
    ).collect { |p| p.name }
  end
  
  def tasks_allowed_for_user(user)
    tasks_allowed(permissions_for_user(user))
  end

  # Price Cost Cache
  %w(price cost).each do |type|
    composed_of "total_#{type}_cache".to_sym, :class_name => 'Money', :mapping => ["total_#{type}_cache", 'units']
  end
  composed_of :payed, :class_name => 'Money', :mapping => ["payed", 'units']

  before_save :update_cache
  def update_cache
    self['total_price_cache'] = price = total_item_price.min.round_cents
    self['total_cost_cache'] = cost = total_item_cost.min.round_cents
    self.quickbooks_id = 'BLOCKED'
    true
  end

  def push_quickbooks!
    Order.transaction do
      if self.quickbooks_id == 'BLOCKED'
        self.quickbooks_id = nil
        self.save!
      end
      if customer.quickbooks_id == 'BLOCKED'
        customer.quickbooks_id = nil
        customer.save!
      end
    end
  end

  def total_profit_cache
    total_price_cache - total_cost_cache
  end

  def commission
    attributes['commission'] || user.commission
  end

  def payable
    (total_profit_cache * commission).round_cents
  end
end
