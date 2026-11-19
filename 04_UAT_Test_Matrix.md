# USER ACCEPTANCE TESTING (UAT) & VALIDATION SUITE

## Test Execution Summary
* **Total Scenarios Executed:** 5 (4 Governance Scenarios + 1 Security Guardrail)
* **Pass Rate:** 100% (5/5 Passed)
* **Database Engine:** MariaDB 10.4 / MySQL 8.0 (InnoDB ACID Engine)


### UAT-01: Standard Eco-Hub EV Routing — `[PASS]`
* **Input Parameters:** `ORD-2026-001` | Destination: `Matara` | Product: `SKU-SOL-100` (Qty: 10) | SLA: `12h`
* **Expected Behavior:** Select `WH-GAL-02` via `EV_VAN`, log `0.1688 kg CO2e`, and deduct 10 units from inventory.
* **Actual Result:** Routed to `WH-GAL-02` (`EV_VAN`), logged `0.1688 kg CO2e` (`WITHIN_CAP`), and stock reduced from `60` to `50`.


### UAT-02: Tight SLA Override Protection — `[PASS]`
* **Input Parameters:** `ORD-2026-002` | Destination: `Jaffna` | Product: `SKU-SOL-100` (Qty: 15) | SLA: `12h`
* **Expected Behavior:** Eliminate Rail (`36h`) and Colombo Truck (`14h`) due to SLA breach; select Kandy Truck (`11h`) over Air (`3h`).
* **Actual Result:** Routed to `WH-KDY-03` (`DIESEL_TRUCK`), logged `12.2063 kg CO2e`, and order status set to `ALLOCATED`.


### UAT-03: Carbon Cap Breach & Governance Hold — `[PASS]`
* **Input Parameters:** `ORD-2026-003` | Destination: `Jaffna` | Product: `SKU-BAT-200` (Qty: 40, 1.6 tons) | SLA: `4h`
* **Expected Behavior:** Force `AIR` freight (`3h`); calculated `308.2240 kg CO2e` exceeds Colombo's `150.00 kg` cap and triggers `CARBON_HOLD`.
* **Actual Result:** Routed via `WH-CMB-01` (`AIR`), logged `308.2240 kg CO2e` (`EXCEEDED_CAP`), and status auto-updated to `CARBON_HOLD`.


### UAT-04: Multi-Hub EV Optimization — `[PASS]`
* **Input Parameters:** `ORD-2026-004` | Destination: `Colombo` | Product: `SKU-TEA-300` (Qty: 100) | SLA: `15h`
* **Expected Behavior:** Evaluate all valid routes under `15h` SLA and assign the lowest-carbon option.
* **Actual Result:** Routed to `WH-GAL-02` (`EV_VAN`), logging `2.8125 kg CO2e` vs. `19.6875 kg CO2e` diesel baseline (`16.8750 kg` net CO2 saved).


### UAT-05: Negative Stock Security Lockout — `[PASS]`
* **Input Parameters:** Request Qty `500` when maximum warehouse stock is `120`
* **Expected Behavior:** `BEFORE INSERT` trigger aborts transaction via `SQLSTATE 45000` to prevent negative inventory.
* **Actual Result:** Transaction blocked cleanly with `ROUTING_FAILED` / `INSUFFICIENT_STOCK` and zero data corruption.