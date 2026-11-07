-- STEP 1: 이커머스 기본 스키마
-- 대상 DB: dba_lab / PostgreSQL 16
-- 성능 테스트용 ecommerce_bench와 분리
CREATE SCHEMA IF NOT EXISTS ecommerce;

-- 고객: 이메일 중복 방지
CREATE TABLE IF NOT EXISTS ecommerce.customers (
    customer_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- 상품: 음수 가격 방지
CREATE TABLE IF NOT EXISTS ecommerce.products (
    product_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- 주문: 고객 테이블 참조(FK)
CREATE TABLE IF NOT EXISTS ecommerce.orders (
    order_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES ecommerce.customers(customer_id),
    order_status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (order_status IN ('PENDING', 'PAID', 'CANCELLED')),
    ordered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
-- 주문상세: 주문·상품 연결 및 주문 단가 저장
CREATE TABLE IF NOT EXISTS ecommerce.order_items (
    order_item_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INT NOT NULL REFERENCES ecommerce.orders(order_id),
    product_id INT NOT NULL REFERENCES ecommerce.products(product_id),
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0)
);
-- 재고: 음수 재고 방지
CREATE TABLE IF NOT EXISTS ecommerce.inventory (
    product_id INT PRIMARY KEY REFERENCES ecommerce.products(product_id),
    quantity INT NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
