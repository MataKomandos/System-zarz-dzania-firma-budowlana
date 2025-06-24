-- Wstawianie przykładowych użytkowników
INSERT INTO Users (username, email, password_hash) VALUES
    ('john_doe', 'john@example.com', 'hash1'), -- Przykładowy użytkownik 1
    ('jane_smith', 'jane@example.com', 'hash2'), -- Przykładowy użytkownik 2
    ('bob_wilson', 'bob@example.com', 'hash3'); -- Przykładowy użytkownik 3

-- Wstawianie przykładowych produktów
INSERT INTO Products (name, description, price, stock_quantity) VALUES
    ('Laptop Pro', 'High-performance laptop with 16GB RAM', 1299.99, 50), -- Laptop z wysoką wydajnością
    ('Smartphone X', '5G smartphone with dual camera', 699.99, 100), -- Smartfon z 5G
    ('Wireless Earbuds', 'Noise-cancelling wireless earbuds', 149.99, 200), -- Bezprzewodowe słuchawki
    ('Smart Watch', 'Fitness tracking smartwatch', 199.99, 75), -- Smartwatch do fitness
    ('Tablet Ultra', '10-inch tablet with stylus support', 499.99, 30); -- Tablet z rysikiem

-- Wstawianie przykładowych zamówień
INSERT INTO Orders (user_id, status, total_amount)
SELECT 
    u.user_id,
    'pending'::order_status, -- Status oczekujący
    699.99 -- Kwota zamówienia
FROM Users u
WHERE u.username = 'john_doe'
UNION ALL
SELECT 
    u.user_id,
    'completed'::order_status, -- Status zakończony
    1449.98 -- Kwota zamówienia
FROM Users u
WHERE u.username = 'jane_smith';

-- Wstawianie przykładowych pozycji zamówienia
INSERT INTO OrderItems (order_id, product_id, quantity, unit_price)
SELECT 
    o.order_id,
    p.product_id,
    1, -- Ilość: 1 sztuka
    p.price -- Cena jednostkowa z tabeli produktów
FROM Orders o
CROSS JOIN Products p
WHERE p.name = 'Smartphone X'
AND o.total_amount = 699.99
UNION ALL
SELECT 
    o.order_id,
    p.product_id,
    2, -- Ilość: 2 sztuki
    p.price -- Cena jednostkowa z tabeli produktów
FROM Orders o
CROSS JOIN Products p
WHERE p.name = 'Wireless Earbuds'
AND o.total_amount = 1449.98;

-- Wstawianie przykładowych płatności
INSERT INTO Payments (order_id, amount, status, transaction_id)
SELECT 
    o.order_id,
    o.total_amount, -- Kwota płatności równa kwocie zamówienia
    'completed'::payment_status, -- Status płatności: zakończona
    'TXN-' || gen_random_uuid() -- Generowanie unikalnego ID transakcji
FROM Orders o
WHERE o.status = 'completed';

-- Wstawianie przykładowych recenzji
INSERT INTO Reviews (user_id, product_id, rating, comment)
SELECT 
    u.user_id,
    p.product_id,
    5, -- Najwyższa ocena
    'Excellent product, very satisfied!' -- Komentarz do recenzji
FROM Users u
CROSS JOIN Products p
WHERE u.username = 'jane_smith'
AND p.name = 'Wireless Earbuds'; 