USE ecologix_db;

-- 1. Insert Regional Fulfillment Warehouses
INSERT INTO warehouses (warehouse_code, location_name, max_carbon_cap_kg) VALUES
('WH-CMB-01', 'Colombo Central Logistics Hub', 150.00),
('WH-GAL-02', 'Galle Southern Eco-Hub', 100.00),
('WH-KDY-03', 'Kandy Highland Distribution Center', 120.00);

-- 2. Insert Products with Unit Weights (kg)
INSERT INTO products (sku, product_name, unit_weight_kg) VALUES
('SKU-SOL-100', 'Commercial Solar Inverter 5kW', 25.00),
('SKU-BAT-200', 'Lithium Iron Storage Module', 40.00),
('SKU-TEA-300', 'Export Ceylon Tea Bulk Crate', 15.00);

-- 3. Populate Initial Inventory Across Warehouses
INSERT INTO inventory (warehouse_id, product_id, stock_quantity) VALUES
(1, 1, 120), (1, 2, 80),  (1, 3, 300), -- Colombo Stock
(2, 1, 60),  (2, 2, 40),  (2, 3, 250), -- Galle Stock
(3, 1, 50),  (3, 2, 30),  (3, 3, 180); -- Kandy Stock

-- 4. Populate Multi-Modal Route Matrix
INSERT INTO route_matrix (warehouse_id, destination_city, transport_mode, distance_km, estimated_transit_hours) VALUES
-- Routes to Matara
(2, 'Matara', 'EV_VAN',       45.00,  4),
(2, 'Matara', 'DIESEL_TRUCK', 45.00,  2),
(1, 'Matara', 'RAIL',         160.00, 18),
(1, 'Matara', 'DIESEL_TRUCK', 160.00, 5),

-- Routes to Jaffna
(1, 'Jaffna', 'RAIL',         395.00, 36),
(1, 'Jaffna', 'DIESEL_TRUCK', 395.00, 14),
(1, 'Jaffna', 'AIR',          320.00, 3),
(3, 'Jaffna', 'DIESEL_TRUCK', 310.00, 11),

-- Routes to Colombo
(2, 'Colombo', 'EV_VAN',      125.00, 8),
(2, 'Colombo', 'RAIL',        120.00, 12),
(3, 'Colombo', 'RAIL',        115.00, 10),
(3, 'Colombo', 'DIESEL_TRUCK',115.00, 4);