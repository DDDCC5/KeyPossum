param([string]$OutputDirectory = "")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $root "dist/KeyPossum-Windows-x64" }
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
& dotnet run --project (Join-Path $root "windows/KeyPossum.Core.Tests") -c Release
if ($LASTEXITCODE -ne 0) { throw "Core tests failed." }
& dotnet publish (Join-Path $root "windows/KeyPossum/KeyPossum.csproj") -c Release -r win-x64 --self-contained true -p:EnableWindowsTargeting=true -p:PublishSingleFile=false -p:DebugType=None -p:DebugSymbols=false -o $OutputDirectory
if ($LASTEXITCODE -ne 0) { throw "Windows publish failed." }
Copy-Item (Join-Path $root "LICENSE") $OutputDirectory
$notices = Join-Path $OutputDirectory "third-party"
New-Item -ItemType Directory -Path $notices -Force | Out-Null
Copy-Item (Join-Path $root "third-party/*") $notices -Recurse -Force
$archive = Join-Path (Split-Path -Parent $OutputDirectory) "KeyPossum-0.1.0-alpha.1-windows-x64.zip"
Compress-Archive -Path (Join-Path $OutputDirectory "*") -DestinationPath $archive -Force
Write-Host "Published self-contained Windows 11 x64 application: $OutputDirectory"
Write-Host "Release archive: $archive"
Write-Host "Physical input qualification remains required. Run KeyPossum.exe; no administrator permission is requested."
