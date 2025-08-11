import SwiftUI

struct LASKOSupportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.05, green: 0.08, blue: 0.15)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("Support & Help")
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

                    VStack(alignment: .leading, spacing: 12) {
                        supportRow(icon: "questionmark.circle", title: "FAQ", subtitle: "Common questions and answers")
                        supportRow(icon: "envelope.fill", title: "Contact Support", subtitle: "Email support@telestai.org")
                        supportRow(icon: "link", title: "Status Page", subtitle: "Network and service status")
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func supportRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                Text(subtitle)
                    .foregroundColor(.white.opacity(0.75))
                    .font(.system(size: 13))
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

