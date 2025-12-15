#!/bin/bash

################################################################################
# CUDA Side-by-Side Installation Script
#
# This script installs any CUDA toolkit version alongside existing installations
# without modifying display drivers or existing CUDA versions.
#
# Features:
#   - Version-agnostic: Install any CUDA version you specify
#   - Smart resume: Detects installation state and resumes from where it left off
#   - Safe: Does NOT touch display drivers or existing installations
#   - Automatic downloads: CUDA toolkit and cuDNN
#   - Validation: Verifies installation at each step
#
# Usage:
#   sudo ./install_cuda_alongside.sh [CUDA_VERSION]
#
#   Examples:
#     sudo ./install_cuda_alongside.sh 12.6.2
#     sudo ./install_cuda_alongside.sh 11.8.0
#     sudo ./install_cuda_alongside.sh    # Interactive mode
#
# Author: Claude Code
# Date: 2025-12-15
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Log functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${BLUE}[SUCCESS]${NC} $1"
}

step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

debug() {
    echo -e "${MAGENTA}[DEBUG]${NC} $1"
}

################################################################################
# Configuration and Version URLs
################################################################################

# CUDA version mappings
# Format: VERSION|MAJOR.MINOR|DOWNLOAD_URL|DRIVER_VERSION
declare -A CUDA_VERSIONS=(
    # CUDA 12.x
    ["12.6.2"]="12.6|https://developer.download.nvidia.com/compute/cuda/12.6.2/local_installers/cuda_12.6.2_560.35.03_linux.run|560.35.03"
    ["12.6.1"]="12.6|https://developer.download.nvidia.com/compute/cuda/12.6.1/local_installers/cuda_12.6.1_560.35.03_linux.run|560.35.03"
    ["12.6.0"]="12.6|https://developer.download.nvidia.com/compute/cuda/12.6.0/local_installers/cuda_12.6.0_560.28.03_linux.run|560.28.03"
    ["12.5.1"]="12.5|https://developer.download.nvidia.com/compute/cuda/12.5.1/local_installers/cuda_12.5.1_555.42.06_linux.run|555.42.06"
    ["12.4.1"]="12.4|https://developer.download.nvidia.com/compute/cuda/12.4.1/local_installers/cuda_12.4.1_550.54.15_linux.run|550.54.15"
    ["12.3.2"]="12.3|https://developer.download.nvidia.com/compute/cuda/12.3.2/local_installers/cuda_12.3.2_545.23.08_linux.run|545.23.08"
    ["12.2.2"]="12.2|https://developer.download.nvidia.com/compute/cuda/12.2.2/local_installers/cuda_12.2.2_535.104.05_linux.run|535.104.05"
    ["12.1.1"]="12.1|https://developer.download.nvidia.com/compute/cuda/12.1.1/local_installers/cuda_12.1.1_530.30.02_linux.run|530.30.02"
    ["12.0.1"]="12.0|https://developer.download.nvidia.com/compute/cuda/12.0.1/local_installers/cuda_12.0.1_525.85.12_linux.run|525.85.12"

    # CUDA 11.x
    ["11.8.0"]="11.8|https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run|520.61.05"
    ["11.7.1"]="11.7|https://developer.download.nvidia.com/compute/cuda/11.7.1/local_installers/cuda_11.7.1_515.65.01_linux.run|515.65.01"
    ["11.6.2"]="11.6|https://developer.download.nvidia.com/compute/cuda/11.6.2/local_installers/cuda_11.6.2_510.47.03_linux.run|510.47.03"
)

# cuDNN version mappings
# Format: CUDA_MAJOR.MINOR|CUDNN_VERSION|DOWNLOAD_URL
declare -A CUDNN_VERSIONS=(
    # cuDNN for CUDA 12.x
    ["12.6"]="8.9.7|https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz"
    ["12.5"]="8.9.7|https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz"
    ["12.4"]="8.9.7|https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz"
    ["12.3"]="8.9.7|https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz"
    ["12.2"]="8.9.7|https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz"
    ["12.1"]="8.9.7|https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz"
    ["12.0"]="8.9.7|https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.9.7.29_cuda12-archive.tar.xz"

    # cuDNN for CUDA 11.x
    ["11.8"]="8.9.7|https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.9.7.29_cuda11-archive.tar.xz"
    ["11.7"]="8.9.7|https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.9.7.29_cuda11-archive.tar.xz"
    ["11.6"]="8.6.0|https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.6.0.163_cuda11-archive.tar.xz"
)

################################################################################
# Global Variables
################################################################################

CUDA_VERSION=""
CUDA_MAJOR_MINOR=""
CUDA_DOWNLOAD_URL=""
CUDA_DRIVER_VERSION=""
CUDNN_VERSION=""
CUDNN_DOWNLOAD_URL=""
CUDA_INSTALL_DIR=""
DOWNLOAD_DIR="/tmp/cuda_install_$$"
STATE_FILE="$DOWNLOAD_DIR/install_state.txt"

################################################################################
# Utility Functions
################################################################################

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (sudo)"
        exit 1
    fi
}

# Parse version info
parse_version() {
    local version=$1

    if [[ -z "${CUDA_VERSIONS[$version]}" ]]; then
        return 1
    fi

    IFS='|' read -r major_minor url driver <<< "${CUDA_VERSIONS[$version]}"
    CUDA_MAJOR_MINOR="$major_minor"
    CUDA_DOWNLOAD_URL="$url"
    CUDA_DRIVER_VERSION="$driver"

    if [[ -z "${CUDNN_VERSIONS[$major_minor]}" ]]; then
        error "No cuDNN mapping found for CUDA $major_minor"
        return 1
    fi

    IFS='|' read -r cudnn_ver cudnn_url <<< "${CUDNN_VERSIONS[$major_minor]}"
    CUDNN_VERSION="$cudnn_ver"
    CUDNN_DOWNLOAD_URL="$cudnn_url"

    CUDA_INSTALL_DIR="/usr/local/cuda-$major_minor"

    return 0
}

# Interactive version selection
select_version_interactive() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Available CUDA Versions"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "CUDA 12.x (Latest):"
    echo "  1) 12.6.2 (Recommended for Gorgonia)"
    echo "  2) 12.6.1"
    echo "  3) 12.5.1"
    echo "  4) 12.4.1"
    echo "  5) 12.3.2"
    echo ""
    echo "CUDA 11.x (Stable):"
    echo "  6) 11.8.0 (Most compatible)"
    echo "  7) 11.7.1"
    echo "  8) 11.6.2"
    echo ""
    echo "  0) Custom version"
    echo ""
    read -p "Select CUDA version to install [1-8, 0]: " choice

    case $choice in
        1) CUDA_VERSION="12.6.2" ;;
        2) CUDA_VERSION="12.6.1" ;;
        3) CUDA_VERSION="12.5.1" ;;
        4) CUDA_VERSION="12.4.1" ;;
        5) CUDA_VERSION="12.3.2" ;;
        6) CUDA_VERSION="11.8.0" ;;
        7) CUDA_VERSION="11.7.1" ;;
        8) CUDA_VERSION="11.6.2" ;;
        0)
            read -p "Enter CUDA version (e.g., 12.6.2, 11.8.0): " CUDA_VERSION
            ;;
        *)
            error "Invalid selection"
            exit 1
            ;;
    esac

    if ! parse_version "$CUDA_VERSION"; then
        error "Unsupported CUDA version: $CUDA_VERSION"
        error "Supported versions: ${!CUDA_VERSIONS[@]}"
        exit 1
    fi
}

################################################################################
# State Management
################################################################################

save_state() {
    local state=$1
    echo "$state" > "$STATE_FILE"
    debug "State saved: $state"
}

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "START"
    fi
}

################################################################################
# Installation State Checks
################################################################################

check_installation_state() {
    local state="START"

    # Check if CUDA is installed
    if [[ -d "$CUDA_INSTALL_DIR" ]]; then
        if [[ -f "$CUDA_INSTALL_DIR/bin/nvcc" ]]; then
            local installed_version=$("$CUDA_INSTALL_DIR/bin/nvcc" --version 2>/dev/null | grep "release" | awk '{print $5}' | cut -d',' -f1 || echo "unknown")

            if [[ "$installed_version" == "$CUDA_MAJOR_MINOR"* ]]; then
                state="CUDA_INSTALLED"

                # Check if cuDNN is installed
                if [[ -f "$CUDA_INSTALL_DIR/include/cudnn.h" ]] && [[ -f "$CUDA_INSTALL_DIR/lib64/libcudnn.so" ]]; then
                    state="CUDNN_INSTALLED"

                    # Check if environment is configured
                    if [[ -f "/usr/local/bin/use-cuda${CUDA_MAJOR_MINOR/./}" ]]; then
                        state="COMPLETE"
                    fi
                fi
            fi
        fi
    fi

    # Check if downloads exist
    if [[ -f "$DOWNLOAD_DIR/cuda_${CUDA_VERSION}_linux.run" ]]; then
        if [[ "$state" == "START" ]]; then
            state="CUDA_DOWNLOADED"
        fi
    fi

    if [[ -f "$DOWNLOAD_DIR/cudnn.tar.xz" ]]; then
        if [[ "$state" == "CUDA_DOWNLOADED" ]] || [[ "$state" == "CUDA_INSTALLED" ]]; then
            state="CUDNN_DOWNLOADED"
        fi
    fi

    echo "$state"
}

################################################################################
# Prerequisites Check
################################################################################

check_prerequisites() {
    step "Checking prerequisites..."

    # Check if nvidia-smi works
    if ! command -v nvidia-smi &> /dev/null; then
        error "nvidia-smi not found. NVIDIA driver may not be installed."
        exit 1
    fi

    # Check driver version
    local driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)
    log "Current NVIDIA driver: $driver_version"

    # Check existing CUDA installations
    log "Existing CUDA installations:"
    for cuda_dir in /usr/local/cuda-*; do
        if [[ -d "$cuda_dir" ]] && [[ -f "$cuda_dir/bin/nvcc" ]]; then
            local ver=$("$cuda_dir/bin/nvcc" --version 2>/dev/null | grep "release" | awk '{print $5}' | cut -d',' -f1 || echo "unknown")
            log "  - $cuda_dir (version $ver)"
        fi
    done

    # Check disk space (need ~5GB)
    local available_space=$(df /usr/local | tail -1 | awk '{print $4}')
    local required_space=5242880  # 5GB in KB

    if [[ $available_space -lt $required_space ]]; then
        error "Insufficient disk space in /usr/local"
        error "Required: 5GB, Available: $((available_space / 1024 / 1024))GB"
        exit 1
    fi

    # Check for required tools
    for cmd in wget tar; do
        if ! command -v $cmd &> /dev/null; then
            error "$cmd is not installed. Please install it first."
            exit 1
        fi
    done

    success "Prerequisites check passed"
}

################################################################################
# Download Functions
################################################################################

download_cuda() {
    step "Downloading CUDA $CUDA_VERSION toolkit..."

    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"

    local cuda_file="cuda_${CUDA_VERSION}_linux.run"

    if [[ -f "$cuda_file" ]]; then
        log "CUDA installer already downloaded"
        local file_size=$(du -h "$cuda_file" | cut -f1)
        log "File size: $file_size"
    else
        log "Downloading from: $CUDA_DOWNLOAD_URL"
        warn "Download size: ~3.5-4.5GB (this may take 10-30 minutes)"

        if ! wget -c "$CUDA_DOWNLOAD_URL" -O "$cuda_file"; then
            error "Failed to download CUDA installer"
            exit 1
        fi
        success "CUDA toolkit downloaded"
    fi

    chmod +x "$cuda_file"
    save_state "CUDA_DOWNLOADED"
}

download_cudnn() {
    step "Downloading cuDNN $CUDNN_VERSION..."

    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"

    local cudnn_file="cudnn.tar.xz"

    if [[ -f "$cudnn_file" ]]; then
        log "cuDNN archive already downloaded"
        local file_size=$(du -h "$cudnn_file" | cut -f1)
        log "File size: $file_size"
    else
        log "Downloading from: $CUDNN_DOWNLOAD_URL"
        warn "Download size: ~700MB-1GB"
        warn "Note: cuDNN download may require NVIDIA Developer account authentication"

        if ! wget -c "$CUDNN_DOWNLOAD_URL" -O "$cudnn_file" 2>/dev/null; then
            warn "Automatic download failed (may require authentication)"
            echo ""
            echo "Please manually download cuDNN from:"
            echo "https://developer.nvidia.com/rdp/cudnn-archive"
            echo ""
            echo "Download: cuDNN v$CUDNN_VERSION for CUDA $CUDA_MAJOR_MINOR (Linux x86_64)"
            echo "Save as: $DOWNLOAD_DIR/$cudnn_file"
            echo ""
            read -p "Press Enter once you've downloaded the file..."

            if [[ ! -f "$cudnn_file" ]]; then
                error "cuDNN file not found at $DOWNLOAD_DIR/$cudnn_file"
                exit 1
            fi
        fi
        success "cuDNN downloaded"
    fi

    save_state "CUDNN_DOWNLOADED"
}

################################################################################
# Installation Functions
################################################################################

install_cuda_toolkit() {
    step "Installing CUDA $CUDA_VERSION toolkit to $CUDA_INSTALL_DIR..."

    local cuda_file="$DOWNLOAD_DIR/cuda_${CUDA_VERSION}_linux.run"

    if [[ ! -f "$cuda_file" ]]; then
        error "CUDA installer not found at $cuda_file"
        exit 1
    fi

    log "This will NOT modify your display driver or existing CUDA installations"
    log "Installation may take 5-15 minutes..."

    # Install only toolkit, no driver, no samples, no docs
    if "$cuda_file" \
        --toolkit \
        --toolkitpath="$CUDA_INSTALL_DIR" \
        --no-opengl-libs \
        --no-drm \
        --no-man-page \
        --override \
        --silent; then
        success "CUDA $CUDA_VERSION toolkit installed to $CUDA_INSTALL_DIR"
        save_state "CUDA_INSTALLED"
    else
        error "CUDA toolkit installation failed"
        exit 1
    fi
}

install_cudnn() {
    step "Installing cuDNN $CUDNN_VERSION to $CUDA_INSTALL_DIR..."

    local cudnn_file="$DOWNLOAD_DIR/cudnn.tar.xz"

    if [[ ! -f "$cudnn_file" ]]; then
        error "cuDNN archive not found at $cudnn_file"
        exit 1
    fi

    local extract_dir="$DOWNLOAD_DIR/cudnn_extract"
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"

    # Extract cuDNN
    log "Extracting cuDNN archive..."
    tar -xf "$cudnn_file" -C "$extract_dir"

    # Find the extracted directory
    local cudnn_dir=$(find "$extract_dir" -maxdepth 1 -type d -name "cudnn*" | head -n1)

    if [[ -z "$cudnn_dir" ]]; then
        error "Failed to extract cuDNN archive"
        exit 1
    fi

    log "Copying cuDNN files..."

    # Copy headers
    if [[ -d "$cudnn_dir/include" ]]; then
        cp -P "$cudnn_dir"/include/cudnn*.h "$CUDA_INSTALL_DIR/include/" 2>/dev/null || true
    fi

    # Copy libraries (check both lib and lib64)
    if [[ -d "$cudnn_dir/lib" ]]; then
        cp -P "$cudnn_dir"/lib/libcudnn* "$CUDA_INSTALL_DIR/lib64/" 2>/dev/null || true
    fi
    if [[ -d "$cudnn_dir/lib64" ]]; then
        cp -P "$cudnn_dir"/lib64/libcudnn* "$CUDA_INSTALL_DIR/lib64/" 2>/dev/null || true
    fi

    # Set permissions
    chmod a+r "$CUDA_INSTALL_DIR"/include/cudnn*.h 2>/dev/null || true
    chmod a+r "$CUDA_INSTALL_DIR"/lib64/libcudnn* 2>/dev/null || true

    # Clean up
    rm -rf "$extract_dir"

    # Verify installation
    if [[ -f "$CUDA_INSTALL_DIR/include/cudnn.h" ]] && [[ -f "$CUDA_INSTALL_DIR/lib64/libcudnn.so" ]]; then
        success "cuDNN $CUDNN_VERSION installed successfully"
        save_state "CUDNN_INSTALLED"
    else
        error "cuDNN installation verification failed"
        error "Expected files not found in $CUDA_INSTALL_DIR"
        exit 1
    fi
}

################################################################################
# Environment Setup
################################################################################

setup_environment() {
    step "Setting up environment configuration..."

    local version_tag="${CUDA_MAJOR_MINOR/./}"  # e.g., "126" from "12.6"

    # Create version-specific switcher script
    cat > "/usr/local/bin/use-cuda$version_tag" << EOF
#!/bin/bash
# Switch to CUDA $CUDA_MAJOR_MINOR
export CUDA_HOME=$CUDA_INSTALL_DIR
export PATH=\$CUDA_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH
export CGO_CFLAGS="-I\$CUDA_HOME/include"
export CGO_LDFLAGS="-L\$CUDA_HOME/lib64 -lcuda -lcudart -lcublas -lcudnn"
echo "Switched to CUDA $CUDA_MAJOR_MINOR"
echo "CUDA_HOME=\$CUDA_HOME"
EOF

    chmod +x "/usr/local/bin/use-cuda$version_tag"
    success "Created: /usr/local/bin/use-cuda$version_tag"

    # Update or create default profile
    local profile_file="/etc/profile.d/cuda-gorgonia.sh"

    cat > "$profile_file" << EOF
# CUDA environment for Gorgonia
# Auto-generated by install_cuda_alongside.sh

# Available CUDA installations
EOF

    # Add all installed CUDA versions
    for cuda_dir in /usr/local/cuda-*; do
        if [[ -d "$cuda_dir" ]] && [[ -f "$cuda_dir/bin/nvcc" ]]; then
            local ver=$(basename "$cuda_dir" | sed 's/cuda-//')
            echo "export CUDA_HOME_${ver/./}=$cuda_dir" >> "$profile_file"
        fi
    done

    cat >> "$profile_file" << EOF

# Default to CUDA $CUDA_MAJOR_MINOR
export CUDA_HOME=$CUDA_INSTALL_DIR
export PATH=\$CUDA_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH
export CGO_CFLAGS="-I\$CUDA_HOME/include"
export CGO_LDFLAGS="-L\$CUDA_HOME/lib64 -lcuda -lcudart -lcublas -lcudnn"
EOF

    chmod +x "$profile_file"
    success "Updated: $profile_file"

    save_state "COMPLETE"
}

################################################################################
# Verification
################################################################################

verify_installation() {
    step "Verifying installation..."

    local errors=0

    # Check CUDA directory
    if [[ ! -d "$CUDA_INSTALL_DIR" ]]; then
        error "CUDA installation directory not found: $CUDA_INSTALL_DIR"
        ((errors++))
    else
        success "CUDA directory exists"
    fi

    # Check nvcc
    if [[ -f "$CUDA_INSTALL_DIR/bin/nvcc" ]]; then
        local nvcc_version=$("$CUDA_INSTALL_DIR/bin/nvcc" --version | grep "release" | awk '{print $5}' | cut -d',' -f1)
        success "nvcc found: version $nvcc_version"
    else
        error "nvcc not found in CUDA installation"
        ((errors++))
    fi

    # Check cuDNN headers
    if [[ -f "$CUDA_INSTALL_DIR/include/cudnn.h" ]]; then
        success "cuDNN headers installed"
    else
        warn "cuDNN headers not found"
        ((errors++))
    fi

    # Check cuDNN libraries
    if [[ -f "$CUDA_INSTALL_DIR/lib64/libcudnn.so" ]]; then
        success "cuDNN libraries installed"
    else
        warn "cuDNN libraries not found"
        ((errors++))
    fi

    # Check environment scripts
    local version_tag="${CUDA_MAJOR_MINOR/./}"
    if [[ -f "/usr/local/bin/use-cuda$version_tag" ]]; then
        success "Environment switcher created: use-cuda$version_tag"
    else
        warn "Environment switcher not found"
        ((errors++))
    fi

    if [[ $errors -eq 0 ]]; then
        success "Installation verification complete - all checks passed!"
        return 0
    else
        warn "Installation verification found $errors issue(s)"
        return 1
    fi
}

################################################################################
# Display Final Instructions
################################################################################

show_completion_message() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  CUDA $CUDA_VERSION Installation Complete!"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Installation Details:"
    echo "  • CUDA Version: $CUDA_VERSION"
    echo "  • Install Path: $CUDA_INSTALL_DIR"
    echo "  • cuDNN Version: $CUDNN_VERSION"
    echo ""
    echo "Available CUDA Installations:"
    for cuda_dir in /usr/local/cuda-*; do
        if [[ -d "$cuda_dir" ]] && [[ -f "$cuda_dir/bin/nvcc" ]]; then
            local ver=$("$cuda_dir/bin/nvcc" --version 2>/dev/null | grep "release" | awk '{print $5}' | cut -d',' -f1 || echo "unknown")
            local tag=$(basename "$cuda_dir" | sed 's/cuda-//' | sed 's/\.//')
            echo "  • $cuda_dir (v$ver) - use: source /usr/local/bin/use-cuda$tag"
        fi
    done
    echo ""
    echo "Quick Start:"
    echo "  # Switch to CUDA $CUDA_MAJOR_MINOR"
    local version_tag="${CUDA_MAJOR_MINOR/./}"
    echo "  source /usr/local/bin/use-cuda$version_tag"
    echo ""
    echo "  # Verify installation"
    echo "  nvcc --version"
    echo ""
    echo "  # Build Gorgonia with CUDA"
    echo "  cd /home/gperry/Documents/GitHub/devtools/gorgonia"
    echo "  go build -tags=cuda ./cuda/..."
    echo ""
    echo "Notes:"
    echo "  • New terminals will use CUDA $CUDA_MAJOR_MINOR by default"
    echo "  • Your display driver was NOT modified"
    echo "  • No reboot required"
    echo "  • Download files kept at: $DOWNLOAD_DIR"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo ""
}

################################################################################
# Main Installation Flow
################################################################################

main() {
    # Header
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  CUDA Side-by-Side Installation Script"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    # Check root
    check_root

    # Get CUDA version
    if [[ -n "$1" ]]; then
        CUDA_VERSION="$1"
        log "Using specified CUDA version: $CUDA_VERSION"

        if ! parse_version "$CUDA_VERSION"; then
            error "Unsupported CUDA version: $CUDA_VERSION"
            echo ""
            echo "Supported versions:"
            for ver in "${!CUDA_VERSIONS[@]}"; do
                echo "  - $ver"
            done | sort -V
            exit 1
        fi
    else
        select_version_interactive
    fi

    # Display installation plan
    echo ""
    echo "Installation Plan:"
    echo "  • CUDA Version: $CUDA_VERSION"
    echo "  • CUDA Major.Minor: $CUDA_MAJOR_MINOR"
    echo "  • Install Directory: $CUDA_INSTALL_DIR"
    echo "  • cuDNN Version: $CUDNN_VERSION"
    echo "  • Download Size: ~4-5GB"
    echo ""

    # Check current state
    local current_state=$(check_installation_state)
    log "Current installation state: $current_state"

    if [[ "$current_state" == "COMPLETE" ]]; then
        success "CUDA $CUDA_VERSION is already fully installed!"

        read -p "Reinstall? This will verify and fix any issues (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            verify_installation
            show_completion_message
            exit 0
        fi

        # Reset state for reinstall
        current_state="START"
    fi

    # Confirm installation
    warn "This script will:"
    echo "  ✓ Install CUDA $CUDA_VERSION to $CUDA_INSTALL_DIR"
    echo "  ✓ Install cuDNN $CUDNN_VERSION"
    echo "  ✓ Create environment switcher scripts"
    echo ""
    warn "This script will NOT:"
    echo "  ✗ Modify your NVIDIA display driver"
    echo "  ✗ Remove or modify existing CUDA installations"
    echo "  ✗ Affect your display or GUI"
    echo ""

    read -p "Continue with installation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Installation cancelled by user"
        exit 0
    fi

    # Run prerequisites check
    check_prerequisites

    # Execute installation steps based on current state
    case "$current_state" in
        START)
            download_cuda
            ;&  # Fall through
        CUDA_DOWNLOADED)
            download_cudnn
            ;&  # Fall through
        CUDNN_DOWNLOADED)
            install_cuda_toolkit
            ;&  # Fall through
        CUDA_INSTALLED)
            install_cudnn
            ;&  # Fall through
        CUDNN_INSTALLED)
            setup_environment
            ;;
    esac

    # Verify installation
    verify_installation

    # Show completion message
    show_completion_message

    success "Installation complete!"
}

################################################################################
# Script Entry Point
################################################################################

# Trap errors
trap 'error "Installation failed at line $LINENO. State saved for resume."; exit 1' ERR

# Run main function
main "$@"
