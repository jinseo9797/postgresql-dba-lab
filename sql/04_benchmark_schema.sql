-- 성능 테스트 스키마 생성
CREATE SCHEMA IF NOT EXISTS ecommerce_bench;
-- 고객·상품 테이블
CREATE TABLE IF NOT EXISTS ecommerce_bench.customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE
);
CREATE TABLE IF NOT EXISTS ecommerce_bench.products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    price NUMERIC(12,2) NOT NULL CHECK (price >= 0)
);
-- 주문·주문상세 테이블
CREATE TABLE IF NOT EXISTS ecommerce_bench.orders (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES ecommerce_bench.customers(customer_id),
    ordered_at TIMESTAMP NOT NULL
);
CREATE TABLE IF NOT EXISTS ecommerce_bench.order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT NOT NULL REFERENCES ecommerce_bench.orders(order_id),
    product_id INT NOT NULL REFERENCES ecommerce_bench.products(product_id),
    quantity INT NOT NULL CHECK(quantity > 0),
    unit_price NUMERIC(12,2) NOT NULL CHECK(unit_price >= 0)
);
-- 인덱스는 별도 실습에서 생성
