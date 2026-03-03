param(
  [string]$RenderTarget = ".",
  [switch]$NoRender,
  [switch]$PerFile,
  [int]$RenderRetries = 3,
  [int]$MaxRetries = 6,
  [int]$RetryDelaySec = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Remove-WithRetry {
  param(
    [Parameter(Mandatory = $true)]
    [string]$PathPattern
  )

  $items = Get-ChildItem -Path $PathPattern -Force -ErrorAction SilentlyContinue
  if (-not $items) {
    return
  }

  foreach ($item in $items) {
    $removed = $false
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
      try {
        Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
        Write-Host "[ok] Removed $($item.FullName)"
        $removed = $true
        break
      }
      catch {
        if ($attempt -eq $MaxRetries) {
          Write-Warning "[skip] Could not remove after $MaxRetries attempts: $($item.FullName)"
        }
        else {
          Start-Sleep -Seconds $RetryDelaySec
        }
      }
    }
  }
}

Write-Host "Cleaning Quarto temporary/output folders..."

# Common locked render artifacts
Remove-WithRetry ".\index_files"
Remove-WithRetry ".\item-bank_files"
Remove-WithRetry ".\descriptive-statistics_files"
Remove-WithRetry ".\psychometric-results_files"
Remove-WithRetry ".\proposed-cutoff_files"

# Quarto temp sessions and freeze libs that can be locked
Remove-WithRetry ".\.quarto\quarto-session-temp*"
Remove-WithRetry ".\.quarto\_freeze\site_libs"

if ($NoRender) {
  Write-Host "Cleanup complete. Skipping render because -NoRender was provided."
  exit 0
}

function Invoke-QuartoRenderWithRetry {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Target
  )

  for ($attempt = 1; $attempt -le $RenderRetries; $attempt++) {
    Write-Host "Running: quarto render $Target (attempt $attempt/$RenderRetries)"
    & quarto render $Target
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
      return 0
    }

    Write-Warning "Render failed for '$Target' with exit code $exitCode."
    if ($attempt -lt $RenderRetries) {
      Write-Host "Retrying after cleanup..."
      Remove-WithRetry ".\index_files"
      Remove-WithRetry ".\item-bank_files"
      Remove-WithRetry ".\descriptive-statistics_files"
      Remove-WithRetry ".\psychometric-results_files"
      Remove-WithRetry ".\proposed-cutoff_files"
      Remove-WithRetry ".\.quarto\quarto-session-temp*"
      Start-Sleep -Seconds $RetryDelaySec
    }
    else {
      return $exitCode
    }
  }
}

if ($PerFile -and $RenderTarget -eq ".") {
  $qmdFiles = @(
    "index.qmd",
    "descriptive-statistics.qmd",
    "item-bank.qmd",
    "proposed-cutoff.qmd",
    "psychometric-results.qmd"
  ) | Where-Object { Test-Path $_ }

  foreach ($qmd in $qmdFiles) {
    $code = Invoke-QuartoRenderWithRetry -Target $qmd
    if ($code -ne 0) {
      Write-Error "Quarto render failed on $qmd with exit code $code."
      exit $code
    }
  }

  Write-Host "[ok] Quarto render completed (per-file mode)."
}
else {
  $code = Invoke-QuartoRenderWithRetry -Target $RenderTarget
  if ($code -ne 0) {
    Write-Error "Quarto render failed with exit code $code."
    exit $code
  }
  Write-Host "[ok] Quarto render completed."
}
