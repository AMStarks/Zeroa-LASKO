import SwiftUI

struct FluxItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let sizeKB: Int
    let date: Date
}
 
struct FluxStoredItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [FluxItem] = [
        FluxItem(name: "post_image_001.png", sizeKB: 420, date: Date().addingTimeInterval(-3600)),
        FluxItem(name: "intro_video.mov", sizeKB: 50240, date: Date().addingTimeInterval(-86400 * 2)),
        FluxItem(name: "draft.md", sizeKB: 12, date: Date().addingTimeInterval(-86400 * 10))
    ]
    @State private var query: String = ""

    var filtered: [FluxItem] {
        guard !query.isEmpty else { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.15, green: 0.15, blue: 0.15).ignoresSafeArea()
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        Text("Stored Items")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.7))
                        TextField("Search files", text: $query)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .padding(.horizontal, 20)

                    // List
                    List {
                        ForEach(filtered) { item in
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: item.name))
                                    .foregroundColor(Color(red: 1.0, green: 0.6, blue: 0.0))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .foregroundColor(.white)
                                    Text(detail(for: item))
                                        .foregroundColor(.white.opacity(0.7))
                                        .font(.system(size: 12))
                                }
                                Spacer()
                                Button("Delete") {
                                    if let idx = items.firstIndex(of: item) { items.remove(at: idx) }
                                }
                                .foregroundColor(.red)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
    }

    private func icon(for name: String) -> String {
        let lower = name.lowercased()
        if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") { return "photo" }
        if lower.hasSuffix(".mov") || lower.hasSuffix(".mp4") { return "video" }
        if lower.hasSuffix(".md") || lower.hasSuffix(".txt") { return "doc.text" }
        return "doc"
    }

    private func detail(for item: FluxItem) -> String {
        let kb = item.sizeKB
        let size = kb > 1024 ? String(format: "%.1f MB", Double(kb)/1024.0) : "\(kb) KB"
        let df = DateFormatter()
        df.dateStyle = .medium
        return "\(size) • \(df.string(from: item.date))"
    }
}

