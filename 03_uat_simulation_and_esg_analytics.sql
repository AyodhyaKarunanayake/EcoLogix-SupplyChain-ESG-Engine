USE ecologix_db;

-- PART 1: UAT EDGE-CASE SIMULATION SUITE


-- UAT-02: Tight SLA Override Test (Jaffna Express Order within 12 Hours)
-- Rail (36h) & Colombo Truck (14h) breach 12h SLA; chooses Kandy Truck (11h) over Air.
CALL sp_SmartRouteOrder('ORD-2026-002', 'Northern Solar Grid Corp', 'Jaffna', 1, 15, 12);

-- UAT-03: Carbon Cap Breach & Governance Hold Test (Heavy Bulk Shipment)
-- 40 Lithium Batteries (1.6 tons) to Jaffna in 4h forces AIR (308.2240 kg > 150 kg cap).
-- Automatically flags 'EXCEEDED_CAP' and sets order_status = 'CARBON_HOLD'.
CALL sp_SmartRouteOrder('ORD-2026-003', 'Jaffna Hospital Emergency', 'Jaffna', 2, 40, 4);

-- UAT-04: Multi-Hub Rail Optimization Test (Colombo Bulk Tea Order, 15-Hour SLA)
-- Kandy Rail (115km, 10h) beats Galle Rail (120km, 12h) and EV Van (125km, 8h).
CALL sp_SmartRouteOrder('ORD-2026-004', 'Ceylon Artisanal Exports', 'Colombo', 3, 100, 15);


-- PART 2: VERIFY UAT OUTCOMES


SELECT 
    o.order_number,
    o.customer_name,
    o.destination_city,
    w.warehouse_code AS assigned_hub,
    o.order_status,
    o.total_carbon_expenditure_kg
FROM orders o
JOIN warehouses w ON o.assigned_warehouse_id = w.warehouse_id
ORDER BY o.order_id;

SELECT 
    log_id,
    order_id,
    transport_mode,
    shipment_weight_tons,
    distance_km,
    calculated_carbon_kg,
    compliance_flag
FROM carbon_audit_logs
ORDER BY log_id;


-- PART 3: EXECUTIVE ESG & SUPPLY CHAIN ANALYTICS QUERIES


-- KPI Report 1: Scope 3 Emissions & Compliance Breakdown by Warehouse Hub
SELECT 
    w.warehouse_code,
    w.location_name,
    COUNT(c.log_id) AS total_shipments,
    ROUND(SUM(c.shipment_weight_tons), 2) AS total_tonnage_shipped,
    ROUND(SUM(c.calculated_carbon_kg), 4) AS total_scope3_co2_kg,
    SUM(CASE WHEN c.compliance_flag = 'EXCEEDED_CAP' THEN 1 ELSE 0 END) AS carbon_cap_breaches
FROM warehouses w
LEFT JOIN carbon_audit_logs c ON w.warehouse_id = c.warehouse_id
GROUP BY w.warehouse_id, w.warehouse_code, w.location_name
ORDER BY total_scope3_co2_kg DESC;

-- KPI Report 2: Net Carbon Savings vs. Baseline Diesel Road Transport
SELECT 
    c.order_id,
    c.transport_mode AS selected_mode,
    c.calculated_carbon_kg AS actual_co2_kg,
    ROUND(c.distance_km * c.shipment_weight_tons * 0.1050, 4) AS baseline_diesel_co2_kg,
    ROUND((c.distance_km * c.shipment_weight_tons * 0.1050) - c.calculated_carbon_kg, 4) AS net_co2_saved_kg
FROM carbon_audit_logs c
ORDER BY c.order_id;