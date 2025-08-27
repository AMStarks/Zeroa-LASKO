# TestFlight Deployment Guide for PAAI

This guide will walk you through the process of uploading PAAI to TestFlight so you can test it on your iPhone.

## 📋 Prerequisites

### 1. Apple Developer Account
- You need an **Apple Developer Account** ($99/year)
- If you don't have one, sign up at [developer.apple.com](https://developer.apple.com)

### 2. Xcode Setup
- Latest version of Xcode (16.0+)
- Valid Apple Developer Team configured in Xcode
- Your device registered in your developer account

### 3. App Store Connect
- Access to [App Store Connect](https://appstoreconnect.apple.com)
- App record created for PAAI

## 🚀 Step-by-Step Process

### Step 1: Configure Xcode Project

1. **Open the project in Xcode:**
   ```bash
   cd PAAI
   open PAAI.xcodeproj
   ```

2. **Set up your Team:**
   - Select the PAAI project in the navigator
   - Select the "PAAI" target
   - Go to "Signing & Capabilities" tab
   - Select your Apple Developer Team
   - Ensure "Automatically manage signing" is checked

3. **Update Bundle Identifier:**
   - Change from `com.telestai.PAAI` to something unique like:
   - `com.yourname.PAAI` or `com.yourcompany.PAAI`

### Step 2: Create App Store Connect Record

1. **Go to App Store Connect:**
   - Visit [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   - Sign in with your Apple Developer account

2. **Create New App:**
   - Click the "+" button
   - Select "New App"
   - Fill in the details:
     - **Platforms**: iOS
     - **Name**: PAAI
     - **Primary Language**: English
     - **Bundle ID**: Use the same bundle ID from Xcode
     - **SKU**: PAAI-001 (or any unique identifier)
     - **User Access**: Full Access

### Step 3: Archive and Upload

1. **Select Generic iOS Device:**
   - In Xcode, change the target from "iPhone 16" to "Any iOS Device (arm64)"

2. **Archive the App:**
   - Go to Product → Archive
   - Wait for the archive process to complete

3. **Upload to App Store Connect:**
   - In the Organizer window that opens
   - Select your archive
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Select "Upload"
   - Follow the prompts to upload

### Step 4: Configure TestFlight

1. **In App Store Connect:**
   - Go to your PAAI app
   - Click on "TestFlight" tab
   - Wait for processing (can take 10-30 minutes)

2. **Add Test Information:**
   - Fill in the required information:
     - **What to Test**: Key features to test
     - **Feedback Email**: Your email address
     - **App Description**: Brief description of the app

3. **Add Internal Testers:**
   - Click "Internal Testing"
   - Add yourself as an internal tester
   - Use the same email as your Apple ID

### Step 5: Install on Your iPhone

1. **Download TestFlight:**
   - Install TestFlight from the App Store on your iPhone

2. **Accept Invitation:**
   - Check your email for the TestFlight invitation
   - Click the link to accept

3. **Install PAAI:**
   - Open TestFlight on your iPhone
   - Find PAAI in the list
   - Tap "Install"

## 🔧 Troubleshooting

### Common Issues

1. **Code Signing Errors:**
   - Ensure your Apple Developer Team is selected
   - Check that your bundle identifier is unique
   - Verify your provisioning profiles

2. **Upload Failures:**
   - Check your internet connection
   - Ensure you're using the latest Xcode
   - Verify your Apple Developer account is active

3. **TestFlight Not Showing:**
   - Wait 10-30 minutes for processing
   - Check that you've added yourself as a tester
   - Verify the email matches your Apple ID

### Build Issues

If you encounter build issues:

1. **Clean Build:**
   - Product → Clean Build Folder
   - Product → Build

2. **Check Dependencies:**
   - Ensure all frameworks are properly linked
   - Verify asset catalogs are complete

3. **Update Xcode:**
   - Use the latest version of Xcode
   - Update iOS deployment target if needed

## 📱 Testing Checklist

Once installed, test these key features:

- [ ] **Send/Receive**: Test cryptocurrency send and receive functionality
- [ ] **Address Generation**: Verify unique addresses for each coin
- [ ] **Share Functionality**: Test AirDrop, SMS, WhatsApp, Email sharing
- [ ] **Tap-to-Copy**: Verify address copying works
- [ ] **Theme Switching**: Test dark/light theme functionality
- [ ] **Coin Picker**: Test the redesigned coin selection
- [ ] **Fiat Conversion**: Test currency conversion in Send view
- [ ] **AI Companions**: Test AI companion interactions
- [ ] **Navigation**: Verify all navigation flows work properly

## 🎯 Next Steps

After successful TestFlight deployment:

1. **Test Thoroughly**: Use the app extensively on your device
2. **Gather Feedback**: Note any issues or improvements needed
3. **Iterate**: Make improvements and upload new versions
4. **External Testing**: Add external testers for broader feedback

## 📞 Support

If you encounter issues:

1. **Xcode Issues**: Check Apple Developer documentation
2. **TestFlight Issues**: Contact Apple Developer Support
3. **App Issues**: Review the code and logs for debugging

---

**PAAI v1.2.0** - Ready for TestFlight deployment with enhanced Send/Receive functionality and comprehensive UI improvements. 