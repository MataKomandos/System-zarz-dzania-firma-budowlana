-- Tworzenie tabel dla bazy danych
-- Włączenie rozszerzenia UUID do generowania unikalnych identyfikatorów
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tworzenie typów wyliczeniowych dla statusów
CREATE TYPE order_status AS ENUM ('pending', 'processing', 'completed', 'cancelled');
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');

-- Tworzenie tabeli Użytkowników
CREATE TABLE Users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), -- Unikalny identyfikator użytkownika
    username VARCHAR(50) NOT NULL UNIQUE, -- Unikalna nazwa użytkownika
    email VARCHAR(100) NOT NULL UNIQUE CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'), -- Adres email z walidacją
    password_hash VARCHAR(255) NOT NULL, -- Zahaszowane hasło
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- Data utworzenia konta
    last_login TIMESTAMP WITH TIME ZONE, -- Ostatnie logowanie
    is_active BOOLEAN DEFAULT true -- Status aktywności konta
);

-- Tworzenie tabeli Produktów
CREATE TABLE Products (
    product_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), -- Unikalny identyfikator produktu
    name VARCHAR(100) NOT NULL, -- Nazwa produktu
    description TEXT, -- Opis produktu
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0), -- Cena z walidacją
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0), -- Stan magazynowy
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- Data dodania produktu
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP -- Data ostatniej aktualizacji
);

-- Tworzenie tabeli Zamówień
CREATE TABLE Orders (
    order_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), -- Unikalny identyfikator zamówienia
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE, -- Powiązanie z użytkownikiem
    status order_status DEFAULT 'pending', -- Status zamówienia
    total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0), -- Łączna kwota
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- Data utworzenia
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP -- Data aktualizacji
);

-- Tworzenie tabeli Pozycji Zamówienia
CREATE TABLE OrderItems (
    order_item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), -- Unikalny identyfikator pozycji
    order_id UUID NOT NULL REFERENCES Orders(order_id) ON DELETE CASCADE, -- Powiązanie z zamówieniem
    product_id UUID NOT NULL REFERENCES Products(product_id) ON DELETE CASCADE, -- Powiązanie z produktem
    quantity INTEGER NOT NULL CHECK (quantity > 0), -- Ilość
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0), -- Cena jednostkowa
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED -- Automatycznie obliczana suma częściowa
);

-- Tworzenie tabeli Płatności
CREATE TABLE Payments (
    payment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), -- Unikalny identyfikator płatności
    order_id UUID NOT NULL REFERENCES Orders(order_id) ON DELETE CASCADE, -- Powiązanie z zamówieniem
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0), -- Kwota płatności
    status payment_status DEFAULT 'pending', -- Status płatności
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- Data płatności
    transaction_id VARCHAR(100) UNIQUE -- Unikalny identyfikator transakcji
);

-- Tworzenie tabeli Recenzji
CREATE TABLE Reviews (
    review_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), -- Unikalny identyfikator recenzji
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE, -- Powiązanie z użytkownikiem
    product_id UUID NOT NULL REFERENCES Products(product_id) ON DELETE CASCADE, -- Powiązanie z produktem
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5), -- Ocena (1-5)
    comment TEXT, -- Komentarz
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, -- Data utworzenia
    UNIQUE(user_id, product_id) -- Jeden użytkownik może dodać tylko jedną recenzję do produktu
);

-- Dodanie triggerów do aktualizacji pola updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger dla tabeli Produktów
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON Products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger dla tabeli Zamówień
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON Orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column(); 