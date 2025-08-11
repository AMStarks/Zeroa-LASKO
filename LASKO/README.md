# LASKO iOS App

A native iOS application for the LASKO decentralized social media platform, built with SwiftUI and designed with a Nostr-inspired interface.

## 🚀 Quick Start

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later
- macOS 14.0 or later

### Setup Instructions

1. **Create a new Xcode project:**
   - Open Xcode
   - Choose "Create a new Xcode project"
   - Select "App" under iOS
   - Set Product Name: `LASKO`
   - Choose your team and organization identifier
   - Select "SwiftUI" for interface
   - Choose your project location

2. **Replace the default content:**
   - Copy the contents of `LASKOApp.swift` into your main app file
   - Add all the files from the `Models/`, `Services/`, and `Views/` directories
   - Copy the `Assets.xcassets` folder to your project

3. **Build and run:**
   - Select iPhone 16 Pro as your target device
   - Press Cmd+R to build and run

## 🎨 Design Features

### Brand Identity
- **Primary Color**: LASKO Orange (#FF9900)
- **Background**: Dark Teal (#1A2A33)
- **Card Background**: Darker Teal (#263340)
- **Typography**: System fonts with bold weights

### UI Components
- **Welcome Screen**: Branded landing page with feature highlights
- **Feed View**: Chronological post feed with like/reply actions
- **Post Composer**: Clean interface for creating new posts
- **Profile View**: User profile with stats and settings

## 🔧 Architecture

### MVVM Pattern
- **Models**: `PostModel.swift` - Data structures
- **Views**: SwiftUI views for UI components
- **Services**: `LASKOService.swift` - API communication

### Key Features
- **Decentralized Posts**: Content stored on Telestai blockchain
- **Privacy First**: No algorithm manipulation
- **Blockchain Powered**: Built on Telestai network
- **Real-time Updates**: Live feed with mock data

## 📱 Target Devices

- **Primary**: iPhone 16 Pro
- **Compatibility**: iOS 17.0+
- **Orientation**: Portrait (can be extended to landscape)

## 🔗 API Integration

The app is configured to connect to the LASKO indexer running on:
- **Local Development**: `http://localhost:3000/api`
- **Production**: Configurable via environment variables

## 🎯 Development Status

- ✅ **Core UI Components**: Complete
- ✅ **Brand Integration**: Complete
- ✅ **Mock Data**: Working
- ✅ **Build System**: Configured for iPhone 16 Pro
- 🔄 **API Integration**: Ready for backend connection
- 🔄 **Authentication**: To be implemented
- 🔄 **Real-time Features**: To be implemented

## 🛠️ Customization

### Adding New Features
1. Create new Swift files in appropriate directories
2. Follow the existing naming conventions
3. Use the established color scheme
4. Test on iPhone 16 Pro target

### Branding Updates
- Colors are defined in `Assets.xcassets`
- Logo and branding elements can be updated in the asset catalog
- Typography and spacing follow the established design system

## 📋 Next Steps

1. **Connect to Real API**: Replace mock data with live indexer
2. **Add Authentication**: Implement user login/signup
3. **Real-time Features**: Add live updates and notifications
4. **Advanced UI**: Add animations and transitions
5. **Testing**: Comprehensive unit and UI tests

## 🐛 Troubleshooting

### Common Issues
- **Build Errors**: Ensure all files are added to the Xcode project
- **Color Issues**: Verify asset catalog is properly imported
- **API Errors**: Check that the LASKO indexer is running locally

### Debug Commands
```bash
# Check if indexer is running
curl http://localhost:3000/api/posts

# Clean build
xcodebuild clean -project LASKO.xcodeproj
```

## 📄 License

This project is part of the LASKO decentralized social media platform.

---

**Built with ❤️ for the decentralized web** 