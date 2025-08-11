import SwiftUI

struct GIFPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedGIFs: [URL]
    @State private var query: String = "funny cats"
    @State private var results: [URL] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                HStack {
                    TextField("Search GIFs", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Button("Search") { Task { await search() } }
                }
                .padding(.horizontal)
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(results, id: \.self) { url in
                            AsyncImage(url: url) { img in
                                img.resizable().aspectRatio(1, contentMode: .fill)
                            } placeholder: { Color.gray.opacity(0.2) }
                            .frame(height: 100)
                            .clipped()
                            .cornerRadius(8)
                            .onTapGesture {
                                selectedGIFs.append(url)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Pick GIF")
            .task { await search() }
        }
    }
    
    private func searchEndpoint(for q: String) -> URL? {
        // No external keys; fallback to a simple anonymous endpoint on Giphy's public beta or a static JSON mirror
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://giphy.com/search/\(encoded)") // placeholder; will use a static curated set
    }
    
    private func parseFallback() -> [URL] {
        // Curated set of trending GIFs (direct URLs) to avoid API keys
        return [
            URL(string: "https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif")!,
            URL(string: "https://media.giphy.com/media/3o6ZsY8l4QGqZCkxzC/giphy.gif")!,
            URL(string: "https://media.giphy.com/media/l0HlSNOxJB956qwfK/giphy.gif")!,
            URL(string: "https://media.giphy.com/media/26xBukh4z3wQAbn2w/giphy.gif")!,
            URL(string: "https://media.giphy.com/media/13HgwGsXF0aiGY/giphy.gif")!,
        ]
    }
    
    private func normalizeToDirectGIF(_ html: String) -> [URL] {
        // Very naive parsing: look for ".gif" URLs in the page
        var urls: [URL] = []
        for token in html.components(separatedBy: "\"") {
            if token.hasSuffix(".gif"), let u = URL(string: token) {
                urls.append(u)
            }
        }
        return Array(Set(urls)).prefix(30).map { $0 }
    }
    
    private func search() async {
        // Try to fetch; if blocked, fallback to curated
        guard let url = searchEndpoint(for: query) else {
            results = parseFallback(); return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let html = String(data: data, encoding: .utf8) {
                let found = normalizeToDirectGIF(html)
                if !found.isEmpty { results = found; return }
            }
            results = parseFallback()
        } catch {
            results = parseFallback()
        }
    }
}

