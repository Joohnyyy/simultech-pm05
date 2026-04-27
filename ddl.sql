-- ============================================================
-- База данных: simultech
-- СУБД: PostgreSQL
-- Описание: Создание таблиц для системы "Симултех"
-- ============================================================

-- Таблица категорий товаров
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

-- Таблица поставщиков
CREATE TABLE suppliers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    contact VARCHAR(100)
);

-- Таблица товаров
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    barcode VARCHAR(13) NOT NULL UNIQUE,
    price DECIMAL(10,2) NOT NULL CHECK (price > 0),
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    category_id INTEGER NOT NULL,
    supplier_id INTEGER NOT NULL,
    is_prescription BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT
);

-- Таблица пользователей системы
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    login VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('cashier','manager','admin'))
);

-- Таблица чеков
CREATE TABLE checks (
    id SERIAL PRIMARY KEY,
    fiscal_number VARCHAR(20) NOT NULL UNIQUE,
    cashier_id INTEGER NOT NULL,
    date_time TIMESTAMP NOT NULL DEFAULT NOW(),
    total DECIMAL(12,2) NOT NULL CHECK (total >= 0),
    payment_type VARCHAR(10) NOT NULL CHECK (payment_type IN ('cash','card')),
    FOREIGN KEY (cashier_id) REFERENCES users(id) ON DELETE RESTRICT
);

-- Таблица позиций чека
CREATE TABLE check_items (
    id SERIAL PRIMARY KEY,
    check_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    price_at_moment DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (check_id) REFERENCES checks(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
);