-- 재고 ROLLBACK 검증
-- 예제 데이터 등록 후 실행
-- 변경사항은 ROLLBACK

-- 변경 전 재고 조회
SELECT p.product_name, i.quantity AS quantity_before
FROM ecommerce.inventory i
JOIN ecommerce.products p USING (product_id)
WHERE p.product_name = 'Keyboard';

BEGIN;

-- 재고 1개 차감
UPDATE ecommerce.inventory i
SET quantity = i.quantity - 1,
    updated_at = CURRENT_TIMESTAMP
FROM ecommerce.products p
WHERE i.product_id = p.product_id
  AND p.product_name = 'Keyboard'
  AND i.quantity >= 1
RETURNING i.product_id, i.quantity AS quantity_in_transaction;

-- ROLLBACK
ROLLBACK;

-- 변경 취소 후 재고 조회
SELECT p.product_name, i.quantity AS quantity_after_rollback
FROM ecommerce.inventory i
JOIN ecommerce.products p USING (product_id)
WHERE p.product_name = 'Keyboard';

-- 오류 테스트: 03b_failed_order_test.sql
