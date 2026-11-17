# SYSTEM REQUIREMENTS SPECIFICATION (SRS) & AGILE USER STORIES

## 1. Functional Requirements (FR)

| Req ID | Requirement Title | System Rule & Logic Specification | Priority |
| :--- | :--- | :--- | :--- |
| **FR-01** | **Multi-Hub Stock Verification** | System must query live inventory across all active warehouse nodes upon order ingestion and filter out nodes where `available_stock < order_quantity`. | Critical |
| **FR-02** | **SLA Window Filtering** | System must calculate transit time per transport mode (`EV_VAN`, `RAIL`, `DIESEL_TRUCK`, `AIR`) and exclude any route exceeding the customer's checkout SLA deadline. | Critical |
| **FR-03** | **Scope 3 Carbon Calculation** | System must compute exact shipment emissions using: `Distance (km) × Weight (tons) × Mode Emission Factor`. | High |
| **FR-04** | **Carbon Cap Threshold Check** | If a route's calculated emission exceeds the warehouse node's `max_carbon_cap_kg`, the engine must flag `CARBON_HOLD` or auto-switch to an EV/Rail multimodal route. | High |
| **FR-05** | **Immutable Audit Logging** | Upon order allocation, a database trigger must automatically deduct inventory and write a timestamped record to `carbon_audit_logs` within the same ACID transaction. | Critical |

---

## 2. Non-Functional Requirements (NFR)

* **NFR-01 (Latency)**: The routing evaluation engine must return a warehouse assignment decision in **under 500 milliseconds** during checkout.
* **NFR-02 (Data Integrity)**: Inventory deduction and carbon audit insertion must be **atomic**—if carbon logging fails, the stock deduction must roll back completely.
* **NFR-03 (Audit Compliance)**: Records in `carbon_audit_logs` must be append-only (no `UPDATE` or `DELETE` permissions for standard application users) to satisfy CSRD external audits.

---

## 3. Agile User Stories (Azure DevOps / Gherkin Format)

### User Story 01: Standard Carbon-Aware Hub Selection
> **As a** Supply Chain Operations Analyst,  
> **I want** the routing engine to select the lowest-emission warehouse among all SLA-compliant hubs,  
> **So that** the company minimizes Scope 3 emissions without delaying customer deliveries.

```gherkin
Feature: Carbon-Aware Order Routing
  Scenario: Selecting the lowest-carbon warehouse within SLA
    Given a customer orders 50 units of SKU "SKU-101" (unit weight 2.0 kg) with a 48-hour SLA
    And Warehouse "WH-COLOMBO" has 200 units in stock with a Diesel Truck emission of 12.60 kg CO2e (24h transit)
    And Warehouse "WH-GALLE" has 150 units in stock with an EV Van emission of 1.80 kg CO2e (36h transit)
    When the EcoLogix allocation engine evaluates candidate hubs
    Then both hubs pass Stage 1 (Stock and SLA checks)
    And the engine assigns the order to "WH-GALLE" based on lower carbon expenditure
    And records a net carbon saving of 10.80 kg CO2e.