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

# Function to install using winget
function Install-WithWinget {
    param($PackageId, $Name)
    
    if (-not (Test-CommandExists "winget")) {
        Write-Error "winget is not available. Please install manually from: https://docs.microsoft.com/en-us/windows/package-manager/winget/"
        return $false
    }
    
    Write-Info "Installing $Name via winget..."
    try {
        winget install --id $PackageId --silent --accept-source-agreements --accept-package-agreements
        Write-Success "$Name installed successfully"
        Write-Warning "Please restart your PowerShell session or run: refreshenv"
        return $true
    } catch {
        Write-Error "Failed to install $Name"
        return $false
    }
}

# ============================================================================
# STEP 1: Check and Install Dependencies
# ============================================================================

if (-not $SkipChecks) {
    Write-Step "Checking dependencies..."
    
    # Check Rust
    if (-not (Test-CommandExists "cargo")) {
        Write-Warning "Rust/Cargo not found!"
        Write-Info "Installing Rust..."
        
        if (Install-WithWinget "Rustlang.Rustup" "Rust") {
            Write-Info "Refreshing environment variables..."
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        } else {
            Write-Error "Please install Rust manually from https://rustup.rs/ and re-run this script."
            exit 1
        }
    } else {
        $rustVersion = (cargo --version) -replace 'cargo ', ''
        Write-Success "Rust found: $rustVersion"
    }
    
    # Check Node.js
    if (-not (Test-CommandExists "node")) {
        Write-Warning "Node.js not found!"
        Write-Info "Installing Node.js..."
        
        if (Install-WithWinget "OpenJS.NodeJS.LTS" "Node.js") {
            Write-Info "Refreshing environment variables..."
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        } else {
            Write-Error "Please install Node.js manually from https://nodejs.org/ and re-run this script."
            exit 1
        }
    } else {
        $nodeVersion = node --version
        $npmVersion = npm --version
        Write-Success "Node.js found: $nodeVersion"
        Write-Success "npm found: v$npmVersion"
    }
    
    # Check wasm-pack
    if (-not (Test-CommandExists "wasm-pack")) {
        Write-Warning "wasm-pack not found. Installing..."
        try {
            cargo install wasm-pack
            Write-Success "wasm-pack installed"
        } catch {
            Write-Error "Failed to install wasm-pack. Please install manually: cargo install wasm-pack"
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
try {
    if ($buildMode) {
        cargo build --all $buildMode
    } else {
        cargo build --all
    }
    Write-Success "Rust workspace built successfully in $buildModeStr mode"
} catch {
    Write-Error "Failed to build Rust workspace: $_"
    exit 1
}

# ============================================================================
# STEP 4: Build WASM for Web
# ============================================================================

Write-Step "Building WASM for web..."
try {
    if ($DevBuild) {
        npm run build:wasm-dev
    } else {
        # Build the release version of WASM
        Set-Location crates/brush-app
        if (Test-Path "pkg") { Remove-Item -Recurse -Force pkg }
        wasm-pack build --target web --out-dir ../../brush_nextjs/public/wasm $buildMode
        Set-Location ../..
    }
    Write-Success "WASM built successfully"
} catch {
    Write-Error "Failed to build WASM: $_"
    Set-Location $PSScriptRoot
    exit 1
}

# ============================================================================
# STEP 5: Build Next.js Application
# ============================================================================

Write-Step "Building Next.js application..."
try {
    npm run build
    Write-Success "Next.js application built successfully"
} catch {
    Write-Error "Failed to build Next.js application: $_"
    exit 1
}

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
