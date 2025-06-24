-- Trigger 1: Automatyczna aktualizacja stanu magazynowego produktu gdy zmienia się status zamówienia
CREATE OR REPLACE FUNCTION update_product_stock()
RETURNS TRIGGER AS $$
BEGIN
    -- Jeśli zamówienie jest anulowane, przywróć stan magazynowy
    IF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
        UPDATE Products p
        SET stock_quantity = p.stock_quantity + oi.quantity
        FROM OrderItems oi
        WHERE oi.order_id = NEW.order_id
        AND oi.product_id = p.product_id;
    -- Jeśli zamówienie jest zakończone, nie potrzeba działań, ponieważ stan magazynowy został już zmniejszony
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_product_stock
AFTER UPDATE OF status ON Orders
FOR EACH ROW
EXECUTE FUNCTION update_product_stock();

-- Trigger 2: Sprawdzanie dostępności produktów przed dodaniem pozycji zamówienia
CREATE OR REPLACE FUNCTION check_stock_availability()
RETURNS TRIGGER AS $$
DECLARE
    available_stock INTEGER;
BEGIN
    -- Pobierz aktualny stan magazynowy
    SELECT stock_quantity INTO available_stock
    FROM Products
    WHERE product_id = NEW.product_id;

    -- Sprawdź czy jest wystarczająca ilość produktów
    IF available_stock < NEW.quantity THEN
        RAISE EXCEPTION 'Insufficient stock for product ID %. Available: %, Requested: %',
            NEW.product_id, available_stock, NEW.quantity;
    END IF;

    -- Zmniejsz stan magazynowy
    UPDATE Products
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_stock_availability
BEFORE INSERT ON OrderItems
FOR EACH ROW
EXECUTE FUNCTION check_stock_availability();

-- Trigger 3: Automatyczna aktualizacja całkowitej kwoty zamówienia gdy zmieniają się pozycje
CREATE OR REPLACE FUNCTION update_order_total()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE Orders
        SET total_amount = (
            SELECT SUM(quantity * unit_price)
            FROM OrderItems
            WHERE order_id = NEW.order_id
        )
        WHERE order_id = NEW.order_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE Orders
        SET total_amount = (
            SELECT COALESCE(SUM(quantity * unit_price), 0)
            FROM OrderItems
            WHERE order_id = OLD.order_id
        )
        WHERE order_id = OLD.order_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_order_total
AFTER INSERT OR UPDATE OR DELETE ON OrderItems
FOR EACH ROW
EXECUTE FUNCTION update_order_total();

-- Trigger 4: Rejestr zmian cen
CREATE TABLE IF NOT EXISTS PriceChangeLog (
    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL,
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    changed_by TEXT DEFAULT CURRENT_USER
);

CREATE OR REPLACE FUNCTION log_price_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.price != OLD.price THEN
        INSERT INTO PriceChangeLog (product_id, old_price, new_price)
        VALUES (NEW.product_id, OLD.price, NEW.price);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_price_changes
BEFORE UPDATE OF price ON Products
FOR EACH ROW
EXECUTE FUNCTION log_price_changes(); 