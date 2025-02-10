
#!/bin/zsh

# Check for root permissions
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo:"
    echo "sudo $0"
    exit 1
fi

echo "[+] Checking for Java..."
if ! command -v java &> /dev/null; then
    echo "[+] Installing OpenJDK..."
    apt-get update
    apt-get install -y openjdk-17-jdk
fi

# Set variables
SDK_DIR="$HOME/android-sdk"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip"
CMDLINE_TOOLS_ZIP="commandlinetools-linux.zip"

echo "[+] Downloading Android Command-Line Tools..."
wget -O "$CMDLINE_TOOLS_ZIP" "$CMDLINE_TOOLS_URL"

echo "[+] Creating correct directory structure..."
mkdir -p "$SDK_DIR/cmdline-tools/latest"

echo "[+] Extracting SDK..."
unzip -q "$CMDLINE_TOOLS_ZIP"
mv cmdline-tools/* "$SDK_DIR/cmdline-tools/latest/"
rm -rf cmdline-tools
rm "$CMDLINE_TOOLS_ZIP"

# Set correct permissions
echo "[+] Setting correct permissions..."
chmod +x "$SDK_DIR/cmdline-tools/latest/bin/"*
chown -R $SUDO_USER:$SUDO_USER "$SDK_DIR"

echo "⚙️ Configuring Environment Variables..."
ZSHRC="/home/$SUDO_USER/.zshrc"

# Add environment variables if not already present
grep -qxF 'export ANDROID_HOME=$HOME/android-sdk' "$ZSHRC" || echo 'export ANDROID_HOME=$HOME/android-sdk' >> "$ZSHRC"
grep -qxF 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH' "$ZSHRC" || echo 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$PATH' >> "$ZSHRC"
grep -qxF 'export PATH=$ANDROID_HOME/platform-tools:$PATH' "$ZSHRC" || echo 'export PATH=$ANDROID_HOME/platform-tools:$PATH' >> "$ZSHRC"
grep -qxF 'export PATH=$ANDROID_HOME/emulator:$PATH' "$ZSHRC" || echo 'export PATH=$ANDROID_HOME/emulator:$PATH' >> "$ZSHRC"
grep -qxF 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' "$ZSHRC" || echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> "$ZSHRC"

# Fix ownership of .zshrc
chown $SUDO_USER:$SUDO_USER "$ZSHRC"

# Apply changes (as the original user)
su - $SUDO_USER -c "source $ZSHRC"

echo "📦 Installing Essential SDK Packages..."
# Run sdkmanager as the original user
su - $SUDO_USER -c "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 $SDK_DIR/cmdline-tools/latest/bin/sdkmanager --sdk_root=$SDK_DIR --licenses"
su - $SUDO_USER -c "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 $SDK_DIR/cmdline-tools/latest/bin/sdkmanager --sdk_root=$SDK_DIR \"platform-tools\" \"platforms;android-34\" \"build-tools;34.0.0\""

echo "✅ Setup complete! Verifying installation..."

# Verify installation
if [ -f "$SDK_DIR/platform-tools/adb" ]; then
    su - $SUDO_USER -c "$SDK_DIR/platform-tools/adb version"
    su - $SUDO_USER -c "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 $SDK_DIR/cmdline-tools/latest/bin/sdkmanager --sdk_root=$SDK_DIR --list"
    echo "[+] Android SDK is now configured! Please restart your terminal to apply changes."
else
    echo "❌ Installation might have failed. Please check the error messages above."
fi
