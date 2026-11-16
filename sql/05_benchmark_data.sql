-- 성능 테스트 데이터 311,000건 생성
-- 성능 테스트 스키마 생성 후 실행
-- 기존 데이터 있으면 실행 중단
-- 중복 적재 방지
BEGIN;

-- 빈 테이블 확인
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM ecommerce_bench.customers LIMIT 1)
       OR EXISTS (SELECT 1 FROM ecommerce_bench.products LIMIT 1)
       OR EXISTS (SELECT 1 FROM ecommerce_bench.orders LIMIT 1)
       OR EXISTS (SELECT 1 FROM ecommerce_bench.order_items LIMIT 1) THEN
        RAISE EXCEPTION '벤치마크 데이터가 이미 존재합니다. 별도 빈 DB에서 실행하세요.';
    END IF;
END $$;

-- 고객 10,000건
INSERT INTO ecommerce_bench.customers(customer_id, customer_name, email)
SELECT n, 'Customer_' || n, 'customer_' || n || '@example.com'
FROM generate_series(1, 10000) AS g(n);

-- 상품 1,000건
INSERT INTO ecommerce_bench.products(product_id, product_name, price)
SELECT n, 'Product_' || n, (n % 100 + 1) * 1000
FROM generate_series(1, 1000) AS g(n);

-- 고객당 주문 10건
INSERT INTO ecommerce_bench.orders(order_id, customer_id, ordered_at)
SELECT n, (n % 10000) + 1,
       CURRENT_TIMESTAMP - (n % 365) * INTERVAL '1 day'
FROM generate_series(1, 100000) AS g(n);

-- 주문당 상세 2건
-- 실습용 단가 생성
-- 상품 가격과 차이 가능
INSERT INTO ecommerce_bench.order_items
    (order_item_id, order_id, product_id, quantity, unit_price)
SELECT n,
       ((n - 1) % 100000) + 1,
       ((n - 1) % 1000) + 1,
       (n % 5) + 1,
       ((n % 100) + 1) * 1000
FROM generate_series(1, 200000) AS g(n);

COMMIT;

-- 통계 갱신
ANALYZE ecommerce_bench.customers;
ANALYZE ecommerce_bench.products;
ANALYZE ecommerce_bench.orders;
ANALYZE ecommerce_bench.order_items;

-- 테이블 건수 확인
SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM ecommerce_bench.customers
UNION ALL SELECT 'products', COUNT(*) FROM ecommerce_bench.products
UNION ALL SELECT 'orders', COUNT(*) FROM ecommerce_bench.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM ecommerce_bench.order_items;

-- 잘못된 고객 참조 확인
SELECT COUNT(*) AS invalid_orders
FROM ecommerce_bench.orders o
LEFT JOIN ecommerce_bench.customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL;

-- 잘못된 주문 참조 확인
SELECT COUNT(*) AS invalid_order_items_order
FROM ecommerce_bench.order_items oi
LEFT JOIN ecommerce_bench.orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

-- 잘못된 상품 참조 확인
SELECT COUNT(*) AS invalid_order_items_product
FROM ecommerce_bench.order_items oi
LEFT JOIN ecommerce_bench.products p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL;
