# Building Brush on Windows

This guide explains how to build Brush on Windows.

## Quick Start

### Automated Build (Recommended)

Simply run the build script:

```powershell
.\build.ps1
```

Or double-click `build.bat` in Windows Explorer.

The script will:
1. Check for required tools (Rust, Node.js)
2. Offer to install them automatically via winget if missing
3. Install npm dependencies
4. Build the Rust workspace
5. Build WASM for web
6. Build the Next.js application

### Build Options

```powershell
# Show help
.\build.ps1 -Help

# Build in debug mode (faster compilation, slower runtime)
.\build.ps1 -DevBuild

# Skip dependency checks (if tools are already installed)
.\build.ps1 -SkipChecks

# Combine options
.\build.ps1 -DevBuild -SkipChecks
```

## Manual Build

If you prefer to build manually:

### Prerequisites

1. **Rust 1.88+**
   - Install from https://rustup.rs/
   - Or via winget: `winget install Rustlang.Rustup`

2. **Node.js LTS**
   - Install from https://nodejs.org/
   - Or via winget: `winget install OpenJS.NodeJS.LTS`

3. **Additional Rust tools**
   ```powershell
   rustup target add wasm32-unknown-unknown
   cargo install wasm-pack
   cargo install rerun-cli  # Optional, for visualizations
   ```

### Build Steps

```powershell
# 1. Install npm dependencies
npm install

# 2. Build Rust workspace (release mode)
cargo build --release --all

# 3. Build WASM for web
cd crates/brush-app
wasm-pack build --target web --out-dir ../../brush_nextjs/public/wasm --release
cd ../..

# 4. Build Next.js application
npm run build
```

## Running Brush

### Desktop Application

```powershell
# Run the desktop app (release mode)
cargo run --release

# Or run a debug build
cargo run
```

### Web Application

```powershell
# Start the development server
npm run dev

# Then open http://localhost:3000 in Chrome or Edge
```

### Testing

```powershell
# Run all tests
cargo test --all

# Run benchmarks
cargo bench
```

## Build Outputs

- **Rust binaries**: `target/release/` (or `target/debug/` for dev builds)
- **WASM files**: `brush_nextjs/public/wasm/`
- **Next.js build**: `brush_nextjs/.next/`
- **Main executable**: `target/release/brush-app.exe`

## Troubleshooting

### "cargo: The term 'cargo' is not recognized"

Restart your terminal after installing Rust to refresh environment variables, or run:

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
```

### "npm: The term 'npm' is not recognized"

Same as above - restart your terminal after installing Node.js.

### winget not available

If you're on an older version of Windows 10 or don't have winget:
1. Install App Installer from the Microsoft Store, or
2. Follow manual installation instructions above

### Build fails with "wasm-pack not found"

```powershell
cargo install wasm-pack
```

### Browser compatibility

The web version currently only works on:
- Chrome 134+ (Windows/macOS)
- Edge 134+ (Windows/macOS)

Firefox and Safari support coming soon.

## Additional Build Targets

### Development Web Build

```powershell
# Faster WASM build for development
npm run build:wasm-dev
npm run dev
```

### Viewer-Only Build

```powershell
# Build just the viewer (no training)
npm run build:viewer
npm run dev:viewer
```

## System Requirements

- **OS**: Windows 10/11
- **GPU**: DirectX 12 compatible GPU (AMD/Nvidia/Intel)
- **RAM**: 8GB minimum, 16GB recommended
- **Disk**: 2GB for source + build outputs

## For More Information

See the main [README.md](README.md) for:
- Feature overview
- Using the CLI
- Loading datasets (COLMAP, Nerfstudio format)
- Rerun integration for visualizations
- Benchmarks and performance notes
