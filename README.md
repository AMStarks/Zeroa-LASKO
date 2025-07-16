# PAAI - Zeroa Apple App

A SwiftUI iOS application that integrates with xAI's Grok API for AI-powered interactions.

## Features

- SwiftUI-based iOS app
- Integration with xAI Grok API
- Secure API key management
- Multiple services: Assistant, Crypto, Keychain, Network, and Wallet

## Setup Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/AMStarks/Zeroa-Apple-App.git
cd Zeroa-Apple-App
```

### 2. Configure API Key

You have two options to set up your xAI API key:

#### Option A: Environment Variable (Recommended)
Set the `XAI_API_KEY` environment variable in Xcode:

1. Open the project in Xcode
2. Select your target
3. Go to "Edit Scheme" → "Run" → "Arguments"
4. Add environment variable: `XAI_API_KEY` = `your_api_key_here`

#### Option B: Local Config File
1. Edit `PAAI/PAAI/Config.plist`
2. Replace `YOUR_API_KEY_HERE` with your actual xAI API key
3. The file is already in `.gitignore` so it won't be committed

### 3. Build and Run
1. Open `PAAI.xcodeproj` in Xcode
2. Select your target device/simulator
3. Build and run the project (⌘+R)

## Project Structure

```
PAAI/
├── PAAI/
│   ├── PAAIApp.swift          # App entry point
│   ├── ContentView.swift      # Main UI
│   ├── NetworkService.swift   # API communication
│   ├── AssistantService.swift # Assistant functionality
│   ├── CryptoService.swift    # Cryptographic operations
│   ├── KeychainService.swift  # Secure storage
│   ├── WalletService.swift    # Wallet operations
│   ├── Color+Hex.swift        # Color utilities
│   └── Assets.xcassets/       # App assets
├── PAAITests/                 # Unit tests
└── PAAIUITests/              # UI tests
```

## Security Notes

- API keys are never committed to the repository
- The `Config.plist` file is excluded from git tracking
- Environment variables are used for secure configuration
- All sensitive data is handled through secure services

## Development

### Adding New Features
1. Create new Swift files in the `PAAI/` directory
2. Follow the existing service pattern for new functionality
3. Update tests as needed

### API Integration
The `NetworkService` class handles all API communication. To add new endpoints:

1. Add new methods to `NetworkService`
2. Use the same secure API key loading pattern
3. Handle errors appropriately

## Troubleshooting

### API Key Issues
- Ensure your API key is valid and has proper permissions
- Check that the environment variable is set correctly
- Verify the Config.plist file exists and has the correct key

### Build Issues
- Clean build folder (⌘+Shift+K)
- Reset package caches if using Swift Package Manager
- Check that all required files are included in the target

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

[Add your license information here]
