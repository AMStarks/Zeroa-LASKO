import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreLocation
import AVFoundation
import UIKit

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
    @Published var alertTitle = "Attachment"
    @Published var alertMessage: String?
    @Published var showAlert = false
    @Published var alertOffersSettings = false
    @Published var showAudioRecorder = false

    private let locationProvider = SwitchboardLocationProvider()
    private var photoDelegate: SwitchboardPhotoPickerDelegate?
    private var cameraDelegate: SwitchboardCameraPickerDelegate?
    private var documentDelegate: SwitchboardDocumentPickerDelegate?

    var onDraft: ((String) -> Void)?

    func openPhoto() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        let delegate = SwitchboardPhotoPickerDelegate { [weak self] draft in
            self?.photoDelegate = nil
            if let draft {
                self?.emitDraft(draft)
            }
        }
        photoDelegate = delegate
        picker.delegate = delegate
        present(picker, asPopoverFrom: nil)
    }

    func openCamera() {
        // Simulators report camera availability inconsistently and cannot capture photos.
        #if targetEnvironment(simulator)
        openPhoto()
        return
        #else
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentAlert(
                title: "Camera Unavailable",
                message: "This device has no camera. Opening your photo library instead."
            )
            openPhoto()
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.presentCamera()
                    } else {
                        self?.presentPermissionDenied(
                            title: "Camera Access Needed",
                            message: "Enable Camera access in Settings to attach photos from the camera."
                        )
                    }
                }
            }
        case .denied, .restricted:
            presentPermissionDenied(
                title: "Camera Access Needed",
                message: "Enable Camera access in Settings to attach photos from the camera."
            )
        @unknown default:
            presentAlert(title: "Camera Unavailable", message: "Camera access is unavailable on this device.")
        }
        #endif
    }

    func openDocument() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item, .image, .pdf, .data], asCopy: true)
        picker.allowsMultipleSelection = false
        let delegate = SwitchboardDocumentPickerDelegate { [weak self] draft in
            self?.documentDelegate = nil
            if let draft {
                self?.emitDraft(draft)
            }
        }
        documentDelegate = delegate
        picker.delegate = delegate
        present(picker, asPopoverFrom: nil)
    }

    func openLocation() {
        locationProvider.fetchLocationDescription { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let draft):
                    self?.emitDraft(draft)
                case .failure(let error):
                    if let mediaError = error as? SwitchboardMediaAttachmentError, mediaError == .locationDenied {
                        self?.presentPermissionDenied(
                            title: "Location Access Needed",
                            message: error.localizedDescription
                        )
                    } else {
                        self?.presentAlert(title: "Location", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    func openAudio() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            showAudioRecorder = true
        case .denied:
            presentPermissionDenied(
                title: "Microphone Access Needed",
                message: "Enable Microphone access in Settings to record audio attachments."
            )
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.showAudioRecorder = true
                    } else {
                        self?.presentPermissionDenied(
                            title: "Microphone Access Needed",
                            message: "Enable Microphone access in Settings to record audio attachments."
                        )
                    }
                }
            }
        @unknown default:
            presentAlert(title: "Microphone Unavailable", message: "Microphone access is unavailable on this device.")
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        let delegate = SwitchboardCameraPickerDelegate { [weak self] draft in
            self?.cameraDelegate = nil
            if let draft {
                self?.emitDraft(draft)
            }
        }
        cameraDelegate = delegate
        picker.delegate = delegate
        present(picker, asPopoverFrom: nil, fullScreen: true)
    }

    private func emitDraft(_ draft: String) {
        onDraft?(draft)
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        alertOffersSettings = false
        showAlert = true
    }

    private func presentPermissionDenied(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        alertOffersSettings = true
        showAlert = true
    }

    private func present(_ controller: UIViewController, asPopoverFrom source: UIView?, fullScreen: Bool = false) {
        guard let presenter = SwitchboardPresenter.topViewController() else {
            presentAlert(title: "Unable to Open", message: "Could not present the attachment picker. Please try again.")
            return
        }

        if fullScreen {
            controller.modalPresentationStyle = .fullScreen
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            controller.modalPresentationStyle = .formSheet
            if let popover = controller.popoverPresentationController {
                let anchor = source ?? presenter.view
                popover.sourceView = anchor
                let bounds = source?.bounds ?? anchor?.bounds ?? .zero
                popover.sourceRect = CGRect(
                    x: bounds.midX - 1,
                    y: bounds.midY - 1,
                    width: 2,
                    height: 2
                )
                popover.permittedArrowDirections = []
            }
        }

        presenter.present(controller, animated: true)
    }
}

enum SwitchboardPresenter {
    @MainActor
    static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let navigation = base as? UINavigationController {
            return topViewController(base: navigation.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

private final class SwitchboardPhotoPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    private let completion: (String?) -> Void

    init(completion: @escaping (String?) -> Void) {
        self.completion = completion
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else {
            completion(nil)
            return
        }

        let provider = result.itemProvider
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                let draft: String?
                if let image = object as? UIImage {
                    let bytes = image.jpegData(compressionQuality: 0.85)?.count ?? 0
                    draft = SwitchboardAttachmentDraft.photo("selected-photo", kilobytes: max(1, bytes / 1024))
                } else {
                    draft = nil
                }
                DispatchQueue.main.async {
                    self.completion(draft)
                }
            }
        } else {
            completion(nil)
        }
    }
}

private final class SwitchboardCameraPickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let completion: (String?) -> Void

    init(completion: @escaping (String?) -> Void) {
        self.completion = completion
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let draft: String?
        if let image = info[.originalImage] as? UIImage {
            let bytes = image.jpegData(compressionQuality: 0.85)?.count ?? 0
            draft = SwitchboardAttachmentDraft.camera(max(1, bytes / 1024))
        } else {
            draft = nil
        }
        picker.dismiss(animated: true) {
            self.completion(draft)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.completion(nil)
        }
    }
}

private final class SwitchboardDocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let completion: (String?) -> Void

    init(completion: @escaping (String?) -> Void) {
        self.completion = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let draft = urls.first.map { SwitchboardAttachmentDraft.document($0.lastPathComponent) }
        controller.dismiss(animated: true) {
            self.completion(draft)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true) {
            self.completion(nil)
        }
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
            self.completion = nil
        @unknown default:
            completion(.failure(SwitchboardMediaAttachmentError.locationUnavailable))
            self.completion = nil
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
        finish(
            .success(
                SwitchboardAttachmentDraft.location(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            )
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<String, Error>) {
        completion?(result)
        completion = nil
    }
}

enum SwitchboardMediaAttachmentError: LocalizedError, Equatable {
    case locationDenied
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .locationDenied:
            return "Enable Location access in Settings to share your position in Switchboard messages."
        case .locationUnavailable:
            return "Could not determine your current location."
        }
    }
}

struct SwitchboardAudioRecorderView: View {
    let onRecorded: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = SwitchboardAudioRecorder()
    @State private var errorMessage: String?

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

                if let errorMessage {
                    Text(errorMessage)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

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
        } else if let error = recorder.start() {
            errorMessage = error
        } else {
            errorMessage = nil
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

    @discardableResult
    func start() -> String? {
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
            guard recorder.prepareToRecord(), recorder.record() else {
                return "Could not start audio recording."
            }
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
            return nil
        } catch {
            isRecording = false
            return error.localizedDescription
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
            .onAppear {
                controller.onDraft = { draft in
                    applyDraft(draft)
                }
            }
            .sheet(isPresented: $controller.showAudioRecorder) {
                SwitchboardAudioRecorderView { draft in
                    applyDraft(draft)
                }
                .presentationDetents([.medium, .large])
            }
            .alert(controller.alertTitle, isPresented: $controller.showAlert) {
                if controller.alertOffersSettings {
                    Button("Open Settings") {
                        controller.openSettings()
                    }
                    Button("Cancel", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
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
