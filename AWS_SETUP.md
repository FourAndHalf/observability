# AWS Setup Guide for Observability Stack

This guide outlines the infrastructure and configuration steps required to host the observability project on AWS.

## 1. Create Storage (S3)
*   **Project:** S3 Bucket for Backups.
*   **Steps:**
    1.  Log in to the S3 Console.
    2.  Create a new bucket (e.g., `my-company-observability-backups`).
    3.  **Security:** Ensure "Block all public access" is turned ON.
    4.  **Optimization:** Enable "Bucket Versioning" to protect against accidental deletion of backups.
    5.  **Lifecycle:** (Optional) Add a lifecycle rule to transition backups to "S3 Glacier" or delete them after 90 days.

## 2. Configure Identity & Access (IAM)
*   **Project:** IAM Instance Profile.
*   **Steps:**
    1.  Go to the IAM Console -> **Policies** -> **Create Policy**.
    2.  Paste the following JSON (replace `your-bucket-name` with your actual bucket):
        ```json
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": ["s3:PutObject", "s3:ListBucket", "s3:GetBucketLocation", "s3:GetObject"],
              "Resource": [
                "arn:aws:s3:::your-bucket-name",
                "arn:aws:s3:::your-bucket-name/*"
              ]
            }
          ]
        }
        ```
    3.  Name it `ObservabilityBackupPolicy`.
    4.  Go to **Roles** -> **Create Role**.
    5.  Select **AWS Service** -> **EC2**.
    6.  Attach the `ObservabilityBackupPolicy` you just created.
    7.  Name the role `ObservabilityEC2Role`.

## 3. Set Up Networking (VPC & Security Groups)
*   **Project:** Security Group.
*   **Steps:**
    1.  Go to EC2 Console -> **Security Groups** -> **Create Security Group**.
    2.  Add **Inbound Rules**:
        *   `SSH (22)`: Source: `My IP`.
        *   `HTTP (80)`: Source: `0.0.0.0/0` (For Caddy/SSL).
        *   `HTTPS (443)`: Source: `0.0.0.0/0` (For UI and OTLP).
    3.  Outbound Rules: Keep the default "Allow all".

## 4. Launch Compute (EC2 & EBS)
*   **Project:** EC2 Instance.
*   **Steps:**
    1.  Launch an Instance:
        *   **AMI:** Ubuntu 22.04 LTS or 24.04 LTS.
        *   **Instance Type:** `t3.medium` (2 vCPU, 4GB RAM) or `t3.large` (8GB RAM) for production.
        *   **IAM Instance Profile:** Select `ObservabilityEC2Role`.
    2.  **Storage (EBS):**
        *   Edit the storage settings.
        *   Ensure the Root volume is **gp3**.
        *   Set size to at least **20GB** (OpenObserve and Postgres data will live here).
    3.  Select the Security Group created in Step 3.

## 5. Configure DNS (Route 53)
*   **Project:** DNS Records.
*   **Steps:**
    1.  Go to Route 53 or your DNS provider.
    2.  Create three **A Records** pointing to your EC2 Public IP:
        *   `openobserve.yourdomain.com`
        *   `phoenix.yourdomain.com`
        *   `otel.yourdomain.com`

## 6. Server Initialization
*   **Steps:**
    1.  SSH into your EC2 instance.
    2.  Install Docker and Docker Compose:
        ```bash
        sudo apt-get update
        sudo apt install docker.io docker-compose-v2 -y
        sudo usermod -aG docker $USER && newgrp docker
        ```
    3.  Clone this repository.
    4.  Create and fill your `.env` file based on the `README.md`.
    5.  Run the stack:
        ```bash
        docker compose up -d
        ```
    6.  Verify S3 connectivity by running the backup script manually:
        ```bash
        ./scripts/backup-s3.sh
        ```
