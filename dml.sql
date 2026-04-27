
-- Категории
INSERT INTO categories (name, description) VALUES
('Рецептурные препараты', 'Отпускаются только по рецепту врача'),
('Безрецептурные препараты', 'Свободная продажа'),
('Медицинские изделия', 'Бинты, шприцы, тонометры и пр.');

-- Поставщики
INSERT INTO suppliers (name, contact) VALUES
('ООО Фарм-Трейд', 'Иванов А.П., +79181234567'),
('ЗАО Медикал Групп', 'Петрова Е.С., +79187654321');

-- Товары
INSERT INTO products (name, barcode, price, stock, category_id, supplier_id, is_prescription) VALUES
('Парацетамол 500 мг', '4601234567890', 150.00, 20, 2, 1, FALSE),
('Ибупрофен 200 мг', '4601234567891', 180.00, 15, 2, 1, FALSE),
('Амоксициллин 500 мг', '4601234567892', 250.00, 10, 1, 2, TRUE);

-- Пользователи (пароль для cashier1: password, для manager1 и admin: хэш bcrypt)
INSERT INTO users (login, password_hash, role) VALUES
('cashier1', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', 'cashier'),
('manager1', '$2b$12$LQv3c1yqBWWhxkd0LQ1Cr.eDmqb0K0BfFMNfMz6gFJjpQGhJM9Hs', 'manager'),
('admin', '$2b$12$LQv3c1yqBWWhxkd0LQ1Cr.eDmqb0K0BfFMNfMz6gFJjpQGhJM9Hs', 'admin');

-- Чеки (тестовые)
INSERT INTO checks (fiscal_number, cashier_id, date_time, total, payment_type) VALUES
('FN-00001', 1, '2026-04-26 10:15:00', 330.00, 'cash'),
('FN-00002', 1, '2026-04-26 11:20:00', 180.00, 'card');

-- Позиции чеков
INSERT INTO check_items (check_id, product_id, quantity, price_at_moment) VALUES
(1, 1, 1, 150.00),
(1, 2, 1, 180.00),
(2, 2, 1, 180.00);