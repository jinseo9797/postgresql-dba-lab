-- 주문 오류 시 ROLLBACK 검증
-- 예제 데이터 등록 후 실행
-- ①~③ 순서대로 개별 실행
-- ② 예상 오류: 23514
-- 오류 후 ROLLBACK 필수

-- 변경 전 데이터 조회
SELECT i.quantity AS keyboard_stock
FROM ecommerce.inventory i
JOIN ecommerce.products p ON p.product_id = i.product_id
WHERE p.product_name = 'Keyboard';
SELECT COUNT(*) AS order_item_count FROM ecommerce.order_items;

-- ① 재고 차감
BEGIN;
UPDATE ecommerce.inventory i
SET quantity = i.quantity - 1,
    updated_at = CURRENT_TIMESTAMP
FROM ecommerce.products p
WHERE i.product_id = p.product_id
  AND p.product_name = 'Keyboard'
  AND i.quantity >= 1
RETURNING i.product_id, i.quantity;

-- ② 음수 수량 오류 유도
-- 기존 주문 ID 사용
INSERT INTO ecommerce.order_items(order_id, product_id, quantity, unit_price)
SELECT o.order_id, p.product_id, -1, p.price
FROM ecommerce.orders o
CROSS JOIN ecommerce.products p
WHERE p.product_name = 'Keyboard'
ORDER BY o.order_id DESC, p.product_id
LIMIT 1;

-- ③ ROLLBACK
ROLLBACK;

-- 변경 취소 결과 확인
SELECT i.quantity AS keyboard_stock_after_rollback
FROM ecommerce.inventory i
JOIN ecommerce.products p ON p.product_id = i.product_id
WHERE p.product_name = 'Keyboard';
SELECT COUNT(*) AS invalid_quantities
FROM ecommerce.order_items WHERE quantity <= 0;
SELECT COUNT(*) AS order_item_count_after_rollback
FROM ecommerce.order_items;
