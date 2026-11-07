-- STEP 9: 기본 데이터 및 벤치마크 정합성 확인
-- 데이터 변경 없이 결과만 조회

-- 기본 스키마별 행 수
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM ecommerce.customers
UNION ALL SELECT 'products', COUNT(*) FROM ecommerce.products
UNION ALL SELECT 'orders', COUNT(*) FROM ecommerce.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM ecommerce.order_items
UNION ALL SELECT 'inventory', COUNT(*) FROM ecommerce.inventory;

-- 주문상세가 없는 주문 확인
SELECT COUNT(*) AS orders_without_items
FROM ecommerce.orders o
WHERE NOT EXISTS (
    SELECT 1 FROM ecommerce.order_items oi WHERE oi.order_id = o.order_id
);

-- 벤치마크 예상: 10000 / 1000 / 100000 / 200000
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM ecommerce_bench.customers
UNION ALL SELECT 'products', COUNT(*) FROM ecommerce_bench.products
UNION ALL SELECT 'orders', COUNT(*) FROM ecommerce_bench.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM ecommerce_bench.order_items;

-- 고객 500번 주문 건수와 주문상세 건수 확인
SELECT COUNT(*) AS customer_500_orders
FROM ecommerce_bench.orders WHERE customer_id = 500;
SELECT COUNT(*) AS customer_500_items
FROM ecommerce_bench.order_items oi
JOIN ecommerce_bench.orders o ON o.order_id = oi.order_id
WHERE o.customer_id = 500;
