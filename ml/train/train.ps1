# Single entry point for a fine-tune on the Windows RTX 2060 box.
#
#   .\ml\train\train.ps1 -Config whisper-turbo-id-6gb
#   .\ml\train\train.ps1 -Config whisper-base-id -Steps 500
#
# First-time setup on that machine:
#
#   $env:Path = "C:\Users\Kepatuhan\flutter\bin;$env:Path"
#   cd C:\trareon-work\transcribe\ml
#   uv sync --extra train --extra gpu --extra data
#
# bitsandbytes needs a CUDA build on Windows; if `import bitsandbytes`
# fails, install the matching wheel for the installed CUDA toolkit
# before using any config with load_in_4bit or load_in_8bit.
param(
    [Parameter(Mandatory = $true)][string]$Config,
    [int]$Steps = 0,
    [switch]$SkipMemCheck,
    [string]$Quantize = "q5_0"
)

$ErrorActionPreference = "Stop"
$MlDir = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$ConfigPath = Join-Path $MlDir "train\configs\$Config.yaml"
if (-not (Test-Path $ConfigPath)) {
    throw "config tidak ada: $ConfigPath"
}

Push-Location $MlDir
try {
    $Out = "out\train\$Config"
    $ExportDir = "out\export\$Config"
    New-Item -ItemType Directory -Force -Path $Out | Out-Null

    if (-not $SkipMemCheck) {
        Write-Host "==> [1/4] uji memori VRAM" -ForegroundColor Cyan
        # Exit code 1 means "does not fit safely"; report and continue,
        # because the operator may still want the run.
        uv run python -m train.dry_run_memory --config $ConfigPath --json "$Out\memory_report.json"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    uji memori: TIDAK MUAT dengan aman (lihat saran di atas)" -ForegroundColor Yellow
        }
    }

    Write-Host "==> [2/4] latih" -ForegroundColor Cyan
    if ($Steps -gt 0) {
        uv run python -m train.lora --config $ConfigPath --max-steps $Steps
    } else {
        uv run python -m train.lora --config $ConfigPath
    }
    if ($LASTEXITCODE -ne 0) { throw "pelatihan gagal" }

    Write-Host "==> [3/4] gabungkan adapter + ekspor GGML" -ForegroundColor Cyan
    uv run python -m train.merge_export --adapter "$Out\adapter" --out $ExportDir --quantize $Quantize
    if ($LASTEXITCODE -ne 0) { throw "ekspor gagal" }

    Write-Host "==> [4/4] ukur hasilnya" -ForegroundColor Cyan
    $Ggml = Get-ChildItem -Path $ExportDir, ".whisper-convert" -Filter "ggml-*.bin" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
    if ($Ggml) {
        Write-Host "    model: $($Ggml.FullName)"
        Write-Host "    jalankan: uv run python -m eval.run_benchmark --ggml-path '$($Ggml.FullName)'"
    } else {
        Write-Host "    tidak ada GGML yang dihasilkan; lewati pengukuran" -ForegroundColor Yellow
    }
    Write-Host "selesai." -ForegroundColor Green
}
finally {
    Pop-Location
}
