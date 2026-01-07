CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE TYPE order_status AS ENUM ('pending', 'processing', 'completed', 'cancelled');
CREATE TYPE payment_status AS ENUM ('pending', 'completed', 'failed', 'refunded');
CREATE TABLE Users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
    username VARCHAR(50) NOT NULL UNIQUE, 
    email VARCHAR(100) NOT NULL UNIQUE CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'), 
    password_hash VARCHAR(255) NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, 
    last_login TIMESTAMP WITH TIME ZONE, 
    is_active BOOLEAN DEFAULT true 
);

CREATE TABLE Products (
    product_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
    name VARCHAR(100) NOT NULL,
    description TEXT, 
    price DECIMAL(10,2) NOT NULL CHECK (price >= 0), 
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0), 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP 
);

CREATE TABLE Orders (
    order_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE, 
    status order_status DEFAULT 'pending', 
    total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0), 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, 
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP 
);

CREATE TABLE OrderItems (
    order_item_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
    order_id UUID NOT NULL REFERENCES Orders(order_id) ON DELETE CASCADE, 
    product_id UUID NOT NULL REFERENCES Products(product_id) ON DELETE CASCADE, 
    quantity INTEGER NOT NULL CHECK (quantity > 0), 
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED 
);

CREATE TABLE Payments (
    payment_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES Orders(order_id) ON DELETE CASCADE, 
    amount DECIMAL(10,2) NOT NULL CHECK (amount >= 0), 
    status payment_status DEFAULT 'pending', 
    payment_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, 
    transaction_id VARCHAR(100) UNIQUE 
);

CREATE TABLE Reviews (
    review_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
    user_id UUID NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE, 
    product_id UUID NOT NULL REFERENCES Products(product_id) ON DELETE CASCADE, 
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5), 
    comment TEXT, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP, 
    UNIQUE(user_id, product_id) 
);

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON Products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON Orders
    FOR EACH ROW

    EXECUTE FUNCTION update_updated_at_column(); 
