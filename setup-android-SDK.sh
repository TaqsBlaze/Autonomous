#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print helpers
info() { echo -e "${BLUE}[+]${NC} $1"; }
success() { echo -e "${GREEN}[✅]${NC} $1"; }
warning() { echo -e "${YELLOW}[⚠️]${NC} $1"; }
error() { echo -e "${RED}[❌]${NC} $1"; }

# Check for root permissions only if Java 17 is not installed
if [ "$EUID" -ne 0 ] && [ ! -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then 
    error "Java 17 is not installed and installing it requires root privileges. Please run with sudo:"
    echo "sudo $0"
    exit 1
fi

# Detect non-root user and home directory
if [ -n "$SUDO_USER" ]; then
    NORMAL_USER="$SUDO_USER"
else
    NORMAL_USER=$(logname 2>/dev/null || echo "$USER")
fi

USER_HOME=$(getent passwd "$NORMAL_USER" | cut -d: -f6)
if [ -z "$USER_HOME" ]; then
    USER_HOME="/home/$NORMAL_USER"
fi

# Run command as normal user if running as root, otherwise run directly
run_as_normal_user() {
    if [ "$EUID" -eq 0 ]; then
        su - "$NORMAL_USER" -c "$1"
    else
        eval "$1"
    fi
}

# Helper to fetch remote file size in MB
get_remote_size_mb() {
    local url="$1"
    local size_bytes=""
    if command -v curl &> /dev/null; then
        size_bytes=$(curl -sIL "$url" | grep -i "^content-length" | tail -n 1 | awk '{print $2}' | tr -d '\r')
    elif command -v wget &> /dev/null; then
        size_bytes=$(wget --spider --server-response "$url" 2>&1 | grep -i "^content-length" | tail -n 1 | awk '{print $2}' | tr -d '\r')
    fi
    
    if [ -n "$size_bytes" ] && [ "$size_bytes" -eq "$size_bytes" ] 2>/dev/null; then
        awk -v bytes="$size_bytes" 'BEGIN {printf "%.2f", bytes / 1048576}'
    else
        echo "unknown"
    fi
}

# Helper to fetch apt package size in MB
get_apt_package_size_mb() {
    local package="$1"
    local size_bytes=""
    if command -v apt-cache &> /dev/null; then
        size_bytes=$(apt-cache show "$package" 2>/dev/null | grep -E "^Size:" | head -n 1 | awk '{print $2}')
    fi
    if [ -n "$size_bytes" ] && [ "$size_bytes" -eq "$size_bytes" ] 2>/dev/null; then
        awk -v bytes="$size_bytes" 'BEGIN {printf "%.2f", bytes / 1048576}'
    else
        echo "unknown"
    fi
}

# Helper to parse Google SDK Repository XML for package sizes
get_sdk_package_size_mb() {
    local target_path="$1"
    local xml_file="${2:-/tmp/repository2-1.xml}"
    if [ ! -f "$xml_file" ]; then
        echo "unknown"
        return
    fi
    local size_bytes=$(awk -v path="$target_path" '
    BEGIN { in_pkg = 0; pkg_content = ""; }
    $0 ~ "<remotePackage path=\"" path "\">" {
        in_pkg = 1;
        pkg_content = $0;
        next;
    }
    in_pkg {
        pkg_content = pkg_content "\n" $0;
        if ($0 ~ "</remotePackage>") {
            in_pkg = 0;
            n = split(pkg_content, archives, "<archive>");
            best_size = "";
            for (i = 2; i <= n; i++) {
                block = archives[i];
                
                # Find size
                s_start = index(block, "<size>")
                if (s_start > 0) {
                    s_end = index(block, "</size>")
                    size = substr(block, s_start + 6, s_end - s_start - 6)
                } else {
                    size = ""
                }
                
                # Find host-os
                h_start = index(block, "<host-os>")
                if (h_start > 0) {
                    h_end = index(block, "</host-os>")
                    host_os = substr(block, h_start + 9, h_end - h_start - 9)
                    has_host_os = 1
                } else {
                    host_os = ""
                    has_host_os = 0
                }
                
                if (!has_host_os || host_os == "linux") {
                    best_size = size;
                    if (host_os == "linux") {
                        print size;
                        exit;
                    }
                }
            }
            if (best_size != "") {
                print best_size;
                exit;
            }
        }
    }
    ' "$xml_file")
    
    if [ -n "$size_bytes" ] && [ "$size_bytes" -eq "$size_bytes" ] 2>/dev/null; then
        awk -v bytes="$size_bytes" 'BEGIN {printf "%.2f", bytes / 1048576}'
    else
        echo "unknown"
    fi
}

# 1. Interactive Directory Configuration
DEFAULT_SDK_DIR="$USER_HOME/android-sdk"
echo -n "Enter the installation directory for Android SDK [$DEFAULT_SDK_DIR]: "
read -r user_sdk_dir
SDK_DIR=${user_sdk_dir:-$DEFAULT_SDK_DIR}
if [[ "$SDK_DIR" != /* ]]; then
    SDK_DIR="$(realpath -m "$SDK_DIR")"
fi

SDK_EXISTS=false
if [ -f "$SDK_DIR/cmdline-tools/latest/bin/sdkmanager" ]; then
    SDK_EXISTS=true
    success "Existing Android SDK detected at $SDK_DIR."
fi

# 2. Check and Install Java
info "Checking for Java..."
if [ ! -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
    java_size=$(get_apt_package_size_mb "openjdk-17-jdk")
    warning "Java 17 is not installed. OpenJDK 17 is required."
    if [ "$java_size" != "unknown" ]; then
        info "OpenJDK 17 package download size: ~ $java_size MB"
    fi
    echo -n "Would you like to install OpenJDK 17 now? [Y/n]: "
    read -r install_java
    case "$install_java" in
        [nN][oO]|[nN])
            error "Java 17 is required to run the Android SDK tools. Exiting."
            exit 1
            ;;
        *)
            info "Installing OpenJDK 17..."
            apt-get update
            apt-get install -y openjdk-17-jdk
            ;;
    esac
else
    success "Java 17 is already installed: $(/usr/lib/jvm/java-17-openjdk-amd64/bin/java -version 2>&1 | head -n 1)"
fi

# Set variables
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip"
CMDLINE_TOOLS_ZIP="commandlinetools-linux.zip"

# Fetch metadata for SDK packages
info "Fetching package metadata from Google repository..."
XML_FILE="/tmp/repository2-1.xml"
if ! curl -s -o "$XML_FILE" https://dl.google.com/android/repository/repository2-1.xml; then
    wget -q -O "$XML_FILE" https://dl.google.com/android/repository/repository2-1.xml
fi

# 3. Android Command-Line Tools
if [ "$SDK_EXISTS" = true ]; then
    info "Android Command-Line Tools already installed in $SDK_DIR/cmdline-tools/latest"
else
    info "Checking size for Android Command-Line Tools..."
    cmdline_tools_size=$(get_remote_size_mb "$CMDLINE_TOOLS_URL")
    if [ "$cmdline_tools_size" != "unknown" ]; then
        info "Android Command-Line Tools zip size: $cmdline_tools_size MB"
    else
        info "Android Command-Line Tools zip size: Unknown"
    fi

    echo -n "Download and install Android Command-Line Tools? [Y/n]: "
    read -r download_cmdline
    case "$download_cmdline" in
        [nN][oO]|[nN])
            if [ ! -d "$SDK_DIR/cmdline-tools/latest" ]; then
                error "Android Command-Line Tools are required for the SDK installation. Exiting."
                exit 1
            fi
            info "Using existing Command-Line Tools in $SDK_DIR/cmdline-tools/latest"
            ;;
        *)
            info "Downloading Android Command-Line Tools..."
            wget -O "$CMDLINE_TOOLS_ZIP" "$CMDLINE_TOOLS_URL"
            
            info "Creating directory structure..."
            mkdir -p "$SDK_DIR/cmdline-tools/latest"
            
            info "Extracting SDK..."
            unzip -q "$CMDLINE_TOOLS_ZIP"
            mv cmdline-tools/* "$SDK_DIR/cmdline-tools/latest/"
            rm -rf cmdline-tools
            rm "$CMDLINE_TOOLS_ZIP"
            ;;
    esac
fi

# Set correct permissions
info "Setting correct directory permissions..."
chmod +x "$SDK_DIR/cmdline-tools/latest/bin/"*
if [ "$EUID" -eq 0 ]; then
    chown -R "$NORMAL_USER:$NORMAL_USER" "$SDK_DIR"
fi

# 4. Configure Environment Variables
info "Configuring Environment Variables..."
ZSHRC="$USER_HOME/.zshrc"

# Determine path insertion style based on the SDK path
android_home_export=""
if [[ "$SDK_DIR" == "$USER_HOME"* ]]; then
    suffix="${SDK_DIR#$USER_HOME}"
    android_home_export='export ANDROID_HOME=$HOME'${suffix}
else
    android_home_export="export ANDROID_HOME=$SDK_DIR"
fi

# Add environment variables if not already present
grep -qxF "$android_home_export" "$ZSHRC" || echo "$android_home_export" >> "$ZSHRC"
grep -qxF 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH' "$ZSHRC" || echo 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH' >> "$ZSHRC"
grep -qxF 'export PATH=$ANDROID_HOME/platform-tools:$PATH' "$ZSHRC" || echo 'export PATH=$ANDROID_HOME/platform-tools:$PATH' >> "$ZSHRC"
grep -qxF 'export PATH=$ANDROID_HOME/emulator:$PATH' "$ZSHRC" || echo 'export PATH=$ANDROID_HOME/emulator:$PATH' >> "$ZSHRC"
grep -qxF 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' "$ZSHRC" || echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> "$ZSHRC"

# Fix ownership of .zshrc
if [ "$EUID" -eq 0 ]; then
    chown "$NORMAL_USER:$NORMAL_USER" "$ZSHRC"
fi

# 5. Interactive Package Selection
echo -n "Enter target Android API level (e.g. 34) [34]: "
read -r input_api_level
API_LEVEL=${input_api_level:-34}

if [ "$SDK_EXISTS" = true ]; then
    echo -n "Would you like to set up an Android Virtual Device (Emulator)? [Y/n]: "
    read -r setup_avd_prompt
    case "$setup_avd_prompt" in
        [nN][oO]|[nN])
            SETUP_AVD=false
            ;;
        *)
            SETUP_AVD=true
            ;;
    esac
    
    if [ "$SETUP_AVD" = false ]; then
        success "Android SDK is already configured and AVD setup skipped. Exiting."
        exit 0
    fi
    
    INSTALL_BASIC_PACKAGES=false
else
    echo -n "Enter target Build Tools version (e.g. 34.0.0) [${API_LEVEL}.0.0]: "
    read -r input_build_tools
    BUILD_TOOLS=${input_build_tools:-"${API_LEVEL}.0.0"}

    echo -n "Would you like to set up an Android Virtual Device (Emulator)? [Y/n]: "
    read -r setup_avd_prompt
    case "$setup_avd_prompt" in
        [nN][oO]|[nN])
            SETUP_AVD=false
            ;;
        *)
            SETUP_AVD=true
            ;;
    esac
    
    INSTALL_BASIC_PACKAGES=true
fi

# Retrieve size of SDK components
info "Querying download sizes for SDK components..."
pt_size="0"
plat_size="0"
bt_size="0"
if [ "$INSTALL_BASIC_PACKAGES" = true ]; then
    pt_size=$(get_sdk_package_size_mb "platform-tools")
    plat_size=$(get_sdk_package_size_mb "platforms;android-$API_LEVEL")
    bt_size=$(get_sdk_package_size_mb "build-tools;$BUILD_TOOLS")
fi

# Calculate system image architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    SYS_IMG_ARCH="x86_64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    SYS_IMG_ARCH="arm64-v8a"
else
    SYS_IMG_ARCH="x86_64"
fi

if [ "$SETUP_AVD" = true ]; then
    # Fetch system image metadata
    SYS_IMG_XML="/tmp/sys-img2-1.xml"
    if ! curl -s -o "$SYS_IMG_XML" https://dl.google.com/android/repository/sys-img/google_apis/sys-img2-1.xml; then
        wget -q -O "$SYS_IMG_XML" https://dl.google.com/android/repository/sys-img/google_apis/sys-img2-1.xml
    fi
    
    emulator_size=$(get_sdk_package_size_mb "emulator")
    sys_img_pkg="system-images;android-$API_LEVEL;google_apis;$SYS_IMG_ARCH"
    sys_img_size=$(get_sdk_package_size_mb "$sys_img_pkg" "$SYS_IMG_XML")
fi

echo -e "\n📦 Selected SDK Components & Download Sizes:"
if [ "$INSTALL_BASIC_PACKAGES" = true ]; then
    if [ "$pt_size" != "unknown" ]; then
        echo "  - platform-tools: $pt_size MB"
    else
        echo "  - platform-tools: Unknown size"
    fi

    if [ "$plat_size" != "unknown" ]; then
        echo "  - platforms;android-$API_LEVEL: $plat_size MB"
    else
        warning "platforms;android-$API_LEVEL: Package not found in Google repository, might be invalid."
    fi

    if [ "$bt_size" != "unknown" ]; then
        echo "  - build-tools;$BUILD_TOOLS: $bt_size MB"
    else
        warning "build-tools;$BUILD_TOOLS: Package not found in Google repository, might be invalid."
    fi
fi

if [ "$SETUP_AVD" = true ]; then
    if [ "$emulator_size" != "unknown" ]; then
        echo "  - emulator: $emulator_size MB"
    else
        echo "  - emulator: Unknown size"
    fi
    
    if [ "$sys_img_size" != "unknown" ]; then
        echo "  - $sys_img_pkg: $sys_img_size MB"
    else
        warning "$sys_img_pkg: Package not found in Google repository, might be invalid."
    fi
fi

# Calculate total size
total_size="0"
has_all_sizes=true
size_list=""
if [ "$INSTALL_BASIC_PACKAGES" = true ]; then
    size_list="$pt_size $plat_size $bt_size"
fi
if [ "$SETUP_AVD" = true ]; then
    size_list="$size_list $emulator_size $sys_img_size"
fi

for sz in $size_list; do
    if [ "$sz" = "unknown" ]; then
        has_all_sizes=false
    fi
done

if [ "$has_all_sizes" = true ]; then
    if [ "$INSTALL_BASIC_PACKAGES" = true ] && [ "$SETUP_AVD" = true ]; then
        total_size=$(awk -v pt="$pt_size" -v plat="$plat_size" -v bt="$bt_size" -v emu="$emulator_size" -v img="$sys_img_size" 'BEGIN {printf "%.2f", pt + plat + bt + emu + img}')
    elif [ "$INSTALL_BASIC_PACKAGES" = true ]; then
        total_size=$(awk -v pt="$pt_size" -v plat="$plat_size" -v bt="$bt_size" 'BEGIN {printf "%.2f", pt + plat + bt}')
    else
        total_size=$(awk -v emu="$emulator_size" -v img="$sys_img_size" 'BEGIN {printf "%.2f", emu + img}')
    fi
    echo "  ------------------------------------"
    echo -e "  Total download size: ${GREEN}$total_size MB${NC}\n"
else
    echo "  ------------------------------------"
    echo -e "  Total download size: ${YELLOW}Unknown${NC}\n"
fi

echo -n "Would you like to proceed with installing these SDK packages? [Y/n]: "
read -r install_packages
packages_installed=false

case "$install_packages" in
    [nN][oO]|[nN])
        warning "Skipping SDK package installation. You will need to install them manually."
        ;;
    *)
        info "Accepting licenses and installing essential SDK packages..."
        # Build list of packages to install
        packages=""
        if [ "$INSTALL_BASIC_PACKAGES" = true ]; then
            packages="\"platform-tools\" \"platforms;android-$API_LEVEL\" \"build-tools;$BUILD_TOOLS\""
        fi
        if [ "$SETUP_AVD" = true ]; then
            if [ -n "$packages" ]; then
                packages="$packages \"emulator\" \"system-images;android-$API_LEVEL;google_apis;$SYS_IMG_ARCH\""
            else
                packages="\"emulator\" \"system-images;android-$API_LEVEL;google_apis;$SYS_IMG_ARCH\""
            fi
        fi
        
        # Run sdkmanager as the original user
        run_as_normal_user "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 $SDK_DIR/cmdline-tools/latest/bin/sdkmanager --sdk_root=$SDK_DIR --licenses"
        if run_as_normal_user "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 $SDK_DIR/cmdline-tools/latest/bin/sdkmanager --sdk_root=$SDK_DIR $packages"; then
            packages_installed=true
        else
            error "Failed to install SDK packages."
        fi
        ;;
esac

# 6. Verification
if [ "$packages_installed" = true ]; then
    success "Setup complete! Verifying installation..."
    if [ -f "$SDK_DIR/platform-tools/adb" ]; then
        run_as_normal_user "$SDK_DIR/platform-tools/adb version"
        run_as_normal_user "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 $SDK_DIR/cmdline-tools/latest/bin/sdkmanager --sdk_root=$SDK_DIR --list"
        
        if [ "$SETUP_AVD" = true ]; then
            info "Creating Android Virtual Device (AVD)..."
            avd_cmd="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 $SDK_DIR/cmdline-tools/latest/bin/avdmanager create avd -n \"Android_$API_LEVEL\" -k \"system-images;android-$API_LEVEL;google_apis;$SYS_IMG_ARCH\" --force"
            if echo "no" | run_as_normal_user "$avd_cmd"; then
                success "Android Virtual Device 'Android_$API_LEVEL' created successfully!"
                info "To start the emulator, run:"
                info "emulator -avd Android_$API_LEVEL"
            else
                error "Failed to create Android Virtual Device."
            fi
        fi
        
        success "Android SDK is now configured! Please restart your terminal to apply changes."
    else
        error "Installation might have failed. 'adb' binary not found at $SDK_DIR/platform-tools/adb"
    fi
else
    success "Configuration complete! SDK base directory setup at $SDK_DIR."
    if [ "$SETUP_AVD" = true ]; then
        info "To install packages and create the AVD later, run:"
        info "sdkmanager \"platform-tools\" \"platforms;android-$API_LEVEL\" \"build-tools;$BUILD_TOOLS\" \"emulator\" \"system-images;android-$API_LEVEL;google_apis;$SYS_IMG_ARCH\""
        info "avdmanager create avd -n \"Android_$API_LEVEL\" -k \"system-images;android-$API_LEVEL;google_apis;$SYS_IMG_ARCH\""
    else
        info "To install packages later, run: sdkmanager \"platform-tools\" \"platforms;android-$API_LEVEL\" \"build-tools;$BUILD_TOOLS\""
    fi
fi
