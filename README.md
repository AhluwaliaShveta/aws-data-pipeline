# AWS Agriculture Data Pipeline

A serverless, event-driven weather data pipeline built on AWS. It collects weather observations for three fictional farms, keeps the original API responses in S3, transforms them into an analytics-ready format, and makes them queryable with Amazon Athena.

Infrastructure is managed with Terraform and deployed through GitHub Actions using OIDC, so no long-lived AWS access keys are stored anywhere.

**Stack:** Python, AWS Lambda, S3, EventBridge Scheduler, Glue Data Catalog, Athena, CloudWatch, SNS, Terraform, GitHub Actions

---

## Architecture

```
EventBridge Scheduler (hourly)
        ↓
Ingestion Lambda ──► Open-Meteo API
        ↓
S3  raw/            (original API responses)
        ↓  ObjectCreated event
Transformation Lambda
        ↓
S3  processed/      (flat, analytics-ready records)
        ↓
Glue Data Catalog
        ↓
Amazon Athena (SQL)

CloudWatch alarms ──► SNS ──► email alerts
```

### How it works

1. **Ingestion.** EventBridge Scheduler triggers the ingestion Lambda every hour. It fetches current weather (temperature, humidity, precipitation, wind speed) for farms in Indiana, Iowa, and Oregon, and writes each unmodified response to `raw/`.
2. **Transformation.** A new object under `raw/` triggers the transformation Lambda, which flattens the nested response into one record and writes it to `processed/`.
3. **Analytics.** A Glue table with an explicit schema lets Athena query the processed JSON directly.
4. **Monitoring.** CloudWatch alarms watch Lambda errors and send email through SNS.

### Idempotent processing

The processed S3 key is built from the observation, not from when the code ran:

```
processed/{farm_id}/{yyyy}/{mm}/{dd}/{yyyymmddThhmm}.json
```

Processing the same observation twice overwrites the same object instead of creating a duplicate, so Athena returns one record per farm per observation. S3 versioning keeps earlier writes available.

---

## Repository structure

```
aws-data-pipeline/
├── .github/workflows/
│   ├── terraform-ci.yml        # tests + terraform fmt/validate/plan
│   └── terraform-deploy.yml    # manual deploy (workflow_dispatch)
├── bootstrap/                  # persistent layer: state bucket, GitHub OIDC, IAM role
│   ├── main.tf
│   └── oidc.tf
├── src/
│   ├── ingestion/handler.py
│   └── transformation/handler.py
├── terraform/                  # disposable application stack
│   ├── athena.tf  backend.tf  eventbridge.tf  glue.tf  iam.tf
│   ├── lambda.tf  monitoring.tf  outputs.tf  providers.tf
│   └── s3.tf  variables.tf
├── tests/test_transformation.py
├── .gitignore
└── README.md
```

### Two infrastructure lifecycles

| Layer | Folder | Contents | Destroyed with the app? |
|---|---|---|---|
| Bootstrap | `bootstrap/` | Terraform state bucket, GitHub OIDC provider, GitHub Actions IAM role | No |
| Application | `terraform/` | Data bucket, Lambdas, EventBridge, Glue, Athena, CloudWatch, SNS | Yes |

Keeping GitHub's identity outside the application stack means the app can be destroyed and recreated from CI without losing the ability to authenticate.

---

## Prerequisites

- An AWS account and an IAM user with CLI access
- AWS CLI v2, Terraform 1.10+, Python 3.12, Git, GitHub CLI (`gh`)
- A GitHub account

Check your setup:

```bash
aws sts get-caller-identity
terraform -version
python3 --version
```

---

## Getting started

### 1. Clone and set up Python

```bash
git clone https://github.com/<your-username>/aws-data-pipeline.git
cd aws-data-pipeline
python3 -m venv .venv
source .venv/bin/activate
pip install boto3
```

### 2. Run the unit tests

```bash
python -m unittest discover -s tests -v
```

### 3. Deploy the bootstrap layer (once)

```bash
cd bootstrap
terraform init
terraform apply -var="github_repo=<your-username>/aws-data-pipeline"
terraform output state_bucket
terraform output github_role_arn
cd ..
```

Put the state bucket name into `terraform/backend.tf`.

### 4. Deploy the application

```bash
cd terraform
export TF_VAR_alert_email="you@example.com"
terraform init
terraform validate
terraform plan
terraform apply
```

Confirm the SNS subscription email so alarm notifications are delivered.

### 5. Configure GitHub Actions

```bash
cd bootstrap
gh variable set AWS_ROLE_ARN --body "$(terraform output -raw github_role_arn)"
cd ..
gh variable set ALERT_EMAIL --body "you@example.com"
```

---

## Testing the pipeline

Invoke ingestion:

```bash
aws lambda invoke \
  --function-name agri-pipeline-ingestion \
  --cli-binary-format raw-in-base64-out \
  --payload '{}' response.json
```

Check the S3 layers:

```bash
BUCKET=$(cd terraform && terraform output -raw data_bucket)
aws s3 ls "s3://$BUCKET/raw/" --recursive
aws s3 ls "s3://$BUCKET/processed/" --recursive
```

Query in Athena (workgroup `agri-pipeline-wg`, database `agriculture_data`):

```sql
SELECT farm_name, observation_time, temperature_c,
       humidity_percent, precipitation_mm, wind_speed_kmh
FROM agriculture_data.weather_observations
ORDER BY farm_name, observation_time DESC;
```

Verify idempotency (each farm and observation time should appear once):

```sql
SELECT farm_id, observation_time, COUNT(*) AS record_count
FROM agriculture_data.weather_observations
GROUP BY farm_id, observation_time
ORDER BY farm_id, observation_time DESC;
```

---

## CI/CD

| Workflow | Trigger | Steps |
|---|---|---|
| `terraform-ci.yml` | push, pull request | unit tests → `terraform fmt -check` → OIDC login → `init` → `validate` → `plan` |
| `terraform-deploy.yml` | manual (`workflow_dispatch`) | unit tests → OIDC login → `init` → `plan` → `apply` |

Pushing code never changes AWS on its own. Deployments are started manually.

---

## Tearing down

```bash
cd terraform
terraform destroy
```

This removes the application stack and keeps the bootstrap layer so the project can be recreated later.

---

## Design decisions

- **Lambda instead of Glue ETL:** the transformation is small and event-driven.
- **Raw and processed layers:** raw data can be reprocessed without calling the API again.
- **Explicit Glue schema instead of a crawler:** the processed record shape is predictable.
- **No VPC for Lambda:** it only needs the public API, which avoids NAT Gateway cost.
- **OIDC instead of access keys:** GitHub gets short-lived credentials from AWS STS.

## Possible improvements

- Parquet output and date partitioning for cheaper Athena scans
- Dead-letter queue or failure destinations for the Lambdas
- S3 lifecycle rules for raw data and old versions
- Separate, least-privilege IAM roles per Lambda and a narrower CI role
- Integration tests against the deployed pipeline

---

## Data source and credit

Weather data comes from [Open-Meteo](https://open-meteo.com/), which is free for non-commercial use. Please review their terms before any commercial use.

Based on the design described in Artem Saitov's article, *Building an Event-Driven AWS Data Pipeline with Lambda, S3, Terraform, and GitHub Actions*.

