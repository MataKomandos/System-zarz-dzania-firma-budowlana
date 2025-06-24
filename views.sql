-- Widok 1: Szczegółowe informacje o zamówieniach
-- Ten widok łączy informacje o zamówieniach, użytkownikach, płatnościach i produktach
CREATE OR REPLACE VIEW vw_order_details AS
SELECT 
    o.order_id, -- ID zamówienia
    u.username, -- Nazwa użytkownika
    u.email, -- Email użytkownika
    o.status as order_status, -- Status zamówienia
    o.total_amount, -- Łączna kwota
    o.created_at as order_date, -- Data zamówienia
    p.status as payment_status, -- Status płatności
    p.payment_date, -- Data płatności
    COUNT(oi.order_item_id) as total_items, -- Liczba pozycji
    STRING_AGG(pr.name, ', ') as products -- Lista produktów
FROM Orders o
JOIN Users u ON o.user_id = u.user_id
LEFT JOIN Payments p ON o.order_id = p.order_id
JOIN OrderItems oi ON o.order_id = oi.order_id
JOIN Products pr ON oi.product_id = pr.product_id
GROUP BY o.order_id, u.username, u.email, o.status, o.total_amount, o.created_at, p.status, p.payment_date;

-- Widok 2: Analiza wydajności produktów
-- Ten widok pokazuje statystyki sprzedaży i ocen dla każdego produktu
CREATE OR REPLACE VIEW vw_product_performance AS
SELECT 
    p.product_id, -- ID produktu
    p.name, -- Nazwa produktu
    p.price, -- Aktualna cena
    p.stock_quantity, -- Stan magazynowy
    COUNT(DISTINCT oi.order_id) as total_orders, -- Liczba zamówień
    SUM(oi.quantity) as total_units_sold, -- Łączna liczba sprzedanych sztuk
    SUM(oi.quantity * oi.unit_price) as total_revenue, -- Łączny przychód
    COALESCE(AVG(r.rating), 0) as avg_rating, -- Średnia ocena
    COUNT(r.review_id) as review_count -- Liczba recenzji
FROM Products p
LEFT JOIN OrderItems oi ON p.product_id = oi.product_id
LEFT JOIN Reviews r ON p.product_id = r.product_id
GROUP BY p.product_id, p.name, p.price, p.stock_quantity;

-- Widok 3: Analiza zachowań klientów
-- Ten widok pokazuje historię zakupów i preferencje każdego klienta
CREATE OR REPLACE VIEW vw_customer_insights AS
SELECT 
    u.user_id, -- ID użytkownika
    u.username, -- Nazwa użytkownika
    u.email, -- Email
    COUNT(DISTINCT o.order_id) as total_orders, -- Liczba zamówień
    SUM(o.total_amount) as total_spent, -- Łączna kwota wydana
    MAX(o.created_at) as last_order_date, -- Data ostatniego zamówienia
    STRING_AGG(DISTINCT p.name, ', ') as purchased_products, -- Lista zakupionych produktów
    ROUND(AVG(r.rating), 2) as avg_rating_given -- Średnia wystawionych ocen
FROM Users u
LEFT JOIN Orders o ON u.user_id = o.user_id
LEFT JOIN OrderItems oi ON o.order_id = oi.order_id
LEFT JOIN Products p ON oi.product_id = p.product_id
LEFT JOIN Reviews r ON u.user_id = r.user_id
GROUP BY u.user_id, u.username, u.email;

-- Widok 4: Status magazynu w czasie rzeczywistym
-- Ten widok pokazuje aktualny stan magazynowy z uwzględnieniem zamówień w toku
CREATE OR REPLACE VIEW vw_inventory_status AS
WITH pending_orders AS (
    SELECT 
        product_id,
        SUM(quantity) as reserved_quantity -- Suma zarezerwowanych produktów
    FROM OrderItems oi
    JOIN Orders o ON oi.order_id = o.order_id
    WHERE o.status = 'pending'
    GROUP BY product_id
)
SELECT 
    p.product_id, -- ID produktu
    p.name, -- Nazwa produktu
    p.stock_quantity as total_stock, -- Całkowity stan magazynowy
    COALESCE(po.reserved_quantity, 0) as reserved_stock, -- Zarezerwowana ilość
    p.stock_quantity - COALESCE(po.reserved_quantity, 0) as available_stock, -- Dostępna ilość
    CASE 
        WHEN p.stock_quantity - COALESCE(po.reserved_quantity, 0) <= 10 THEN 'Niski stan'
        WHEN p.stock_quantity - COALESCE(po.reserved_quantity, 0) <= 30 THEN 'Średni stan'
        ELSE 'Wystarczający stan'
    END as stock_status -- Status stanu magazynowego
FROM Products p
LEFT JOIN pending_orders po ON p.product_id = po.product_id; 