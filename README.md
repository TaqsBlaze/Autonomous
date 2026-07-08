# Autonomous
----
### 🔧 Included Scripts  

1. **install-tools.sh** – Installs essential penetration testing tools to set up a powerful security testing environment.  
2. **setup-android-SDK.sh** – Downloads, installs, and configures the Android SDK. Features include:
   - **Smart Detection**: Detects existing SDK installations to skip unnecessary downloads.
   - **Non-Root Execution**: Runs without `sudo` if OpenJDK 17 is already present.
   - **AVD Setup**: Prompts to download system images and configure an Android Virtual Device (Emulator), showing download sizes beforehand.
3. **setup-flutter-SDK.sh** – Downloads, installs, and configures the Flutter SDK, providing a seamless setup for cross-platform app development.  

### 📌 How to Use  

Make the scripts executable and run them as needed:  

```sh
chmod +x install-tools.sh setup-android-SDK.sh setup-flutter-SDK.sh
./install-tools.sh
./setup-android-SDK.sh
./setup-flutter-SDK.sh
```

### ✅ Requirements
- Debian based system
- zsh shell  
- A Unix-based system (Linux/macOS)  
- `curl` and `wget` installed (for downloading dependencies)  
- Sufficient disk space for SDK installations  

### ⚡ What's New?  
- Automated installation for penetration testing tools  
- Hassle-free Android SDK and Flutter SDK setup  
- **Enhanced Android SDK Script**: Added non-root support, existing SDK detection, and automated Android Virtual Device (AVD) emulator setup with pre-download size estimates.
- Streamlined configuration to get started quickly  

📢 Feel free to contribute, suggest improvements, or report any issues! 🚀  

---
