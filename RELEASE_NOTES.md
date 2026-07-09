# Release Notes - Autonomous Project: Android SDK & Emulator Setup Script (v1.1.0)

We are excited to release **v1.1.0** of the Android SDK installation and setup suite for the **Autonomous** project. This update brings shell compatibility bug fixes, user convenience enhancements, and automated emulator/virtual device configurations.

---

## 🚀 Key Features

### 1. Android Virtual Device (AVD) & Emulator Setup
- **Automated Creation**: Seamlessly downloads and configures the Android Emulator and a dynamic `google_apis` system image.
- **Pre-Download Size Estimates**: Connects to Google's official XML image repository metadata to display exact download package sizes for the Emulator and System Image before starting the download.
- **AVD Manager Integration**: Automatically generates the virtual device (`Android_<API_LEVEL>`) with the correct CPU architecture (supporting both `x86_64` and `arm64-v8a` via dynamic `uname -m` detection).

### 2. Intelligent Existing SDK Detection
- Automatically detects existing installations of the Android SDK inside the target directory.
- Avoids redundant downloads of command-line tools if they are already present, saving significant bandwidth and time.

### 3. Non-Root (Sudo-free) Execution
- The script no longer requires administrative (`root`/`sudo`) privileges if OpenJDK 17 is already installed on the system.
- Automatically handles permission checking and avoids password prompting loops by running commands natively under the active user's shell context.

---

## 🛠️ Bug Fixes & Under-the-Hood Improvements

- **Interpreter Fix**: Resolved duplicate shebangs and moved from `zsh` target fallback to `/bin/bash` for robust POSIX script execution across Debian/Ubuntu/ParrotOS distributions.
- **Variable Scope Fix**: Corrected the misuse of top-level `local` variable keywords which caused standard shell syntax execution errors.
- **Dynamic User Elevation**: Added the `run_as_normal_user` elevation wrapper which intelligently skips `su -` switching when the current execution context is already user-owned.
- **Clean Temp File Handling**: Cleaned up package metadata and directory configuration routines.

---

## 📦 Changes Breakdown

| Component | Status | Description |
| :--- | :--- | :--- |
| **Java Dependency** | Enhanced | Swapped generic `java` command check to verify path `/usr/lib/jvm/java-17-openjdk-amd64`. |
| **Command-Line Tools** | Optimized | Skips fetching/unzipping commandlinetools-linux.zip when `sdkmanager` binary exists. |
| **Emulator & Sys-Image** | Added | Integrated size query from Google repositories and configured automated AVD creation. |
| **README.md** | Updated | Added documentation on running without root and setting up emulators. |

> [!TIP]
> To run the script and download the new packages, simply execute:
> ```bash
> ./setup-android-SDK.sh
> ```
> Follow the interactive prompts to define your target API level and configure the virtual emulator.
