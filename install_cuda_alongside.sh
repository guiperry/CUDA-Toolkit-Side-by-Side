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

# Progress spinner function
spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    echo -n "$message "
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %10 ))
        printf "\r$message ${spin:$i:1}"
        sleep 0.1
    done
    printf "\r$message ✓\n"
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
    ["11.4.4"]="11.4|https://developer.download.nvidia.com/compute/cuda/11.4.4/local_installers/cuda_11.4.4_470.82.01_linux.run|470.82.01"
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
    ["11.4"]="8.2.4|https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-8.2.4.15_cuda11-archive.tar.xz"
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
    echo "  9) 11.4.4 (Driver 470 compatible)"
    echo ""
    echo "  0) Custom version"
    echo ""
    read -p "Select CUDA version to install [1-9, 0]: " choice

    case $choice in
        1) CUDA_VERSION="12.6.2" ;;
        2) CUDA_VERSION="12.6.1" ;;
        3) CUDA_VERSION="12.5.1" ;;
        4) CUDA_VERSION="12.4.1" ;;
        5) CUDA_VERSION="12.3.2" ;;
        6) CUDA_VERSION="11.8.0" ;;
        7) CUDA_VERSION="11.7.1" ;;
        8) CUDA_VERSION="11.6.2" ;;
        9) CUDA_VERSION="11.4.4" ;;
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

check_driver_compatibility() {
    step "Checking driver compatibility..."

    # Get current driver version
    local driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)

    if [[ -z "$driver_version" ]]; then
        error "Could not determine NVIDIA driver version"
        return 1
    fi

    # Extract major version for comparison
    local driver_major=$(echo "$driver_version" | cut -d'.' -f1)
    local required_driver_major=$(echo "$CUDA_DRIVER_VERSION" | cut -d'.' -f1)

    log "Current driver: $driver_version"
    log "CUDA $CUDA_VERSION requires driver: $CUDA_DRIVER_VERSION (minimum)"

    # Check if driver meets minimum requirement
    if [[ $driver_major -lt $required_driver_major ]]; then
        warn "═══════════════════════════════════════════════════════════════"
        warn "  DRIVER COMPATIBILITY WARNING"
        warn "═══════════════════════════════════════════════════════════════"
        warn ""
        warn "Your NVIDIA driver version ($driver_version) may not be compatible"
        warn "with CUDA $CUDA_VERSION which requires driver $CUDA_DRIVER_VERSION or newer."
        warn ""
        warn "This may cause runtime errors like 'CUDA_ERROR_NOT_INITIALIZED'."
        warn ""
        warn "Recommended actions:"
        warn "  1) Choose a CUDA version compatible with your driver:"

        # Suggest compatible CUDA versions
        local suggested_versions=""
        for ver in "${!CUDA_VERSIONS[@]}"; do
            IFS='|' read -r _ _ req_driver <<< "${CUDA_VERSIONS[$ver]}"
            local req_major=$(echo "$req_driver" | cut -d'.' -f1)
            if [[ $driver_major -ge $req_major ]]; then
                suggested_versions="$suggested_versions $ver"
            fi
        done

        if [[ -n "$suggested_versions" ]]; then
            echo "$suggested_versions" | tr ' ' '\n' | sort -V | while read -r v; do
                if [[ -n "$v" ]]; then
                    warn "     - CUDA $v"
                fi
            done
        else
            warn "     - No compatible CUDA versions found in this script"
        fi

        warn "  2) Upgrade your NVIDIA driver to $CUDA_DRIVER_VERSION or newer"
        warn ""
        warn "═══════════════════════════════════════════════════════════════"
        warn ""

        read -p "Continue anyway? Installation may fail at runtime (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Installation cancelled. Please choose a compatible CUDA version."
            exit 0
        fi
        warn "Proceeding with potentially incompatible driver..."
    else
        success "Driver version is compatible with CUDA $CUDA_VERSION"
    fi
}

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

    # Check for both .tar.xz and .tgz files in current directory
    local cudnn_file=""
    local file_exists=false

    # Function to validate archive file
    validate_archive() {
        local file=$1
        # Check if it's a valid tar archive
        if tar -tzf "$file" &>/dev/null || tar -tJf "$file" &>/dev/null; then
            return 0
        else
            return 1
        fi
    }

    if [[ -f "cudnn.tar.xz" ]]; then
        if validate_archive "cudnn.tar.xz"; then
            cudnn_file="cudnn.tar.xz"
            file_exists=true
        else
            warn "Found cudnn.tar.xz but it's not a valid archive, removing..."
            rm -f "cudnn.tar.xz" &
            spinner $! "  Removing invalid file"
        fi
    fi

    if [[ "$file_exists" == false ]] && [[ -f "cudnn.tgz" ]]; then
        if validate_archive "cudnn.tgz"; then
            cudnn_file="cudnn.tgz"
            file_exists=true
        else
            warn "Found cudnn.tgz but it's not a valid archive, removing..."
            rm -f "cudnn.tgz" &
            spinner $! "  Removing invalid file"
        fi
    fi

    if [[ "$file_exists" == true ]]; then
        log "cuDNN archive already present in working directory: $cudnn_file"
        local file_size=$(du -h "$cudnn_file" | cut -f1)
        log "File size: $file_size"
        save_state "CUDNN_DOWNLOADED"
        return 0
    fi

    # File not in current directory, need to download or find it
    cudnn_file="cudnn.tar.xz"  # Default target filename
    log "cuDNN archive not found in $DOWNLOAD_DIR, will download or locate it..."

    if true; then  # Always try download first
        log "Downloading from: $CUDNN_DOWNLOAD_URL"
        warn "Download size: ~700MB-1GB"
        warn "Note: cuDNN download may require NVIDIA Developer account authentication"

        if ! wget -c "$CUDNN_DOWNLOAD_URL" -O "$cudnn_file" 2>/dev/null; then
            warn "Automatic download failed (may require authentication)"
            echo ""
            echo "════════════════════════════════════════════════════════════════"
            echo "  Manual cuDNN Download Required"
            echo "════════════════════════════════════════════════════════════════"
            echo ""
            echo "Please manually download cuDNN from:"
            echo "  https://developer.nvidia.com/rdp/cudnn-archive"
            echo ""
            echo "Download: cuDNN v$CUDNN_VERSION for CUDA $CUDA_MAJOR_MINOR (Linux x86_64)"
            echo ""
            echo "Common download locations to check:"
            echo "  - ~/Downloads/"
            echo "  - ~/"
            echo "  - Current directory"
            echo ""
            echo "The file should be named like:"
            echo "  cudnn-linux-x86_64-*_cuda${CUDA_MAJOR_MINOR/.}-archive.tar.xz"
            echo "  cudnn-${CUDA_MAJOR_MINOR}-linux-x64-v*.tgz"
            echo ""
            echo "════════════════════════════════════════════════════════════════"
            echo ""

            # Function to find cuDNN file
            find_cudnn_file() {
                # Get the real user's home directory (not root's when using sudo)
                local real_user="${SUDO_USER:-$USER}"
                local real_home=$(eval echo ~$real_user)

                local search_locations=(
                    "$real_home/Downloads"
                    "$real_home"
                )

                # Don't search in current DOWNLOAD_DIR to avoid finding invalid wget files
                # Send debug to stderr so it doesn't interfere with return value
                debug "Real user: $real_user, Real home: $real_home" >&2
                debug "Searching for cuDNN in: ${search_locations[*]}" >&2

                # Try multiple patterns for cuDNN files
                local patterns=(
                    "cudnn*linux*x86*64*cuda*${CUDA_MAJOR_MINOR/./}*.tar.xz"
                    "cudnn*linux*x86*64*cuda*${CUDA_MAJOR_MINOR/./}*.tgz"
                    "cudnn-${CUDA_MAJOR_MINOR}*linux*x86*64*.tar.xz"
                    "cudnn-${CUDA_MAJOR_MINOR}*linux*x86*64*.tgz"
                    "cudnn-${CUDA_MAJOR_MINOR}*linux*x64*.tar.xz"
                    "cudnn-${CUDA_MAJOR_MINOR}*linux*x64*.tgz"
                    "cudnn*.tar.xz"
                    "cudnn*.tgz"
                )

                for pattern in "${patterns[@]}"; do
                    debug "Trying pattern: $pattern" >&2
                    for location in "${search_locations[@]}"; do
                        if [[ -d "$location" ]]; then
                            debug "  Searching in: $location" >&2
                            local found_files=$(find "$location" -maxdepth 1 -type f -name "$pattern" 2>/dev/null | sort -r)
                            if [[ -n "$found_files" ]]; then
                                local found_file=$(echo "$found_files" | head -n1)
                                debug "  Found match: $found_file" >&2
                                echo "$found_file"
                                return 0
                            fi
                        else
                            debug "  Location does not exist: $location" >&2
                        fi
                    done
                done

                debug "No cuDNN file found in any location" >&2
                return 1
            }

            # Try to auto-detect the file
            log "Searching for cuDNN archive in common locations..."
            local found_file=$(find_cudnn_file)

            if [[ -n "$found_file" ]]; then
                success "Found cuDNN archive: $found_file"
                read -p "Use this file? (Y/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    # Preserve the file extension
                    local ext="${found_file##*.}"
                    if [[ "$ext" == "tgz" ]]; then
                        cudnn_file="cudnn.tgz"
                    else
                        cudnn_file="cudnn.tar.xz"
                    fi
                    log "Copying cuDNN archive to working directory as: $cudnn_file"
                    debug "Source: $found_file"
                    debug "Destination: $DOWNLOAD_DIR/$cudnn_file"

                    if cp "$found_file" "$cudnn_file"; then
                        success "cuDNN archive copied successfully"
                        local file_size=$(du -h "$cudnn_file" | cut -f1)
                        log "File size: $file_size"
                    else
                        error "Failed to copy cuDNN archive from $found_file to $cudnn_file"
                        found_file=""
                    fi
                else
                    log "User declined to use the found file"
                    found_file=""
                fi
            else
                warn "Auto-detection did not find any cuDNN archive"
            fi

            # If not found or user declined, ask for manual path
            while [[ ! -f "$cudnn_file" ]]; do
                echo ""
                read -p "Enter full path to cuDNN archive (or press Enter to search again): " user_path

                if [[ -z "$user_path" ]]; then
                    # Search again
                    found_file=$(find_cudnn_file)
                    if [[ -n "$found_file" ]]; then
                        log "Found: $found_file"
                        # Preserve the file extension
                        local ext="${found_file##*.}"
                        if [[ "$ext" == "tgz" ]]; then
                            cudnn_file="cudnn.tgz"
                        else
                            cudnn_file="cudnn.tar.xz"
                        fi
                        if cp "$found_file" "$cudnn_file" 2>/dev/null; then
                            success "cuDNN archive copied successfully"
                            break
                        else
                            warn "Failed to copy file (permission issue?)"
                            # Try with sudo
                            if sudo cp "$found_file" "$cudnn_file" 2>/dev/null; then
                                sudo chmod 644 "$cudnn_file"
                                success "cuDNN archive copied successfully (with sudo)"
                                break
                            else
                                error "Failed to copy even with sudo"
                            fi
                        fi
                    else
                        warn "cuDNN archive not found in common locations"
                        echo "Please download it manually and try again"
                    fi
                elif [[ -f "$user_path" ]]; then
                    log "Copying from: $user_path"
                    # Preserve the file extension
                    local ext="${user_path##*.}"
                    if [[ "$ext" == "tgz" ]]; then
                        cudnn_file="cudnn.tgz"
                    else
                        cudnn_file="cudnn.tar.xz"
                    fi
                    if cp "$user_path" "$cudnn_file" 2>/dev/null; then
                        success "cuDNN archive copied successfully"
                        local file_size=$(du -h "$cudnn_file" | cut -f1)
                        log "File size: $file_size"
                        break
                    else
                        warn "Failed to copy file (permission issue?)"
                        # Try with sudo
                        if sudo cp "$user_path" "$cudnn_file" 2>/dev/null; then
                            sudo chmod 644 "$cudnn_file"
                            success "cuDNN archive copied successfully (with sudo)"
                            break
                        else
                            error "Failed to copy file"
                        fi
                    fi
                else
                    error "File not found: $user_path"
                fi
            done
        fi
        success "cuDNN ready for installation"
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

    # Function to validate archive file
    validate_archive() {
        local file=$1
        # Check if it's a valid tar archive
        if tar -tzf "$file" &>/dev/null || tar -tJf "$file" &>/dev/null; then
            return 0
        else
            return 1
        fi
    }

    # Check for both .tar.xz and .tgz files and validate them
    local cudnn_file=""

    if [[ -f "$DOWNLOAD_DIR/cudnn.tar.xz" ]]; then
        if validate_archive "$DOWNLOAD_DIR/cudnn.tar.xz"; then
            cudnn_file="$DOWNLOAD_DIR/cudnn.tar.xz"
        else
            warn "Found cudnn.tar.xz but it's not a valid archive, removing..."
            rm -f "$DOWNLOAD_DIR/cudnn.tar.xz" &
            spinner $! "  Removing invalid file"
        fi
    fi

    if [[ -z "$cudnn_file" ]] && [[ -f "$DOWNLOAD_DIR/cudnn.tgz" ]]; then
        if validate_archive "$DOWNLOAD_DIR/cudnn.tgz"; then
            cudnn_file="$DOWNLOAD_DIR/cudnn.tgz"
        else
            warn "Found cudnn.tgz but it's not a valid archive, removing..."
            rm -f "$DOWNLOAD_DIR/cudnn.tgz" &
            spinner $! "  Removing invalid file"
        fi
    fi

    if [[ -z "$cudnn_file" ]]; then
        error "No valid cuDNN archive found at $DOWNLOAD_DIR/cudnn.tar.xz or $DOWNLOAD_DIR/cudnn.tgz"
        exit 1
    fi

    log "Using cuDNN archive: $cudnn_file"

    local extract_dir="$DOWNLOAD_DIR/cudnn_extract"
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"

    # Extract cuDNN
    log "Extracting cuDNN archive..."
    debug "Extraction command: tar -xf $cudnn_file -C $extract_dir"

    # Extract in background and show spinner
    tar -xf "$cudnn_file" -C "$extract_dir" &
    local extract_pid=$!

    spinner $extract_pid "  Extracting $(basename $cudnn_file)"

    # Check if extraction succeeded
    wait $extract_pid
    local extract_status=$?

    if [[ $extract_status -eq 0 ]]; then
        success "Archive extracted successfully"
    else
        error "Failed to extract cuDNN archive (exit code: $extract_status)"
        exit 1
    fi

    # Show what was extracted
    debug "Extracted contents:"
    ls -la "$extract_dir" >&2

    # Find the extracted directory - look for subdirectories, not the extract_dir itself
    # Try common patterns: cudnn*, cuda, or any subdirectory
    local cudnn_dir=""

    # First try cudnn* pattern
    cudnn_dir=$(find "$extract_dir" -maxdepth 1 -mindepth 1 -type d -name "cudnn*" 2>/dev/null | head -n1)

    # If not found, try cuda directory
    if [[ -z "$cudnn_dir" ]] && [[ -d "$extract_dir/cuda" ]]; then
        cudnn_dir="$extract_dir/cuda"
        log "Found 'cuda' directory"
    fi

    # If still not found, use first subdirectory
    if [[ -z "$cudnn_dir" ]]; then
        warn "No 'cudnn*' or 'cuda' directory found, checking for other directories..."
        cudnn_dir=$(find "$extract_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -n1)

        if [[ -z "$cudnn_dir" ]]; then
            error "No subdirectories found in extracted archive"
            error "Archive contents:"
            ls -la "$extract_dir"
            exit 1
        fi
        log "Using directory: $cudnn_dir"
    else
        log "Found cuDNN directory: $cudnn_dir"
    fi

    debug "cuDNN directory contents:"
    ls -la "$cudnn_dir" >&2

    log "Copying cuDNN files..."

    # Copy headers
    if [[ -d "$cudnn_dir/include" ]]; then
        log "Copying headers from $cudnn_dir/include/"
        debug "Header files found:"
        ls -la "$cudnn_dir/include/" | grep cudnn >&2
        local header_count=$(cp -Pv "$cudnn_dir"/include/cudnn*.h "$CUDA_INSTALL_DIR/include/" 2>&1 | tee /dev/stderr | wc -l)
        log "Copied $header_count header file(s)"
    else
        warn "No include directory found in $cudnn_dir"
    fi

    # Copy libraries (check both lib and lib64)
    local lib_copied=false
    if [[ -d "$cudnn_dir/lib" ]]; then
        log "Copying libraries from $cudnn_dir/lib/"
        debug "Library files found:"
        ls -la "$cudnn_dir/lib/" | grep libcudnn >&2
        local lib_count=$(cp -Pv "$cudnn_dir"/lib/libcudnn* "$CUDA_INSTALL_DIR/lib64/" 2>&1 | tee /dev/stderr | wc -l)
        log "Copied $lib_count library file(s) from lib/"
        lib_copied=true
    fi

    if [[ -d "$cudnn_dir/lib64" ]]; then
        log "Copying libraries from $cudnn_dir/lib64/"
        debug "Library files found:"
        ls -la "$cudnn_dir/lib64/" | grep libcudnn >&2
        local lib64_count=$(cp -Pv "$cudnn_dir"/lib64/libcudnn* "$CUDA_INSTALL_DIR/lib64/" 2>&1 | tee /dev/stderr | wc -l)
        log "Copied $lib64_count library file(s) from lib64/"
        lib_copied=true
    fi

    if [[ "$lib_copied" == false ]]; then
        warn "No lib or lib64 directory found in $cudnn_dir"
    fi

    # Set permissions
    log "Setting permissions..."
    chmod a+r "$CUDA_INSTALL_DIR"/include/cudnn*.h 2>/dev/null || true
    chmod a+r "$CUDA_INSTALL_DIR"/lib64/libcudnn* 2>/dev/null || true

    # Clean up
    log "Cleaning up temporary files..."
    rm -rf "$extract_dir"

    # Verify installation
    log "Verifying installation..."
    debug "Checking for: $CUDA_INSTALL_DIR/include/cudnn.h"
    debug "Checking for: $CUDA_INSTALL_DIR/lib64/libcudnn.so"

    if [[ -f "$CUDA_INSTALL_DIR/include/cudnn.h" ]]; then
        debug "✓ cudnn.h found"
    else
        debug "✗ cudnn.h NOT found"
        debug "Headers in include directory:"
        ls -la "$CUDA_INSTALL_DIR/include/" | grep -i cudnn >&2 || echo "No cuDNN headers found" >&2
    fi

    if [[ -f "$CUDA_INSTALL_DIR/lib64/libcudnn.so" ]]; then
        debug "✓ libcudnn.so found"
    else
        debug "✗ libcudnn.so NOT found"
        debug "Libraries in lib64 directory:"
        ls -la "$CUDA_INSTALL_DIR/lib64/" | grep -i cudnn >&2 || echo "No cuDNN libraries found" >&2
    fi

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

    # -------------------------------------------------------------------------
    # Configure update-alternatives for CUDA version management
    # -------------------------------------------------------------------------
    step "Configuring update-alternatives for CUDA $CUDA_MAJOR_MINOR..."

    # Calculate priority based on version (e.g., "12.6" -> 126, "13.0" -> 130)
    local priority=$(echo "$CUDA_MAJOR_MINOR" | sed 's/\.//' | sed 's/^0*//')

    # Check if this version is already registered
    if update-alternatives --query cuda 2>/dev/null | grep -q "$CUDA_INSTALL_DIR"; then
        log "CUDA $CUDA_MAJOR_MINOR already registered with update-alternatives"
        # Remove and re-add to update priority
        update-alternatives --remove cuda "$CUDA_INSTALL_DIR" 2>/dev/null || true
    fi

    # Register this CUDA version
    log "Registering CUDA $CUDA_MAJOR_MINOR with update-alternatives (priority: $priority)"
    update-alternatives --install /usr/local/cuda cuda "$CUDA_INSTALL_DIR" "$priority"

    # Set this version as the default
    log "Setting CUDA $CUDA_MAJOR_MINOR as default"
    update-alternatives --set cuda "$CUDA_INSTALL_DIR"

    success "/usr/local/cuda symlink configured via update-alternatives"

    # Verify the symlink
    local actual_target=$(readlink -f /usr/local/cuda)
    log "Verified: /usr/local/cuda -> $actual_target"

    # -------------------------------------------------------------------------
    # Configure ldconfig for library resolution
    # -------------------------------------------------------------------------
    step "Configuring ldconfig for CUDA $CUDA_MAJOR_MINOR..."

    local ldconfig_file="/etc/ld.so.conf.d/cuda-$CUDA_MAJOR_MINOR.conf"

    cat > "$ldconfig_file" << EOF
# CUDA $CUDA_MAJOR_MINOR library paths
# Auto-generated by install_cuda_alongside.sh
$CUDA_INSTALL_DIR/lib64
$CUDA_INSTALL_DIR/lib
$CUDA_INSTALL_DIR/targets/x86_64-linux/lib
EOF

    success "Created: $ldconfig_file"

    # Update ldconfig cache
    log "Updating library cache..."
    ldconfig

    success "Library cache updated"

    # Verify library resolution
    log "Verifying library resolution..."
    if ldconfig -p | grep -q "libcudart.so.*$CUDA_INSTALL_DIR"; then
        success "Libraries from CUDA $CUDA_MAJOR_MINOR are properly registered"
    else
        warn "Library resolution may need verification"
    fi

    # -------------------------------------------------------------------------
    # Create version-specific switcher script
    # -------------------------------------------------------------------------
    step "Creating environment switcher script..."

    cat > "/usr/local/bin/use-cuda$version_tag" << EOF
#!/bin/bash
# Switch to CUDA $CUDA_MAJOR_MINOR
export CUDA_HOME=$CUDA_INSTALL_DIR
export PATH=\$CUDA_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH
export CGO_CFLAGS="-I\$CUDA_HOME/include"
export CGO_LDFLAGS="-L\$CUDA_HOME/lib64 -lcuda -lcudart -lcublas -lcudnn"

# Go 1.23 compatibility for gorgonia CUDA
export ASSUME_NO_MOVING_GC_UNSAFE_RISK_IT_WITH=go1.23

echo "Switched to CUDA $CUDA_MAJOR_MINOR"
echo "CUDA_HOME=\$CUDA_HOME"
EOF

    chmod +x "/usr/local/bin/use-cuda$version_tag"
    success "Created: /usr/local/bin/use-cuda$version_tag"

    # -------------------------------------------------------------------------
    # Update system-wide profile
    # -------------------------------------------------------------------------
    step "Updating system-wide CUDA profile..."

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

# Go 1.23 compatibility for gorgonia CUDA
export ASSUME_NO_MOVING_GC_UNSAFE_RISK_IT_WITH=go1.23
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

    # Check driver compatibility
    check_driver_compatibility

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
            # Always ensure cuDNN file is present before installing
            download_cudnn
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
