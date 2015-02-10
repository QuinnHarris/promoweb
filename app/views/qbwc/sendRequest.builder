xml.instruct! :xml, :version=> '1.0', :encoding => 'UTF-8'
xml.instruct! :qbxml, :version=> '7.0'
xml.QBXML do
  xml.QBXMLMsgsRq :onError => 'continueOnError' do
    items(xml, @suppliers, 'Vendor') do |supplier, new_item|
      xml.Name supplier.name[0...41]
      xml.CompanyName supplier.name[0...41]

      xml.VendorAddress do
        generic_address(xml, supplier.address)
      end if supplier.address

      xml.Phone supplier.phone if supplier.phone
      xml.Fax supplier.fax if supplier.fax
      xml.Email supplier.artwork_email if supplier.artwork_email

      xml.VendorTypeRef do
        xml.ListID @qb_list_id['VendorType-Suppliers']
      end if new_item
    end
    
    items(xml, @products, 'ItemNonInventory') do |product, new_item|
      xml.Name "#{product.id}"[0...31]
      xml.IsActive !product.deleted
      xml.ParentRef do
        xml.ListID @qb_list_id['Item-Products']
      end
      xml.ManufacturerPartNumber product.supplier_num
      xml.SalesTaxCodeRef do
        #xml.ListID 
        xml.FullName 'Non'
      end if new_item
      xml.tag!("SalesAndPurchase#{new_item ? '' : 'Mod'}") do
        product_name = product.name.encode('ASCII', :invalid => :replace, :undef => :replace, :replace => '')
        xml.SalesDesc "#{product_name} (#{product.id})"
        xml.SalesPrice '0.00'
        xml.IncomeAccountRef do
          xml.ListID @qb_list_id['Account-Sales']
        end
        xml.ApplyIncomeAccountRefToExistingTxns 1 unless new_item
        
        xml.PurchaseDesc "#{product.supplier_num} - #{product_name}"
        xml.PurchaseCost '0.00'
        xml.ExpenseAccountRef do
          xml.ListID @qb_list_id['Account-COG']
        end
        xml.ApplyExpenseAccountRefToExistingTxns 1 unless new_item
        
        xml.PrefVendorRef do
          xml.ListID product.supplier.quickbooks_id
        end if new_item
      end
    end
    
    items(xml, @decoration_techniques, 'ItemNonInventory') do |technique, new_item|
      xml.Name technique.name
      xml.ParentRef do
	xml.ListID @qb_list_id['Item-Decorations']
      end
      xml.SalesTaxCodeRef do
        xml.FullName 'Non'
      end
      xml.SalesAndPurchase do
        xml.SalesDesc "#{technique.name} - #{technique.unit_name}"
        xml.SalesPrice '0.00'
        xml.IncomeAccountRef do
  	  xml.ListID @qb_list_id['Account-Sales']
        end
        xml.PurchaseDesc "#{technique.name} - #{technique.unit_name}"
        xml.PurchaseCost '0.00'
        xml.ExpenseAccountRef do
	  xml.ListID @qb_list_id['Account-COG']
        end if new_item
      end
    end
 
    items(xml, @customers, 'Customer') do |customer, new_item|
      name = (customer.company_name.strip.empty? ? customer.person_name : customer.company_name)[0...39]
      idx = Customer.find(:all,
        :conditions => ["substr(coalesce(nullif(company_name,''), person_name), 0, 39) = ?", name],
        :order => 'id').index(customer)
      xml.Name encode(name + ((idx && (idx > 0)) ? " #{idx}" : ''))
      xml.IsActive customer.orders.find { |o| !o.closed } ? 1 : 0
#      xml.ParentRef do
#        xml.FullName '100-WEB Customers'
#      end
  
      customer_info(xml, customer)
    end
    
    items(xml, @orders, 'Customer', 'ListID', %w(Name)) do |order, new_item|
      xml.Name "Order #{order.id}"
      xml.IsActive order.closed ? 0 : 1

      xml.ParentRef do
        xml.ListID order.customer.quickbooks_id
      end
      
      customer_info(xml, order.customer)
      
      xml.JobStatus order.closed ? 'Closed' : 'InProgress' 
      xml.JobStartDate order.created_at.strftime("%Y-%m-%d")
      xml.JobProjectedEndDate order.delivery_date.strftime("%Y-%m-%d") if order.delivery_date
      xml.JobEndDate order.updated_at.strftime("%Y-%m-%d") if order.closed
      xml.JobDesc order.event_nature[0...99] if order.event_nature
#      xml.Notes order.customer_notes[0...4095] if order.our_notes
      
      xml.JobTypeRef do
        xml.ListID @qb_list_id["JobType-#{order.closed ? 'Closed' : 'Open'}"]
      end
    end
    

  @invoices.each do |invoice|
    negate = (invoice.total_price.to_i < 0)
    item(xml, invoice, qb_type = (negate ? 'CreditMemo' : 'Invoice'), 'TxnID') do |invoice, new_item|
      xml.CustomerRef do
        xml.ListID invoice.order.quickbooks_id
      end
      xml.ClassRef do
        xml.ListID @qb_list_id['Class']
      end
      #xml.ARAcountRef do
        #xml.FullName "Accounts Receivable"
      #end
      #xml.TemplateRef do
      xml.TxnDate invoice.created_at.strftime("%Y-%m-%d")
      xml.RefNumber invoice.quickbooks_ref if invoice.quickbooks_ref
      bill_ship_address(xml, invoice.order.customer)
      #xml.IsPending
        #xml.IsFinaceCharge
      #xml.PONumber?
      #xml.TermsRef
      xml.DueDate invoice.order.delivery_date if invoice.order.delivery_date
      #xml.SalesRepRef do
      #xml.FOB
      #xml.ShipDate
      #xml.ShipMethodRef do
      taxed = (invoice.tax_type && (invoice.tax_type != 'nonprofit'))
      xml.ItemSalesTaxRef do
        xml.ListID invoice.qb_sales_tax_id
      end if taxed
      xml.Memo "Order #{invoice.order.id}"
      xml.IsToBePrinted 0
      #xml.IsToBeEmailed
      xml.CustomerSalesTaxCodeRef do
        xml.FullName taxed ? 'Tax' : 'Non'
      end
      #xml.Other
      #xml.LinkToTxnIDList  
      sub_items_invoice(xml, invoice.entries, new_item, qb_type, negate, taxed)
      #xml.InvoiceLineGroupAdd do
      #xml.IncludeRetElementList
    end
  end if @invoices

    
    items(xml, @purchase_orders, 'PurchaseOrder', 'TxnID') do |po, new_item|
      purchase = po.purchase
      xml.VendorRef do
        xml.ListID purchase.supplier.quickbooks_id
      end
      xml.ClassRef do
        xml.ListID @qb_list_id['Class']
      end
      xml.ShipToEntityRef do
        xml.ListID purchase.order.quickbooks_id
      end
      xml.RefNumber po.quickbooks_ref if po.quickbooks_ref
      xml.DueDate purchase.order.delivery_date.strftime("%Y-%m-%d") if purchase.order.delivery_date

      xml.ShipMethodRef do
        xml.FullName 'UPS'
      end

      xml.FOB "Yes" if purchase.order.rush  # Set as 'RUSH ORDER'

      xml.TxnDate po.created_at.strftime("%Y-%m-%d")

      xml.Memo "Order #{purchase.order.id}, P: #{purchase.id}"
      xml.IsToBePrinted 1
      #xml.IsToBeEmailed

      xml.Other2 purchase.order.user.name if purchase.order.user  # Set as 'Orderd By'
      
      sub_items_po_bill(xml, purchase, new_item, false)
    end

    items(xml, @bills, 'Bill', 'TxnID', %w(ItemLineRet)) do |bill, new_item|
      purchase = bill.purchase
      xml.VendorRef do
        # Using ListID on Bills causes Quickbooks to crash for some reason QBBUG!
        #xml.ListID purchase.supplier.quickbooks_id
	supplier = purchase.supplier
        supplier = supplier.parent until supplier.attributes['quickbooks_id']
        xml.FullName supplier.attributes['name'][0...41]
      end

      xml.RefNumber((bill.quickbooks_ref.nil? or bill.quickbooks_ref.strip.empty?) ? purchase.purchase_order.quickbooks_ref : bill.quickbooks_ref)

      xml.TxnDate bill.created_at.strftime("%Y-%m-%d")

      xml.Memo "Order #{purchase.order.id}, P: #{purchase.id}"
      
      sub_items_po_bill(xml, purchase, new_item, true)
    end


    @payment_transactions.each do |payment_transaction|
      charge = payment_transaction.amount.to_i > 0
      if charge or payment_transaction.method.is_a?(PaymentCreditCard)
        item(xml, payment_transaction, charge ? 'ReceivePayment': 'ARRefundCreditCard', 'TxnID') do |pt, new_item|
          xml.CustomerRef do
            xml.ListID pt.order.quickbooks_id
          end
#	  xml.RefundFromAccountRef do
#	    xml.FullName "Undeposited Funds"
#	  end unless charge
#         xml.ARAccountRef do
#           xml.FullName "Undeposited Funds"
#         end
          xml.TxnDate pt.created_at.strftime("%Y-%m-%d")
          xml.RefNumber "#{pt.method.billing_id}:#{pt.id}"
	  amount = pt.amount.round_cents.abs
          xml.TotalAmount amount.to_s if charge
          xml.PaymentMethodRef do 
	    xml.FullName pt.method.quickbooks_type
	  end if pt.method.quickbooks_type
          xml.Memo pt.comment
#          xml.DepositToAccountRef do
#	    if pt.is_a?(BitCoinTransaction)
#	      xml.ListID @qb_list_id['Account-Bitcoin']
#	    else
#              xml.FullName "Undeposited Funds"
#	    end
#          end
          xml.DepositToAccountRef do
	    xml.ListID @qb_list_id['Account-Bitcoin']
          end if pt.is_a?(BitCoinTransaction)
	  if charge
            xml.IsAutoApply 1
	  else
	    pt.order.invoices.to_a.find_all { |i| i.total_price.to_i < 0 }.sort_by { |i| [i.total_price.abs == amount ? 0 : 1, i.total_price.abs.to_i] }.each do |invoice|
	      xml.RefundAppliedToTxnAdd do
	        xml.TxnID invoice.quickbooks_id
		refund = [invoice.total_price.abs, amount].min
		xml.RefundAmount refund.to_s
		amount -= refund
	      end
	      break if amount.zero?
	    end
	  end
        end
      else
        item(xml, payment_transaction, 'Check', 'TxnID') do |pt, new_item|
          xml.AccountRef do
            xml.ListID @qb_list_id['Account-Checking']
          end
          xml.PayeeEntityRef do
            xml.ListID pt.order.quickbooks_id
          end
          xml.RefNumber pt.method.billing_id
          xml.TxnDate pt.created_at.strftime("%Y-%m-%d")
          xml.Memo pt.comment

#        if invoice = pt.order.invoices.find { |i| i.total_price == pt.amount }
#          xml.tag!("ApplyCheckToTxn#{new_item ? 'Add' : 'Mod'}") do
#            xml.TxnID invoice.quickbooks_id
#            xml.Amount (-pt.amount).to_s
#          end
#        end

          xml.tag!("ExpenseLine#{new_item ? 'Add' : 'Mod'}") do
            xml.AccountRef do
              xml.FullName "Accounts Receivable"
            end
            xml.Amount pt.amount.abs.to_s
            xml.CustomerRef do
              xml.ListID pt.order.quickbooks_id
            end
            xml.ClassRef do
              xml.ListID @qb_list_id['Class']
            end
 	  end
        end
      end
    end if @payment_transactions
  end
end