# PAAI - Personal AI Assistant

A SwiftUI iOS app that integrates AI and blockchain features for personal assistance.

## Features

- AI-powered command line interface
- TLS blockchain integration
- Secure wallet management
- Hybrid messaging system (Switchboard)
- Theme management (Light/Dark/Native)
- Multi-language support
- Real-time price tracking

## Development

### Prerequisites

- Xcode 15+
- iOS 18.5+ Simulator
- macOS 14+

### Setup

1. Clone the repository
2. Open `PAAI.xcodeproj` in Xcode
3. Select iPhone 16 Pro Simulator
4. Build and run

### Troubleshooting

#### Mac Keyboard Not Working in iOS Simulator

If you cannot type using your Mac keyboard in the iOS Simulator:

1. Open the iOS Simulator
2. Go to **Hardware > Keyboard > Connect Hardware Keyboard**
3. Make sure this option is **checked** (✔️)
4. If it's already checked, try unchecking and rechecking it
5. Restart the Simulator if needed

This setting must be enabled for the Mac keyboard to work with text fields in the Simulator.

## Version History

- v1.16: Fix Mac keyboard input for AI command line
- v1.15: Add comprehensive debugging for keyboard input issue
- v1.14: Replace InputField with direct TextField for AI command line
- v1.13: Fix Mac keyboard input for AI command line
- v1.12: Fix Switchboard UI theme alignment
- v1.11: Fix keyboard input for AI command line
- v1.10: Fix AI command line functionality
- v1.9: Rename P2P Messaging to Switchboard
- v1.8: Add back button and UI theming for messaging
- v1.7: Implement hybrid messaging system
- v1.6: Move Support & Help to menu
- v1.5: Fix bottom navigation alignment
- v1.4: Restore create account flow
- v1.3: Update login screen UI
- v1.2: Add menu text and fix command alignment
- v1.1: Add TLS price integration
- v1.0: Baseline version
