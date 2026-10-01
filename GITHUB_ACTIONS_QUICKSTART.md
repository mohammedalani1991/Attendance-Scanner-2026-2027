# GitHub Actions Quick Start Guide

## Step-by-Step: Build Your APK on GitHub

### 1. Create a GitHub Account (if you don't have one)
Visit https://github.com/signup

### 2. Create a New Repository
1. Click the "+" icon in top right → "New repository"
2. Name it: `flutter-attendance-scanner` (or any name you like)
3. Choose: **Public** (to get free unlimited build minutes)
4. Don't initialize with README (we already have one)
5. Click "Create repository"

### 3. Push Your Code to GitHub

Open Git Bash or Command Prompt in your project folder and run:

```bash
# Navigate to project directory
cd "C:\Users\Mohammed\Downloads\flutter-attendance-scanner-master\flutter-attendance-scanner-master"

# Initialize git (if not already)
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit with GitHub Actions workflows"

# Add your GitHub repository as remote (replace with your URL)
git remote add origin https://github.com/YOUR_USERNAME/flutter-attendance-scanner.git

# Push to GitHub
git branch -M main
git push -u origin main
```

**Replace `YOUR_USERNAME` with your actual GitHub username!**

### 4. Watch the Build

1. Go to your repository on GitHub
2. Click the "**Actions**" tab at the top
3. You'll see "Build Android APK" workflow running
4. Click on it to watch the progress (takes about 5-10 minutes)

### 5. Download Your APK

Once the build is complete (green checkmark ✓):

1. Click on the completed workflow run
2. Scroll down to "**Artifacts**" section
3. You'll see three downloadable files:
   - **attendance-scanner-release-apk** ← Download this one!
   - attendance-scanner-debug-apk (for testing)
   - attendance-scanner-split-apks (smaller size, per device)

4. Click on "attendance-scanner-release-apk"
5. A ZIP file will download
6. Extract it to get `app-release.apk`

### 6. Install on Your Android Phone

1. Transfer `app-release.apk` to your phone (via USB, email, or cloud)
2. On your phone, go to **Settings** → **Security** → Enable "**Install from Unknown Sources**"
3. Open the APK file on your phone
4. Tap "**Install**"
5. Done! The app is installed

---

## Manual Trigger (Build Without Pushing Code)

You can also trigger builds manually:

1. Go to your repository on GitHub
2. Click "**Actions**" tab
3. Click "**Build Android APK**" on the left sidebar
4. Click "**Run workflow**" button (top right)
5. Select branch (main)
6. Click green "**Run workflow**" button
7. Wait for completion
8. Download from Artifacts

---

## Troubleshooting

**Q: I don't see the Actions tab**
- Make sure your repository is public OR
- Enable Actions in: Settings → Actions → General → Allow all actions

**Q: Build failed**
- Check the error logs in the failed workflow
- Common issue: Flutter version mismatch
- Solution: Update flutter-version in `.github/workflows/build-apk.yml`

**Q: Can't install APK on phone**
- Make sure "Install from Unknown Sources" is enabled
- Try rebooting your phone
- Check if you have enough storage space

**Q: How do I update the app?**
1. Make your code changes
2. Commit and push to GitHub
3. New build runs automatically
4. Download new APK and install (it will update the existing app)

---

## What About iOS?

The iOS workflow is also set up, but:
- It creates an **unsigned IPA**
- You cannot install it directly on iPhones
- You need an Apple Developer account ($99/year) to sign and distribute

For iOS testing, it's better to use Xcode on a Mac.

---

## Next Steps

1. **Add a Build Badge** to your README.md:
   ```markdown
   ![Build APK](https://github.com/YOUR_USERNAME/flutter-attendance-scanner/workflows/Build%20Android%20APK/badge.svg)
   ```

2. **Create Releases** for version tracking:
   - Tag your commits: `git tag v1.0.0`
   - Push tag: `git push origin v1.0.0`
   - Create release on GitHub with APK attached

3. **Share Your App**:
   - Share the GitHub release URL
   - Others can download APK directly from GitHub

---

**Need help?** Check `.github/workflows/README.md` for detailed documentation.

---

## Summary of Files Created

- `.github/workflows/build-apk.yml` - Android APK build workflow
- `.github/workflows/build-ios.yml` - iOS IPA build workflow (optional)
- `.github/workflows/README.md` - Detailed workflow documentation
- `GITHUB_ACTIONS_QUICKSTART.md` - This guide

**You're all set!** Push to GitHub and get your APK in 5-10 minutes! 🚀
