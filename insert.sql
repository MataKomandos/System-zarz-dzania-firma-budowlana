INSERT INTO Users (username, email, password_hash) VALUES
    ('john_doe', 'john@example.com', 'hash1'), 
    ('jane_smith', 'jane@example.com', 'hash2'), 
    ('bob_wilson', 'bob@example.com', 'hash3'); 

INSERT INTO Products (name, description, price, stock_quantity) VALUES
    ('Laptop Pro', 'High-performance laptop with 16GB RAM', 1299.99, 50), 
    ('Smartphone X', '5G smartphone with dual camera', 699.99, 100), 
    ('Wireless Earbuds', 'Noise-cancelling wireless earbuds', 149.99, 200), 
    ('Smart Watch', 'Fitness tracking smartwatch', 199.99, 75), 
    ('Tablet Ultra', '10-inch tablet with stylus support', 499.99, 30); 

INSERT INTO Orders (user_id, status, total_amount)
SELECT 
    u.user_id,
    'pending'::order_status, 
    699.99 
FROM Users u
WHERE u.username = 'john_doe'
UNION ALL
SELECT 
    u.user_id,
    'completed'::order_status, 
    1449.98 
FROM Users u
WHERE u.username = 'jane_smith';

INSERT INTO OrderItems (order_id, product_id, quantity, unit_price)
SELECT 
    o.order_id,
    p.product_id,
    1, 
    p.price 
FROM Orders o
CROSS JOIN Products p
WHERE p.name = 'Smartphone X'
AND o.total_amount = 699.99
UNION ALL
SELECT 
    o.order_id,
    p.product_id,
    2, 
    p.price 
FROM Orders o
CROSS JOIN Products p
WHERE p.name = 'Wireless Earbuds'
AND o.total_amount = 1449.98;

INSERT INTO Payments (order_id, amount, status, transaction_id)
SELECT 
    o.order_id,
    o.total_amount, 
    'completed'::payment_status, 
    'TXN-' || gen_random_uuid() 
FROM Orders o
WHERE o.status = 'completed';

INSERT INTO Reviews (user_id, product_id, rating, comment)
SELECT 
    u.user_id,
    p.product_id,
    5, 
    'Excellent product, very satisfied!' 
FROM Users u
CROSS JOIN Products p
WHERE u.username = 'jane_smith'

AND p.name = 'Wireless Earbuds'; 
