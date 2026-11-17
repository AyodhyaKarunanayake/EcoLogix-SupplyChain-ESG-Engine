# EXECUTIVE PROJECT CHARTER: ECOLOGIX MIDDLEWARE

## 1. Executive Summary & Business Need
Global retail enterprises face dual pressures: maintaining fast e-commerce delivery timelines while complying with international carbon regulations (e.g., EU Corporate Sustainability Reporting Directive - CSRD). Legacy ERP and WMS platforms route orders based strictly on distance and stock, ignoring environmental impact. 

EcoLogix is an enterprise middleware solution designed to dynamically allocate orders to the optimal fulfillment warehouse based on **Stock Availability**, **Delivery SLA**, and **Scope 3 Carbon Footprint**, while automatically logging an unalterable carbon ledger for regulatory auditing.

## 2. Project Vision & Core Objectives
* **Vision**: Build a carbon-aware order routing and audit engine that bridges e-commerce platforms with enterprise backend ERP databases.
* **Target Business KPIs**:
  * **25% Reduction** in Scope 3 transport carbon emissions ($kg CO_2e$) across fulfillment routes.
  * **18% Reduction** in total transport fuel spend by prioritizing low-emission multimodal routes (EV/Rail).
  * **99.5% Adherence** to guaranteed delivery SLA timeframes.
  * **100% Audit Readiness** for regulatory ESG compliance reporting via real-time database trigger logging.

## 3. Stakeholder & System Actor Map

| Actor / Stakeholder | Role in System | Key Needs / Objectives |
| :--- | :--- | :--- |
| **E-Commerce Customer** | Initiates order placement at checkout. | Fast delivery, transparent green shipping options. |
| **Supply Chain Analyst** | Manages routing rules & transport emission caps. | Real-time visibility into route efficiency & SLA status. |
| **ESG / Sustainability Auditor** | Reviews regulatory compliance logs. | Verified, tamper-proof Scope 3 carbon audit trails. |
| **Warehouse Fulfillment Lead** | Receives allocated pick/pack requests. | Accurate stock deduction and zero inventory lockouts. |
| **EcoLogix Engine (System)** | Middleware execution service. | Evaluates routing scores & executes database transactions. |

## 4. In-Scope vs. Out-of-Scope Boundaries

### In-Scope
* Multi-warehouse inventory allocation logic based on stock, SLA, and emission factors.
* BPMN 2.0 process flow mapping (AS-IS legacy vs. TO-BE EcoLogix routing).
* Azure DevOps Agile backlog generation with Gherkin User Stories.
* 3NF MySQL relational database schema with automated carbon calculation triggers.
* Generative AI synthetic data generation (500+ rows) and UAT edge-case validation suite.

### Out-of-Scope
* Physical hardware IoT sensor integration on trucks.
* Live satellite GPS tracking of active transit vehicles.
* Front-end payment gateway transaction processing.