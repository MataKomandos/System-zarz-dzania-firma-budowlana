-- Funkcja 1: Obliczanie przychodów dla zadanego okresu
-- Ta funkcja oblicza całkowity przychód, liczbę zamówień i średnią wartość zamówienia
CREATE OR REPLACE FUNCTION calculate_revenue(start_date TIMESTAMP, end_date TIMESTAMP)
RETURNS TABLE (
    total_revenue DECIMAL(10,2), -- Całkowity przychód
    total_orders INTEGER, -- Liczba zamówień
    avg_order_value DECIMAL(10,2) -- Średnia wartość zamówienia
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

-- Funkcja 2: Rekomendacje produktów na podstawie historii zakupów
-- Ta funkcja zwraca rekomendowane produkty dla użytkownika na podstawie jego wcześniejszych zakupów
CREATE OR REPLACE FUNCTION get_product_recommendations(user_id_param UUID)
RETURNS TABLE (
    product_id UUID, -- ID produktu
    product_name VARCHAR(100), -- Nazwa produktu
    similarity_score INTEGER -- Wynik podobieństwa
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

-- Funkcja 3: Obliczanie statystyk zakupowych użytkownika
-- Ta funkcja analizuje zachowania zakupowe użytkownika i zwraca różne statystyki
CREATE OR REPLACE FUNCTION get_user_statistics(user_id_param UUID)
RETURNS TABLE (
    total_purchases DECIMAL(10,2), -- Suma wszystkich zakupów
    avg_order_value DECIMAL(10,2), -- Średnia wartość zamówienia
    favorite_product VARCHAR(100), -- Ulubiony produkt
    purchase_frequency INTERVAL -- Częstotliwość zakupów
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

-- Funkcja 4: Aktualizacja stanu magazynowego i obsługa zamówień oczekujących
-- Ta funkcja zarządza stanem magazynowym produktów i obsługuje zamówienia oczekujące
CREATE OR REPLACE FUNCTION process_inventory_update(
    product_id_param UUID, -- ID produktu
    quantity_change INTEGER, -- Zmiana ilości
    allow_backorder BOOLEAN DEFAULT false -- Czy zezwolić na zamówienia oczekujące
) RETURNS TABLE (
    status VARCHAR(50), -- Status operacji
    message TEXT, -- Wiadomość zwrotna
    new_quantity INTEGER -- Nowa ilość
) AS $$
DECLARE
    current_stock INTEGER;
    new_stock INTEGER;
BEGIN
    -- Pobranie aktualnego stanu
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

    -- Aktualizacja stanu
    UPDATE Products
    SET stock_quantity = new_stock
    WHERE product_id = product_id_param;

    -- Zwrócenie wyniku
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