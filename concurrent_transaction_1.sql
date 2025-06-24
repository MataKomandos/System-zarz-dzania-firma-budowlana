-- Transakcja 1: Przetwarzanie zamówienia i aktualizacja stanu magazynowego
-- Ta transakcja demonstruje prawidłową obsługę współbieżnego przetwarzania zamówień

BEGIN;

-- Ustawienie poziomu izolacji transakcji na REPEATABLE READ, aby zapobiec odczytom fantomowym
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Deklaracja zmiennych
DO $$
DECLARE
    v_product_id UUID;
    v_user_id UUID;
    v_order_id UUID;
    v_quantity INTEGER := 2;
    v_available_stock INTEGER;
BEGIN
    -- Pobranie ID produktu (dla demonstracji)
    SELECT product_id INTO v_product_id
    FROM Products
    WHERE name = 'Laptop Pro'
    FOR UPDATE;  -- Zablokowanie wiersza, aby zapobiec równoczesnym modyfikacjom

    -- Pobranie ID użytkownika (dla demonstracji)
    SELECT user_id INTO v_user_id
    FROM Users
    WHERE username = 'john_doe';

    -- Sprawdzenie dostępności produktu z jawnym blokowaniem
    SELECT stock_quantity INTO v_available_stock
    FROM Products
    WHERE product_id = v_product_id
    FOR UPDATE;  -- Zablokowanie wiersza, aby zapobiec równoczesnym modyfikacjom

    IF v_available_stock >= v_quantity THEN
        -- Utworzenie nowego zamówienia
        INSERT INTO Orders (user_id, status, total_amount)
        VALUES (v_user_id, 'pending', 0)
        RETURNING order_id INTO v_order_id;

        -- Dodanie pozycji zamówienia
        INSERT INTO OrderItems (order_id, product_id, quantity, unit_price)
        SELECT 
            v_order_id,
            v_product_id,
            v_quantity,
            price
        FROM Products
        WHERE product_id = v_product_id;

        -- Aktualizacja stanu magazynowego
        UPDATE Products
        SET stock_quantity = stock_quantity - v_quantity
        WHERE product_id = v_product_id;

        -- Utworzenie rekordu płatności
        INSERT INTO Payments (order_id, amount, status, transaction_id)
        SELECT 
            v_order_id,
            total_amount,
            'pending',
            'TXN-' || gen_random_uuid()
        FROM Orders
        WHERE order_id = v_order_id;

        -- Zatwierdzenie zamówienia
        UPDATE Orders
        SET status = 'completed'
        WHERE order_id = v_order_id;

        RAISE NOTICE 'Zamówienie przetworzone pomyślnie. ID zamówienia: %', v_order_id;
    ELSE
        RAISE EXCEPTION 'Niewystarczający stan magazynowy dla produktu ID %. Dostępne: %, Żądane: %',
            v_product_id, v_available_stock, v_quantity;
    END IF;
END $$;

COMMIT; 