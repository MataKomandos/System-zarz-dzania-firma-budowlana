CREATE OR REPLACE VIEW vw_order_details AS
SELECT 
    o.order_id, 
    u.username, 
    u.email, 
    o.status as order_status, 
    o.total_amount, 
    o.created_at as order_date, 
    p.status as payment_status, 
    p.payment_date, 
    COUNT(oi.order_item_id) as total_items, 
    STRING_AGG(pr.name, ', ') as products 
FROM Orders o
JOIN Users u ON o.user_id = u.user_id
LEFT JOIN Payments p ON o.order_id = p.order_id
JOIN OrderItems oi ON o.order_id = oi.order_id
JOIN Products pr ON oi.product_id = pr.product_id
GROUP BY o.order_id, u.username, u.email, o.status, o.total_amount, o.created_at, p.status, p.payment_date;

CREATE OR REPLACE VIEW vw_product_performance AS
SELECT 
    p.product_id, 
    p.name, 
    p.price, 
    p.stock_quantity, 
    COUNT(DISTINCT oi.order_id) as total_orders, 
    SUM(oi.quantity) as total_units_sold, 
    SUM(oi.quantity * oi.unit_price) as total_revenue, 
    COALESCE(AVG(r.rating), 0) as avg_rating, 
    COUNT(r.review_id) as review_count 
FROM Products p
LEFT JOIN OrderItems oi ON p.product_id = oi.product_id
LEFT JOIN Reviews r ON p.product_id = r.product_id
GROUP BY p.product_id, p.name, p.price, p.stock_quantity;

CREATE OR REPLACE VIEW vw_customer_insights AS
SELECT 
    u.user_id, 
    u.username, 
    u.email, 
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_spent,
    MAX(o.created_at) as last_order_date, 
    STRING_AGG(DISTINCT p.name, ', ') as purchased_products, 
    ROUND(AVG(r.rating), 2) as avg_rating_given 
FROM Users u
LEFT JOIN Orders o ON u.user_id = o.user_id
LEFT JOIN OrderItems oi ON o.order_id = oi.order_id
LEFT JOIN Products p ON oi.product_id = p.product_id
LEFT JOIN Reviews r ON u.user_id = r.user_id
GROUP BY u.user_id, u.username, u.email;

CREATE OR REPLACE VIEW vw_inventory_status AS
WITH pending_orders AS (
    SELECT 
        product_id,
        SUM(quantity) as reserved_quantity 
    FROM OrderItems oi
    JOIN Orders o ON oi.order_id = o.order_id
    WHERE o.status = 'pending'
    GROUP BY product_id
)
SELECT 
    p.product_id,
    p.name, 
    p.stock_quantity as total_stock, 
    COALESCE(po.reserved_quantity, 0) as reserved_stock, 
    p.stock_quantity - COALESCE(po.reserved_quantity, 0) as available_stock, 
    CASE 
        WHEN p.stock_quantity - COALESCE(po.reserved_quantity, 0) <= 10 THEN 'Niski stan'
        WHEN p.stock_quantity - COALESCE(po.reserved_quantity, 0) <= 30 THEN 'Średni stan'
        ELSE 'Wystarczający stan'
    END as stock_status 
FROM Products p

LEFT JOIN pending_orders po ON p.product_id = po.product_id; 
