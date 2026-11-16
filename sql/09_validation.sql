-- 데이터 정합성 검증
-- 조회 전용

-- 기본 테이블 건수
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM ecommerce.customers
UNION ALL SELECT 'products', COUNT(*) FROM ecommerce.products
UNION ALL SELECT 'orders', COUNT(*) FROM ecommerce.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM ecommerce.order_items
UNION ALL SELECT 'inventory', COUNT(*) FROM ecommerce.inventory;

-- 주문상세 누락 확인
SELECT COUNT(*) AS orders_without_items
FROM ecommerce.orders o
WHERE NOT EXISTS (
    SELECT 1 FROM ecommerce.order_items oi WHERE oi.order_id = o.order_id
);

-- 성능 테스트 예상 건수: 10000 / 1000 / 100000 / 200000
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM ecommerce_bench.customers
UNION ALL SELECT 'products', COUNT(*) FROM ecommerce_bench.products
UNION ALL SELECT 'orders', COUNT(*) FROM ecommerce_bench.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM ecommerce_bench.order_items;

-- 고객 500번 조회 건수 확인
SELECT COUNT(*) AS customer_500_orders
FROM ecommerce_bench.orders WHERE customer_id = 500;
SELECT COUNT(*) AS customer_500_items
FROM ecommerce_bench.order_items oi
JOIN ecommerce_bench.orders o ON o.order_id = oi.order_id
WHERE o.customer_id = 500;
