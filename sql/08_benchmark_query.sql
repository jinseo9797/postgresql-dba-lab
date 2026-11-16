-- 고객별 주문 조회 성능 측정
-- 인덱스 적용 전후 동일 쿼리 실행
-- EXPLAIN ANALYZE: 실제 쿼리 실행
-- BUFFERS: 버퍼 사용량
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.customer_id, c.customer_name, o.order_id, o.ordered_at,
       SUM(oi.quantity * oi.unit_price) AS order_amount
FROM ecommerce_bench.customers c
JOIN ecommerce_bench.orders o ON c.customer_id = o.customer_id
JOIN ecommerce_bench.order_items oi ON o.order_id = oi.order_id
WHERE c.customer_id = 500
GROUP BY c.customer_id, c.customer_name, o.order_id, o.ordered_at
ORDER BY o.ordered_at DESC;

-- 인덱스 스캔 제한 테스트
-- ① BEGIN 및 SET LOCAL
-- ② 워밍업 1회·측정 5회
-- ③ ROLLBACK
-- 설정은 개별 실행

-- BEGIN;
-- SET LOCAL enable_indexscan = off;
-- SET LOCAL enable_bitmapscan = off;
-- SET LOCAL enable_indexonlyscan = off;
-- ROLLBACK;

-- PK 인덱스 사용도 제한됨
-- 인덱스 삭제 실험과 다름
