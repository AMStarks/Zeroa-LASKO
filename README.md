## Versioning

This repo hosts two apps: Zeroa and LASKO.

- Zeroa
  - CFBundleShortVersionString: 1.1.0
  - CFBundleVersion (Build): 2
- LASKO
  - CFBundleShortVersionString: 1.1.0
  - CFBundleVersion (Build): 2

Changelog highlights:
- Composer (LASKO): Rebuilt with rich text, compact toolbar, width constraints, and X-style header. Bottom toolbar decoupled and resized; icons tinted to brand orange.
- Feed actions (LASKO): Equidistant icons, active-state colors, count formatting fixed, TLS gold (#9C9876).
- FluxDrive (LASKO): Menu entries, upgrade tiers, stored items view added.
- Deep link handling (Zeroa): Session-scoped return to LASKO. Stale responses are consumed/cleared to prevent unwanted flips.
- Debug cleanup (Zeroa): Removed “Test LASKO Integration” and “Debug App Groups” buttons.

Release process:
1. Bump versions in `Zeroa/Info.plist` and `LASKO_AppInfo.plist`.
2. Clean build in Xcode (Shift+Cmd+K), then archive for distribution.
3. Tag release in git and push.

# Zeroa-LASKO Workspace

This workspace contains both the Zeroa and LASKO iOS apps for debugging inter-app communication issues.

## Project Structure

```
Zeroa-LASKO-Workspace/
├── Zeroa/           # Zeroa iOS app (symlink to ../Zeroa)
├── LASKO/           # LASKO iOS app (symlink to ../LASKO)
└── README.md        # This file
```

## Current Issues

### 🔍 App Groups Communication Problems
- **LASKO → Zeroa Request**: LASKO writes `lasko_auth_request` but Zeroa can't read it
- **Zeroa → LASKO Response**: Zeroa writes `lasko_auth_response` but LASKO can't read it
- **Container Access**: Both apps show `CFPrefsPlistSource` warnings with `Container: (null)`

### 🔍 File-Based Communication Issues
- LASKO has file-based fallback but Zeroa doesn't write responses to files
- Creates one-way communication deadlock

### 🔍 URL Scheme Trust Issues
- "Request is not trusted" error indicates URL scheme permissions regression
- Affects automatic app switching functionality

## Debugging Approach

### 1. App Groups Configuration
- Verify both apps have same App Groups identifier: `group.com.telestai.zeroa-lasko`
- Check entitlements files in both projects
- Ensure provisioning profiles include App Groups capability

### 2. File-Based Communication
- Implement file-based response writing in Zeroa
- Ensure both apps can read/write to shared directory: `Documents/Shared/`

### 3. URL Scheme Trust
- Fix URL scheme permissions in both apps
- Verify `Info.plist` configurations

## Quick Commands

```bash
# Build Zeroa
cd Zeroa && xcodebuild -project Zeroa.xcodeproj -scheme Zeroa -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Build LASKO  
cd LASKO && xcodebuild -project LASKO.xcodeproj -scheme LASKO -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Install and launch Zeroa
xcrun simctl install booted /path/to/Zeroa.app
xcrun simctl launch booted com.telestai.Zeroa

# Install and launch LASKO
xcrun simctl install booted /path/to/LASKO.app  
xcrun simctl launch booted com.telestai.LASKO
```

## Next Steps

1. **Fix App Groups container access** in both apps
2. **Implement file-based communication** in Zeroa
3. **Fix URL scheme trust issues**
4. **Test bidirectional communication**
5. **Verify automatic app switching** 