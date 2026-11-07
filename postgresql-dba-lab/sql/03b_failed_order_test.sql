-- STEP 3b: 주문상세 오류 발생 시 트랜잭션 취소
-- 02_seed_data.sql 실행 후 사용
-- pgAdmin에서 아래 ①, ②, ③을 각각 선택하여 실행
-- ②에서 SQLSTATE 23514 발생이 정상
-- 오류 후 ③ ROLLBACK 반드시 실행

-- 현재 재고와 주문상세 수 확인
SELECT i.quantity AS keyboard_stock
FROM ecommerce.inventory i
JOIN ecommerce.products p ON p.product_id = i.product_id
WHERE p.product_name = 'Keyboard';
SELECT COUNT(*) AS order_item_count FROM ecommerce.order_items;

-- ① 트랜잭션 시작 및 재고 차감
BEGIN;
UPDATE ecommerce.inventory i
SET quantity = i.quantity - 1,
    updated_at = CURRENT_TIMESTAMP
FROM ecommerce.products p
WHERE i.product_id = p.product_id
  AND p.product_name = 'Keyboard'
  AND i.quantity >= 1
RETURNING i.product_id, i.quantity;

-- ② 음수 주문 수량 입력으로 CHECK 오류 발생
-- 주문상세가 아닌 기존 주문을 참조
INSERT INTO ecommerce.order_items(order_id, product_id, quantity, unit_price)
SELECT o.order_id, p.product_id, -1, p.price
FROM ecommerce.orders o
CROSS JOIN ecommerce.products p
WHERE p.product_name = 'Keyboard'
ORDER BY o.order_id DESC, p.product_id
LIMIT 1;

-- ③ 실패한 트랜잭션 정리
ROLLBACK;

-- 재고 복구 및 잘못된 주문상세 미저장 확인
SELECT i.quantity AS keyboard_stock_after_rollback
FROM ecommerce.inventory i
JOIN ecommerce.products p ON p.product_id = i.product_id
WHERE p.product_name = 'Keyboard';
SELECT COUNT(*) AS invalid_quantities
FROM ecommerce.order_items WHERE quantity <= 0;
SELECT COUNT(*) AS order_item_count_after_rollback
FROM ecommerce.order_items;
