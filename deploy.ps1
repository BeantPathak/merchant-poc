Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------- CONFIG ----------------
$ContainerName = "merchant-postgres"

$BaseDir = "C:\Users\Administrator\Desktop\merchant_poc"
$LambdaBaseDir = "$BaseDir\lambdas"
$SQLFileFull = "$BaseDir\init-db.sql"
$StepFunctionFile = "$BaseDir\stepfunctions\merchant-onboarding.json"
$DistDir = "$BaseDir\dist"

$Lambdas = @(
    "create_merchant",
    "start_kyc",
    "kyccallback",
    "risk_analysis",
    "activate_merchant"
)

$Region = "us-east-1"
$Endpoint = "http://localhost:4566"
$Handler = "handler.handler"

# DB env for Lambda
$EnvVars = "Variables={DB_HOST=merchant-postgres,DB_NAME=merchantdb,DB_USER=merchant,DB_PASSWORD=merchant}"

# ---------------- CLEAN DIST ----------------
if (Test-Path $DistDir) { Remove-Item $DistDir -Recurse -Force }
New-Item -ItemType Directory -Path $DistDir | Out-Null

# ---------------- DB INIT ----------------
Write-Host "Initializing Postgres..."

# Copy init SQL into container safely (avoid powershell ':' issue)
$dockerTarget = "$($ContainerName):/init-db.sql"
docker cp "$SQLFileFull" $dockerTarget

# Execute SQL (ensure role exists in init-db.sql)
docker exec -i $ContainerName psql -U postgres -d postgres -f /init-db.sql
Write-Host "Postgres ready"

# ---------------- PACKAGE LAMBDAS ----------------
foreach ($fn in $Lambdas) {
    Write-Host ("Packaging " + $fn)
    $LambdaDir = "$LambdaBaseDir\$fn"
    if (-not (Test-Path $LambdaDir)) { throw ("Missing lambda dir: " + $LambdaDir) }

    # Clean previous zip and old dependencies
    $zip = "$DistDir\$fn.zip"
    if (Test-Path $zip) { Remove-Item $zip -Force }
    Remove-Item "$LambdaDir\pg8000" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$LambdaDir\*.dist-info" -Recurse -Force -ErrorAction SilentlyContinue

    try {
        # Install pg8000 (pure Python, Lambda compatible)
        python -m pip install --upgrade pg8000 -t $LambdaDir | Out-Null
        Compress-Archive -Path "$LambdaDir\*" -DestinationPath $zip -Force
    } catch {
        Write-Host ("Error packaging Lambda " + $fn + ": " + $_.Exception.Message)
        exit 1
    }
}

Write-Host "Lambdas packaged"

# ---------------- DEPLOY LAMBDAS ----------------
foreach ($fn in $Lambdas) {
    Write-Host ("Deploying " + $fn)
    $zipPath = ("$DistDir\$fn.zip") -replace '\\','/'

    try {
        $getArgs = @(
            "lambda", "get-function",
            "--function-name", $fn,
            "--region", $Region,
            "--endpoint-url", $Endpoint
        )
        $proc = Start-Process -FilePath "aws" -ArgumentList $getArgs -Wait -NoNewWindow -PassThru

        if ($proc.ExitCode -eq 0) {
            Write-Host ("Updating existing Lambda: " + $fn)
            $updateArgs = @(
                "lambda", "update-function-code",
                "--function-name", $fn,
                "--zip-file", "fileb://$zipPath",
                "--region", $Region,
                "--endpoint-url", $Endpoint
            )
            Start-Process -FilePath "aws" -ArgumentList $updateArgs -Wait -NoNewWindow
        } else {
            Write-Host ("Creating new Lambda: " + $fn)
            $createArgs = @(
                "lambda", "create-function",
                "--function-name", $fn,
                "--runtime", "python3.10",
                "--handler", $Handler,
                "--role", "arn:aws:iam::000000000000:role/lambda-role",
                "--zip-file", "fileb://$zipPath",
                "--environment", $EnvVars,
                "--region", $Region,
                "--endpoint-url", $Endpoint
            )
            Start-Process -FilePath "aws" -ArgumentList $createArgs -Wait -NoNewWindow
        }
    } catch {
        Write-Host ("Error deploying Lambda " + $fn + ": " + $_.Exception.Message)
        exit 1
    }
}

# ---------------- STEP FUNCTION ----------------
Write-Host "Deploying Step Function..."
$smName = "merchant-onboarding"

try {
    $existing = aws --endpoint-url $Endpoint stepfunctions list-state-machines `
        --region $Region | ConvertFrom-Json |
        Select-Object -ExpandProperty stateMachines |
        Where-Object { $_.name -eq $smName }

    if ($existing) {
        Write-Host "Updating existing Step Function"
        aws --endpoint-url $Endpoint stepfunctions update-state-machine `
            --state-machine-arn $existing.stateMachineArn `
            --definition "file://$StepFunctionFile" `
            --region $Region
    } else {
        Write-Host "Creating new Step Function"
        aws --endpoint-url $Endpoint stepfunctions create-state-machine `
            --name $smName `
            --definition "file://$StepFunctionFile" `
            --role-arn arn:aws:iam::000000000000:role/StepFunctionsRole `
            --region $Region
    }
} catch {
    Write-Host ("Error deploying Step Function: " + $_.Exception.Message)
    exit 1
}

Write-Host "DEPLOYMENT COMPLETE"
