-- STEP 3: 재고 변경 후 ROLLBACK 검증
-- 02_seed_data.sql 실행 후 사용
-- 재고 변경은 최종 반영하지 않음

-- 테스트 전 Keyboard 재고 확인
SELECT p.product_name, i.quantity AS quantity_before
FROM ecommerce.inventory i
JOIN ecommerce.products p USING (product_id)
WHERE p.product_name = 'Keyboard';

BEGIN;

-- 재고가 있는 경우에만 1개 차감
UPDATE ecommerce.inventory i
SET quantity = i.quantity - 1,
    updated_at = CURRENT_TIMESTAMP
FROM ecommerce.products p
WHERE i.product_id = p.product_id
  AND p.product_name = 'Keyboard'
  AND i.quantity >= 1
RETURNING i.product_id, i.quantity AS quantity_in_transaction;

-- 트랜잭션 내 변경 취소
ROLLBACK;

-- ROLLBACK 후 재고 확인
SELECT p.product_name, i.quantity AS quantity_after_rollback
FROM ecommerce.inventory i
JOIN ecommerce.products p USING (product_id)
WHERE p.product_name = 'Keyboard';

-- CHECK 제약조건 오류는 03b_failed_order_test.sql에서 검증
