-- STEP 6: 인덱스 최적화
-- PK 인덱스 외 FK 조회용 인덱스 추가
-- 고객 조회 및 주문일 정렬용 복합 인덱스
CREATE INDEX IF NOT EXISTS idx_orders_customer_date
    ON ecommerce_bench.orders(customer_id, ordered_at DESC);
-- 주문 ID 기반 주문상세 조회용 인덱스
CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON ecommerce_bench.order_items(order_id);
-- 인덱스 생성 후 통계 갱신
ANALYZE ecommerce_bench.orders;
ANALYZE ecommerce_bench.order_items;

SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname='ecommerce_bench'
ORDER BY tablename,indexname;
-- 08_benchmark_query.sql 재실행
