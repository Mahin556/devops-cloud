Yes — this uploaded text is a **different and much more complete monitoring tutorial**. It covers **Express.js → Prometheus → Grafana for metrics**, then **Winston/Loki → Grafana for logs**, including custom request-latency metrics.

The core architecture in the source is a centralized monitoring system where services expose metrics and logs that can then be collected and visualized centrally. 

I’ll give you the **entire practical process from start to finish**, with commands and files.

# Complete Monitoring Stack

```text
                         ┌──────────────────┐
                         │   Express App    │
                         │    Port 8000     │
                         └────────┬─────────┘
                                  │
                  ┌───────────────┴───────────────┐
                  │                               │
             /metrics                         Application
                  │                               │
                  ▼                               ▼
          ┌───────────────┐                 ┌─────────────┐
          │  Prometheus   │                 │    Logs     │
          │   Port 9090   │                 └──────┬──────┘
          └───────┬───────┘                        │
                  │                                ▼
                  │                         ┌─────────────┐
                  │                         │    Loki     │
                  │                         │   Port 3100 │
                  │                         └──────┬──────┘
                  │                                │
                  └──────────────┬─────────────────┘
                                 │
                                 ▼
                         ┌─────────────────┐
                         │     Grafana     │
                         │    Port 3000    │
                         └─────────────────┘
```

The source first separates monitoring into **metrics** and **log collection**. Metrics are numerical values such as latency, CPU, memory and concurrent requests; logs contain runtime/application events and errors. 

---

# PART 1 — Create the Project

## 1. Create directory

```bash
mkdir monitoring-demo
cd monitoring-demo
```

Create:

```bash
mkdir app
mkdir prometheus
```

Final structure:

```text
monitoring-demo/
├── app/
├── prometheus/
└── docker-compose.yml
```

---

# PART 2 — Express Application

The source creates a simple Express server on **port 8000** with:

```text
GET /
GET /slow
GET /metrics
```

The `/slow` endpoint intentionally performs a slow/heavy operation and can sometimes return an error, which makes it useful for demonstrating monitoring. 

---

## 2. Initialize Node.js

```bash
cd app
npm init -y
```

Install Express:

```bash
npm install express
```

Install Prometheus client:

```bash
npm install prom-client
```

Install logging packages:

```bash
npm install winston
```

If following the source's request-time middleware approach:

```bash
npm install response-time
```

---

# PART 3 — Express Application Code

Create:

```bash
vim app.js
```

Use:

```javascript
const express = require("express");
const client = require("prom-client");

const app = express();
const PORT = 8000;

// --------------------------------------------------
// Prometheus default metrics
// --------------------------------------------------

client.collectDefaultMetrics();

// --------------------------------------------------
// Custom request latency histogram
// --------------------------------------------------

const httpRequestDuration = new client.Histogram({
  name: "http_express_request_response_time",
  help: "Time taken by HTTP request and response",
  labelNames: ["method", "route", "status_code"],
  buckets: [1, 50, 100, 200, 400, 500, 800, 1000, 2000],
});

// --------------------------------------------------
// Request timing middleware
// --------------------------------------------------

app.use((req, res, next) => {
  const start = Date.now();

  res.on("finish", () => {
    const duration = Date.now() - start;

    httpRequestDuration
      .labels(
        req.method,
        req.originalUrl,
        res.statusCode
      )
      .observe(duration);
  });

  next();
});

// --------------------------------------------------
// Home
// --------------------------------------------------

app.get("/", (req, res) => {
  res.send("Hello from Express");
});

// --------------------------------------------------
// Slow endpoint
// --------------------------------------------------

app.get("/slow", async (req, res) => {
  try {
    const delay = Math.floor(Math.random() * 3000);

    await new Promise(resolve =>
      setTimeout(resolve, delay)
    );

    // Random error
    if (Math.random() < 0.2) {
      throw new Error("Random internal server error");
    }

    res.send(`Heavy task completed in ${delay} ms`);

  } catch (error) {
    res.status(500).send("Internal Server Error");
  }
});

// --------------------------------------------------
// Prometheus metrics endpoint
// --------------------------------------------------

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", client.register.contentType);

  const metrics = await client.register.metrics();

  res.send(metrics);
});

// --------------------------------------------------
// Start server
// --------------------------------------------------

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
```

The important Prometheus flow from the source is:

```text
prom-client
     ↓
collectDefaultMetrics()
     ↓
register
     ↓
/metrics
     ↓
Prometheus scrapes it
```

The source explicitly describes installing `prom-client`, initializing it, collecting default metrics and exposing those metrics through a `/metrics` endpoint.  

---

# PART 4 — Run Express

From:

```bash
cd app
```

Run:

```bash
node app.js
```

Expected:

```text
Server running on port 8000
```

---

# 5. Test Application

Open:

```bash
curl http://localhost:8000/
```

Expected:

```text
Hello from Express
```

Test slow endpoint:

```bash
curl http://localhost:8000/slow
```

Example:

```text
Heavy task completed in 1250 ms
```

Run repeatedly:

```bash
for i in {1..20}; do
    curl http://localhost:8000/slow
    echo
done
```

Because the source's `/slow` endpoint intentionally varies response time and sometimes produces errors, it provides data for demonstrating latency and error monitoring. 

---

# PART 5 — Verify `/metrics`

This is the most important step.

Run:

```bash
curl http://localhost:8000/metrics
```

You'll see Prometheus-format data similar to:

```text
# HELP process_cpu_user_seconds_total Total user CPU time spent in seconds.
# TYPE process_cpu_user_seconds_total counter
process_cpu_user_seconds_total 2.31

# HELP process_resident_memory_bytes Resident memory size in bytes.
# TYPE process_resident_memory_bytes gauge
process_resident_memory_bytes 12345678
```

You will also eventually see your custom metric:

```text
http_express_request_response_time_bucket{...}
```

The source demonstrates that `/metrics` exposes CPU, memory and Node.js runtime metrics and that the values change as the application runs. 

---

# PART 6 — Prometheus

Now we need the Prometheus server.

The flow is:

```text
Express
   │
   │ /metrics
   ▼
Prometheus
```

Prometheus periodically **scrapes/pulls** metrics from the application. The source uses a scrape interval of four seconds in the demonstration. 

---

# 6. Create Prometheus Configuration

```bash
cd ../prometheus
vim prometheus.yml
```

Use:

```yaml
global:
  scrape_interval: 4s

scrape_configs:

  - job_name: "express"

    static_configs:
      - targets:
          - "host.docker.internal:8000"
```

### Meaning

```yaml
scrape_interval: 4s
```

Prometheus asks for metrics every four seconds.

```yaml
job_name: "express"
```

Identifies the target.

```yaml
targets:
  - "host.docker.internal:8000"
```

Means:

```text
Prometheus
    ↓
http://host.docker.internal:8000/metrics
```

---

# 7. Important Docker Networking Point

This is one of the most important concepts in the tutorial.

If Prometheus runs inside Docker:

```text
Prometheus container
       |
       | localhost:8000 ❌
       |
       X
```

`localhost` means **the Prometheus container itself**, not your host.

Therefore, for Docker Desktop:

```text
host.docker.internal:8000
```

For Linux Docker environments, you can instead use the host gateway:

```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```

or put your application and Prometheus into the same Docker Compose network and use:

```text
app:8000
```

The source specifically points out that the host address cannot simply be `localhost` when Prometheus itself is running inside Docker. 

---

# PART 7 — Docker Compose

Create:

```bash
cd ..
vim docker-compose.yml
```

Use:

```yaml
services:

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus

    ports:
      - "9090:9090"

    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro

    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Start:

```bash
docker compose up -d
```

The source uses Docker Compose to run Prometheus and mounts the Prometheus configuration into the container. 

---

# 8. Check Prometheus

```bash
docker ps
```

You should see:

```text
prometheus
```

Check logs:

```bash
docker logs prometheus
```

Follow:

```bash
docker logs -f prometheus
```

---

# 9. Open Prometheus

Open:

```text
http://localhost:9090
```

Prometheus UI:

```text
Status
   ↓
Targets
```

You should see:

```text
express
   UP
```

This means:

```text
Prometheus
    |
    | scrape
    ↓
Express /metrics
```

---

# 10. Verify Target Directly

Inside the Prometheus container:

```bash
docker exec prometheus wget -qO- \
http://host.docker.internal:8000/metrics
```

If that returns metrics, networking works.

---

# PART 8 — Prometheus Queries

Go to:

```text
http://localhost:9090
```

Click:

```text
Graph
```

Try:

```promql
process_cpu_user_seconds_total
```

Then:

```promql
process_resident_memory_bytes
```

You can also query:

```promql
process_start_time_seconds
```

The source demonstrates querying CPU-related metrics and watching the values change automatically as Prometheus collects new samples. 

---

# PART 9 — Grafana

Now:

```text
Prometheus
      ↓
   Grafana
```

Grafana doesn't collect the metrics itself.

It queries Prometheus and creates:

```text
Charts
Graphs
Gauges
Tables
Dashboards
```

The source describes exactly this flow: Prometheus collects/scrapes the metrics, while Grafana uses Prometheus to create visualizations. 

---

# 11. Run Grafana

Add Grafana to:

```text
docker-compose.yml
```

Complete file:

```yaml
services:

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus

    ports:
      - "9090:9090"

    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro

    extra_hosts:
      - "host.docker.internal:host-gateway"


  grafana:
    image: grafana/grafana:latest
    container_name: grafana

    ports:
      - "3000:3000"

    depends_on:
      - prometheus

    volumes:
      - grafana-data:/var/lib/grafana


volumes:
  grafana-data:
```

Run:

```bash
docker compose up -d
```

Check:

```bash
docker ps
```

You should now have:

```text
express
prometheus
grafana
```

---

# 12. Open Grafana

Open:

```text
http://localhost:3000
```

Default credentials for a fresh Grafana installation are commonly:

```text
username: admin
password: admin
```

Then change the password when prompted.

The source demonstrates Grafana running on port `3000` and configuring the initial login. 

---

# PART 10 — Connect Grafana to Prometheus

In Grafana:

```text
Connections
       ↓
Data sources
       ↓
Add data source
       ↓
Prometheus
```

Set URL.

Because both are in the same Compose network:

```text
http://prometheus:9090
```

**Do not use:**

```text
http://localhost:9090
```

when Grafana is itself inside a container.

Click:

```text
Save & Test
```

You should get:

```text
Successfully queried the Prometheus API
```

The source demonstrates adding Prometheus as the Grafana data source and testing the connection. 

---

# PART 11 — Create Grafana Dashboard

Go:

```text
Dashboards
   ↓
New
   ↓
New Dashboard
   ↓
Add visualization
```

Select:

```text
Prometheus
```

Now query:

```promql
process_cpu_user_seconds_total
```

Choose:

```text
Time series
```

Click:

```text
Run queries
```

You should get a CPU-related graph.

The source follows this same process: create a visualization, select Prometheus as the data source, choose a metric, and render the chart. 

---

# PART 12 — CPU Dashboard

Use:

```promql
process_cpu_user_seconds_total
```

Visualization:

```text
Time series
```

---

# PART 13 — Memory Dashboard

Use:

```promql
process_resident_memory_bytes
```

Visualization:

```text
Time series
```

---

# PART 14 — Process Start Time

```promql
process_start_time_seconds
```

---

# PART 15 — Active Requests

If you create/use an appropriate active-request metric, visualize it in Grafana.

The source demonstrates exploring available metrics such as active resources and active requests from the Prometheus metrics endpoint. 

---

# PART 16 — Import an Existing Dashboard

Instead of manually creating every panel:

```text
Grafana
   ↓
Dashboards
   ↓
Import
```

Enter a Grafana dashboard ID.

Then:

```text
Load
   ↓
Select Prometheus
   ↓
Import
```

The source specifically demonstrates importing an existing Grafana dashboard instead of building every chart manually. 

---

# PART 17 — Custom Metrics

This is the **most important part for interviews**.

Default metrics tell you things like:

```text
CPU
Memory
Node.js process
Runtime
```

But your application may need:

```text
Request latency
Requests per endpoint
Error count
Database latency
Queue length
Business metrics
```

The source demonstrates creating a custom request-response-time histogram. 

---

# 17. Create Histogram

```javascript
const httpRequestDuration = new client.Histogram({
  name: "http_express_request_response_time",

  help: "Time taken by HTTP request and response",

  labelNames: [
    "method",
    "route",
    "status_code"
  ],

  buckets: [
    1,
    50,
    100,
    200,
    400,
    500,
    800,
    1000,
    2000
  ]
});
```

---

# 18. What Is a Histogram?

Imagine requests take:

```text
20 ms
40 ms
80 ms
150 ms
500 ms
900 ms
2000 ms
```

We put them into buckets:

```text
≤ 1ms
≤ 50ms
≤ 100ms
≤ 200ms
≤ 400ms
≤ 500ms
≤ 800ms
≤ 1000ms
≤ 2000ms
```

This allows Prometheus to understand the distribution of request latency.

---

# 19. Add Labels

The source uses labels for:

```text
method
route
status_code
```

So Prometheus can distinguish:

```text
GET / 200
GET /slow 200
GET /slow 500
```

Conceptually:

```text
http_express_request_response_time
          |
          +── method
          +── route
          +── status_code
```

---

# 20. Observe Request Time

Middleware:

```javascript
app.use((req, res, next) => {

  const start = Date.now();

  res.on("finish", () => {

    const duration = Date.now() - start;

    httpRequestDuration
      .labels(
        req.method,
        req.originalUrl,
        res.statusCode
      )
      .observe(duration);

  });

  next();
});
```

Now every request gets measured.

Example:

```text
GET /slow
     ↓
start timer
     ↓
application processing
     ↓
response
     ↓
500ms
     ↓
Prometheus histogram
```

---

# PART 18 — Query Custom Metric

After generating traffic:

```bash
for i in {1..50}; do
    curl -s http://localhost:8000/slow
    echo
done
```

Check:

```bash
curl http://localhost:8000/metrics | grep http_express
```

You'll see metrics such as:

```text
http_express_request_response_time_bucket
http_express_request_response_time_sum
http_express_request_response_time_count
```

The source demonstrates that a histogram generates bucket, count and sum-related series. 

---

# PART 19 — Prometheus Query for Routes

You can filter by route.

For example:

```promql
http_express_request_response_time_bucket{
  route="/slow"
}
```

Or:

```promql
http_express_request_response_time_bucket{
  route="/"
}
```

Now you can see which route has the latency problem.

---

# PART 20 — Calculate Latency

A useful PromQL query for histogram latency is:

```promql
rate(
  http_express_request_response_time_sum[5m]
)
/
rate(
  http_express_request_response_time_count[5m]
)
```

This gives an approximate average request duration over the selected window.

---

# PART 21 — 95th Percentile Latency

For a histogram:

```promql
histogram_quantile(
  0.95,
  sum(
    rate(
      http_express_request_response_time_bucket[5m]
    )
  ) by (le)
)
```

For route-level analysis:

```promql
histogram_quantile(
  0.95,
  sum(
    rate(
      http_express_request_response_time_bucket[5m]
    )
  ) by (le, route)
)
```

This lets you answer:

> "What is the p95 latency for each route?"

---

# PART 22 — Why This Is Useful

Suppose:

```text
GET /
p95 = 10 ms

GET /slow
p95 = 2.5 sec
```

Now you immediately know:

```text
/slow
   ↓
problematic endpoint
   ↓
investigate database/API/heavy computation
```

This is the real purpose of application monitoring.

---

# PART 23 — Generate Load

Use:

```bash
while true; do
    curl -s http://localhost:8000/ > /dev/null
    curl -s http://localhost:8000/slow > /dev/null
    sleep 1
done
```

Stop:

```text
Ctrl+C
```

Or generate parallel traffic:

```bash
for i in {1..100}; do
    curl -s http://localhost:8000/slow > /dev/null &
done

wait
```

Now Grafana will have more useful data.

---

# PART 24 — Logs

Metrics tell us:

```text
CPU increased
Latency increased
Error rate increased
```

But they don't necessarily tell us:

```text
WHY did the error happen?
```

That's where logs come in.

The source explicitly transitions from metrics to **log collection**, with the goal of centralizing logs from multiple services. 

---

# PART 25 — Winston Logging

Install:

```bash
npm install winston
```

Create:

```javascript
const winston = require("winston");

const logger = winston.createLogger({
  level: "info",

  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),

  transports: [
    new winston.transports.Console()
  ]
});
```

---

# PART 26 — Replace console.log

Instead of:

```javascript
console.log("Server started");
```

Use:

```javascript
logger.info("Server started");
```

For errors:

```javascript
logger.error("Internal server error");
```

For warnings:

```javascript
logger.warn("Slow request detected");
```

---

# PART 27 — Log Errors

Inside `/slow`:

```javascript
catch (error) {

  logger.error("Request failed", {
    error: error.message,
    route: req.originalUrl
  });

  res.status(500).send("Internal Server Error");
}
```

The source demonstrates capturing application errors and sending the error message through the logging mechanism. 

---

# PART 28 — Loki

Now:

```text
Express
   ↓
Winston
   ↓
Logs
   ↓
Promtail
   ↓
Loki
   ↓
Grafana
```

Loki becomes the centralized log storage/query system.

---

# PART 29 — Run Loki

Add Loki to `docker-compose.yml`:

```yaml
services:

  loki:
    image: grafana/loki:latest
    container_name: loki

    ports:
      - "3100:3100"

    command:
      - -config.file=/etc/loki/local-config.yaml

```

Start:

```bash
docker compose up -d
```

Check:

```bash
docker ps
```

Check:

```bash
docker logs loki
```

---

# PART 30 — Promtail

Promtail reads the logs and pushes them into Loki.

Create:

```bash
mkdir -p promtail
vim promtail/promtail-config.yml
```

Example:

```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:

  - job_name: express

    static_configs:
      - targets:
          - localhost

        labels:
          job: express
          application: express

          __path__: /var/log/express/*.log
```

---

# PART 31 — Log File

If you want Promtail to read a file rather than Docker stdout, configure Winston with a file transport.

```javascript
new winston.transports.File({
  filename: "/var/log/express/app.log"
})
```

Complete:

```javascript
const logger = winston.createLogger({

  level: "info",

  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),

  transports: [

    new winston.transports.Console(),

    new winston.transports.File({
      filename: "/var/log/express/app.log"
    })

  ]
});
```

Create directory:

```bash
sudo mkdir -p /var/log/express
```

Permissions must allow the Node process to write there.

---

# PART 32 — Promtail Reads the File

Promtail:

```yaml
__path__: /var/log/express/*.log
```

means:

```text
/var/log/express/
       |
       └── app.log
              |
              ▼
          Promtail
              |
              ▼
             Loki
```

---

# PART 33 — Grafana + Loki

Go to:

```text
Grafana
   ↓
Connections
   ↓
Data Sources
   ↓
Add data source
   ↓
Loki
```

Set:

```text
URL:
http://loki:3100
```

Click:

```text
Save & Test
```

The source shows the same pattern: after logs are pushed to Loki, Grafana is configured with Loki as a data source. 

---

# PART 34 — Explore Logs

Go:

```text
Explore
```

Select:

```text
Loki
```

Query:

```logql
{job="express"}
```

You should see your application logs.

---

# PART 35 — Filter Errors

```logql
{job="express"} |= "error"
```

Or:

```logql
{job="express"} |= "Internal server error"
```

---

# PART 36 — Filter INFO

```logql
{job="express"} |= "info"
```

The source demonstrates creating separate visualizations for Express logs and filtering based on log level such as `info` and `error`. 

---

# PART 37 — Final Grafana Dashboard

Now you can create one dashboard containing:

```text
┌────────────────────────────────────────────┐
│           EXPRESS MONITORING               │
├──────────────────────┬─────────────────────┤
│ CPU                  │ Memory              │
│ Time Series          │ Gauge               │
├──────────────────────┼─────────────────────┤
│ Request Rate         │ Error Rate          │
│ Time Series          │ Time Series         │
├──────────────────────┴─────────────────────┤
│              Request Latency               │
│                 Time Series                │
├────────────────────────────────────────────┤
│              Application Logs              │
│                  Table                     │
└────────────────────────────────────────────┘
```

---

# PART 38 — The Most Important Flow

You should be able to explain this without looking at notes:

### Metrics

```text
Express
   ↓
prom-client
   ↓
/metrics
   ↓
Prometheus
   ↓
PromQL
   ↓
Grafana
```

### Logs

```text
Express
   ↓
Winston
   ↓
Log file/stdout
   ↓
Promtail
   ↓
Loki
   ↓
LogQL
   ↓
Grafana
```

---

# PART 39 — What Each Component Does

| Component     | Responsibility                     |
| ------------- | ---------------------------------- |
| Express       | Application                        |
| `prom-client` | Creates/exposes Prometheus metrics |
| `/metrics`    | Metrics endpoint                   |
| Prometheus    | Scrapes/stores metrics             |
| PromQL        | Queries metrics                    |
| Winston       | Application logging                |
| Promtail      | Collects/pushes logs               |
| Loki          | Stores/query logs                  |
| LogQL         | Queries logs                       |
| Grafana       | Visualization/dashboard            |

---

# PART 40 — Complete Docker Compose

For a clean lab, you can bring the infrastructure together:

```yaml
services:

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus

    ports:
      - "9090:9090"

    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro

    extra_hosts:
      - "host.docker.internal:host-gateway"


  loki:
    image: grafana/loki:latest
    container_name: loki

    ports:
      - "3100:3100"

    command:
      - -config.file=/etc/loki/local-config.yaml


  grafana:
    image: grafana/grafana:latest
    container_name: grafana

    ports:
      - "3000:3000"

    depends_on:
      - prometheus
      - loki

    volumes:
      - grafana-data:/var/lib/grafana


volumes:

  grafana-data:
```

Start everything:

```bash
docker compose up -d
```

Check:

```bash
docker compose ps
```

---

# PART 41 — Complete Verification

## Application

```bash
curl http://localhost:8000/
```

```bash
curl http://localhost:8000/slow
```

```bash
curl http://localhost:8000/metrics
```

---

## Prometheus

```bash
curl http://localhost:9090/-/healthy
```

Check:

```text
http://localhost:9090/targets
```

Target should be:

```text
UP
```

---

## Loki

```bash
curl http://localhost:3100/ready
```

Expected:

```text
ready
```

---

## Grafana

Open:

```text
http://localhost:3000
```

---

# PART 42 — Troubleshooting

### Prometheus target DOWN

Check:

```bash
docker logs prometheus
```

Then:

```bash
docker exec prometheus \
wget -qO- http://host.docker.internal:8000/metrics
```

Also check:

```bash
curl http://localhost:8000/metrics
```

---

### `/metrics` returns 404

Check Express:

```bash
curl http://localhost:8000/metrics
```

Verify:

```javascript
app.get("/metrics", ...)
```

---

### Grafana cannot connect to Prometheus

Inside Grafana's container:

```bash
docker exec -it grafana sh
```

Then:

```bash
wget -qO- http://prometheus:9090/-/healthy
```

---

### Grafana cannot connect to Loki

```bash
docker exec -it grafana sh
```

Then:

```bash
wget -qO- http://loki:3100/ready
```

---

### Promtail cannot send logs

Check:

```bash
docker logs promtail
```

Check Loki:

```bash
docker logs loki
```

---

# PART 43 — Interview Explanation

If they ask:

### "How did you implement monitoring?"

Say:

> I implemented centralized application monitoring using Prometheus and Grafana for metrics and Loki with Promtail for logs. The Express application uses the Prometheus Node.js client to expose default runtime metrics and custom application metrics through a `/metrics` endpoint. Prometheus periodically scrapes that endpoint and stores the time-series data. Grafana connects to Prometheus and visualizes metrics such as CPU, memory, request latency and application-specific metrics.
>
> For logs, the application generates structured logs, which are collected by Promtail and pushed to Loki. Grafana is also configured with Loki as a data source, allowing us to search and visualize application errors and informational logs using LogQL.

That matches the monitoring architecture and implementation described in your source. 

---

# PART 44 — The Problem → Solution

This is the key story behind the whole tutorial.

### Without monitoring

```text
Customer
   ↓
"My application was slow last night."
   ↓
Developer
   ↓
"What happened?"
   ↓
No metrics
No logs
No history
   ↓
Cannot determine root cause
```

The source's scenario specifically describes a customer reporting slow responses/errors after the fact, while the developer has no way to determine what happened during the incident. 

### With monitoring

```text
Customer
   ↓
"Application was slow."
   ↓
Developer
   ↓
Grafana
   ├── CPU
   ├── Memory
   ├── Request rate
   ├── Error rate
   ├── Request latency
   └── Logs
          ↓
       Loki
```

Then:

```text
Latency ↑
     ↓
/slow endpoint
     ↓
Error logs
     ↓
Root cause investigation
```

**This is the main thing you should understand, not just memorize the commands.** The source's goal is precisely to build a central monitoring system capable of tracking server/service health, latency, memory, CPU, errors and logs over time. 

### Final architecture to memorize

```text
                         ┌──────────────────┐
                         │  Express App     │
                         │    :8000         │
                         └────────┬─────────┘
                                  │
             ┌────────────────────┴───────────────────┐
             │                                        │
             │ METRICS                                │ LOGS
             ▼                                        ▼
       ┌─────────────┐                         ┌─────────────┐
       │ prom-client │                         │   Winston   │
       └──────┬──────┘                         └──────┬──────┘
              │                                       │
              │ /metrics                              │
              ▼                                       ▼
       ┌─────────────┐                         ┌─────────────┐
       │ Prometheus  │                         │  Promtail   │
       │    :9090    │                         └──────┬──────┘
       └──────┬──────┘                                │
              │                                       ▼
              │                                ┌─────────────┐
              │                                │    Loki     │
              │                                │    :3100    │
              │                                └──────┬──────┘
              │                                       │
              └────────────────┬──────────────────────┘
                               ▼
                       ┌─────────────────┐
                       │     Grafana     │
                       │      :3000      │
                       └─────────────────┘
                               │
                               ▼
                       Dashboards / Alerts
```
