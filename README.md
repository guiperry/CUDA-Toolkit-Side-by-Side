# CUDA Toolkit Side-by-Side Installation Script

**Version:** 2.0
**Repository:** [https://github.com/guiperry/CUDA-Toolkit-Side-by-Side](https://github.com/guiperry/CUDA-Toolkit-Side-by-Side)

A safe, intelligent script for installing multiple CUDA toolkit versions side-by-side without breaking your system or display drivers.

## ✨ Features

- 🔄 **Version Agnostic**: Install any CUDA version, even future releases
- 🛡️ **Safe**: Never modifies display drivers or existing CUDA installations
- 🎯 **Smart Resume**: Automatically detects state and resumes interrupted installations
- 📦 **Automatic Downloads**: Fetches CUDA toolkit and cuDNN automatically
- 🔌 **Custom URLs**: Support for bleeding-edge or custom CUDA builds
- ✅ **Validation**: Verifies each step of the installation process
- 🌐 **Multi-Version**: Manage unlimited CUDA versions simultaneously

## 🚀 Quick Start

### Interactive Mode (Recommended)
```bash
sudo ./install_cuda_alongside.sh
```

### Install Specific Version
```bash
sudo ./install_cuda_alongside.sh -v 12.6.2
```

### Install Future/Custom Version
```bash
sudo ./install_cuda_alongside.sh -v 13.0.0 \
  -u https://developer.nvidia.com/compute/cuda/13.0.0/local_installers/cuda_13.0.0_linux.run
```

## 📋 Requirements

### System Requirements
- **OS**: Linux (Ubuntu, Debian, RHEL, CentOS, Fedora)
- **Disk Space**: 5GB free in `/usr/local`
- **Tools**: `wget`, `tar` (auto-checked by script)
- **Permissions**: Must run as root (`sudo`)

### NVIDIA Driver
- Display driver must already be installed
- Driver version should support your target CUDA version:
  - CUDA 12.x: Driver 525.60.13+ (Linux) or 528.33+ (Windows)
  - CUDA 11.x: Driver 470.57.02+ (Linux) or 471.11+ (Windows)

**Note:** The script does NOT install or modify display drivers!

## 📖 Usage

### Command Line Options

```
Usage: sudo ./install_cuda_alongside.sh [OPTIONS]

Options:
  -v VERSION         CUDA version to install (e.g., 12.6.2, 11.8.0)
  -u URL            Custom CUDA download URL
  -d URL            Custom cuDNN download URL
  -c VERSION        Custom cuDNN version
  -i                Interactive mode (default)
  --list            List all known CUDA versions
  --help            Show help message

Examples:
  # Interactive mode with menu
  sudo ./install_cuda_alongside.sh

  # Install specific version
  sudo ./install_cuda_alongside.sh -v 12.6.2

  # Install with custom CUDA URL (for new versions)
  sudo ./install_cuda_alongside.sh -v 12.7.0 \
    -u https://developer.nvidia.com/.../cuda_12.7.0_linux.run

  # Install with custom cuDNN
  sudo ./install_cuda_alongside.sh -v 12.6.2 \
    -d https://developer.nvidia.com/.../cudnn-12-linux-x64-v9.0.0.tar.xz \
    -c 9.0.0

  # List known versions
  ./install_cuda_alongside.sh --list
```

### Interactive Mode

When run without arguments, the script presents an interactive menu:

```
════════════════════════════════════════════════════════════════
  Available CUDA Versions
════════════════════════════════════════════════════════════════

CUDA 12.x (Latest):
  1) 12.6.2 (Recommended)
  2) 12.6.1
  3) 12.5.1
  ...

CUDA 11.x (Stable):
  6) 11.8.0 (Most compatible)
  7) 11.7.1
  ...

  0) Custom version (provide URL)
```

## 🔧 How It Works

### Installation Process

1. **Prerequisites Check**
   - Verifies NVIDIA driver is installed
   - Checks available disk space (5GB minimum)
   - Validates required tools (`wget`, `tar`)

2. **State Detection**
   - Scans for existing CUDA installations
   - Detects partial installations
   - Determines resume point if interrupted

3. **Download**
   - Downloads CUDA toolkit (~3.5-4.5GB)
   - Downloads cuDNN (~700MB-1GB)
   - Resumes interrupted downloads

4. **Installation**
   - Installs CUDA toolkit to `/usr/local/cuda-X.Y/`
   - Installs cuDNN libraries and headers
   - Creates environment switcher scripts

5. **Configuration**
   - Sets up version switcher commands
   - Configures default CUDA environment
   - Generates shell integration scripts

6. **Verification**
   - Validates `nvcc` installation
   - Checks cuDNN headers and libraries
   - Verifies environment scripts

### Directory Structure

After installation, your system will have:

```
/usr/local/
├── cuda-11.8/          # CUDA 11.8 installation
├── cuda-12.6/          # CUDA 12.6 installation
├── cuda-13.0/          # CUDA 13.0 installation (if installed)
└── cuda -> cuda-12.6   # Symlink (optional)

/usr/local/bin/
├── use-cuda118         # Switch to CUDA 11.8
├── use-cuda126         # Switch to CUDA 12.6
└── use-cuda130         # Switch to CUDA 13.0

/etc/profile.d/
└── cuda-env.sh         # Default CUDA environment
```

## 🔄 Switching CUDA Versions

### Temporary Switch (Current Shell)
```bash
# Switch to CUDA 12.6
source /usr/local/bin/use-cuda126

# Verify
nvcc --version
echo $CUDA_HOME
```

### Permanent Switch (Default)
Edit `/etc/profile.d/cuda-env.sh` and change the default CUDA_HOME:

```bash
# Default to CUDA 12.6
export CUDA_HOME=/usr/local/cuda-12.6
```

### Per-Project Configuration
Add to your project's `.envrc` or activation script:

```bash
# .envrc (for direnv)
source /usr/local/bin/use-cuda126

# Or manually
export CUDA_HOME=/usr/local/cuda-12.6
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
```

### System-Wide Switch (update-alternatives)

The installation script (v2.1+) automatically registers CUDA versions with Linux's `update-alternatives` system. This provides system-wide version management.

#### View Available Versions
```bash
# Display all registered CUDA versions
update-alternatives --display cuda
```

Output example:
```
cuda - auto mode
  link best version is /usr/local/cuda-12.6
  link currently points to /usr/local/cuda-12.6
  link cuda is /usr/local/cuda
/usr/local/cuda-11.8 - priority 118
/usr/local/cuda-12.6 - priority 126
/usr/local/cuda-13.0 - priority 130
```

#### Switch CUDA Version
```bash
# Interactive selection menu
sudo update-alternatives --config cuda
```

This will show a menu:
```
There are 3 choices for the alternative cuda (providing /usr/local/cuda).

  Selection    Path                      Priority   Status
------------------------------------------------------------
* 0            /usr/local/cuda-13.0       130       auto mode
  1            /usr/local/cuda-11.8       118       manual mode
  2            /usr/local/cuda-12.6       126       manual mode
  3            /usr/local/cuda-13.0       130       manual mode

Press <enter> to keep the current choice[*], or type selection number:
```

#### Set Specific Version
```bash
# Set CUDA 12.6 as default
sudo update-alternatives --set cuda /usr/local/cuda-12.6

# Verify the change
readlink -f /usr/local/cuda
# Output: /usr/local/cuda-12.6
```

#### Update Library Cache
After switching versions, update the library cache:
```bash
sudo ldconfig
ldconfig -p | grep libcudart  # Verify correct libraries are found
```

#### Fix Symlinks for Older Installations

If you installed CUDA before the script included update-alternatives support, run:
```bash
sudo ./fix_current_cuda_symlinks.sh
```

This script will:
- Register all existing CUDA installations with update-alternatives
- Set CUDA 12.6 as the default (or specify a different version)
- Configure ldconfig properly
- Fix library resolution issues

## 📦 Adding New CUDA Versions

### Method 1: Update the Script (Permanent)

Edit the script and add to the `CUDA_VERSIONS` array:

```bash
declare -A CUDA_VERSIONS=(
    ...existing versions...
    ["13.0.0"]="13.0|https://developer.nvidia.com/.../cuda_13.0.0_linux.run|xxx.xx.xx"
)
```

Add corresponding cuDNN:

```bash
declare -A CUDNN_VERSIONS=(
    ...existing versions...
    ["13.0"]="9.0.0|https://developer.nvidia.com/.../cudnn-13-linux-x64-v9.0.0.tar.xz"
)
```

### Method 2: Custom URL (One-Time)

```bash
sudo ./install_cuda_alongside.sh \
  -v 13.0.0 \
  -u https://developer.download.nvidia.com/compute/cuda/13.0.0/local_installers/cuda_13.0.0_xxx.xx.xx_linux.run \
  -d https://developer.download.nvidia.com/compute/cudnn/.../cudnn-13-linux-x64-v9.0.0.tar.xz \
  -c 9.0.0
```

### Finding Download URLs

**CUDA Toolkit:**
1. Visit [NVIDIA CUDA Archive](https://developer.nvidia.com/cuda-toolkit-archive)
2. Select your desired version
3. Choose: Linux → x86_64 → runfile (local)
4. Copy the download URL

**cuDNN:**
1. Visit [cuDNN Archive](https://developer.nvidia.com/rdp/cudnn-archive)
2. Select version matching your CUDA version
3. Download "Local Installer for Linux x86_64 (Tar)"
4. Note: Requires NVIDIA Developer account (free)

## 🛡️ Safety Features

### What the Script Does NOT Do

- ❌ Does NOT modify your NVIDIA display driver
- ❌ Does NOT remove existing CUDA installations
- ❌ Does NOT affect your GUI or display
- ❌ Does NOT require a reboot
- ❌ Does NOT stop your display manager

### What the Script DOES Do

- ✅ Installs CUDA toolkit to separate directory
- ✅ Creates environment switcher scripts
- ✅ Validates installation at each step
- ✅ Saves state for resume capability
- ✅ Preserves all existing installations

### Rollback

If anything goes wrong, your system remains intact. To remove an installation:

```bash
# Remove CUDA installation
sudo rm -rf /usr/local/cuda-12.6

# Remove switcher script
sudo rm /usr/local/bin/use-cuda126

# Update environment file
sudo nano /etc/profile.d/cuda-env.sh
```

## 🔍 Troubleshooting

### Download Fails

**Problem:** `wget` fails to download CUDA or cuDNN

**Solutions:**
1. Check internet connection
2. Verify URL is correct (visit in browser)
3. For cuDNN, ensure you're logged into NVIDIA Developer account
4. Try manual download and place in `/tmp/cuda_install_*/`

### Installation Hangs

**Problem:** CUDA installer appears frozen

**Solution:** The installer is running silently. Wait 5-15 minutes.

### Driver Version Mismatch

**Problem:** "Driver version XXX insufficient"

**Solution:**
- Check your driver: `nvidia-smi`
- Upgrade driver if needed: See [NVIDIA Driver Downloads](https://www.nvidia.com/Download/index.aspx)
- Or install older CUDA version compatible with your driver

### cuDNN Not Found

**Problem:** cuDNN download fails (requires authentication)

**Solution:**
1. Visit [cuDNN Archive](https://developer.nvidia.com/rdp/cudnn-archive)
2. Create free NVIDIA Developer account
3. Download manually
4. Save as `/tmp/cuda_install_*/cudnn.tar.xz`
5. Re-run script (it will detect existing file)

### Multiple Installations Conflict

**Problem:** Wrong CUDA version being used

**Solution:**
```bash
# Check what's active
which nvcc
echo $CUDA_HOME

# Explicitly switch
source /usr/local/bin/use-cuda126

# Verify
nvcc --version
```

## 📊 Supported CUDA Versions

### Pre-Configured Versions

| CUDA Version | cuDNN | Driver Requirement | Status |
|--------------|-------|-------------------|---------|
| 12.6.2 | 8.9.7 | 560.35.03+ | ✅ Recommended |
| 12.6.1 | 8.9.7 | 560.35.03+ | ✅ Stable |
| 12.5.1 | 8.9.7 | 555.42.06+ | ✅ Stable |
| 12.4.1 | 8.9.7 | 550.54.15+ | ✅ Stable |
| 11.8.0 | 8.9.7 | 520.61.05+ | ✅ Most Compatible |
| 11.7.1 | 8.9.7 | 515.65.01+ | ✅ Stable |

### Future Versions

Any CUDA version can be installed using custom URLs:

```bash
sudo ./install_cuda_alongside.sh -v VERSION -u URL
```

## 🎯 Use Cases

### Machine Learning Researchers
Install multiple CUDA versions for testing different frameworks:

```bash
sudo ./install_cuda_alongside.sh -v 12.6.2  # For PyTorch
sudo ./install_cuda_alongside.sh -v 11.8.0  # For TensorFlow
```

Switch based on your project:
```bash
# PyTorch project
source /usr/local/bin/use-cuda126

# TensorFlow project
source /usr/local/bin/use-cuda118
```

### Software Developers
Test compatibility across CUDA versions:

```bash
# Install all supported versions
for v in 11.8.0 12.4.1 12.6.2; do
    sudo ./install_cuda_alongside.sh -v $v
done

# Test script
for cuda in /usr/local/cuda-*; do
    export CUDA_HOME=$cuda
    export PATH=$CUDA_HOME/bin:$PATH
    make test
done
```

### System Administrators
Deploy specific CUDA versions for different users/projects without conflicts.

## 🤝 Contributing

Contributions are welcome! To add new CUDA versions to the pre-configured list:

1. Fork the repository
2. Add version to `CUDA_VERSIONS` array
3. Add corresponding `CUDNN_VERSIONS` entry
4. Test installation
5. Submit pull request

## 📄 License

This script is provided as-is for educational and research purposes.

## 🔗 Links

- **Repository:** [https://github.com/guiperry/CUDA-Toolkit-Side-by-Side](https://github.com/guiperry/CUDA-Toolkit-Side-by-Side)
- **NVIDIA CUDA:** [https://developer.nvidia.com/cuda-toolkit](https://developer.nvidia.com/cuda-toolkit)
- **NVIDIA cuDNN:** [https://developer.nvidia.com/cudnn](https://developer.nvidia.com/cudnn)
- **CUDA Archive:** [https://developer.nvidia.com/cuda-toolkit-archive](https://developer.nvidia.com/cuda-toolkit-archive)

## ⚠️ Disclaimer

This script modifies system directories and installs software. While designed to be safe:

- Always backup important data before running system modification scripts
- Review the script before running
- Test in a non-production environment first
- The author is not responsible for any system damage

## 📝 Changelog

### Version 2.0 (2025-12-15)
- Added support for custom CUDA URLs
- Implemented smart state detection and resume
- Added cuDNN version mapping
- Improved error handling and validation
- Added comprehensive help and documentation

### Version 1.0 (2025-12-15)
- Initial release
- Support for CUDA 11.x and 12.x
- Interactive and command-line modes
- Safe side-by-side installation

---

**Made with ❤️ for the CUDA development community**
