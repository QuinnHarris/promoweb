module QbwcHelper
  def item(xml, item, name, id_name = 'ListID', include = [])
    new_item = item.quickbooks_id.nil?
    query = !new_item && item.quickbooks_sequence.nil?
    tag_name = "#{name}#{new_item ? 'Add' : (query ? 'Query' : 'Mod')}"
    xml.tag!("#{tag_name}Rq", :requestID => item.id) do
      if query
        xml.tag!(id_name, item.quickbooks_id)
      else
        xml.tag!(tag_name) do
          unless new_item
            xml.tag!(id_name, item.quickbooks_id)
            xml.EditSequence item.quickbooks_sequence
          end
          yield item, new_item
        end
      end
      
      xml.IncludeRetElement id_name
      xml.IncludeRetElement 'EditSequence'
      unless id_name == 'ListID'
        xml.IncludeRetElement 'RefNumber'
        xml.IncludeRetElement "#{name}LineRet"
      end
      include.each do |elem|
        xml.IncludeRetElement elem
      end
    end
  end

  def items(xml, item_list, name, id_name = 'ListID', include = [], &block)
    return unless item_list
    item_list.each do |item|
      item(xml, item, name, id_name, include, &block)
    end
  end
  
  # Invoice and PO's'
  def sub_item_aspect(xml, item, new_item, qb_type, bill_po = nil, aspect = nil, exclude = nil)
    txn_id = txn_po_id = nil
    if item and item.respond_to?("quickbooks_po_#{aspect ? (aspect+'_') : ''}id")
      txn_id = item && item.send("quickbooks_#{bill_po ? 'bill' : 'po'}_#{aspect ? (aspect+'_') : ''}id")
      txn_po_id = item && item.send("quickbooks_po_#{aspect ? (aspect+'_') : ''}id") if bill_po
    end

    return if exclude #and txn_po_id.nil?

    xml.tag!("#{qb_type}Line#{new_item ? 'Add' : 'Mod'}") do
      xml.TxnLineID txn_id || -1 unless new_item
      xml.ItemRef do
        if item && item.respond_to?(:quickbooks_ref) and item.quickbooks_ref
          xml.ListID item.quickbooks_ref
        else
          xml.FullName 'Misc'
        end
      end unless bill_po and txn_po_id
      
      yield

      if new_item and bill_po and txn_po_id
        xml.LinkToTxn do
          xml.TxnID bill_po.quickbooks_id
          xml.TxnLineID txn_po_id
        end
      end
    end
  end
  
  def sub_item(xml, item, new_item, qb_type, character, negate = nil, bill_po = nil, tax = nil)
    price = item.send("list_#{character}")

    (item.respond_to?(:order_item_variants) ? item.order_item_variants : [item]).each do |oiv|
      next if oiv.quantity == 0
      oiv.order_item.target = item if oiv.respond_to?(:order_item)

      sub_item_aspect(xml, oiv, new_item, qb_type, bill_po, nil, price.marginal.nil?) do
        xml.Desc oiv.description
        xml.Quantity oiv.quantity
        #xml.UnitOfMeasure
        xml.tag!(bill_po ? 'Cost' : 'Rate', negate ? -price.marginal : price.marginal)
        #xml.RatePercent
        #xml.PriceLevelRef do
        xml.ClassRef do
          xml.ListID @qb_list_id['Class']
        end
        #xml.Amount
        #xml.ServiceDate
        xml.SalesTaxCodeRef do
          xml.FullName 'Tax'
        end if tax
        #xml.OverrideItemAccountRef
        unless bill_po
          if oiv.respond_to?(:variant) and oiv.variant
            vp = oiv.variant.properties_unique
            string = vp.delete('color') || ''
            string << " - " + vp.collect { |name, value| "#{name.capitalize}: #{value}" }.join(', ') unless vp.empty?
            xml.Other1 string[0..24] # Item Color
          end
          xml.Other2 oiv.imprint_colors[0..28] if oiv.respond_to?(:imprint_colors)	# Imprint Color
        end
        #xml.LinkToTxn do
        #xml.DataExtList do          
      end
    end

    sub_item_aspect(xml, item, new_item, qb_type, bill_po, nil, price.fixed.nil? || (price.fixed.to_i == 0)) do
      xml.Desc "|- Less Than Minimum Charge"
      xml.Amount(negate ? -price.fixed : price.fixed)
#      xml.ClassRef do
#        xml.ListID @qb_list_id['Class']
#      end
      xml.SalesTaxCodeRef do
        xml.FullName 'Tax'
      end if tax
    end
  
    item.sub_items.each do |sub|
      price = sub.send("list_#{character}")

      no_marginal = (price.marginal.nil? or price.marginal.to_i == 0)
      no_fixed = (price.fixed.nil? or price.fixed.to_i == 0)

      if ((price.marginal.to_i == 0) or
          (price.fixed.to_i == 0)) and
          no_marginal and no_fixed

        # Just a Comment
        sub_item_aspect(xml, sub, new_item, qb_type, bill_po, 'fixed') do
          xml.Desc "|- #{sub.description}"
          xml.Amount '0.00'
          xml.SalesTaxCodeRef do
            xml.FullName 'Tax'
          end if tax
        end
      else
        sufix = true #(no_margin && no_fixed && sub.is_a?())

        sub_item_aspect(xml, sub, new_item, qb_type, bill_po, 'marginal', no_marginal) do
          xml.Desc "|- #{sub.description}#{sufix && ' Unit'}"
          xml.Quantity item.quantity
          xml.tag!(bill_po ? 'Cost' : 'Rate', negate ? -price.marginal : price.marginal)
          xml.SalesTaxCodeRef do
            xml.FullName 'Tax'
          end if tax
        end
        
        sub_item_aspect(xml, sub, new_item, qb_type, bill_po, 'fixed', no_fixed) do
          xml.Desc(no_marginal ? "|- #{sub.description}#{sufix && ' Setup'}" : "|  * Setup")
          xml.Amount(negate ? -price.fixed : price.fixed)
          xml.SalesTaxCodeRef do
            xml.FullName 'Tax'
          end if tax
        end
      end
    end

    # Shipping
    if item.respond_to?(:shipping_type)
      ship_price = item.send("list_shipping_#{character}")
      sub_item_aspect(xml, item, new_item, qb_type, bill_po, 'shipping', ship_price.nil? || ship_price.zero?) do
        xml.Desc "Shipping: #{item.shipping_description}"
        xml.Amount(negate ? -ship_price : ship_price)
        xml.SalesTaxCodeRef do
          xml.FullName 'Tax'
        end if tax
      end
    end
  end
    
  def sub_items_invoice(xml, items, new_item, qb_type, negate = false, tax = nil)
    items.each do |item|
      if item.is_a?(InvoiceOrderItem)
        sub_item(xml, item.order_item, new_item, qb_type, 'price', negate, nil, tax)
        
        correction = item.total_price - item.order_item.total_price
        unless correction.zero?
          sub_item_aspect(xml, item, new_item, qb_type) do
            xml.Desc "Adjustment for past invoice(s)"
            xml.Amount(negate ? -correction : correction)
            xml.SalesTaxCodeRef do
              xml.FullName 'Tax'
            end if tax
          end
        end
      else
        sub_item(xml, item, new_item, qb_type, 'price', negate, nil, tax)
      end      
    end
  end
  
  def sub_items_po_bill(xml, purchase, new_item, bill)
    qb_type = bill ? 'Item' : 'PurchaseOrder'
    purchase.items.each do |item|
      sub_item(xml, item, new_item, qb_type, 'cost', false, bill && purchase.purchase_order)
    end

    purchase.entries.each do |entry|
      sub_item_aspect(xml, entry, new_item, qb_type, bill && purchase.purchase_order) do
        xml.Desc entry.description  
        xml.Quantity entry.quantity 
        xml.tag!(bill ? 'Cost' : 'Rate',  entry.cost)
      end
    end
  end

  def common_address(xml, address)
    xml.City((address.city || '')[0...31])
    xml.State((address.state || '')[0...21])
    xml.PostalCode((address.postalcode || '')[0...13])
    #xml.Country
    #xml.Notes
  end
  
  def generic_address(xml, address)
    xml.Addr1((address.address_1 || '')[0...41])
    xml.Addr2((address.address_2 || '')[0...41])
    common_address(xml, address)
  end
  
  def customer_address(xml, customer, address)
    xml.Addr1 customer.company_name[0...41]
    xml.Addr2 "ATTN: #{(address.name and !address.name.strip.empty?) ? address.name : customer.person_name}"[0...41]
    xml.Addr3((address.address_1 || '')[0...41])
    xml.Addr4((address.address_2 || '')[0...41])
    common_address(xml, address)
  end
  
  def bill_ship_address(xml, customer)
    if address = (customer.bill_address || customer.default_address)
      xml.BillAddress do
        customer_address(xml, customer, address)
      end
    end
      
    if address = (customer.ship_address || customer.default_address)
      xml.ShipAddress do
        customer_address(xml, customer, address)
      end
    end
  end
  
  def customer_info(xml, customer)
    xml.CompanyName customer.company_name[0...41]
    
    name_list = customer.person_name.strip.split(' ')
    #xml.Salutation
    xml.FirstName name_list.shift[0...25] if name_list.length > 1
    xml.MiddleName name_list.shift[0...5] if name_list.length > 1
    xml.LastName name_list.join(' ')[0...25]
    
    bill_ship_address(xml, customer)
    
    xml.Phone customer.phone_numbers.first.number_string[0..21] if customer.phone_numbers.first
    #xml.AltPhone
    #xml.Fax
    xml.Email customer.email_addresses.first.address if customer.email_addresses.first
    xml.Contact customer.person_name[0...41]
    #xml.AltContact
    #xml.CustomerTypeRef do
    #xml.TermsRef do
    #xml.SalesRepRef do
    #xml.SalesTaxCodeRef do
    #xml.ItemSalesTaxRef do
    #xml.ResaleNumber
    #xml.AccountNumber
    #xml.CreditLimit
    #xml.PreferredPaymentMethodRef do
    #xml.CreditCardInfo do
    #xml.job*
    #xml.Notes
    #xml.PriceLevelRef do
    #xml.IncludeRetElement
  end
end
