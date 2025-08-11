import SwiftUI

struct LASKOSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lasko_push_enabled") private var pushEnabled = true
    @AppStorage("lasko_safe_mode") private var safeMode = true
    @AppStorage("lasko_auto_play_media") private var autoPlayMedia = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.08, blue: 0.15)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // Toggles
                    settingsRow(
                        title: "Push Notifications",
                        subtitle: "Mentions and replies",
                        isOn: $pushEnabled
                    )

                    settingsRow(
                        title: "Safe Mode",
                        subtitle: "Hide sensitive media by default",
                        isOn: $safeMode
                    )

                    settingsRow(
                        title: "Auto-play Media",
                        subtitle: "Play videos and GIFs automatically",
                        isOn: $autoPlayMedia
                    )

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func settingsRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                    Text(subtitle)
                        .foregroundColor(.white.opacity(0.75))
                        .font(.system(size: 13))
                }

                Spacer()

                Toggle("", isOn: isOn)
                    .labelsHidden()
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(14)
        .padding(.horizontal, 20)
    }
}

