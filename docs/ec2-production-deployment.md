# EC2 Production Deployment

Use this when the repository is cloned on the EC2 instance.

## DNS

Create these DNS records at your DNS provider or in Route 53:

```text
openobserve.yourdomain.com -> EC2 public IPv4
phoenix.yourdomain.com     -> EC2 public IPv4
otel.yourdomain.com        -> EC2 public IPv4
```

Use `A` records for a fixed Elastic IP. If you use an AWS load balancer later, use `CNAME` or Route 53 alias records.

## Security Group

Inbound rules:

```text
22/tcp   from your IP only
80/tcp   from 0.0.0.0/0 and ::/0
443/tcp  from 0.0.0.0/0 and ::/0
```

Do not expose these publicly:

```text
4317
4318
5080
5081
5432
6006
```

The production `.env` binds raw OTLP ports to `127.0.0.1`; public app ingestion should use:

```text
https://otel.yourdomain.com
```

## Buckets

Recommended buckets:

```text
your-observability-backup-bucket
your-openobserve-data-bucket
```

Use one bucket with separate prefixes if you prefer:

```text
s3://your-observability-bucket/backups
s3://your-observability-bucket/openobserve
```

For backups, set:

```env
AWS_S3_BACKUP_URI=s3://your-observability-backup-bucket/observability
```

For optional OpenObserve S3 stream storage, set:

```env
OPENOBSERVE_S3_PROVIDER=aws
OPENOBSERVE_S3_BUCKET_NAME=your-openobserve-data-bucket
OPENOBSERVE_S3_REGION_NAME=ap-south-1
```

Keep Block Public Access enabled on all buckets. Enable versioning and default encryption.

## IAM Role

Attach an instance profile to the EC2 instance. Do not put AWS access keys in `.env`.

Minimum policy when using separate buckets:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BackupBucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::your-observability-backup-bucket"
    },
    {
      "Sid": "BackupObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::your-observability-backup-bucket/observability/*"
    },
    {
      "Sid": "OpenObserveBucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::your-openobserve-data-bucket"
    },
    {
      "Sid": "OpenObserveObjectAccess",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:AbortMultipartUpload",
        "s3:ListMultipartUploadParts"
      ],
      "Resource": "arn:aws:s3:::your-openobserve-data-bucket/*"
    }
  ]
}
```

If you only use S3 for backups and keep OpenObserve on EBS, omit the OpenObserve statements.

## Prepare `.env`

On EC2:

```sh
cp .env.production.example .env
nano .env
```

Generate secrets:

```sh
openssl rand -hex 32
openssl rand -base64 24
```

Generate the OpenObserve auth header:

```sh
printf '%s' 'admin@yourdomain.com:YOUR_OPENOBSERVE_PASSWORD' | base64 -w 0
```

Generate the Collector ingest password hash:

```sh
docker run --rm httpd:2.4-alpine htpasswd -nbB otel_ingest 'YOUR_INGEST_PASSWORD'
```

In `.env`, escape every `$` in the htpasswd output as `$$`.

Also generate the application header for projects:

```sh
printf '%s' 'otel_ingest:YOUR_INGEST_PASSWORD' | base64 -w 0
```

Projects will use:

```env
OTEL_EXPORTER_OTLP_ENDPOINT=https://otel.yourdomain.com
OTEL_EXPORTER_OTLP_HEADERS=Authorization=Basic GENERATED_VALUE
```

## Pull And Start

Local EBS-backed OpenObserve:

```sh
docker compose pull
docker compose up -d
docker compose ps
```

OpenObserve with S3 stream storage:

```sh
docker compose -f docker-compose.yml -f docker-compose.s3.yml pull
docker compose -f docker-compose.yml -f docker-compose.s3.yml up -d
docker compose -f docker-compose.yml -f docker-compose.s3.yml ps
```

## Verify

Check Caddy got certificates:

```sh
docker compose logs -f caddy
```

Open:

```text
https://openobserve.yourdomain.com
https://phoenix.yourdomain.com
```

Test Collector auth:

```sh
curl -i https://otel.yourdomain.com/v1/traces
```

Expected without auth:

```text
401 Unauthorized
```

After Phoenix starts, log in and create a system API key:

```text
Phoenix -> Settings -> API Keys -> System API Key
```

Put it into `.env`:

```env
PHOENIX_API_KEY=...
```

Restart the Collector:

```sh
docker compose up -d otel-collector
```

## Backups

Install AWS CLI if needed:

```sh
sudo apt-get update
sudo apt-get install -y awscli
```

Run a backup:

```sh
./scripts/backup-s3.sh
```

Cron:

```cron
15 2 * * * cd /path/to/observability && ./scripts/backup-s3.sh >> ./backups/backup.log 2>&1
```

## Service Commands

```sh
docker compose ps
docker compose logs -f caddy
docker compose logs -f openobserve
docker compose logs -f phoenix
docker compose logs -f otel-collector
docker compose restart otel-collector
```
