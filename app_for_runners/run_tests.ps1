$ErrorActionPreference = "Stop"

$tmpFile = Join-Path $env:TEMP "pytest_output.txt"
Remove-Item $tmpFile -ErrorAction SilentlyContinue | Out-Null

# Redirect everything to a file to avoid pytest progress "dots".
# Important: do NOT pass `-q` here; `pytest.ini` already sets it.
# Use `--capture=no` so our per-check prints are written to stdout (and thus into $tmpFile).
#
# Force ANSI colors even though stdout is redirected to a file.
$env:FORCE_COLOR = "1"
& python -m pytest --capture=no 1>$tmpFile 2>&1
$exitCode = $LASTEXITCODE

$output = Get-Content $tmpFile -ErrorAction SilentlyContinue

$expectLines = $output | Select-String -Pattern "-> expected" | ForEach-Object {
    ($_.Line.Trim()).TrimStart('.').Trim()
}
$expectLines = @($expectLines)

if ($expectLines.Count -gt 0) {
    $expectLines | ForEach-Object { Write-Output $_ }
}

$summaryLine = $output | Select-String -Pattern "passed|failed|error" | Select-Object -Last 1
if ($summaryLine) {
    Write-Output $summaryLine.Line.Trim()
} else {
    # Fallback: last line
    $last = $output | Select-Object -Last 1
    if ($last) { Write-Output $last.Trim() }
}

if ($exitCode -ne 0) {
    # On failure print the last chunk for debugging
    $tail = $output | Select-Object -Last 30
    Write-Output ""
    Write-Output "Last output:"
    $tail | ForEach-Object { Write-Output $_ }
    exit $exitCode
}

exit 0

