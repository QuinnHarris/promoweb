/* Remove Abandoned price groups */
BEGIN;
CREATE TEMP TABLE ids AS (SELECT id FROM price_groups) EXCEPT
  ((SELECT price_group_id FROM price_groups_variants) UNION
   (SELECT fixed_id FROM decoration_price_entries) UNION
   (SELECT marginal_id FROM decoration_price_entries) UNION
   (SELECT price_group_id FROM order_items)
   );

DELETE FROM price_entries WHERE price_group_id IN (select id from ids);
DELETE FROM price_groups WHERE id IN (select id from ids);
COMMIT;

/* set orders to those with bad price_group_id */
CREATE temp table cust as SELECT order_id FROM order_items where price_group_id IN ((SELECT id FROM price_groups) EXCEPT
  ((SELECT price_group_id FROM price_groups_variants) UNION
   (SELECT fixed_id FROM decoration_price_entries) UNION
   (SELECT marginal_id FROM decoration_price_entries)));

/* Remove customers without any orders, artworks or payments */
DELETE FROM customers WHERE id NOT IN
  ((select customer_id from orders) UNION
   (select customer_id from artwork_groups) UNION
   (select customer_id from payment_methods));
   


/* Remove deleted variants */
BEGIN;
create temp table vars as select * from variants where deleted and id not in (select variant_id from price_groups_variants join order_items on price_groups_variants.price_group_id = order_items.price_group_id) and id not in (select variant_id from order_item_variants where variant_id is not null);

delete from price_groups_variants where variant_id in (select id from vars);
delete from properties_variants where variant_id in (select id from vars);
delete from variants where id in (select id from vars);
COMMIT;

delete from decorations where deleted and id not in (select decoration_id from order_item_decorations where decoration_id is not null);

DELETE FROM properties WHERE id NOT IN (SELECT DISTINCT property_id FROM properties_variants);

/* Remove customers without name that are old */
BEGIN;
delete from phone_numbers where number_string is null;
delete from email_addresses where address is null;

create temp table cust as select * from customers where (updated_at < '2013-09-01' and person_name = '' and company_name = '' and id not in (select customer_id from email_addresses) and id not in (select customer_id from phone_numbers)) or company_name ~ 'Mountain Express';

delete from order_item_decorations using order_items join orders on order_items.order_id = orders.id join customers on orders.customer_id = customers.id
  where order_item_decorations.order_item_id = order_items.id and customers.id in (select id from cust);
  
delete from order_item_entries using order_items join orders on order_items.order_id = orders.id join customers on orders.customer_id = customers.id
  where order_item_entries.order_item_id = order_items.id and customers.id in (select id from cust);
  
delete from order_item_tasks using order_items join orders on order_items.order_id = orders.id join customers on orders.customer_id = customers.id
  where order_item_tasks.order_item_id = order_items.id and customers.id in (select id from cust);

delete from order_item_variants using order_items join orders on order_items.order_id = orders.id join customers on orders.customer_id = customers.id
  where order_item_variants.order_item_id = order_items.id and customers.id in (select id from cust);

delete from order_items using orders join customers on orders.customer_id = customers.id
  where order_items.order_id = orders.id and customers.id in (select id from cust);
  
delete from order_entries using orders join customers on orders.customer_id = customers.id
  where order_entries.order_id = orders.id and customers.id in (select id from cust);

delete from order_tasks using orders join customers on orders.customer_id = customers.id
  where order_tasks.order_id = orders.id and customers.id in (select id from cust);

delete from payment_transactions using orders join customers on orders.customer_id = customers.id
  where payment_transactions.order_id = orders.id and customers.id in (select id from cust);

delete from invoice_entries using invoices join orders on invoices.order_id = orders.id join customers on orders.customer_id = customers.id
  where invoice_entries.invoice_id = invoices.id and customers.id in (select id from cust);

delete from invoices using orders join customers on orders.customer_id = customers.id
  where invoices.order_id = orders.id and customers.id in (select id from cust);

delete from permissions using orders join customers on orders.customer_id = customers.id
  where permissions.order_id = orders.id and customers.id in (select id from cust);

delete from orders using customers
  where orders.customer_id = customers.id and customers.id in (select id from cust);

delete from customer_tasks using customers
  where customer_tasks.customer_id = customers.id and customers.id in (select id from cust);

delete from artwork_tags using artworks join artwork_groups on artworks.group_id = artwork_groups.id join customers on artwork_groups.customer_id = customers.id
  where artwork_tags.artwork_id = artworks.id and customers.id in (select id from cust);

delete from artworks using artwork_groups join customers on artwork_groups.customer_id = customers.id
  where artworks.group_id = artwork_groups.id and customers.id in (select id from cust);

delete from artwork_groups using customers
  where artwork_groups.customer_id = customers.id and customers.id in (select id from cust);

delete from payment_methods using customers
  where payment_methods.customer_id = customers.id and customers.id in (select id from cust);

delete from purchase_orders using order_items join orders on order_items.order_id = orders.id where purchase_orders.purchase_id = order_items.purchase_id and customer_id in (select id from cust);

delete from bills using order_items join orders on order_items.order_id = orders.id where bills.purchase_id = order_items.purchase_id and customer_id in (select id from cust);

delete from purchases using order_items join orders on order_items.order_id = orders.id where purchases.id = order_items.purchase_id and customer_id in (select id from cust);

delete from shipping_rates where customer_id in (select id from cust);

delete from phone_numbers where customer_id in (select id from cust);
delete from email_addresses where customer_id in (select id from cust);

delete from customers where customers.id in (select id from cust);
COMMIT;


delete from purchase_orders where purchase_id not in (select purchase_id from order_items where purchase_id is not null);
delete from bills where purchase_id not in (select purchase_id from order_items where purchase_id is not null);
delete from purchases where id not in (select purchase_id from order_items where purchase_id is not null);


/* orders with abandoned price group */
SELECT customer_id AS id FROM customers JOIN orders ON customers.id = orders.customer_id JOIN order_items ON orders.id = order_items.order_id
  WHERE order_items.price_group_id IN 
    ((SELECT id FROM price_groups) EXCEPT
       ((SELECT price_group_id FROM price_groups_variants) UNION
        (SELECT fixed_id FROM decoration_price_entries) UNION
        (SELECT marginal_id FROM decoration_price_entries)));


   
/* Abandoned properties */
SELECT * FROM properties WHERE id NOT IN
  (SELECT property_id FROM properties_variants);

/* Duplicate cost groups */
SELECT * FROM price_groups
  LEFT OUTER JOIN price_groups_variants ON price_groups.id = price_groups_variants.price_group.id;

SELECT product_id, COUNT(*) FROM
  (SELECT variants.product_id, price_groups_variants.price_group_id FROM variants
    LEFT OUTER JOIN price_groups_variants ON variants.id = price_groups_variants.variant_id
    LEFT OUTER JOIN price_groups ON price_groups_variants.price_group_id = price_groups.id
    WHERE NULLVALUE(price_groups.source_id)
    GROUP BY variants.product_id, price_groups_variants.price_group_id) AS base
  GROUP BY product_id
  ORDER BY count;


SELECT product_id, MIN(min) FROM variants
  LEFT OUTER JOIN
  (SELECT variant_id, COUNT(*), MIN(price_group_id) FROM
    (SELECT variant_id, price_group_id FROM price_groups_variants
      LEFT OUTER JOIN price_groups ON price_groups_variants.price_group_id = price_groups.id
      WHERE NULLVALUE(price_groups.source_id)
      GROUP BY price_groups_variants.variant_id, price_groups_variants.price_group_id) AS base
    GROUP BY variant_id
    ORDER BY count) AS base
  ON variants.id = base.variant_id
  WHERE count > 1
  GROUP BY product_id
  ORDER BY product_id;


SELECT * FROM order_items
  LEFT OUTER JOIN price_groups_variants ON order_items.price_group_id = price_groups_variants.price_group_id;


  
/* emp */
ALTER TABLE suppliers ALTER COLUMN price_source_id DROP NOT NULL;

/* decoration used */
SELECT suppliers.id, suppliers.name, decoration_techniques.id, decoration_techniques.name FROM decorations
  JOIN products ON product_id = products.id
  JOIN suppliers ON supplier_id = suppliers.id
  JOIN decoration_techniques ON technique_id = decoration_techniques.id
  GROUP BY suppliers.id, suppliers.name, decoration_techniques.id, decoration_techniques.name
  ORDER BY suppliers.id, decoration_techniques.id;
  
  
SELECT products.id, products.supplier_num, products.name, products.price_max_cache, MAX(price_entries.marginal) AS price_min_cache FROM products
  JOIN variants on products.id = variants.product_id
  JOIN price_groups_variants ON variants.id = price_groups_variants.variant_id
  JOIN price_groups ON price_groups_variants.price_group_id = price_groups.id
  JOIN price_entries ON price_entries.price_group_id = price_groups.id
  WHERE nullvalue(price_groups.source_id)
  GROUP BY products.id, products.supplier_num, products.name, products.price_max_cache;
  

/* One time */
alter table order_items alter marginal_price drop not null;
alter table order_items alter fixed_price drop not null;
  
  
CREATE ROLE read_public;
GRANT SELECT ON addresses,categories,categories_keywords,categories_products,customers,decoration_price_entries,decoration_price_groups,decoration_techniques,decorations,keywords,order_entries,order_item_decorations,order_item_entries,order_items,order_states,orders,price_entries,price_groups,price_groups_variants,price_sources,products,properties,properties_variants,suppliers,tags,users,variants,warehouses TO read_public;
GRANT read_public TO "www-data";
GRANT read_public TO "quinn";

CREATE ROLE write_products;
GRANT SELECT, INSERT, UPDATE, DELETE ON price_sources,price_entries,price_groups,price_groups_variants,products,properties,properties_variants,suppliers,tags,variants TO write_products;
GRANT SELECT, UPDATE ON price_sources_id_seq TO write_products;
GRANT write_products to "mongrel";

CREATE ROLE write_orders;
CREATE ROLE write_trivial;
GRANT SELECT, INSERT, UPDATE, DELETE ON addresses,customers,order_states,orders,order_entries,order_items,order_item_entries,order_item_decorations TO write_orders;
GRANT SELECT, UPDATE ON addresses_id_seq,customers_id_seq,order_states_id_seq,orders_id_seq,order_entries_id_seq,order_items_id_seq,order_item_entries_id_seq,order_item_decorations_id_seq TO write_orders;
GRANT UPDATE ON products TO write_trivial;
GRANT write_orders TO "www-data";
GRANT write_trivial TO "www-data";


GRANT SELECT, INSERT, UPDATE, DELETE ON artworks TO write_orders;
GRANT SELECT, UPDATE ON artworks_id_seq TO write_orders;

GRANT SELECT ON countries, regions, zipcodes TO read_public;

GRANT SELECT, INSERT, UPDATE, DELETE ON artwork_order_tags, payment_methods TO write_orders;
GRANT SELECT, INSERT, UPDATE ON customer_tasks, order_tasks, order_item_tasks TO write_orders;
GRANT SELECT, INSERT, UPDATE ON payment_transactions TO write_orders;
GRANT SELECT ON task_definitions TO write_orders;

GRANT SELECT, UPDATE ON artwork_order_tags_id_seq, payment_methods_id_seq, customer_tasks_id_seq, order_tasks_id_seq, order_item_tasks_id_seq, payment_transactions_id_seq TO write_orders;

GRANT SELECT, INSERT, UPDATE, DELETE ON purchase_orders, purchase_order_entries, invoices, invoice_entries TO write_orders;
GRANT SELECT, UPDATE ON purchase_orders_id_seq, purchase_order_entries_id_seq, invoices_id_seq, invoice_entries_id_seq TO write_orders;

GRANT SELECT, INSERT, UPDATE, DELETE ON permissions, delegatables TO write_orders;
GRANT SELECT, UPDATE ON permissions_id_seq, delegatables_id_seq TO write_orders;

GRANT SELECT, INSERT, UPDATE, DELETE ON order_item_variants TO write_orders;
GRANT USAGE ON order_item_variants_id_seq TO write_orders;

GRANT SELECT, INSERT ON call_logs TO freeswitch;
GRANT SELECT, UPDATE ON call_logs_id_seq TO freeswitch;


update users set name = 'Quinn Harris', email = 'quinn@mountainofpromos.com' where login = 'quinn';
update users set name = 'Monica Bosick', email = 'monica@mountainofpromos.com' where login = 'monica';


/* Update lanco supplier_num on variants */
update variants set supplier_num = split_part(variants.supplier_num,'-',1) || '-' || properties.value
  from products, properties_variants
  left outer join properties on properties_variants.property_id = properties.id
  where supplier_id=4 and properties.name = 'color' and variants.product_id = products.id and variants.id = properties_variants.variant_id;
  
update variants set supplier_num = split_part(variants.supplier_num,'-',1)
  from products
  where variants.product_id = products.id and supplier_id=4 and 
    variants.id not in 
(select variants.id
  from variants, products, properties_variants
  left outer join properties on properties_variants.property_id = properties.id
  where properties.name = 'color' and variants.product_id = products.id and variants.id = properties_variants.variant_id);
  
  

select products.supplier_num AS product_num, variants.id, variants.supplier_num AS variant_num, properties.value,
  products.supplier_num || '-' || properties.value
  from products 
  left outer join variants on products.id = variants.product_id 
  left outer join properties_variants on variants.id = properties_variants.variant_id
  left outer join properties on properties_variants.property_id = properties.id
  where supplier_id=4 and properties.name = 'color';
  order by length;


select products.supplier_num AS product_num, variants.id, variants.supplier_num AS variant_num
  from products 
  left outer join variants on products.id = variants.product_id 
  where supplier_id=4;
  

select name, count(*) from (select person_name as name from customers) as sub group by name order by count;




/* Get all added product ids */
select product_id, count(*) from (SELECT product_id from variants where id IN ((select price_groups_variants.variant_id from order_items join price_groups_variants on order_items.price_group_id = price_groups_variants.price_group_id) UNION (SELECT variant_id FROM order_items where NOT NULLVALUE(variant_id)))) as sub group by product_id order by count; 


/* Set all products on an order to the cost + 20% */
UPDATE order_items set marginal_price = min*1.2, marginal_cost = min
  FROM (SELECT price_group_id, min(marginal) FROM price_entries GROUP BY price_group_id) AS cost
  WHERE order_id = 3608 AND order_items.price_group_id = cost.price_group_id;
;




CREATE TABLE sites (
  id   SERIAL PRIMARY KEY,
  type VARCHAR(32) NOT NULL,
  hit_at TIMESTAMP,
  
  created_at TIMESTAMP NOT NULL
);

CREATE TABLE pages (
  id    SERIAL PRIMARY KEY,
  site_id INTEGER NOT NULL REFERENCES sites(id),
  request_uri VARCHAR NOT NULL,
  UNIQUE (site_id, request_uri),
  fetch_started_at TIMESTAMP,
  fetch_complete_at TIMESTAMP,

  updated_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP NOT NULL
);

CREATE TABLE page_products (
  id    SERIAL PRIMARY KEY,
  page_id INTEGER NOT NULL REFERENCES pages(id),
  product_id INTEGER NOT NULL,
  UNIQUE (page_id, product_id),
  
  correct BOOLEAN,
  score FLOAT
);

CREATE INDEX pages_pop ON pages ( site_id, fetch_started_at, fetch_complete_at);


/* Prune crawl DB */
DELETE FROM pages WHERE id NOT IN (SELECT page_id from page_products);


/* Access */
CREATE INDEX page_accesses_address ON page_accesses ( address );
CREATE INDEX page_accesses_created_at ON page_accesses ( created_at );

SELECT order_session_accesses.order_id, it.count, page_accesses.created_at, page_accesses.params LIKE '%gclid%' AS ppc, page_accesses.referer FROM
  (SELECT session_access_id, MIN(id) AS page_access_id, count(*) FROM page_accesses WHERE NOT nullvalue(referer) GROUP BY session_access_id) AS it
  JOIN page_accesses ON it.page_access_id = page_accesses.id
  JOIN session_accesses ON it.session_access_id = session_accesses.id
  JOIN order_session_accesses ON it.session_access_id = order_session_accesses.session_access_id
  WHERE nullvalue(session_accesses.user_id)
  ORDER BY order_session_accesses.order_id;

SELECT order_id FROM order_tasks WHERE type = 'AcknowledgeOrderTask' AND active ORDER BY order_id;


CREATE ROLE access_write;
CREATE ROLE access_read;
GRANT access_write TO "mongrel";
GRANT access_read TO "mongrel";

GRANT SELECT ON order_session_accesses, page_accesses, session_accesses TO access_read;
GRANT SELECT, INSERT ON order_session_accesses, page_accesses TO access_write;
GRANT SELECT, INSERT, UPDATE ON session_accesses TO access_write;
GRANT USAGE ON order_session_accesses_id_seq, page_accesses_id_seq, session_accesses_id_seq TO access_write;



/* Remove categories */
BEGIN;
delete from categories_products;
delete from categories_keywords;
update products set featured_id = null, featured_at = null;
delete from categories where id > 1;
update categories set rgt = 2 where id = 1;
COMMIT;

CREATE INDEX page_access_index ON page_accesses (controller, action, action_id);



delete from page_accesses where controller = 'products' and action = 'main' and nullvalue(action_id) and nullvalue(params);



/* Find missing google category products */
SELECT id, name FROM products WHERE NOT deleted AND id NOT IN (
  WITH RECURSIVE my_categories(id) AS (
      SELECT id FROM categories WHERE google_category IS NOT NULL
    UNION
      SELECT c.id FROM categories c, my_categories m WHERE c.parent_id = m.id
    )
  SELECT categories_products.product_id FROM my_categories JOIN categories_products ON my_categories.id = categories_products.category_id) ORDER BY id;

/* Find missing google categories */
  WITH RECURSIVE my_categories(id) AS (
      SELECT id FROM categories WHERE google_category IS NOT NULL
    UNION
      SELECT c.id FROM categories c, my_categories m WHERE c.parent_id = m.id
    )
  SELECT id, name FROM categories WHERE id NOT IN (SELECT id FROM my_categories);


insert into decoration_techniques (name, parent_id, unit_name) values ('Laser Engrave - Level 1', 10, 'location');
insert into decoration_techniques (name, parent_id, unit_name) values ('Laser Engrave - Level 2', 10, 'location');
insert into decoration_techniques (name, parent_id, unit_name) values ('Laser Engrave - Level 3', 10, 'location');

insert into decoration_techniques (name, unit_name) values ('PhotoGrafixx', 'location');
insert into decoration_techniques (name, parent_id, unit_name) values ('PhotoGrafixx - Level 1', 145, 'location');
insert into decoration_techniques (name, parent_id, unit_name) values ('PhotoGrafixx - Level 2,3', 145, 'location');
insert into decoration_techniques (name, parent_id, unit_name) values ('PhotoGrafixx - Level 4', 145, 'location');

insert into decoration_techniques (name, unit_name) values ('Pen Print', 'colors');

insert into decoration_techniques (name, unit_name) values ('Color Print', 'colors') RETURNING id;
insert into decoration_techniques (name, parent_id, unit_name) values ('Color Print - Level 1', 178, 'colors');
insert into decoration_techniques (name, parent_id, unit_name) values ('Color Print - Level 2', 178, 'colors');


SELECT
  "orders".*
FROM "orders"
WHERE "orders"."user_id" = 16 AND "orders"."id" IN (SELECT
                                                      id
                                                    FROM "order_tasks"
                                                    WHERE
						      orders.created_at > '2014-01-01' AND
                                                      "order_tasks"."type" IN
                                                      ('CompleteOrderTask')) AND
      (closed) AND (NOT settled)
ORDER BY orders.id DESC;


SELECT
  "orders"."id"                          AS t0_r0,
  "orders"."customer_id"                 AS t0_r1,
  "orders"."delivery_date"               AS t0_r2,
  "orders"."event_nature"                AS t0_r3,
  "orders"."special"                     AS t0_r4,
  "orders"."customer_notes"              AS t0_r5,
  "orders"."our_notes"                   AS t0_r6,
  "orders"."created_at"                  AS t0_r7,
  "orders"."updated_at"                  AS t0_r8,
  "orders"."process_order"               AS t0_r9,
  "orders"."user_id"                     AS t0_r10,
  "orders"."our_comments"                AS t0_r11,
  "orders"."terms"                       AS t0_r12,
  "orders"."rush"                        AS t0_r13,
  "orders"."ship_method"                 AS t0_r14,
  "orders"."fob"                         AS t0_r15,
  "orders"."closed"                      AS t0_r16,
  "orders"."quickbooks_id"               AS t0_r17,
  "orders"."quickbooks_at"               AS t0_r18,
  "orders"."quickbooks_sequence"         AS t0_r19,
  "orders"."urgent_note"                 AS t0_r20,
  "orders"."total_price_cache"           AS t0_r21,
  "orders"."total_cost_cache"            AS t0_r22,
  "orders"."commission"                  AS t0_r23,
  "orders"."payed"                       AS t0_r24,
  "orders"."settled"                     AS t0_r25,
  "orders"."delivery_date_not_important" AS t0_r26,
  "orders"."tax_rate"                    AS t0_r27,
  "orders"."tax_type"                    AS t0_r28,
  "orders"."purchase_order"              AS t0_r29,
  "order_tasks"."id"                     AS t1_r0,
  "order_tasks"."order_id"               AS t1_r1,
  "order_tasks"."comment"                AS t1_r2,
  "order_tasks"."created_at"             AS t1_r3,
  "order_tasks"."updated_at"             AS t1_r4,
  "order_tasks"."user_id"                AS t1_r5,
  "order_tasks"."data"                   AS t1_r6,
  "order_tasks"."type"                   AS t1_r7,
  "order_tasks"."host"                   AS t1_r8,
  "order_tasks"."active"                 AS t1_r9,
  "order_tasks"."expected_at"            AS t1_r10
FROM "orders"
  LEFT OUTER JOIN "order_tasks"
    ON "order_tasks"."order_id" = "orders"."id" AND order_tasks.active
WHERE "orders"."user_id" = 16 AND
      (closed AND NOT orders.settled AND order_tasks.type = 'CompleteOrderTask')
ORDER BY orders.id DESC



/* most used suppliers */
SELECT * FROM
(SELECT suppliers.name, count(*) FROM suppliers
  JOIN products ON products.supplier_id = suppliers.id
  JOIN order_items ON order_items.product_id = products.id
  JOIN orders ON orders.id = order_items.order_id
  WHERE orders.closed AND orders.id IN (SELECT order_id FROM order_tasks WHERE type = 'CompleteOrderTask')
    AND orders.created_at > '2014-01-01'
  GROUP BY suppliers.name) AS t1
  ORDER BY count;




SELECT EXTRACT(year from order_tasks.created_at) as year, EXTRACT(month from order_tasks.created_at) as month,
  sum(total_price_cache) as price, sum(total_cost_cache) as cost
FROM orders JOIN order_tasks ON orders.id = order_tasks.order_id
WHERE order_tasks.type = 'CompleteOrderTask' and order_tasks.active
GROUP BY EXTRACT(year from order_tasks.created_at), EXTRACT(month from order_tasks.created_at)
ORDER BY EXTRACT(year from order_tasks.created_at), EXTRACT(month from order_tasks.created_at);
