-- STEP 2: 이커머스 예제 데이터 등록
-- 01_schema.sql 실행 후 사용
-- 기존 고객·상품·재고 보존

-- 고객 이메일 기준 중복 방지
INSERT INTO ecommerce.customers(customer_name, email)
VALUES ('Kim', 'kim@example.com'),
       ('Lee', 'lee@example.com'),
       ('Park', 'park@example.com')
ON CONFLICT (email) DO NOTHING;

-- 상품명 기준 기존 상품 확인
-- 실습용 상품명 사용, 운영 환경은 고유 SKU 권장
INSERT INTO ecommerce.products(product_name, price)
SELECT v.product_name, v.price
FROM (VALUES ('Keyboard', 50000::numeric),
             ('Mouse', 30000::numeric),
             ('Monitor', 200000::numeric)) AS v(product_name, price)
WHERE NOT EXISTS (
    SELECT 1 FROM ecommerce.products p
    WHERE p.product_name = v.product_name
);

-- 초기 재고 등록, 기존 재고 유지
INSERT INTO ecommerce.inventory(product_id, quantity)
SELECT p.product_id, v.quantity
FROM (VALUES ('Keyboard', 100),
             ('Mouse', 200),
             ('Monitor', 50)) AS v(product_name, quantity)
JOIN ecommerce.products p ON p.product_name = v.product_name
ON CONFLICT (product_id) DO NOTHING;

-- 샘플 주문 1건과 주문상세 2건 등록
-- 같은 상품 구성이 있는 Kim의 기존 주문은 중복 생성하지 않음
-- 주문 생성 실습이므로 재고 차감·결제 처리는 수행하지 않음
DO $$
DECLARE
    v_customer_id INT;
    v_keyboard_id INT;
    v_mouse_id INT;
    v_order_id INT;
BEGIN
    SELECT customer_id INTO v_customer_id
    FROM ecommerce.customers WHERE email = 'kim@example.com';

    SELECT product_id INTO v_keyboard_id
    FROM ecommerce.products WHERE product_name = 'Keyboard'
    ORDER BY product_id LIMIT 1;

    SELECT product_id INTO v_mouse_id
    FROM ecommerce.products WHERE product_name = 'Mouse'
    ORDER BY product_id LIMIT 1;

    IF v_customer_id IS NULL OR v_keyboard_id IS NULL OR v_mouse_id IS NULL THEN
        RAISE EXCEPTION '샘플 주문에 필요한 고객 또는 상품이 없습니다.';
    END IF;

    -- 샘플 주문과 같은 구성의 기존 주문 확인
    IF NOT EXISTS (
        SELECT 1
        FROM ecommerce.orders o
        WHERE o.customer_id = v_customer_id
          AND EXISTS (
              SELECT 1 FROM ecommerce.order_items oi
              WHERE oi.order_id = o.order_id
                AND oi.product_id = v_keyboard_id AND oi.quantity = 1
          )
          AND EXISTS (
              SELECT 1 FROM ecommerce.order_items oi
              WHERE oi.order_id = o.order_id
                AND oi.product_id = v_mouse_id AND oi.quantity = 2
          )
    ) THEN
        INSERT INTO ecommerce.orders(customer_id, order_status)
        VALUES (v_customer_id, 'PENDING')
        RETURNING order_id INTO v_order_id;

        INSERT INTO ecommerce.order_items(order_id, product_id, quantity, unit_price)
        SELECT v_order_id, p.product_id, v.quantity, p.price
        FROM (VALUES (v_keyboard_id, 1), (v_mouse_id, 2)) AS v(product_id, quantity)
        JOIN ecommerce.products p ON p.product_id = v.product_id;
    END IF;
END $$;

-- 고객별 주문·상품 조회
SELECT c.customer_name, o.order_id, p.product_name, oi.quantity,
       oi.unit_price, oi.quantity * oi.unit_price AS line_amount
FROM ecommerce.customers c
JOIN ecommerce.orders o ON o.customer_id = c.customer_id
JOIN ecommerce.order_items oi ON oi.order_id = o.order_id
JOIN ecommerce.products p ON p.product_id = oi.product_id
ORDER BY o.order_id, oi.order_item_id;
