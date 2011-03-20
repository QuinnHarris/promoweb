class InvoiceEntry < ActiveRecord::Base
  belongs_to :invoice
  attr_accessor :predicesor
  
  composed_of :total_price, :class_name => 'Money', :mapping => %w(total_price units)
  serialize :data
  
  def list_price
    PricePair.new(total_price / quantity, nil)
  end
  
  def sub_items; []; end
    
  def html_row(template, absolute = false)
    desc = description
    desc = "#{predicesor.description} -> #{desc}" if predicesor and predicesor.description != desc
    
    total_quantity = "<strong>#{total_price.to_perty}</strong>"
    if quantity != 1
      total_quantity = "$#{orig_price / quantity} &times; #{quantity} = " + total_quantity
    end

    if predicesor
      if orig_price.zero?
        total_quantity = "Item Removed "
      else
        total_quantity = "(New Price: <strong>#{orig_price.to_perty})</strong> &ndash; (Previous invoice total: <strong>#{predicesor.orig_price.to_perty})</strong> = <strong>#{total_price.to_perty}</strong>"
      end
    end
    
    "#{desc}: <span class='num'>#{total_quantity}</span>"
  end
  
  def orig_price
    (predicesor ? predicesor.orig_price : Money.new(0)) + total_price
  end
end

class InvoiceOrderEntry < InvoiceEntry
  belongs_to :entry, :class_name => 'OrderEntry', :foreign_key => 'entry_id'
end

class InvoicePurchaseEntry < InvoiceEntry
  belongs_to :entry, :class_name => 'PurchaseEntry', :foreign_key => 'entry_id'
end


class InvoiceOrderItem < InvoiceEntry
  belongs_to :entry, :class_name => 'OrderItem', :foreign_key => 'entry_id'
  
  def order_item
    return @item if @item
    attr = data
    # Make consistent on if hash or object !!!
    attr['decorations'] = attr['decorations'].collect { |h| h.is_a?(OrderItemDecoration) ? h : OrderItemDecoration.new(h) }
    attr['entries'] = attr['entries'].collect { |h| h.is_a?(OrderItemEntry) ? h : OrderItemEntry.new(h) }
    attr['order_item_variants'] = attr['order_item_variants'].collect { |h| h.is_a?(OrderItemVariant) ? h : OrderItemVariant.new(h) }

    %w(price cost).each { |n| attr["shipping_#{n}"] = Money.new(attr["shipping_#{n}"]) if attr["shipping_#{n}"] and !attr["shipping_#{n}"].is_a?(Money) }

    @item = OrderItem.new(attr)
    # Kludge to insert product_id if not there (Added Dec 2010)
    @item.product_id = @item.price_group.variants.first.product_id unless @item.product_id
    @item.order = invoice.order
    @item.decorations.each { |d| d.order_item = @item }
    @item.entries.each { |e| e.order_item = @item }
    @item.order_item_variants.each { |v| v.order_item = @item }

    @item
  end
  
  def html_row(template, absolute = false)
    tail = nil
    if predicesor
      tail = ["&ndash; (Previous invoice total: <strong>#{predicesor.orig_price.to_perty}</strong>) = <strong>Total:</strong>", total_price.to_perty]
    end
    template.render(:partial => '/order/order_item',
                    :locals => { :order_item => order_item, :static => true, :absolute => absolute, :shipping => false, :invoice => true, :user => nil, :tail => tail })
  end

  def list_price
    order_item.list_price
  end
  
  def sub_items
    order_item.decorations + order_item.entries
  end
end
