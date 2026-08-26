import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreLocation
import AVFoundation

enum SwitchboardAttachmentDraft {
    static func photo(_ name: String, kilobytes: Int) -> String {
        "[Photo: \(name) (\(kilobytes) KB)]"
    }

    static func camera(_ kilobytes: Int) -> String {
        "[Photo from camera (\(kilobytes) KB)]"
    }

    static func document(_ name: String) -> String {
        "[Document: \(name)]"
    }

    static func location(latitude: Double, longitude: Double) -> String {
        String(format: "[Location: %.5f, %.5f]", latitude, longitude)
    }

    static func audio(_ name: String, seconds: Int) -> String {
        "[Audio: \(name) (\(seconds)s)]"
    }
}

@MainActor
final class SwitchboardMediaAttachmentController: ObservableObject {
    @Published var showPhotoPicker = false
    @Published var showCameraPicker = false
    @Published var showDocumentPicker = false
    @Published var showAudioRecorder = false
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var alertMessage: String?
    @Published var showAlert = false

    private let locationProvider = SwitchboardLocationProvider()

    func openPhoto() {
        showPhotoPicker = true
    }

    func openCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentAlert("Camera is not available on this device.")
            return
        }
        showCameraPicker = true
    }

    func openDocument() {
        showDocumentPicker = true
    }

    func openLocation(onDraft: @escaping (String) -> Void) {
        locationProvider.fetchLocationDescription { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let draft):
                    onDraft(draft)
                case .failure(let error):
                    self?.presentAlert(error.localizedDescription)
                }
            }
        }
    }

    func openAudio() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            showAudioRecorder = true
        case .denied:
            presentAlert("Microphone access is required to record audio. Enable it in Settings.")
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.showAudioRecorder = true
                    } else {
                        self?.presentAlert("Microphone access is required to record audio.")
                    }
                }
            }
        @unknown default:
            presentAlert("Microphone access is unavailable.")
        }
    }

    func consumeSelectedPhoto(onDraft: @escaping (String) -> Void) {
        guard let item = selectedPhotoItem else { return }
        let identifier = item.itemIdentifier ?? "selected-photo"
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let draft = SwitchboardAttachmentDraft.photo(identifier, kilobytes: max(1, data.count / 1024))
                await MainActor.run {
                    selectedPhotoItem = nil
                    showPhotoPicker = false
                    onDraft(draft)
                }
            } else {
                await MainActor.run {
                    selectedPhotoItem = nil
                    showPhotoPicker = false
                    presentAlert("Could not load the selected photo.")
                }
            }
        }
    }

    private func presentAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

private final class SwitchboardLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((Result<String, Error>) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func fetchLocationDescription(completion: @escaping (Result<String, Error>) -> Void) {
        self.completion = completion

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            completion(.failure(SwitchboardMediaAttachmentError.locationDenied))
        @unknown default:
            completion(.failure(SwitchboardMediaAttachmentError.locationUnavailable))
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard completion != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(SwitchboardMediaAttachmentError.locationDenied))
        case .notDetermined:
            break
        @unknown default:
            finish(.failure(SwitchboardMediaAttachmentError.locationUnavailable))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finish(.failure(SwitchboardMediaAttachmentError.locationUnavailable))
            return
        }
        let draft = SwitchboardAttachmentDraft.location(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        finish(.success(draft))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<String, Error>) {
        completion?(result)
        completion = nil
    }
}

enum SwitchboardMediaAttachmentError: LocalizedError {
    case locationDenied
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .locationDenied:
            return "Location access is required to share your position. Enable it in Settings."
        case .locationUnavailable:
            return "Could not determine your current location."
        }
    }
}

struct SwitchboardCameraPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SwitchboardCameraPicker

        init(parent: SwitchboardCameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct SwitchboardDocumentPicker: UIViewControllerRepresentable {
    let onDocumentPicked: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: SwitchboardDocumentPicker

        init(parent: SwitchboardDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.dismiss()
                return
            }
            parent.onDocumentPicked(url)
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

struct SwitchboardAudioRecorderView: View {
    let onRecorded: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = SwitchboardAudioRecorder()

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "mic.circle")
                    .font(.system(size: 72))
                    .foregroundColor(recorder.isRecording ? .red : DesignSystem.Colors.secondary)

                Text(recorder.isRecording ? "Recording…" : "Record a voice note")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.text)

                Text(recorder.elapsedLabel)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Button(action: toggleRecording) {
                    Text(recorder.isRecording ? "Stop" : "Start Recording")
                        .font(DesignSystem.Typography.bodyMedium.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(recorder.isRecording ? Color.red : DesignSystem.Colors.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                if recorder.hasRecording {
                    Button("Attach Recording") {
                        if let draft = recorder.makeDraft() {
                            onRecorded(draft)
                            dismiss()
                        }
                    }
                    .font(DesignSystem.Typography.bodyMedium.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.secondary)
                }

                Spacer()
            }
            .padding(.top, DesignSystem.Spacing.xl)
            .navigationTitle("Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recorder.cancel()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                recorder.cancel()
            }
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stop()
        } else {
            recorder.start()
        }
    }
}

@MainActor
final class SwitchboardAudioRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var hasRecording = false

    var elapsedLabel: String {
        String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var outputURL: URL?

    func start() {
        cancel()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("switchboard-audio-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()
            self.recorder = recorder
            outputURL = url
            isRecording = true
            elapsedSeconds = 0
            hasRecording = false
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.elapsedSeconds += 1
                }
            }
        } catch {
            isRecording = false
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        isRecording = false
        hasRecording = outputURL != nil
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        recorder?.stop()
        recorder = nil
        if let outputURL {
            try? FileManager.default.removeItem(at: outputURL)
        }
        outputURL = nil
        isRecording = false
        elapsedSeconds = 0
        hasRecording = false
    }

    func makeDraft() -> String? {
        guard let outputURL else { return nil }
        let seconds = max(1, elapsedSeconds)
        return SwitchboardAttachmentDraft.audio(outputURL.lastPathComponent, seconds: seconds)
    }
}

private struct SwitchboardMediaAttachmentModifiers: ViewModifier {
    @ObservedObject var controller: SwitchboardMediaAttachmentController
    @Binding var messageText: String
    @Binding var showMediaOptions: Bool

    func body(content: Content) -> some View {
        content
            .photosPicker(
                isPresented: $controller.showPhotoPicker,
                selection: $controller.selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: controller.selectedPhotoItem) { _, _ in
                controller.consumeSelectedPhoto { draft in
                    applyDraft(draft)
                }
            }
            .fullScreenCover(isPresented: $controller.showCameraPicker) {
                SwitchboardCameraPicker { image in
                    let byteCount = image.jpegData(compressionQuality: 0.85)?.count ?? 0
                    let kilobytes = max(1, byteCount / 1024)
                    applyDraft(SwitchboardAttachmentDraft.camera(kilobytes))
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $controller.showDocumentPicker) {
                SwitchboardDocumentPicker { url in
                    applyDraft(SwitchboardAttachmentDraft.document(url.lastPathComponent))
                }
            }
            .sheet(isPresented: $controller.showAudioRecorder) {
                SwitchboardAudioRecorderView { draft in
                    applyDraft(draft)
                }
            }
            .alert("Attachment", isPresented: $controller.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(controller.alertMessage ?? "")
            }
    }

    private func applyDraft(_ draft: String) {
        if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messageText = draft
        } else {
            messageText += "\n\(draft)"
        }
        withAnimation(.easeInOut(duration: 0.3)) {
            showMediaOptions = false
        }
    }
}

extension View {
    func switchboardMediaAttachments(
        controller: SwitchboardMediaAttachmentController,
        messageText: Binding<String>,
        showMediaOptions: Binding<Bool>
    ) -> some View {
        modifier(
            SwitchboardMediaAttachmentModifiers(
                controller: controller,
                messageText: messageText,
                showMediaOptions: showMediaOptions
            )
        )
    }
}
