UPDATE suppliers set quickbooks_id = null, quickbooks_at = null, quickbooks_sequence = null;
update suppliers set quickbooks_at = '3000-01-01' where parent_id is not null;
UPDATE decoration_techniques set quickbooks_id = null, quickbooks_at = null, quickbooks_sequence = null;

UPDATE products set quickbooks_id = 'BLOCKED', quickbooks_at = null, quickbooks_sequence = null;
UPDATE customers SET quickbooks_id = 'BLOCKED', quickbooks_at = null, quickbooks_sequence = null;
UPDATE orders SET quickbooks_id = 'BLOCKED', quickbooks_at = null, quickbooks_sequence = null;
UPDATE invoices SET quickbooks_id = 'BLOCKED', quickbooks_at = null, quickbooks_sequence = null;
UPDATE purchase_orders SET quickbooks_id = 'BLOCKED', quickbooks_at = null, quickbooks_sequence = null;
UPDATE bills SET quickbooks_id = 'BLOCKED', quickbooks_at = null, quickbooks_sequence = null;
UPDATE payment_transactions SET quickbooks_id = 'BLOCKED', quickbooks_at = null, quickbooks_sequence = null where type IN ('PaymentCharge', 'PaymentCredit', 'PaymentBitCoinAccept');

UPDATE order_entries SET quickbooks_id = null, quickbooks_at = null;
UPDATE order_item_decorations SET quickbooks_po_marginal_id = null, quickbooks_po_fixed_id = null, quickbooks_bill_marginal_id = null, quickbooks_bill_fixed_id = null;
UPDATE order_item_entries SET quickbooks_po_marginal_id = null, quickbooks_po_fixed_id = null, quickbooks_bill_marginal_id = null, quickbooks_bill_fixed_id = null;
UPDATE order_item_variants SET quickbooks_po_id = null, quickbooks_bill_id = null;
UPDATE order_items SET quickbooks_po_id = null, quickbooks_po_shipping_id = null, quickbooks_bill_id = null, quickbooks_bill_shipping_id = null;
UPDATE purchase_entries SET quickbooks_po_id = null, quickbooks_bill_id = null;


update purchase_orders set quickbooks_id = null where created_at > '2014-01-01';
update bills set quickbooks_id = null where purchase_id in (select purchase_id from purchase_orders where created_at > '2014-01-01');
update invoices set quickbooks_id = null where created_at > '2014-01-01';
update orders set quickbooks_id = null where id in ((select order_id from order_items join purchase_orders on order_items.purchase_id = purchase_orders.purchase_id where purchase_orders.created_at > '2014-01-01') UNION (SELECT order_id from invoices where created_at > '2014-01-01'));
update customers set quickbooks_id = null where id in (select customer_id from orders where id in ((select order_id from order_items join purchase_orders on order_items.purchase_id = purchase_orders.purchase_id where purchase_orders.created_at > '2014-01-01') UNION (SELECT order_id from invoices where created_at > '2014-01-01')));
update products set quickbooks_id = null where id in (select product_id from order_items where order_id in ((select order_id from order_items join purchase_orders on order_items.purchase_id = purchase_orders.purchase_id where purchase_orders.created_at > '2014-01-01') UNION (SELECT order_id from invoices where created_at > '2014-01-01')));
update payment_transactions SET quickbooks_id = null where order_id in ((select order_id from order_items join purchase_orders on order_items.purchase_id = purchase_orders.purchase_id where purchase_orders.created_at > '2014-01-01') UNION (SELECT order_id from invoices where created_at > '2014-01-01'));
