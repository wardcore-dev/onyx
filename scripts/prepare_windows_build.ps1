```powershell
param()
# Kill running ONYX.exe
Try {
    if (Get-Process -Name "ONYX" -ErrorAction SilentlyContinue) {
        Write-Host "Found running ONYX.exe — stopping..."
        Stop-Process -Name "ONYX" -Force -ErrorAction SilentlyContinue
    }
} catch { Write-Warning "Failed to stop process: $_" }

# Remove existing output exe to avoid LNK1104 conflicts
$exeRel = "..\build\windows\x64\runner\Release\ONYX.exe"
$exePath = Resolve-Path -LiteralPath $exeRel -ErrorAction SilentlyContinue
if ($exePath) {
    Write-Host "Removing existing exe: $exePath"
    Remove-Item -Force $exePath -ErrorAction SilentlyContinue
}

# Ensure nuget.exe in tools\nuget\nuget.exe
$toolsDir = Join-Path $PSScriptRoot "..\tools\nuget"
$nugetExe = Join-Path $toolsDir "nuget.exe"
if (-not (Test-Path $nugetExe)) {
    Write-Host "nuget.exe not found — downloading..."
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    $url = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
    Try {
        Invoke-WebRequest -Uri $url -OutFile $nugetExe -UseBasicParsing -ErrorAction Stop
        Write-Host "Downloaded nuget.exe -> $nugetExe"
    } catch {
        Write-Error "Failed to download nuget.exe: $_"
        exit 1
    }
} else { Write-Host "nuget.exe already present: $nugetExe" }

# Add nuget to PATH for current session
$env:PATH = "$toolsDir;$env:PATH"
Write-Host "Temporary PATH updated to include nuget."

# Try to find a .sln under windows/ and run nuget restore
$windowsDir = Join-Path $PSScriptRoot "..\windows"
$sln = Get-ChildItem -Path $windowsDir -Filter *.sln -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($sln) {
    Write-Host "Running: nuget.exe restore $($sln.FullName)"
    & $nugetExe restore $sln.FullName
} else {
    Write-Host "No solution (.sln) found under $windowsDir — skipping nuget restore."
}

Write-Host "Preparation done. Run 'flutter clean' then 'flutter build windows --release'. If errors persist, run build with --verbose and attach logs."
```