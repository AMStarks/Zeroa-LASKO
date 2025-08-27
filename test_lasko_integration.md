# 🧪 LASKO Integration Testing Guide

## **Quick Test (No LASKO App Needed)**

### **Step 1: Build and Run Zeroa**
```bash
# Open Xcode and build Zeroa
# Or use command line:
xcodebuild -workspace Zeroa.xcworkspace -scheme Zeroa -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### **Step 2: Test with Button**
1. **Run Zeroa** in the iOS Simulator
2. **Look for orange "Test LASKO Integration" button** on main screen
3. **Tap the button** - this simulates LASKO sending a request
4. **Verify the auth UI appears** with permissions and authorize/deny buttons

### **Step 3: Test with URL**
1. **In Safari** (in the simulator), type this URL:
   ```
   zeroa://auth?app=LASKO&appId=com.telestai.LASKO&permissions=post,read&callback=lasko://auth/callback
   ```
2. **Tap the URL** - Zeroa should open with the auth request
3. **Verify the auth UI appears**

## **What You Should See**

### **✅ Success Indicators:**
- Orange "Test LASKO Integration" button appears (DEBUG mode)
- Tapping button shows beautiful auth UI
- UI shows "LASKO wants to use your Zeroa identity"
- Permissions listed: "Create posts on your behalf", "Access your TLS address"
- "Authorize Login" and "Deny" buttons work
- Real TLS signatures are generated (check console logs)

### **❌ Failure Indicators:**
- Button doesn't appear (not in DEBUG mode)
- App crashes when tapping button
- Auth UI doesn't appear
- Console shows errors

## **Console Logs to Check**

When testing, look for these logs in Xcode console:

```
✅ Received LASKO auth request: LASKO requesting ["post", "read"]
✅ TLS signing working - Session created:
   TLS Address: TLS123...
   Session Token: session_abc...
   Signature: real_signature...
✅ Successfully sent callback to LASKO
```

## **Real LASKO Integration (If You Have LASKO)**

If you have access to the LASKO app:

1. **Build both apps** on same device/simulator
2. **Open LASKO** and trigger its auth flow
3. **LASKO should open Zeroa** with auth request
4. **Zeroa shows auth UI** and sends callback back
5. **LASKO receives authenticated session**

## **Troubleshooting**

### **Build Issues:**
```bash
# Clean and rebuild
xcodebuild -workspace Zeroa.xcworkspace -scheme Zeroa clean
pod install
xcodebuild -workspace Zeroa.xcworkspace -scheme Zeroa build
```

### **URL Scheme Issues:**
- Check that `zeroa://` is registered in project settings
- Verify URL handler is properly implemented in `ZeroaApp.swift`

### **TLS Signing Issues:**
- Ensure `WalletService.shared.loadAddress()` returns a valid address
- Check that `WalletService.shared.signMessage()` works
- Verify console logs for signature generation

## **Next Steps**

1. **Test the button** - confirms integration works
2. **Test the URL** - confirms URL scheme works  
3. **Test with real LASKO** - confirms full integration
4. **Remove test button** - for production (already wrapped in `#if DEBUG`)

The integration is **complete and ready for testing!** 🚀 