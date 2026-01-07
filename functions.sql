CREATE OR REPLACE FUNCTION calculate_revenue(start_date TIMESTAMP, end_date TIMESTAMP)
RETURNS TABLE (
    total_revenue DECIMAL(10,2), 
    total_orders INTEGER, 
    avg_order_value DECIMAL(10,2) 
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(o.total_amount), 0) as total_revenue,
        COUNT(DISTINCT o.order_id) as total_orders,
        CASE 
            WHEN COUNT(DISTINCT o.order_id) > 0 
            THEN ROUND(COALESCE(SUM(o.total_amount), 0) / COUNT(DISTINCT o.order_id), 2)
            ELSE 0
        END as avg_order_value
    FROM Orders o
    WHERE o.created_at BETWEEN start_date AND end_date
    AND o.status = 'completed';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_product_recommendations(user_id_param UUID)
RETURNS TABLE (
    product_id UUID, 
    product_name VARCHAR(100), 
    similarity_score INTEGER 
) AS $$
BEGIN
    RETURN QUERY
    WITH user_categories AS (
        SELECT DISTINCT p.name
        FROM Orders o
        JOIN OrderItems oi ON o.order_id = oi.order_id
        JOIN Products p ON oi.product_id = p.product_id
        WHERE o.user_id = user_id_param
    )
    SELECT 
        p.product_id,
        p.name,
        COUNT(DISTINCT uc.name) as similarity_score
    FROM Products p
    CROSS JOIN user_categories uc
    WHERE p.product_id NOT IN (
        SELECT DISTINCT oi2.product_id
        FROM Orders o2
        JOIN OrderItems oi2 ON o2.order_id = oi2.order_id
        WHERE o2.user_id = user_id_param
    )
    GROUP BY p.product_id, p.name
    HAVING COUNT(DISTINCT uc.name) > 0
    ORDER BY similarity_score DESC, p.name
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_user_statistics(user_id_param UUID)
RETURNS TABLE (
    total_purchases DECIMAL(10,2), 
    avg_order_value DECIMAL(10,2), 
    favorite_product VARCHAR(100), 
    purchase_frequency INTERVAL 
) AS $$
BEGIN
    RETURN QUERY
    WITH user_orders AS (
        SELECT 
            o.total_amount,
            o.created_at,
            p.name as product_name,
            COUNT(*) OVER (PARTITION BY p.product_id) as product_count
        FROM Orders o
        JOIN OrderItems oi ON o.order_id = oi.order_id
        JOIN Products p ON oi.product_id = p.product_id
        WHERE o.user_id = user_id_param
        AND o.status = 'completed'
    )
    SELECT 
        COALESCE(SUM(uo.total_amount), 0) as total_purchases,
        COALESCE(AVG(uo.total_amount), 0) as avg_order_value,
        (
            SELECT product_name
            FROM user_orders
            WHERE product_count = (SELECT MAX(product_count) FROM user_orders)
            LIMIT 1
        ) as favorite_product,
        CASE 
            WHEN COUNT(*) > 1 THEN 
                (MAX(uo.created_at) - MIN(uo.created_at)) / (COUNT(*) - 1)
            ELSE NULL
        END as purchase_frequency
    FROM user_orders uo;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_inventory_update(
    product_id_param UUID, 
    quantity_change INTEGER, 
    allow_backorder BOOLEAN DEFAULT false 
) RETURNS TABLE (
    status VARCHAR(50), 
    message TEXT, 
    new_quantity INTEGER 
) AS $$
DECLARE
    current_stock INTEGER;
    new_stock INTEGER;
BEGIN
    SELECT stock_quantity INTO current_stock
    FROM Products
    WHERE product_id = product_id_param;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 
            'error'::VARCHAR(50),
            'Nie znaleziono produktu'::TEXT,
            0::INTEGER;
        RETURN;
    END IF;

    new_stock := current_stock + quantity_change;

    IF new_stock < 0 AND NOT allow_backorder THEN
        RETURN QUERY SELECT 
            'error'::VARCHAR(50),
            'Niewystarczający stan magazynowy i brak możliwości zamówień oczekujących'::TEXT,
            current_stock::INTEGER;
        RETURN;
    END IF;

    UPDATE Products
    SET stock_quantity = new_stock
    WHERE product_id = product_id_param;

    RETURN QUERY SELECT 
        CASE 
            WHEN new_stock >= 0 THEN 'success'::VARCHAR(50)
            ELSE 'backorder'::VARCHAR(50)
        END,
        CASE 
            WHEN new_stock >= 0 THEN 'Stan magazynowy zaktualizowany pomyślnie'::TEXT
            ELSE 'Utworzono zamówienie oczekujące'::TEXT
        END,
        new_stock::INTEGER;
END;

$$ LANGUAGE plpgsql; 
