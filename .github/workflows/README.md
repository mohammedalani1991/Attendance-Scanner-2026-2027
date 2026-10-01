# GitHub Actions CI/CD Workflows

This directory contains automated build workflows for the Attendance Scanner app.

## Available Workflows

### 1. Build Android APK (`build-apk.yml`)
Automatically builds Android APK files on every push/PR to main/master branch.

**What it builds:**
- Debug APK (for testing)
- Release APK (universal, works on all devices)
- Split APKs (optimized size per CPU architecture: arm64-v8a, armeabi-v7a, x86_64)

**How to use:**
1. Push your code to GitHub
2. Go to "Actions" tab in your repository
3. Wait for the build to complete (5-10 minutes)
4. Download the APK from "Artifacts" section

**Manual trigger:**
1. Go to "Actions" tab
2. Click "Build Android APK" workflow
3. Click "Run workflow" button
4. Wait for completion and download artifacts

### 2. Build iOS IPA (`build-ios.yml`)
Automatically builds iOS IPA files on every push/PR to main/master branch.

**What it builds:**
- Unsigned IPA file (for testing/archival)

**Important notes:**
- The IPA is **unsigned** and cannot be installed directly on devices
- For App Store distribution, you need:
  - Valid Apple Developer account ($99/year)
  - Proper code signing certificates
  - Provisioning profiles
  - Use Xcode or fastlane for production builds

**How to use:**
1. Push your code to GitHub
2. Go to "Actions" tab in your repository
3. Wait for the build to complete (10-15 minutes)
4. Download the IPA from "Artifacts" section

## Getting Started

### Step 1: Push to GitHub
```bash
# Initialize git (if not already)
git init
git add .
git commit -m "Initial commit with GitHub Actions workflows"

# Create a new repository on GitHub, then:
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git push -u origin main
```

### Step 2: Enable GitHub Actions
1. Go to your repository on GitHub
2. Click on "Actions" tab
3. GitHub Actions should be enabled by default
4. You'll see the workflows running automatically

### Step 3: Download Build Artifacts
1. Click on any completed workflow run
2. Scroll down to "Artifacts" section
3. Click on the artifact name to download:
   - `attendance-scanner-debug-apk` - Debug APK for testing
   - `attendance-scanner-release-apk` - Release APK (universal)
   - `attendance-scanner-split-apks` - Optimized APKs per architecture
   - `attendance-scanner-ios-ipa` - iOS IPA (unsigned)

## APK Installation Guide

### For Android:

**Release APK (Universal):**
1. Download `app-release.apk`
2. Transfer to your Android phone
3. Enable "Install from Unknown Sources" in Settings
4. Tap the APK file and install

**Split APKs (Smaller size):**
1. Download the split APK for your device:
   - `app-arm64-v8a-release.apk` - Modern phones (2016+)
   - `app-armeabi-v7a-release.apk` - Older phones
   - `app-x86_64-release.apk` - Emulators/tablets
2. If unsure, use arm64-v8a for most modern devices
3. Install same as universal APK

## IPA Installation Guide

### For iOS:

**Option 1: TestFlight (Recommended for distribution)**
1. Sign up for Apple Developer Program
2. Use Xcode to archive and upload to TestFlight
3. Invite testers via email
4. They install via TestFlight app

**Option 2: Direct Installation (Development only)**
1. Open the project in Xcode
2. Connect your iPhone via USB
3. Select your device as the target
4. Click "Run" to build and install

**Option 3: Enterprise Distribution**
- Requires Apple Enterprise Developer Program ($299/year)
- Allows distribution outside App Store

## Workflow Customization

### Trigger on Specific Branches
Edit the `on:` section in the workflow file:
```yaml
on:
  push:
    branches: [ main, develop, release/* ]
```

### Build Only on Tags (Releases)
```yaml
on:
  push:
    tags:
      - 'v*'  # Trigger on version tags like v1.0.0
```

### Disable Automatic Builds
Remove the `push:` and `pull_request:` sections, keep only `workflow_dispatch:` for manual triggers.

## Troubleshooting

### Workflow fails with "No space left on device"
- GitHub Actions has 14GB disk space limit
- Try removing unnecessary build outputs
- Use split APKs only

### iOS build fails
- Check if you have proper iOS setup in your Flutter project
- Run `flutter doctor` locally to verify iOS toolchain
- macOS runners are required for iOS builds

### APK won't install on device
- Make sure you enabled "Install from Unknown Sources"
- Try the debug APK first
- Check if you have enough storage space

### Tests fail
- Set `continue-on-error: true` in the test step
- Or remove the test step if you don't have tests yet

## Build Status Badge

Add this to your main README.md to show build status:

```markdown
![Build Android APK](https://github.com/YOUR_USERNAME/YOUR_REPO/workflows/Build%20Android%20APK/badge.svg)
![Build iOS IPA](https://github.com/YOUR_USERNAME/YOUR_REPO/workflows/Build%20iOS%20IPA/badge.svg)
```

## Estimated Build Times

- **Android APK**: 5-10 minutes
- **iOS IPA**: 10-15 minutes

## Costs

- **GitHub Actions**: FREE for public repositories
- **Private repos**: 2,000 free minutes/month, then $0.008/minute
- These builds typically use 10-20 minutes per run

## Advanced: Automated Releases

To automatically create GitHub releases with APK/IPA attached:

1. Create a new workflow file: `release.yml`
2. Use `actions/create-release@v1`
3. Attach build artifacts to the release
4. Trigger on version tags

Example coming soon!

---

**Need help?** Open an issue in the repository.
