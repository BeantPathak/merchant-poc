$ErrorActionPreference = "Stop"

$Region = "us-east-1"
$Endpoint = "http://localhost:4566"
$FlowDir = Join-Path $PSScriptRoot "flows"

if (!(Test-Path $FlowDir)) {
    New-Item -ItemType Directory -Path $FlowDir | Out-Null
}

function Invoke-Lambda($functionName, $payloadPath, $outputPath) {
    aws --endpoint-url $Endpoint lambda invoke `
        --function-name $functionName `
        --region $Region `
        --cli-binary-format raw-in-base64-out `
        --payload file://$payloadPath `
        $outputPath | Out-Null
}

Write-Host "===== create_merchant ====="
$createPayload = Join-Path $FlowDir "01_create.json"
$createOutput  = Join-Path $FlowDir "01_create_out.json"
"{}" | Set-Content $createPayload
Invoke-Lambda "create_merchant" $createPayload $createOutput
$create = Get-Content $createOutput | ConvertFrom-Json
$merchantId = $create.merchantId

Write-Host "===== start_kyc ====="
$kycPayload = Join-Path $FlowDir "02_start_kyc.json"
$kycOutput  = Join-Path $FlowDir "02_start_kyc_out.json"
@{ merchantId = $merchantId } | ConvertTo-Json -Compress | Set-Content $kycPayload
Invoke-Lambda "start_kyc" $kycPayload $kycOutput
$kyc = Get-Content $kycOutput | ConvertFrom-Json
$kycId = $kyc.kycId

Write-Host "===== kyccallback ====="
$cbPayload = Join-Path $FlowDir "03_kyc_callback.json"
$cbOutput  = Join-Path $FlowDir "03_kyc_callback_out.json"
@{ merchantId = $merchantId; kycId = $kycId; status = "APPROVED" } | ConvertTo-Json -Compress | Set-Content $cbPayload
Invoke-Lambda "kyccallback" $cbPayload $cbOutput

Write-Host "===== risk_analysis ====="
$riskPayload = Join-Path $FlowDir "04_risk.json"
$riskOutput  = Join-Path $FlowDir "04_risk_out.json"
@{ merchantId = $merchantId } | ConvertTo-Json -Compress | Set-Content $riskPayload
Invoke-Lambda "risk_analysis" $riskPayload $riskOutput

Write-Host "===== activate_merchant ====="
$actPayload = Join-Path $FlowDir "05_activate.json"
$finalOutput = Join-Path $FlowDir "final.json"
@{ merchantId = $merchantId } | ConvertTo-Json -Compress | Set-Content $actPayload
Invoke-Lambda "activate_merchant" $actPayload $finalOutput

Write-Host "========== FINAL RESULT =========="
Get-Content $finalOutput