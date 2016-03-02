COPY (
SELECT EXTRACT(year from order_tasks.created_at) as year, EXTRACT(month from order_tasks.created_at) as month,
  sum(total_price_cache) / 1000.0 as price, sum(total_cost_cache) / 1000.0 as cost
FROM orders JOIN order_tasks ON orders.id = order_tasks.order_id
WHERE order_tasks.type = 'CompleteOrderTask' and order_tasks.active
GROUP BY EXTRACT(year from order_tasks.created_at), EXTRACT(month from order_tasks.created_at)
ORDER BY EXTRACT(year from order_tasks.created_at), EXTRACT(month from order_tasks.created_at)

) TO STDOUT WITH CSV;


COPY (
SELECT EXTRACT(year from order_tasks.created_at) as year, EXTRACT(month from order_tasks.created_at) as month,
  sum(total_price_cache) / 1000.0 as price, sum(total_cost_cache) / 1000.0 as cost
FROM orders JOIN order_tasks ON orders.id = order_tasks.order_id
WHERE order_tasks.type = 'CompleteOrderTask' and order_tasks.active AND
  orders.id NOT IN (SELECT min(orders.id) as order_id
FROM orders JOIN order_tasks ON orders.id = order_tasks.order_id
WHERE order_tasks.type = 'CompleteOrderTask' and order_tasks.active
GROUP BY orders.customer_id)
GROUP BY EXTRACT(year from order_tasks.created_at), EXTRACT(month from order_tasks.created_at)
ORDER BY EXTRACT(year from order_tasks.created_at), EXTRACT(month from order_tasks.created_at)

) TO STDOUT WITH CSV;




COPY (
SELECT EXTRACT(year from order_tasks.created_at) as year, EXTRACT(month from order_tasks.created_at) as month,
  sum(total_price_cache) / 1000.0 as price, sum(total_cost_cache) / 1000.0 as cost
FROM orders AS mainord JOIN order_tasks ON mainord.id = order_tasks.order_id
WHERE order_tasks.type = 'CompleteOrderTask' and order_tasks.active AND
  mainord.customer_id IN (
SELECT orders.customer_id
FROM orders JOIN order_tasks ON orders.id = order_tasks.order_id
WHERE order_tasks.type = 'CompleteOrderTask' and order_tasks.active AND mainord.created_at > orders.created_at + interval '1 year' AND mainord.customer_id = orders.customer_id
)
GROUP BY EXTRACT(year from order_tasks.created_at), EXTRACT(month from order_tasks.created_at)
ORDER BY EXTRACT(year from order_tasks.created_at), EXTRACT(month from order_tasks.created_at)

) TO STDOUT WITH CSV;