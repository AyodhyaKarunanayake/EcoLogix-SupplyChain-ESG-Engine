-
-- ECOLOGIX: CARBON-AWARE SUPPLY CHAIN & ESG AUDIT ENGINE
-- Database Schema (3NF), Validation Triggers, and Smart Routing Procedure


DROP DATABASE IF EXISTS ecologix_db;
CREATE DATABASE ecologix_db;
USE ecologix_db;


-- 1. MASTER TABLES


-- Fulfillment Warehouse Nodes
CREATE TABLE warehouses (
    warehouse_id INT AUTO_INCREMENT PRIMARY KEY,
    warehouse_code VARCHAR(20) NOT NULL UNIQUE,
    location_name VARCHAR(100) NOT NULL,
    max_carbon_cap_kg DECIMAL(10,2) NOT NULL DEFAULT 500.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product Catalog with Unit Weights for Scope 3 Calculation
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(50) NOT NULL UNIQUE,
    product_name VARCHAR(150) NOT NULL,
    unit_weight_kg DECIMAL(8,2) NOT NULL CHECK (unit_weight_kg > 0),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Live Multi-Warehouse Inventory Ledger
CREATE TABLE inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    warehouse_id INT NOT NULL,
    product_id INT NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT uq_warehouse_product UNIQUE (warehouse_id, product_id)
);

-- Logistics Route Matrix (Distances & Transit SLAs by Mode)
CREATE TABLE route_matrix (
    route_id INT AUTO_INCREMENT PRIMARY KEY,
    warehouse_id INT NOT NULL,
    destination_city VARCHAR(100) NOT NULL,
    transport_mode ENUM('EV_VAN', 'RAIL', 'DIESEL_TRUCK', 'AIR') NOT NULL,
    distance_km DECIMAL(8,2) NOT NULL CHECK (distance_km > 0),
    estimated_transit_hours INT NOT NULL CHECK (estimated_transit_hours > 0),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    CONSTRAINT uq_wh_dest_mode UNIQUE (warehouse_id, destination_city, transport_mode)
);


-- 2. TRANSACTIONAL & AUDIT TABLES


-- Customer Orders Header
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL UNIQUE,
    customer_name VARCHAR(100) NOT NULL,
    destination_city VARCHAR(100) NOT NULL,
    assigned_warehouse_id INT NOT NULL,
    order_status ENUM('PENDING', 'ALLOCATED', 'CARBON_HOLD', 'SHIPPED', 'CANCELLED') DEFAULT 'PENDING',
    total_carbon_expenditure_kg DECIMAL(10,4) NOT NULL DEFAULT 0.0000,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (assigned_warehouse_id) REFERENCES warehouses(warehouse_id)
);

-- Order Line Items
CREATE TABLE order_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    distance_km DECIMAL(8,2) NOT NULL,
    transport_mode ENUM('EV_VAN', 'RAIL', 'DIESEL_TRUCK', 'AIR') NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Immutable Scope 3 Carbon Audit Ledger (Append-Only for CSRD Compliance)
CREATE TABLE carbon_audit_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    warehouse_id INT NOT NULL,
    product_id INT NOT NULL,
    transport_mode VARCHAR(20) NOT NULL,
    shipment_weight_tons DECIMAL(10,4) NOT NULL,
    distance_km DECIMAL(8,2) NOT NULL,
    emission_factor_used DECIMAL(6,4) NOT NULL,
    calculated_carbon_kg DECIMAL(10,4) NOT NULL,
    compliance_flag ENUM('WITHIN_CAP', 'EXCEEDED_CAP') NOT NULL,
    logged_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);


-- 3. AUTOMATED DATABASE TRIGGERS


DELIMITER //

-- Guardrail Trigger 1: Prevent Negative Inventory Before Order Item Commits
CREATE TRIGGER trg_BeforeOrderItemInsert_ValidateStock
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
    DECLARE v_assigned_wh INT;
    DECLARE v_current_stock INT DEFAULT 0;

    SELECT assigned_warehouse_id INTO v_assigned_wh
    FROM orders
    WHERE order_id = NEW.order_id;

    SELECT COALESCE(stock_quantity, 0) INTO v_current_stock
    FROM inventory
    WHERE warehouse_id = v_assigned_wh AND product_id = NEW.product_id;

    IF v_current_stock < NEW.quantity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'INSUFFICIENT_STOCK: Allocation blocked to prevent negative inventory.';
    END IF;
END //

-- Execution Trigger 2: Deduct Stock, Compute Scope 3 Emissions & Write Audit Log
CREATE TRIGGER trg_AfterOrderItemInsert_AuditAndDeduct
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    DECLARE v_unit_weight DECIMAL(8,2);
    DECLARE v_emission_factor DECIMAL(6,4);
    DECLARE v_weight_tons DECIMAL(10,4);
    DECLARE v_carbon_kg DECIMAL(10,4);
    DECLARE v_assigned_wh INT;
    DECLARE v_wh_carbon_cap DECIMAL(10,2);
    DECLARE v_compliance_status VARCHAR(20);

    -- 1. Retrieve product weight & warehouse carbon threshold
    SELECT unit_weight_kg INTO v_unit_weight
    FROM products WHERE product_id = NEW.product_id;

    SELECT o.assigned_warehouse_id, w.max_carbon_cap_kg
    INTO v_assigned_wh, v_wh_carbon_cap
    FROM orders o
    JOIN warehouses w ON o.assigned_warehouse_id = w.warehouse_id
    WHERE o.order_id = NEW.order_id;

    -- 2. Map standard GHG Protocol emission factors (kg CO2e per ton-km)
    CASE NEW.transport_mode
        WHEN 'EV_VAN'       THEN SET v_emission_factor = 0.0150;
        WHEN 'RAIL'         THEN SET v_emission_factor = 0.0280;
        WHEN 'DIESEL_TRUCK' THEN SET v_emission_factor = 0.1050;
        WHEN 'AIR'          THEN SET v_emission_factor = 0.6020;
    END CASE;

    -- 3. Calculate Scope 3 Shipment Emissions
    SET v_weight_tons = (v_unit_weight * NEW.quantity) / 1000.0;
    SET v_carbon_kg = NEW.distance_km * v_weight_tons * v_emission_factor;

    -- 4. Evaluate Carbon Cap Compliance
    IF v_carbon_kg > v_wh_carbon_cap THEN
        SET v_compliance_status = 'EXCEEDED_CAP';
    ELSE
        SET v_compliance_status = 'WITHIN_CAP';
    END IF;

    -- 5. Deduct Live Warehouse Stock
    UPDATE inventory
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE warehouse_id = v_assigned_wh AND product_id = NEW.product_id;

    -- 6. Write Immutable Record to Carbon Audit Ledger
    INSERT INTO carbon_audit_logs (
        order_id, warehouse_id, product_id, transport_mode,
        shipment_weight_tons, distance_km, emission_factor_used,
        calculated_carbon_kg, compliance_flag
    )
    VALUES (
        NEW.order_id, v_assigned_wh, NEW.product_id, NEW.transport_mode,
        v_weight_tons, NEW.distance_km, v_emission_factor,
        v_carbon_kg, v_compliance_status
    );

    -- 7. Update Parent Order Status & Cumulative Emissions
    UPDATE orders
    SET total_carbon_expenditure_kg = total_carbon_expenditure_kg + v_carbon_kg,
        order_status = CASE 
            WHEN (total_carbon_expenditure_kg + v_carbon_kg) > v_wh_carbon_cap THEN 'CARBON_HOLD'
            ELSE 'ALLOCATED'
        END
    WHERE order_id = NEW.order_id;
END //


-- 4. 2-STAGE CARBON-AWARE ROUTING STORED PROCEDURE


CREATE PROCEDURE sp_SmartRouteOrder(
    IN p_order_number VARCHAR(50),
    IN p_customer_name VARCHAR(100),
    IN p_destination_city VARCHAR(100),
    IN p_product_id INT,
    IN p_quantity INT,
    IN p_max_sla_hours INT
)
BEGIN
    DECLARE v_best_wh_id INT DEFAULT NULL;
    DECLARE v_best_mode VARCHAR(20) DEFAULT NULL;
    DECLARE v_best_distance DECIMAL(8,2) DEFAULT NULL;
    DECLARE v_new_order_id INT;

    -- Stage 1 (Filter Stock & SLA) + Stage 2 (Rank by Lowest Carbon Expenditure)
    SELECT 
        r.warehouse_id,
        r.transport_mode,
        r.distance_km
    INTO 
        v_best_wh_id,
        v_best_mode,
        v_best_distance
    FROM route_matrix r
    JOIN warehouses w ON r.warehouse_id = w.warehouse_id
    JOIN inventory i ON r.warehouse_id = i.warehouse_id AND i.product_id = p_product_id
    JOIN products p ON i.product_id = p.product_id
    WHERE w.is_active = TRUE
      AND r.destination_city = p_destination_city
      AND i.stock_quantity >= p_quantity
      AND r.estimated_transit_hours <= p_max_sla_hours
    ORDER BY (
        r.distance_km * ((p.unit_weight_kg * p_quantity) / 1000.0) *
        CASE r.transport_mode
            WHEN 'EV_VAN'       THEN 0.0150
            WHEN 'RAIL'         THEN 0.0280
            WHEN 'DIESEL_TRUCK' THEN 0.1050
            WHEN 'AIR'          THEN 0.6020
        END
    ) ASC
    LIMIT 1;

    -- Handle case where no hub satisfies both Stock and SLA constraints
    IF v_best_wh_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'ROUTING_FAILED: No warehouse meets both Stock and SLA requirements.';
    END IF;

    -- Commit Order & Trigger Automated Inventory/Carbon Pipeline
    INSERT INTO orders (order_number, customer_name, destination_city, assigned_warehouse_id)
    VALUES (p_order_number, p_customer_name, p_destination_city, v_best_wh_id);

    SET v_new_order_id = LAST_INSERT_ID();

    INSERT INTO order_items (order_id, product_id, quantity, distance_km, transport_mode)
    VALUES (v_new_order_id, p_product_id, p_quantity, v_best_distance, v_best_mode);
END //

DELIMITER ;