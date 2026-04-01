# Guide: Modern Observability and Security Data Pipelines

This document serves as a learning tool and reference for designing and building a unified data pipeline that serves both observability and security use cases. It breaks down the silos between DevOps and SecOps by leveraging modern, open-source standards.

---

## Chapter 1: Core Components

Understanding the role of each component is key to designing an effective pipeline.

### 1.1. OpenTelemetry (OTel): The Collector

*   **Role**: To **standardize the generation and transport** of telemetry data. It's the "plumbing" for getting data out of your applications and infrastructure.
*   **The "Three Pillars"**: OTel is built to handle:
    1.  **Metrics**: Numeric measurements for performance monitoring (e.g., CPU usage, request latency).
    2.  **Traces**: The end-to-end journey of a request as it moves through multiple services.
    3.  **Logs**: Text-based records of events.
*   **Key Component**: The **OTel Collector** is a high-performance agent that receives, processes, and exports telemetry data. It's the central hub of our collection strategy.

### 1.2. OCSF (Open Cybersecurity Schema Framework): The Common Language

*   **Role**: To provide a **standardized schema (a common dictionary)** for security-related events.
*   **Goal**: To break down data silos between different security tools (firewalls, EDRs, custom applications). If all tools speak the same "language," a central security system can understand them without needing custom decoders for each one.

### 1.3. Tenzir: The Security Data Engineer

*   **Role**: A specialized **security data pipeline** built for high-performance parsing, normalization, enrichment, and routing of security data.
*   **In this Architecture**: We use Tenzir to transform raw logs into the structured OCSF format. It's the engine that handles the heavy lifting of security data transformation.

### 1.4. SIEM (Security Information and Event Management): The Security Brain

*   **Role**: The central platform for security analytics. It ingests structured event data (like OCSF), correlates events from different sources, triggers alerts, and enables threat hunting.
*   **Examples**: Splunk, Sentinel, Elastic SIEM.

### 1.5. Observability Backend: The Developer's Toolkit

*   **Role**: A log management or observability platform designed for high-volume, cost-effective storage and analysis of non-security data.
*   **Use Case**: Used by developers and SREs for debugging, performance analysis, and understanding application behavior.
*   **Examples**: Loki, Elasticsearch, ClickHouse.

---

## Chapter 2: The Unified Pipeline Architecture

The guiding principle is to **route the right data to the right tool for the right job.** We achieve this by splitting the data stream early.

### 2.1. Recommended Architecture: Split-Stream Routing

```
                                  +---[ IF security-relevant ]--> [ Tenzir ] -> [ SIEM ]
                                  |
[ OTel Collector ]  <-- Inspects logs
                                  |
                                  +---[ ELSE (not security) ]---> [ Observability Backend ]
                                                                      (e.g., Loki)
```

### 2.2. Step-by-Step Data Flow

1.  **Instrumentation**: Your application code is instrumented with an OpenTelemetry SDK. It generates logs for both security (`Login failure`) and observability (`Cache cleared`) events.

2.  **Collection & Routing**: The **OTel Collector** receives *all* logs. You configure a processor (e.g., the `routing` processor) to inspect each log.
    *   A rule is set: "IF a log contains security keywords (`login`, `auth`, `denied`) or comes from a specific source, route it to the 'security' pipeline. ELSE, route it to the 'observability' pipeline."

3.  **Security Transformation**:
    *   Logs routed to the 'security' pipeline are sent from the OTel Collector to **Tenzir**.
    *   A Tenzir pipeline parses the raw log, extracts key entities (user, IP, action), and **transforms the data into a structured OCSF event**.
    *   Tenzir then forwards the clean, OCSF-formatted event to the **SIEM**.

4.  **Observability Storage**:
    *   Logs routed to the 'observability' pipeline **bypass Tenzir completely**.
    *   The OTel Collector sends these logs directly to a cost-effective **Observability Backend** like Loki.

### 2.3. Why This Architecture is Effective

*   **Efficiency & Cost**: Only security-relevant data goes to the specialized (and potentially expensive) security stack. Verbose debug logs go to cheaper bulk storage.
*   **Performance**: Tenzir and the SIEM are not burdened with processing high-volume, non-security-related logs.
*   **Separation of Concerns**: Security teams get clean, relevant data in their SIEM. Development teams get all the verbose logs they need in their own tools.

---

## Chapter 3: Practical Example

Let's trace a single log event: `INFO: Login failure for user 'imposter' from ip 192.0.2.100`

1.  **OTel Collector Receives**: The collector gets the raw log string.
2.  **OTel Collector Routes**: The `routing` processor sees the keywords "Login failure" and sends the log to the Tenzir exporter.
3.  **Tenzir Transforms**: Tenzir receives the log and maps it to OCSF:
    ```json
    {
      "activity_name": "Logon",
      "category": "authentication",
      "status": "Failure",
      "actor": { "user": { "name": "imposter" } },
      "src_endpoint": { "ip": "192.0.2.100" }
    }
    ```
4.  **SIEM Ingests**: The SIEM receives this structured JSON object. It can now easily trigger an alert: "3 login failures for the same user in 1 minute."

---

## Chapter 4: Future Learning & Expansion

This section is for topics to add as your understanding grows.

### 4.1. Handling Metrics and Traces
*   (Add notes here on how metrics and traces flow through the pipeline. *Hint: They usually bypass the security-specific tools like Tenzir and go directly from the OTel Collector to backends like Prometheus and Jaeger.*)

### 4.2. Advanced Enrichment in Tenzir
*   (Add notes on how to enrich events in Tenzir. *Example: Add GeoIP data based on an IP address, or cross-reference an IP/domain against a threat intelligence feed.*)

### 4.3. OTel Collector Configuration
*   (Add practical YAML examples for the `routing` processor and exporter configurations.)

### 4.4. Alternative Tools
*   (Explore and document alternative tools. *Example: What if we use Vector instead of the OTel Collector? What are the pros and cons?*)

### 4.5. Feedback Loops
*   (Consider advanced concepts. *Example: How can an alert from the SIEM trigger an action, like adding a firewall rule or scaling a service?*)

