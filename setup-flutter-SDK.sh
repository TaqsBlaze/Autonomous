#!/bin/zsh

# Check for root permissions
if [ "$EUID" -ne 0 ]; then 
    echo "[+] Please run with sudo: sudo $0"
    exit 1
fi

# Detect the current user (not root)
NORMAL_USER=$(logname)

# Flutter version (latest stable as of February 2025)
FLUTTER_VERSION="3.27.3"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

# Installation directory
INSTALL_DIR="/opt/flutter"

# Prepare the system
echo "[+] Preparing system for Flutter installation..."
apt-get update
apt-get install -y curl git unzip xz-utils zip wget

# Check if Android SDK is installed
if [ ! -d "$HOME/android-sdk" ]; then
    echo "[+] Warning: Android SDK not found. Please install Android SDK first."
fi

# Download Flutter
echo "[+] Downloading Flutter $FLUTTER_VERSION..."
mkdir -p /opt
wget -O flutter.tar.xz "$FLUTTER_URL"

# Extract Flutter
echo "[+] Extracting Flutter..."
tar xf flutter.tar.xz -C /opt
rm flutter.tar.xz

# Set permissions
echo "[+] Setting correct permissions..."
chown -R $NORMAL_USER:$NORMAL_USER /opt/flutter

# Configure environment variables
ZSHRC="/home/$NORMAL_USER/.zshrc"

# Add Flutter to PATH and set environment variables
{
    echo '# Flutter Configuration'
    echo 'export FLUTTER_HOME=/opt/flutter'
    echo 'export PATH=$FLUTTER_HOME/bin:$PATH'
} >> "$ZSHRC"

# Fix ownership of .zshrc
chown $NORMAL_USER:$NORMAL_USER "$ZSHRC"

# Prepare to run Flutter doctor as the normal user
su - $NORMAL_USER << 'EOT'
# Source the updated .zshrc
source ~/.zshrc

# Run Flutter doctor to set up
echo "[+] Running Flutter doctor..."
flutter doctor

# Check if any additional setup is needed
echo "✅ Flutter installation complete!"
echo "Please run 'flutter doctor' to verify your installation and resolve any dependencies."
EOT

# Print final instructions
echo "[+] Flutter has been installed successfully!"
echo "To complete setup:"
echo "1. Restart your terminal"
echo "2. Run 'flutter doctor' to check for any additional dependencies"
echo "3. Run 'flutter --version' to verify installation"
