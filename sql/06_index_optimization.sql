-- 인덱스 생성
-- 조회용 인덱스 추가
-- 고객·주문일 복합 인덱스
CREATE INDEX IF NOT EXISTS idx_orders_customer_date
    ON ecommerce_bench.orders(customer_id, ordered_at DESC);
-- 주문 ID 인덱스
CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON ecommerce_bench.order_items(order_id);
-- 통계 갱신
ANALYZE ecommerce_bench.orders;
ANALYZE ecommerce_bench.order_items;

SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname='ecommerce_bench'
ORDER BY tablename,indexname;
-- 인덱스 적용 후 재측정
