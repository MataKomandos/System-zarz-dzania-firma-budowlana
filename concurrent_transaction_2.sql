BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

DO $$
DECLARE
    v_price_increase DECIMAL(10,2) := 50.00; 
    v_reorder_threshold INTEGER := 20; 
    v_reorder_quantity INTEGER := 50; 
    v_product_record RECORD;
BEGIN
    FOR v_product_record IN (
        SELECT product_id, name, price, stock_quantity
        FROM Products
        WHERE stock_quantity <= v_reorder_threshold
        FOR UPDATE  
    ) LOOP

        UPDATE Products
        SET 
            price = price + v_price_increase,
            stock_quantity = stock_quantity + CASE 
                WHEN stock_quantity <= v_reorder_threshold 
                THEN v_reorder_quantity 
                ELSE 0 
            END
        WHERE product_id = v_product_record.product_id;
    
        IF v_product_record.stock_quantity <= v_reorder_threshold THEN
            RAISE NOTICE 'Uzupełniono stan produktu: %. Poprzedni stan: %. Nowy stan: %',
                v_product_record.name,
                v_product_record.stock_quantity,
                v_product_record.stock_quantity + v_reorder_quantity;
        END IF;

        RAISE NOTICE 'Zaktualizowano cenę produktu: %. Poprzednia cena: %. Nowa cena: %',
            v_product_record.name,
            v_product_record.price,
            v_product_record.price + v_price_increase;
    END LOOP;
END $$;


COMMIT; 
