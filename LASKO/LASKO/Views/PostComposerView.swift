import SwiftUI

struct ModernPostComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var content = "" // legacy
    @State private var author = "User"
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var showGIFPicker = false
    @State private var showPollMaker = false
    @State private var showScheduler = false
    @State private var pickerImage: UIImage? = nil
    @State private var pollOptions: [String] = []
    @State private var pollDurationHours: Int = 24
    @State private var scheduledDate: Date? = nil
    @State private var selectedGIFs: [URL] = []

    @StateObject private var richController = RichTextController()
    @State private var attributedText: NSAttributedString = NSAttributedString(string: "")

    var body: some View {
        ZStack {
            Color.white
                .background(Color.white)

            GeometryReader { geo in
                // Fixed target width 310, clamped to screen with a reasonable minimum
                let containerWidth: CGFloat = max(280, min(geo.size.width - 24, 310))

                ScrollView {
                    VStack(spacing: 0) {
                    // Header (X-style)
                    HStack {
                        Button("Cancel") { dismiss() }
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.black)
                        Spacer()
                        Button("Drafts") {}
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color.blue)
                        Spacer()
                        Button("Post") {
                            Task {
                                let plain = attributedText.string
                                if plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && plain.count <= 1000 {
                                    _ = await LASKOService().createPost(content: plain)
                                    dismiss()
                                }
                            }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(plainDisabled ? Color.blue.opacity(0.35) : Color.blue)
                        )
                        .disabled(plainDisabled)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                    // Avatar + Editor inline
                    HStack(alignment: .top, spacing: 10) {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [Color(red:1, green:0.6, blue:0), Color(red:1, green:0.4, blue:0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 36, height: 36)
                            Text(String(author.prefix(1)))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                        }
                        ZStack(alignment: .topLeading) {
                            // Editor width: min(containerWidth, available screen width minus margins + avatar)
                            let available = geo.size.width - 16 - 36 - 10 - 16
                            let editorWidth = max(200, min(containerWidth, available))
                            RichTextEditor(attributedText: $attributedText, controller: richController, placeholder: "Tell your story...")
                                .frame(minHeight: 210)
                                .frame(width: editorWidth, alignment: .leading)
                                .padding(.horizontal, 0)
                                .padding(.vertical, 0)
                                .background(Color.white)
                            if attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Tell your story...")
                                    .font(.system(size: 22, weight: .regular))
                                    .foregroundColor(Color.gray.opacity(0.6))
                                    .padding(.top, 12)
                                    .padding(.leading, 10)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // Attachments
                    if !selectedImages.isEmpty || !selectedGIFs.isEmpty || !pollOptions.isEmpty || scheduledDate != nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill).frame(width: 56, height: 56).clipped().cornerRadius(6)
                                        Button(action: { selectedImages.remove(at: idx) }) { Image(systemName: "xmark.circle.fill").foregroundColor(.white) }.offset(x: -4, y: 4)
                                    }
                                }
                                ForEach(Array(selectedGIFs.enumerated()), id: \.offset) { idx, url in
                                    ZStack(alignment: .topTrailing) {
                                        AsyncImage(url: url) { img in img.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color.gray.opacity(0.2) }
                                            .frame(width: 56, height: 56).clipped().cornerRadius(6)
                                        Button(action: { selectedGIFs.remove(at: idx) }) { Image(systemName: "xmark.circle.fill").foregroundColor(.white) }.offset(x: -4, y: 4)
                                    }
                                }
                                if !pollOptions.isEmpty {
                                    HStack(spacing: 6) { Image(systemName: "chart.bar").foregroundColor(.black); Text("Poll (\(pollOptions.count)) • \(pollDurationHours)h") }
                                        .font(.caption).padding(8).background(Color.gray.opacity(0.15)).cornerRadius(8)
                                }
                                if let date = scheduledDate { HStack(spacing: 6) { Image(systemName: "calendar.badge.clock").foregroundColor(.black); Text(date.formatted(date: .abbreviated, time: .shortened)) }.font(.caption).padding(8).background(Color.gray.opacity(0.15)).cornerRadius(8) }
                            }
                            .padding(.leading, 16 + 36 + 10)
                            .padding(.trailing, 16)
                        }
                        .padding(.top, 6)
                    }

                    Spacer(minLength: 80)
                    }
                    // remove global width cap so header and avatar can hug screen edges
                }
                .scrollDismissesKeyboard(.interactively)

                // Toolbar inset
                .safeAreaInset(edge: .bottom) {
                    HStack(alignment: .center, spacing: 12) {
                        // Compact icon cluster
                        HStack(spacing: 8) {
                            ComposerToolbarIcon(system: "bold") { richController.toggleBold() }
                            ComposerToolbarIcon(system: "italic") { richController.toggleItalic() }
                            ComposerToolbarIcon(system: "underline") { richController.toggleUnderline() }
                            ComposerToolbarDivider()
                            ComposerToolbarIcon(system: "photo.on.rectangle") { showImagePicker = true }
                            ComposerToolbarIcon(system: "sparkles") { showGIFPicker = true }
                            ComposerToolbarIcon(system: "chart.bar") { showPollMaker = true }
                            ComposerToolbarIcon(system: "calendar.badge.clock") { showScheduler = true }
                        }

                        Spacer(minLength: 8)

                        Capsule()
                            .fill(Color.black.opacity(0.06))
                            .frame(width: 52, height: 24)
                            .overlay(Text("\(attributedText.string.count)/1000").font(.caption2).foregroundColor(.black))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Rectangle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: -2)
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showImagePicker) { ImagePicker(selectedImage: $pickerImage) }
        .sheet(isPresented: $showGIFPicker) { GIFPickerSheet(selectedGIFs: $selectedGIFs) }
        .onChange(of: pickerImage, initial: false) { oldValue, img in if let img = img { selectedImages.append(img) } }
        .sheet(isPresented: $showPollMaker) { PollMakerSheet(options: $pollOptions, durationHours: $pollDurationHours) }
        .sheet(isPresented: $showScheduler) { SchedulerSheet(scheduledDate: $scheduledDate) }
    }

    private var plainDisabled: Bool { attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attributedText.string.count > 1000 }
}

// Local toolbar components for composer to avoid cross-file visibility issues
private struct ComposerToolbarIcon: View {
    let system: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.black.opacity(0.06))
                    .frame(width: 32, height: 32)
                Image(systemName: system)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ComposerToolbarDivider: View {
    var body: some View { Rectangle().fill(Color.black.opacity(0.08)).frame(width: 1, height: 22) }
}

 