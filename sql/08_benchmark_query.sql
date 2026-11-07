-- STEP 8: 고객별 주문 집계 성능 측정
-- 06_index_optimization.sql 적용 전후에 동일 쿼리 실행
-- EXPLAIN ANALYZE는 실제 SELECT 실행
-- BUFFERS는 공유 버퍼 접근량 확인
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.customer_id, c.customer_name, o.order_id, o.ordered_at,
       SUM(oi.quantity * oi.unit_price) AS order_amount
FROM ecommerce_bench.customers c
JOIN ecommerce_bench.orders o ON c.customer_id = o.customer_id
JOIN ecommerce_bench.order_items oi ON o.order_id = oi.order_id
WHERE c.customer_id = 500
GROUP BY c.customer_id, c.customer_name, o.order_id, o.ordered_at
ORDER BY o.ordered_at DESC;

-- 인덱스 스캔 제한 비교: 별도 트랜잭션에서 실행
-- ① BEGIN + SET LOCAL 실행
-- ② 위 EXPLAIN 쿼리만 워밍업 1회 + 측정 5회
-- ③ ROLLBACK 실행
-- 아래 SET 문은 필요한 경우에만 따로 선택 실행

-- BEGIN;
-- SET LOCAL enable_indexscan = off;
-- SET LOCAL enable_bitmapscan = off;
-- SET LOCAL enable_indexonlyscan = off;
-- ROLLBACK;

-- 이 설정은 PK 인덱스 사용에도 영향을 줌
-- 신규 인덱스만 삭제한 상태와 동일하지 않음
