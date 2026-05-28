# Self-Hosted Observability Stack

This project runs a reusable observability platform for all of your projects.

It uses:

- OpenTelemetry Collector as the single ingestion endpoint for every app.
- OpenObserve for logs, metrics, traces, dashboards, alerts, and general APM.
- Phoenix for LLM, RAG, agent, prompt, dataset, and evaluation observability.
- PostgreSQL for durable Phoenix storage.
- Caddy as the reverse proxy and TLS endpoint for browser access and OTLP HTTP ingestion.
- Local and S3 backup scripts for disaster recovery.

The important design decision is that your applications talk to OpenTelemetry, not to OpenObserve or Phoenix directly. This keeps your projects portable if you later replace or add backends.

## Architecture

```text
Application services
  -> OpenTelemetry SDK / auto-instrumentation
  -> OTLP HTTP or gRPC
  -> OpenTelemetry Collector
      -> OpenObserve for logs, metrics, traces
      -> Phoenix for LLM traces

Browser users
  -> Caddy HTTPS reverse proxy
      -> OpenObserve UI
      -> Phoenix UI
```

Default exposed endpoints:

| Purpose | Endpoint |
| --- | --- |
| OpenObserve UI | `https://openobserve.example.com` |
| Phoenix UI | `https://phoenix.example.com` |
| OTLP HTTP ingest | `https://otel.example.com` |
| Raw OTLP HTTP ingest | `http://host:4318` |
| Raw OTLP gRPC ingest | `http://host:4317`, bound to localhost by default |

For production and EC2, prefer `https://otel.example.com` over raw `4318`.

## Files

| File | Purpose |
| --- | --- |
| `docker-compose.yml` | Runs OpenObserve, Phoenix, PostgreSQL, Collector, and Caddy. |
| `config/otel-collector.yaml` | Receives OTLP and exports telemetry to OpenObserve and Phoenix. |
| `caddy/Caddyfile` | Routes public HTTPS hostnames to the internal services. |
| `.env.example` | Template for credentials, domains, stream names, and backup settings. |
| `scripts/backup-local.sh` | Creates local backups of OpenObserve data, Phoenix PostgreSQL, config, and `.env`. |
| `scripts/backup-s3.sh` | Creates a local backup, then syncs it to S3 with server-side encryption. |
| `scripts/restore-local.sh` | Restores OpenObserve data and Phoenix PostgreSQL from a local backup folder. |

## Initial Setup

1. Copy the environment template:

   ```sh
   cp .env.example .env
   ```

2. Edit `.env` and replace every `change-me` and `replace` value.

3. Generate the OpenObserve auth header:

   ```sh
   printf '%s' 'admin@example.com:your-openobserve-password' | base64
   ```

   Put the result into `.env` like this:

   ```env
   OPENOBSERVE_AUTH_HEADER=Basic pasted_base64_value
   ```

4. Generate the Collector ingest password hash:

   ```sh
   docker run --rm httpd:2.4-alpine htpasswd -nbB otel_ingest 'your-ingest-password'
   ```

   Put the entire output into `.env`, but escape every `$` as `$$` because Docker Compose treats `$` as interpolation syntax:

   ```env
   OTEL_COLLECTOR_HTPASSWD=otel_ingest:$$2y$$05$$...
   ```

5. Generate a Phoenix secret:

   ```sh
   openssl rand -hex 32
   ```

   Put it into:

   ```env
   PHOENIX_SECRET=generated_value
   ```

6. Start the stack:

   ```sh
   docker compose up -d
   ```

7. Open Phoenix, log in as the initial admin, then create a system API key:

   ```text
   Email: admin@localhost
   Password: PHOENIX_DEFAULT_ADMIN_INITIAL_PASSWORD from .env
   Phoenix UI -> Settings -> API Keys -> System API Key
   ```

8. Add that key to `.env`:

   ```env
   PHOENIX_API_KEY=your_system_api_key
   ```

9. Restart the Collector:

   ```sh
   docker compose up -d otel-collector
   ```

Until `PHOENIX_API_KEY` is set, OpenObserve can receive traces, logs, and metrics, but Phoenix export will fail authentication.

## Local Development

For local-only development without DNS:

1. Set these in `.env`:

   ```env
   OPENOBSERVE_SITE=http://openobserve.local
   PHOENIX_SITE=http://phoenix.local
   OTEL_SITE=http://otel.local
   ```

2. Add these to `/etc/hosts` on this machine:

   ```text
   127.0.0.1 openobserve.local
   127.0.0.1 phoenix.local
   127.0.0.1 otel.local
   ```

3. For other devices on the LAN, add the same names to their hosts files, but point them to this machine's LAN IP:

   ```text
   192.168.x.x openobserve.local
   192.168.x.x phoenix.local
   192.168.x.x otel.local
   ```

4. Use these local endpoints:

   ```text
   OpenObserve: http://openobserve.local:8080
   Phoenix: http://phoenix.local:8080
   Collector HTTP: http://otel.local:8080
   Collector HTTP: http://localhost:4318
   Collector gRPC: http://localhost:4317
   ```

For EC2 production, set `HTTP_BIND=80` and `HTTPS_BIND=443`.

The Compose file intentionally does not expose OpenObserve or Phoenix directly. Caddy is the browser entry point. If you want raw local UI ports during development, temporarily add `ports` to the relevant services.

## EC2 Deployment

Recommended EC2 shape for a small team:

- Ubuntu LTS.
- Docker Engine and Docker Compose plugin.
- At least 2 vCPU, 4 GB RAM for light use.
- 8 GB RAM or more if you ingest many logs/traces.
- EBS gp3 volume mounted where this repo lives.
- Security group allowing:
  - `22/tcp` from your IP only.
  - `80/tcp` and `443/tcp` from users/apps that need access.
  - Do not expose `5080`, `6006`, `5432`, or raw `4317` publicly.
  - Expose raw `4318` only if you cannot use Caddy/TLS.

DNS should point these names to the EC2 public IP or load balancer:

```text
openobserve.example.com
phoenix.example.com
otel.example.com
```

Caddy will request TLS certificates automatically when the domains resolve correctly and ports 80/443 are reachable.

## Sending Telemetry From Projects

Every app should send to the Collector, not directly to OpenObserve or Phoenix.

For OTLP HTTP:

```env
OTEL_SERVICE_NAME=my-service
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.example.com
OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic base64_of_otel_ingest_colon_password
OTEL_TRACES_EXPORTER=otlp
OTEL_METRICS_EXPORTER=otlp
OTEL_LOGS_EXPORTER=otlp
```

For local raw HTTP:

```env
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic base64_of_otel_ingest_colon_password
```

The Basic header for applications is not the `htpasswd` hash. It is the base64 value of:

```text
otel_ingest:your-ingest-password
```

Generate it with:

```sh
printf '%s' 'otel_ingest:your-ingest-password' | base64
```

## Trace ID Correlation

The Collector forwards the same trace to both backends. That means a trace ID created by your app should be searchable in both OpenObserve and Phoenix.

Use the same OpenTelemetry trace context across normal application spans and LLM spans:

- Do not create separate root traces for LLM calls if they are part of a request.
- Let OpenInference, LangChain, LlamaIndex, OpenAI SDK instrumentation, or your manual spans run under the active request context.
- Include `service.name`, `deployment.environment`, `service.version`, and important domain identifiers like `tenant.id`, `user.id`, `request.id`, or `conversation.id` where allowed by your privacy policy.

In OpenObserve, use the trace view for request-level debugging and the logs view for log-to-trace correlation. In Phoenix, use the same trace ID to inspect LLM call inputs, outputs, tool calls, retrieval steps, and evaluations.

## Security Model

### Browser Access

OpenObserve has its own login controlled by:

```env
OPENOBSERVE_ROOT_EMAIL
OPENOBSERVE_ROOT_PASSWORD
OPENOBSERVE_RETENTION_DAYS
```

Phoenix auth is enabled with:

```env
PHOENIX_ENABLE_AUTH=True
PHOENIX_SECRET
PHOENIX_DEFAULT_ADMIN_INITIAL_PASSWORD
PHOENIX_RETENTION_DAYS
```

After the first Phoenix startup, changing `PHOENIX_DEFAULT_ADMIN_INITIAL_PASSWORD` does not reset the admin password. Change it inside Phoenix or follow Phoenix admin password reset procedures.

### Ingestion Access

The Collector requires Basic auth before accepting OTLP data:

```env
OTEL_COLLECTOR_HTPASSWD=otel_ingest:hashed_password
```

Applications send:

```text
Authorization: Basic base64(otel_ingest:plain_password)
```

Do not expose OpenObserve ingestion credentials to applications. Only the Collector should know `OPENOBSERVE_AUTH_HEADER`.

### Network Rules

Use these rules in production:

- Expose only Caddy on ports 80 and 443.
- Keep PostgreSQL internal to Docker.
- Keep OpenObserve and Phoenix internal to Docker.
- Keep raw Collector gRPC bound to localhost unless you explicitly need it remotely.
- Prefer OTLP HTTP over HTTPS through Caddy for remote services.
- Restrict SSH to your IP address.
- Use AWS Security Groups, OS firewall rules, or both.

### Secrets

Do not commit `.env`. It contains:

- OpenObserve admin password.
- OpenObserve ingestion auth header.
- Phoenix PostgreSQL password.
- Phoenix JWT signing secret.
- Phoenix admin bootstrap password.
- Phoenix API key.
- Collector ingest hash.

For EC2, store a second encrypted copy in AWS Systems Manager Parameter Store, Secrets Manager, or an encrypted S3 location.

## Data Storage

OpenObserve stores local data under:

```text
./data/openobserve
```

Phoenix stores durable data in PostgreSQL under:

```text
./data/phoenix-postgres
```

Caddy stores TLS certificates under:

```text
./data/caddy
```

Do not delete `./data` unless you are intentionally resetting the stack.

## Retention

The stack defaults to a 30-day retention cap for both systems:

```env
OPENOBSERVE_RETENTION_DAYS=30
PHOENIX_RETENTION_DAYS=30
```

OpenObserve uses its compaction retention policy to delete older stream data. Phoenix uses its default project retention policy so new projects inherit the 30-day cap unless you override them in the UI.

## Backups

Backups include:

- OpenObserve local data directory.
- Phoenix PostgreSQL dump.
- Runtime config and `.env`.

Run a local backup:

```sh
./scripts/backup-local.sh
```

The backup is written to:

```text
./backups/YYYYMMDDTHHMMSSZ
```

Run an S3 backup:

```sh
./scripts/backup-s3.sh
```

Configure S3 in `.env`:

```env
AWS_S3_BACKUP_URI=s3://your-bucket/observability
AWS_PROFILE=default
```

The S3 script uses:

```text
aws s3 sync ... --sse AES256
```

For stronger control, enable bucket versioning, default encryption with KMS, lifecycle retention, and restricted IAM permissions.

Minimum IAM permissions for backup upload:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:ListBucket", "s3:GetBucketLocation"],
      "Resource": [
        "arn:aws:s3:::your-bucket",
        "arn:aws:s3:::your-bucket/observability/*"
      ]
    }
  ]
}
```

For restore from S3, add `s3:GetObject`.

## Backup Schedule

For a local server:

```cron
15 2 * * * cd /path/to/observability && ./scripts/backup-local.sh >> ./backups/backup.log 2>&1
```

For EC2 with S3:

```cron
15 2 * * * cd /path/to/observability && ./scripts/backup-s3.sh >> ./backups/backup.log 2>&1
```

Recommended retention:

- Local: 7 to 14 daily backups.
- S3: 30 to 90 daily backups.
- Monthly archive: 6 to 12 months if logs are business-critical.

## Restore

Restore from a local backup:

```sh
./scripts/restore-local.sh ./backups/YYYYMMDDTHHMMSSZ
```

The restore process:

1. Stops Collector, Phoenix, and OpenObserve.
2. Replaces `data/openobserve` from backup.
3. Recreates the Phoenix PostgreSQL database.
4. Restores the Phoenix dump.
5. Starts the stack again.

Always test restore on a separate machine or directory before trusting backups.

## Operations

Start:

```sh
docker compose up -d
```

Stop:

```sh
docker compose down
```

Restart one service:

```sh
docker compose restart otel-collector
```

View logs:

```sh
docker compose logs -f otel-collector
docker compose logs -f openobserve
docker compose logs -f phoenix
```

Upgrade images:

```sh
./scripts/backup-local.sh
docker compose pull
docker compose up -d
```

Do not upgrade without a fresh backup.

## Retention and Cost Control

Start conservative:

- Use sampling in applications for very high-volume traces.
- Avoid putting secrets, full prompts, full completions, access tokens, or private user data into spans.
- Use stable attributes with bounded cardinality.
- Avoid high-cardinality labels like raw URLs, full SQL queries, email addresses, or unbounded user text.
- Keep verbose debug logs out of production unless you are actively investigating.

Recommended attributes:

```text
service.name
service.version
deployment.environment
http.route
http.method
http.status_code
db.system
messaging.system
llm.model_name
llm.provider
openinference.span.kind
```

Use OpenObserve dashboards and alerts for service health. Use Phoenix projects and datasets for LLM workflows.

## LLM Observability Guidance

Phoenix is most useful when your LLM spans include:

- Model provider and model name.
- Prompt template or prompt identifier.
- Input/output token counts.
- Latency.
- Tool calls.
- Retrieval query.
- Retrieved document IDs and scores.
- Evaluation results.
- Error messages and retry counts.

Be careful with prompt and response payloads. If they may contain secrets, customer data, or personal data, redact them before export or only export metadata.

## Production Checklist

Before exposing this stack:

- Replace all placeholder secrets in `.env`.
- Confirm OpenObserve login works.
- Confirm Phoenix login works.
- Create Phoenix system API key and restart Collector.
- Confirm app telemetry reaches OpenObserve.
- Confirm LLM traces reach Phoenix.
- Confirm Caddy HTTPS certificates are issued.
- Confirm Security Group exposes only 80/443 and restricted SSH.
- Run `./scripts/backup-local.sh`.
- Run `./scripts/backup-s3.sh` on EC2.
- Test restore in a separate directory or host.
- Document who has admin access.
- Rotate ingestion credentials if a developer leaves or a project is compromised.

## References

- OpenObserve OTLP ingestion: https://openobserve.ai/docs/ingestion/logs/otlp/
- OpenObserve traces: https://openobserve.ai/docs/user-guide/data-exploration/traces/traces/
- Phoenix self-hosting: https://arize.com/docs/phoenix/self-hosting/deploying-phoenix
- Phoenix configuration: https://arize.com/docs/phoenix/self-hosting/configuration
- Phoenix authentication: https://arize.com/docs/phoenix/self-hosting/authentication
- OpenTelemetry Collector configuration: https://opentelemetry.io/docs/collector/configuration/
