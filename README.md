 # Merchant Onboarding POC

This project demonstrates a **merchant onboarding workflow** using **AWS Step Functions** and **serverless Lambdas** locally with **LocalStack**.

---

 # Prerequisites
 
 **Docker, Python 3.10+, PIP and AWS CLI**


## Overview

The POC implements a merchant onboarding flow:

1. **Create merchant** in the database.
2. **Start KYC** (Know Your Customer) verification.
3. **Handle KYC approval/rejection**.
4. **Perform risk analysis**.
5. **Activate merchant** if approved.

All services run locally via **Docker**.

---

## Architecture

- **PostgreSQL**: Stores merchant and KYC data.
- **AWS Lambda functions**: Implement business logic.
- **AWS Step Functions**: Orchestrates the workflow.
- **LocalStack**: Emulates AWS services locally.

---

## Step Function Workflow

CreateMerchant -> StartKYC -> KYCResult -> {RiskAnalysis -> ActivateMerchant | KYCFailed}

**States:**

- `CreateMerchant` – Inserts a merchant record, returns `merchantId`.
- `StartKYC` – Inserts KYC record (`PENDING`), returns `TaskToken`.
- `KYCResult` – Choice state based on KYC status:
  - `APPROVED` → RiskAnalysis → ActivateMerchant
  - `REJECTED` → Fail
- `RiskAnalysis` – Simulates a risk check.
- `ActivateMerchant` – Marks merchant as active.
- `KYCFailed` – Ends workflow if KYC is rejected.

---

## Lambda Functions

| Function        | Purpose                                                                 |
|-----------------|-------------------------------------------------------------------------|
| `create_merchant` | Adds merchant to Postgres, returns `merchantId`.                       |
| `start_kyc`       | Creates KYC record with status `PENDING`, returns `TaskToken`.         |
| `kyccallback`     | Updates KYC status, calls Step Functions `send_task_success`.          |
| `risk_analysis`   | Performs risk check (simulated).                                       |
| `activate_merchant` | Activates merchant after successful onboarding.                      |

**Notes:**

- `start_kyc` uses **wait for task token** to simulate human approval.
- `kyccallback` must receive **valid JSON with double quotes** when testing locally.

---

## Database

- **Postgres Container**: Initialized via `init-db.sql`.
- Tables:
  - `merchants`: Stores merchant info.
  - `kyc`: Stores KYC records and status.

---

## Deployment Script

The PowerShell script:

1. Zips Lambda directories including Python dependencies (`pg8000`).
2. Deploys or updates Lambda functions to LocalStack.
3. Deploys the Step Function workflow.
4. Initializes Postgres via Docker.

**Key Points:**

- Uses **pg8000** for Postgres access inside Lambdas.
- Targets **Python 3.10**.
- Uses LocalStack endpoint `http://localhost:4566`.

---


 ## Local Setup

1. **Start Docker Compose**:  
       `docker compose up -d`
2. **Bypass Script Execution firewall in Powershell**:            
       `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`
4. **Deploy Lambdas and Step Function**:   
       `.\deploy.ps1`
6. **Start a Step Function execution**:         
       `aws --endpoint-url=http://localhost:4566 stepfunctions start-execution --state-machine-arn <state-machine-arn> --input '{}'`
7. **Check execution history**:   
       `aws --endpoint-url=http://localhost:4566 stepfunctions get-execution-history --execution-arn <execution-arn>`
8. **Approve KYC (manually or via Lambda test)**:   
       `aws --endpoint-url=http://localhost:4566 lambda invoke --function-name kyccallback --payload '{"kycId":1,"status":"APPROVED","TaskToken":"<token>"}' output.json`
9. **To restart execution**:  
       `docker compose down -v`     
           Restart from Step 1


