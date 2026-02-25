#Requires -RunAsAdministrator
# vs-buildtools-create-layout.ps1 -- Download VS 2022 Build Tools offline layout
#
# Run from an elevated PowerShell on any Windows machine with internet access.
# Creates layout at $LayoutPath. Copy to NAS manually when done.
#
# Usage:
#   .\vs-buildtools-create-layout.ps1
#   .\vs-buildtools-create-layout.ps1 -LayoutPath "D:\vs_BuildTools_layout"
#
# Components (per Epic UE 5.7 docs):
#   - VCTools workload (MSVC v143 compiler, MSBuild, CMake, vcpkg)
#   - Windows 11 SDK 26100
#   - C++ AddressSanitizer
#   - LLVM/Clang 18.x
#   - .NET 8.0 Runtime
#
# Sources:
#   https://dev.epicgames.com/documentation/en-us/unreal-engine/setting-up-visual-studio-development-environment-for-cplusplus-projects-in-unreal-engine
#   https://learn.microsoft.com/en-us/visualstudio/install/create-a-network-installation-of-visual-studio

param(
    [string]$LayoutPath = "C:\vs_BuildTools_layout",
    [string]$BootstrapperUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe"
)

if (-not (Test-Path $LayoutPath)) { New-Item -ItemType Directory -Path $LayoutPath | Out-Null }
$bootstrapper = Join-Path $LayoutPath "vs_BuildTools.exe"

if (-not (Test-Path $bootstrapper)) {
    Write-Host "Downloading bootstrapper..."
    Invoke-WebRequest -Uri $BootstrapperUrl -OutFile $bootstrapper
}

Write-Host "Creating VS Build Tools offline layout at: $LayoutPath"
Write-Host "This will download ~5-15 GB from Microsoft..."

# Start the bootstrapper and wait for the spawned layout process to finish.
# The bootstrapper launches vs_setup_bootstrapper.exe which launches the
# actual layout tool -- --wait only waits for the first child. We need to
# wait for the "Setup" process that does the real work.
$proc = Start-Process -FilePath $bootstrapper -ArgumentList @(
    "--layout", $LayoutPath,
    "--add", "Microsoft.VisualStudio.Workload.VCTools",
    "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
    "--add", "Microsoft.VisualStudio.Component.Windows11SDK.26100",
    "--add", "Microsoft.VisualStudio.Component.VC.ASAN",
    "--add", "Microsoft.VisualStudio.Component.VC.Llvm.Clang",
    "--add", "Microsoft.NetCore.Component.Runtime.8.0",
    "--includeRecommended", "--lang", "en-US", "--passive"
) -PassThru

Write-Host "Bootstrapper PID: $($proc.Id). Waiting for layout tool to start..."
Start-Sleep -Seconds 10

# Wait for all "Setup" processes spawned by the bootstrapper to finish
do {
    $setupProcs = Get-Process -Name "vs_setup_bootstrapper", "vs_BuildTools", "Setup" -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -ne $PID }
    if ($setupProcs) {
        Write-Host "Layout in progress... (processes: $($setupProcs.Name -join ', '))"
        Start-Sleep -Seconds 30
    }
} while ($setupProcs)

# Check if layout succeeded by looking for the catalog file
$catalog = Join-Path $LayoutPath "Catalog.json"
if (-not (Test-Path $catalog)) {
    Write-Error "Layout failed -- Catalog.json not found in $LayoutPath"
    Write-Host "Check logs at: $env:TEMP\dd_bootstrapper_*.log"
    exit 1
}

Write-Host "Done. Layout created at $LayoutPath"
