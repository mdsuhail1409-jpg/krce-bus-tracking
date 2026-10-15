# Ralph Loop - Automated Verification Gate for KRCE Bus Tracking
# Runs backend syntax checks and Flutter static analysis

$allPassed = $true

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " [Ralph Loop] Autonomous Verification Gate             " -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

# 1. Backend Python Syntax Compilation
Write-Host "`n[1/2] Checking Backend Python Syntax..." -ForegroundColor Yellow
$pyFiles = Get-ChildItem -Path "backend" -Recurse -Filter "*.py" | Where-Object { $_.FullName -notmatch "venv" }
$pyErrors = 0

foreach ($file in $pyFiles) {
    python -m py_compile "$($file.FullName)" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [FAIL] Syntax Error: $($file.FullName)" -ForegroundColor Red
        $pyErrors++
        $allPassed = $false
    }
}

if ($pyErrors -eq 0) {
    Write-Host "  [PASS] Backend Python: All $($pyFiles.Count) files compile cleanly." -ForegroundColor Green
} else {
    Write-Host "  [FAIL] Backend Python: $pyErrors syntax error(s) detected." -ForegroundColor Red
}

# 2. Flutter Mobile Static Analysis
Write-Host "`n[2/2] Running Flutter Static Analysis..." -ForegroundColor Yellow
Push-Location "frontend\krce_bus_flutter"
$analyzeOutput = & flutter analyze 2>&1
Pop-Location

$compileErrors = $analyzeOutput | Where-Object { $_ -match "error •" }
if ($compileErrors) {
    Write-Host "  [FAIL] Flutter Analysis: Found compile errors:" -ForegroundColor Red
    $compileErrors | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    $allPassed = $false
} else {
    Write-Host "  [PASS] Flutter Analysis: 0 compile errors detected." -ForegroundColor Green
}

# 3. Final Gate Status
Write-Host "`n=======================================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host " [Ralph Loop] Status: GREEN [PASS] (All systems verified)" -ForegroundColor Green
    exit 0
} else {
    Write-Host " [Ralph Loop] Status: RED [FAIL] (Fixes required)" -ForegroundColor Red
    exit 1
}
