-- Transakcja 2: Zbiorcza aktualizacja cen i uzupełnienie magazynu
-- Ta transakcja demonstruje obsługę zbiorczych aktualizacji z odpowiednim blokowaniem

BEGIN;

-- Ustawienie poziomu izolacji transakcji na REPEATABLE READ, aby zapobiec odczytom fantomowym
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Deklaracja zmiennych
DO $$
DECLARE
    v_price_increase DECIMAL(10,2) := 50.00; -- Wartość podwyżki ceny
    v_reorder_threshold INTEGER := 20; -- Próg ponownego zamówienia
    v_reorder_quantity INTEGER := 50; -- Ilość do zamówienia
    v_product_record RECORD;
BEGIN
    -- Przetwarzanie każdego produktu wymagającego aktualizacji ceny i ewentualnego uzupełnienia
    FOR v_product_record IN (
        SELECT product_id, name, price, stock_quantity
        FROM Products
        WHERE stock_quantity <= v_reorder_threshold
        FOR UPDATE  -- Zablokowanie wierszy do aktualizacji
    ) LOOP
        -- Aktualizacja ceny i stanu magazynowego
        UPDATE Products
        SET 
            price = price + v_price_increase,
            stock_quantity = stock_quantity + CASE 
                WHEN stock_quantity <= v_reorder_threshold 
                THEN v_reorder_quantity 
                ELSE 0 
            END
        WHERE product_id = v_product_record.product_id;

        -- Logowanie uzupełnienia stanu magazynowego
        IF v_product_record.stock_quantity <= v_reorder_threshold THEN
            RAISE NOTICE 'Uzupełniono stan produktu: %. Poprzedni stan: %. Nowy stan: %',
                v_product_record.name,
                v_product_record.stock_quantity,
                v_product_record.stock_quantity + v_reorder_quantity;
        END IF;

        -- Logowanie zmiany ceny
        RAISE NOTICE 'Zaktualizowano cenę produktu: %. Poprzednia cena: %. Nowa cena: %',
            v_product_record.name,
            v_product_record.price,
            v_product_record.price + v_price_increase;
    END LOOP;
END $$;

COMMIT; 