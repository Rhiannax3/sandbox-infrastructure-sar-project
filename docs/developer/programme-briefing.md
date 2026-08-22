# Junior Data Engineering Development Programme: Architectural Sandbox Projects

## 1. Programme Overview & Purpose

This initiative provides junior data engineers with the opportunity to learn data architecture principles through carefully tailored, hands-on development projects. Recognizing that abstract architectural discussions can be difficult for early-career professionals to follow, this programme mirrors the production systems they will ultimately support. The primary goal is to build their technical vocabulary, engineering confidence, and architectural knowledge through guided self-study and practical application under the mentorship of a senior architect.

## 2. Project Design Principles & Structure

To ensure these side-of-desk projects remain engaging and educational over a multi-month period, the senior architect designing the environments must adhere to the following principles:

* **Separation of Concerns:** Foundational infrastructure must be isolated from development tasks. Engineers should not need to build web applications from scratch, but rather focus on enhancing existing code when introducing new backend features.


* **Incremental Complexity:** Introduce new concepts through incremental challenges that progressively build functionality or address non-functional requirements.


* **Concept-First Approach:** High-level overviews and theoretical justifications must precede hands-on tasks so engineers understand *why* a pattern is used before learning *how* to implement it.


* **Mentorship over Prescriptiveness:** Engineers should be given clear data contracts and requirements but expected to independently research implementation details (e.g., syntax, cloud console navigation) with the senior architect acting as a guide.


---

## 3. Project A: AWS API & Document Request System

### Scenario & Context

The engineers will build the backend for a compliance web application that manages internal Subject Access Requests (SARs). Compliance officers will use this system to request specific data payloads ('User Profile Summary', 'User Activity Report', and 'User Consent Log') from internal teams. The project involves data flowing through APIs hosted on AWS using Lambda and API Gateway.

### Key Architectural Concepts Covered

* RESTful API design and dynamic JSON payload validation.


* Statelessness and external state management (DynamoDB).


* Zero Trust security, OAuth 2.0, and JSON Web Tokens (JWTs).


* Authentication and authorisation protocols through open-source tooling like Keycloak.


* Resilience, error handling, and appropriate HTTP status code routing.


* C4 modelling (Context, Container, and Component levels).



### Phased Delivery Plan

* **Phase 1: Foundation & The C4 Model:** Engineers research C4 modelling and map out the SAR system. They will deploy a basic "Hello World" AWS Lambda function, expose it via API Gateway, and wire the provided web app to display the response.


* **Phase 2: Core API & Dynamic State Management:** The API is expanded to handle POST, GET, PUT, and DELETE methods. Engineers must validate incoming SAR payloads against a strict, dynamic JSON contract based on the requested document type. They will introduce a data store to persist requests and manage state.


* **Phase 3: Security & Identity Management:** Engineers research OAuth 2.0 flows. They will secure the API Gateway to require a valid Keycloak JWT before invoking Lambda, implementing scope-based authorization (e.g., standard officers vs. senior officers).


* **Phase 4: Resilience & Error Handling:** Engineers introduce deliberate failure scenarios (e.g., database timeouts) to ensure the API fails gracefully with accurate HTTP codes. They will also complete a theoretical exercise on AWS Lambda's native intra-region availability.



### Foundational Infrastructure Requirements

The senior architect must pre-provision the following in the AWS sandbox:

* **Python Django Web Boilerplate:** A basic frontend skeleton with UI placeholders for the SAR requests. Ensure the Python Django application is pre-structured to handle OAuth 2.0 integrations smoothly, allowing the juniors to focus on API Gateway token validation rather than debugging the application-side authentication flows.


* **Keycloak Instance:** A fully deployed and configured Keycloak server with predefined user roles (Standard Officer, Senior Officer) for testing.


* **IAM Baselines:** Basic IAM roles that the engineers can attach to their Lambda functions for database access.

---

## 4. Project B: Databricks Medallion Data Lake & SAR Reporting

### Scenario & Context

This project focuses on the analytical downstream consumption of the SAR application. The engineers will design a data lake and management information reporting solution using Databricks and Power BI. They will process historical SAR operational data and system logs, ultimately building a reporting layer that answers specific business questions for compliance leadership (e.g., operational SLAs, system resilience, and compliance officer engagement).

### Key Architectural Concepts Covered

* Medallion architecture principles (append-only ingestion, progressive refinement).


* Handling data quality issues, schema drift, and implementing quarantine patterns.


* Kimball dimensional data modelling (Star Schemas).


* Data aggregation and core business logic implementation.


* Data governance and role-based access control (RBAC) via Unity Catalog.

### Phased Delivery Plan


| Phase        | Theme                          | Scope                                                                                                                                                                                                                                                |
|--------------|--------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 Bronze     | Ingestion                      | Engineers build pipelines to ingest raw JSON/CSV SAR data into Databricks Delta tables. The focus is on append-only patterns and capturing load metadata without altering the source.                                                                |
| 2 Silver     | Cleansing & Quality            | Engineers standardize data formats and deduplicate records. They must address intentional data quality issues within the sample data by implementing a quarantine pattern, routing failed records to an exceptions table while valid records proceed. |
| 3 Gold       | Data Modelling                 | Applying Kimball principles, engineers design a Star Schema (Fact and Dimension tables) out of the cleansed Silver data. They must establish and enforce strict naming conventions.                                                                  |
| 4 Platinum   | Business Logic                 | Engineers build highly optimized data products encapsulating core business logic, such as average fulfillment times or error rates by parameter. They will connect Power BI to the Databricks SQL endpoint to build a dashboard.                     |
| 5 Governance | Governance & Access Management | Engineers implement RBAC, ensuring standard analysts can only query the Gold and Platinum layers, while engineers retain access to the lower layers.                                                                                                 |



### Foundational Infrastructure Requirements

The senior architect must pre-provision the following in the Azure/Databricks sandbox:

* **Databricks Workspace:** A configured workspace with Unity Catalog enabled and SQL warehouse endpoints active.


* **Blob Storage & Sample Data:** Base infrastructure including blob storage for the medallion layers. The storage must be seeded with historical SAR JSON/CSV files. *Crucially, this sample data must contain deliberate schema anomalies and malformed records to trigger the Silver layer data quality challenges.*


* **Power BI Access:** Appropriate licensing and connectivity enabled for the engineers to publish simple dashboards from the Databricks backend.




