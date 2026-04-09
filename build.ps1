#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build script for Brush on Windows
.DESCRIPTION
    Checks for required tools (Rust, Node.js), installs them if missing, and builds the entire Brush project.
    Target: Windows only (no Android builds)
.EXAMPLE
    .\build.ps1
    .\build.ps1 -SkipChecks
    .\build.ps1 -DevBuild
#>

param(
    [switch]$SkipChecks,
    [switch]$DevBuild,
    [switch]$Help
)

# Color output functions
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Error { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-Warning { param($msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
function Write-Step { param($msg) Write-Host "`n==> $msg" -ForegroundColor Magenta }

if ($Help) {
    Write-Host @"
Brush Build Script for Windows

Usage:
    .\build.ps1 [options]

Options:
    -SkipChecks    Skip dependency checking (assumes tools are installed)
    -DevBuild      Build in debug mode instead of release
    -Help          Show this help message

Build targets:
    - Rust workspace (all crates)
    - WASM for web
    - Next.js application

Requirements (auto-installed if missing):
    - Rust 1.88+
    - Node.js LTS
    - wasm-pack

"@
    exit 0
}

$ErrorActionPreference = "Stop"

Write-Host @"

╔══════════════════════════════════════════════════════════╗
║                  Brush Build Script                      ║
║                   Windows Edition                        ║
╚══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Check if running as administrator (needed for some installations)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Not running as administrator. Some installation steps may require elevation."
}

# Function to check if a command exists
function Test-CommandExists {
    param($Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Function to refresh environment PATH
function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Function to install using winget
function Install-WithWinget {
    param($PackageId, $Name)
    
    if (-not (Test-CommandExists "winget")) {
        Write-Error "winget is not available. Please install manually from: https://docs.microsoft.com/en-us/windows/package-manager/winget/"
        return $false
    }
    
    Write-Info "Installing $Name via winget (this may take a few minutes)..."
    try {
        $process = Start-Process -FilePath "winget" -ArgumentList "install", "--id", $PackageId, "--silent", "--accept-source-agreements", "--accept-package-agreements" -NoNewWindow -PassThru -Wait
        
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq -1978335189) {
            # Exit code -1978335189 means already installed
            Write-Success "$Name installed successfully"
            Refresh-Path
            return $true
        } else {
            Write-Warning "$Name installation returned exit code $($process.ExitCode)"
            Refresh-Path
            return $true  # Try to continue anyway
        }
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Error "Failed to install ${Name}: $errorMsg"
        return $false
    }
}

# ============================================================================
# STEP 1: Check and Install Dependencies
# ============================================================================

if (-not $SkipChecks) {
    Write-Step "Checking dependencies..."
    
    # Refresh PATH to pick up recently installed tools
    Refresh-Path
    
    # Check Rust
    if (-not (Test-CommandExists "cargo")) {
        Write-Warning "Rust/Cargo not found!"
        
        if (Install-WithWinget "Rustlang.Rustup" "Rust") {
            Refresh-Path
            
            # rustup might need initial setup
            if (Test-CommandExists "rustup") {
                Write-Info "Setting up Rust with GNU toolchain (lighter, no Visual Studio required)..."
                rustup toolchain install stable-x86_64-pc-windows-gnu 2>&1 | Out-Null
                rustup default stable-x86_64-pc-windows-gnu 2>&1 | Out-Null
                Refresh-Path
            }
            
            if (-not (Test-CommandExists "cargo")) {
                Write-Error "Rust installation completed but cargo is not available. Please restart your terminal and try again."
                exit 1
            }
        } else {
            Write-Error "Please install Rust manually from https://rustup.rs/ and re-run this script."
            exit 1
        }
    }
    
    $rustVersion = (cargo --version) -replace 'cargo ', ''
    $rustToolchain = (rustup show active-toolchain 2>&1) -replace ' \(.*\)', ''
    Write-Success "Rust found: $rustVersion ($rustToolchain)"
    
    # Ensure we have a working linker for Rust
    if ($rustToolchain -like "*windows-gnu*") {
        if (-not (Test-CommandExists "gcc")) {
            Write-Warning "GCC linker not found. Installing MinGW-w64..."
            
            # Install MSYS2 which includes MinGW
            if (Install-WithWinget "MSYS2.MSYS2" "MSYS2") {
                Refresh-Path
                
                # Install MinGW-w64 GCC
                Write-Info "Installing MinGW-w64 GCC compiler..."
                & C:\msys64\usr\bin\bash.exe -lc "pacman -S --noconfirm mingw-w64-x86_64-gcc" 2>&1 | Out-Null
                
                # Add to PATH
                $mingwPath = "C:\msys64\mingw64\bin"
                $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
                if ($currentPath -notlike "*$mingwPath*") {
                    [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$mingwPath", "User")
                    Write-Info "Added MinGW to PATH"
                }
                Refresh-Path
                
                if (-not (Test-CommandExists "gcc")) {
                    Write-Error "Failed to install GCC. Please install manually or switch to MSVC toolchain."
                    exit 1
                }
                Write-Success "GCC linker installed"
            }
        } else {
            $gccVersion = (gcc --version | Select-Object -First 1) -replace '.* ', '' -replace ' .*', ''
            Write-Success "GCC found: $gccVersion"
        }
    }
    
    # Check Node.js
    if (-not (Test-CommandExists "node")) {
        Write-Warning "Node.js not found!"
        
        if (Install-WithWinget "OpenJS.NodeJS.LTS" "Node.js") {
            Refresh-Path
            
            if (-not (Test-CommandExists "node")) {
                Write-Error "Node.js installation completed but node is not available. Please restart your terminal and try again."
                exit 1
            }
        } else {
            Write-Error "Please install Node.js manually from https://nodejs.org/ and re-run this script."
            exit 1
        }
    }
    
    $nodeVersion = node --version
    $npmVersion = npm --version
    Write-Success "Node.js found: $nodeVersion"
    Write-Success "npm found: v$npmVersion"
    
    # Check wasm-pack
    if (-not (Test-CommandExists "wasm-pack")) {
        Write-Warning "wasm-pack not found. Installing..."
        $wasmInstall = cargo install wasm-pack 2>&1
        if ($LASTEXITCODE -eq 0) {
            Refresh-Path
            Write-Success "wasm-pack installed"
        } else {
            Write-Error "Failed to install wasm-pack. Error: $wasmInstall"
            Write-Error "You may need Visual Studio Build Tools. Run: winget install 'Microsoft.VisualStudio.2022.BuildTools' --silent --override '--wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'"
            exit 1
        }
    } else {
        $wasmPackVersion = wasm-pack --version
        Write-Success "wasm-pack found: $wasmPackVersion"
    }
    
    # Check for wasm32 target
    Write-Info "Checking Rust wasm32-unknown-unknown target..."
    $targets = rustup target list --installed
    if ($targets -notcontains "wasm32-unknown-unknown") {
        Write-Info "Installing wasm32-unknown-unknown target..."
        rustup target add wasm32-unknown-unknown
        Write-Success "wasm32-unknown-unknown target installed"
    } else {
        Write-Success "wasm32-unknown-unknown target already installed"
    }
    
} else {
    Write-Info "Skipping dependency checks..."
}

# ============================================================================
# STEP 2: Install npm dependencies
# ============================================================================

Write-Step "Installing npm dependencies..."
try {
    npm install
    Write-Success "npm dependencies installed"
} catch {
    Write-Error "Failed to install npm dependencies: $_"
    exit 1
}

# ============================================================================
# STEP 3: Build Rust Workspace
# ============================================================================

Write-Step "Building Rust workspace..."
$buildMode = if ($DevBuild) { "" } else { "--release" }
$buildModeStr = if ($DevBuild) { "debug" } else { "release" }

Write-Info "Building in $buildModeStr mode..."
if ($buildMode) {
    cargo build --all $buildMode
} else {
    cargo build --all
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build Rust workspace (exit code: $LASTEXITCODE)"
    Write-Error "You may need Visual Studio Build Tools. Run: winget install 'Microsoft.VisualStudio.2022.BuildTools' --silent --override '--wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'"
    exit 1
}
Write-Success "Rust workspace built successfully in $buildModeStr mode"

# ============================================================================
# STEP 4: Build WASM for Web
# ============================================================================

Write-Step "Building WASM for web..."
if ($DevBuild) {
    npm run build:wasm-dev
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build WASM in dev mode (exit code: $LASTEXITCODE)"
        exit 1
    }
} else {
    # Build the release version of WASM
    Push-Location crates/brush-app
    try {
        if (Test-Path "pkg") { Remove-Item -Recurse -Force pkg }
        wasm-pack build --target web --out-dir ../../brush_nextjs/public/wasm $buildMode
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to build WASM (exit code: $LASTEXITCODE)"
            Pop-Location
            exit 1
        }
    } finally {
        Pop-Location
    }
}
Write-Success "WASM built successfully"

# ============================================================================
# STEP 5: Build Next.js Application
# ============================================================================

Write-Step "Building Next.js application..."
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build Next.js application (exit code: $LASTEXITCODE)"
    exit 1
}
Write-Success "Next.js application built successfully"

# ============================================================================
# Build Complete
# ============================================================================

Write-Host @"

╔══════════════════════════════════════════════════════════╗
║                 BUILD SUCCESSFUL! 🎉                     ║
╚══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Info "Outputs:"
if ($DevBuild) {
    Write-Info "  - Rust binaries: target/debug/"
} else {
    Write-Info "  - Rust binaries: target/release/"
}
Write-Info "  - WASM: brush_nextjs/public/wasm/"
Write-Info "  - Next.js build: brush_nextjs/.next/"

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Info "  Run desktop app:  cargo run --release (or 'cargo run' for debug)"
Write-Info "  Run web server:   npm run dev"
Write-Info "  Run tests:        cargo test --all"

Write-Host ""
