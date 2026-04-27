CREATE OR REPLACE VIEW v_checks_full AS
SELECT
    ch.id AS check_id,
    ch.fiscal_number,
    u.login AS cashier_login,
    ch.date_time,
    ch.total,
    ch.payment_type,
    pr.name AS product_name,
    ci.quantity,
    ci.price_at_moment
FROM checks ch
JOIN users u ON ch.cashier_id = u.id
JOIN check_items ci ON ch.id = ci.check_id
JOIN products pr ON ci.product_id = pr.id
ORDER BY ch.date_time DESC;

-- 2. Представление: продажи по категориям
CREATE OR REPLACE VIEW v_sales_by_category AS
SELECT
    cat.name AS category_name,
    SUM(ci.quantity) AS total_quantity,
    SUM(ci.quantity * ci.price_at_moment) AS total_revenue
FROM check_items ci
JOIN products pr ON ci.product_id = pr.id
JOIN categories cat ON pr.category_id = cat.id
GROUP BY cat.name
ORDER BY total_revenue DESC;

-- 3. Процедура: оформление продажи
CREATE OR REPLACE PROCEDURE sp_add_sale(
    IN p_cashier_id INTEGER,
    IN p_payment_type VARCHAR(10),
    IN p_items JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_check_id INTEGER;
    item RECORD;
    v_total DECIMAL(12,2) := 0;
    v_price DECIMAL(10,2);
    v_fiscal VARCHAR(20) := 'FN-' || to_char(NOW(), 'YYYYMMDDHH24MISSMS');
BEGIN
    INSERT INTO checks (fiscal_number, cashier_id, total, payment_type)
    VALUES (v_fiscal, p_cashier_id, 0, p_payment_type)
    RETURNING id INTO v_check_id;

    FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id INT, quantity INT)
    LOOP
        SELECT price INTO v_price FROM products WHERE id = item.product_id FOR UPDATE;
        IF (SELECT stock FROM products WHERE id = item.product_id) < item.quantity THEN
            RAISE EXCEPTION 'Недостаточно товара на складе для product_id=%', item.product_id;
        END IF;
        INSERT INTO check_items (check_id, product_id, quantity, price_at_moment)
        VALUES (v_check_id, item.product_id, item.quantity, v_price);
        UPDATE products SET stock = stock - item.quantity WHERE id = item.product_id;
        v_total := v_total + (v_price * item.quantity);
    END LOOP;
    UPDATE checks SET total = v_total WHERE id = v_check_id;
END;
$$;

-- 4. Процедура: регистрация пользователя
CREATE OR REPLACE PROCEDURE sp_register_user(
    IN p_login VARCHAR(50),
    IN p_password_hash VARCHAR(255),
    IN p_role VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS(SELECT 1 FROM users WHERE login = p_login) THEN
        RAISE EXCEPTION 'Пользователь с логином "%" уже существует', p_login;
    END IF;
    INSERT INTO users (login, password_hash, role) VALUES (p_login, p_password_hash, p_role);
END;
$$;

-- 5. Таблица аудита остатков
CREATE TABLE IF NOT EXISTS stock_audit (
    id SERIAL PRIMARY KEY,
    product_id INTEGER NOT NULL,
    old_stock INTEGER,
    new_stock INTEGER,
    changed_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (product_id) REFERENCES products(id)
);

-- 6. Триггерная функция: логирование изменения остатка
CREATE OR REPLACE FUNCTION fn_log_stock_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.stock <> NEW.stock THEN
        INSERT INTO stock_audit(product_id, old_stock, new_stock)
        VALUES (OLD.id, OLD.stock, NEW.stock);
    END IF;
    RETURN NEW;
END;
$$;

-- 7. Триггер: аудит изменения остатков
CREATE TRIGGER trg_audit_stock
    AFTER UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION fn_log_stock_change();

-- 8. Добавление поля updated_at (если ещё нет)
ALTER TABLE products ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP;

-- 9. Триггерная функция: автоматический timestamp
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

-- 10. Триггер: автообновление updated_at
CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION fn_set_updated_at();