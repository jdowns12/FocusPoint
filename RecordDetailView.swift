import SwiftUI
import CloudKit
import PhotosUI
import SharedWithYou
import Combine
import CoreLocation
import UIKit

struct RecordDetailView: View {

    @Environment(CloudManager.self) var shareManager

    @State private var showSharingController: Bool = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isUploading: Bool = false

    @State private var cacheLoaded = false
    @State private var cancellables: Set<AnyCancellable> = []
    @State private var hasUnsavedChanges = false

    @State private var showCamera = false
    @State private var cameraImage: UIImage? = nil
    
    @State private var showImageFullScreen = false
    
    @State private var showSaveResult: Bool = false
    @State private var saveResultMessage: String? = nil

    @GestureState private var dragOffset: CGFloat = 0
    @State private var hasDraggedToDismiss = false
    
    @FocusState private var fieldInFocus: Field?
    
    enum Field {
        case title
        case content
    }

    private var locationPermissionDenied: Bool {
        CLLocationManager().authorizationStatus == .denied
    }

    // Loads the image from the CKAsset (if present) on view appear
    private func loadPersistedImageIfNeeded() {
        guard selectedImage == nil else { return } // Don't override if already picked in this session
        guard let asset = shareManager.displayRecord?[CloudManager.imageKey] as? CKAsset, let url = asset.fileURL else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.selectedImage = image
                }
            }
        }
    }

    private func saveChanges() {
        Task {
            guard let _ = shareManager.displayRecord else { return }
            do {
                try await shareManager.updateCKRecordIfNeeded()
                hasUnsavedChanges = false
            } catch {
                print("Error saving changes: \(error)")
                shareManager.error = error
            }
        }
    }
    
    var body: some View {


        ScrollView {
            VStack(spacing: 24) {
                // Last Modified Info Card
                if let displayRecord = shareManager.displayRecord,
                   let share = shareManager.share,
                   let lastModified = displayRecord.lastModifiedDateString {
                    HStack(alignment: .top) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last modified")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let userName = displayRecord.lastModifiedUserName(share) {
                                Text("\(lastModified) by \(userName)")
                            } else {
                                Text(lastModified)
                            }
                        }
                        .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thickMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                    .padding(.horizontal, 8)
                }

                // Image Card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Photo")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.bottom, 4)
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(10)
                                .padding(8)
                                .onTapGesture {
                                    showImageFullScreen = true
                                }
                                .accessibilityLabel("Show Image Fullscreen")
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray.opacity(0.6))
                                Text("No image selected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(height: 200)
                        }
                    }
                    .frame(height: 210)
                    .padding(.bottom, 6)
                    HStack {
                        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                            Label(selectedImage == nil ? "Pick an Image" : "Select/Change Image", systemImage: "photo")
                        }
                        .disabled(isUploading)
                        Button(action: { showCamera = true }) {
                            Label("Take Photo", systemImage: "camera")
                        }
                        .disabled(isUploading)
                        if isUploading {
                            ProgressView("Uploading... Do not leave until I'm gone!")
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal, 8)

                // Title Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.title3)
                        .fontWeight(.semibold)
                    HStack {
                        TextField("Enter title...", text: Binding(
                            get: { shareManager.title },
                            set: {
                                shareManager.title = $0
                                if let displayRecord = shareManager.displayRecord {
                                    shareManager.saveLocalCache(title: $0, content: shareManager.content, for: displayRecord.recordID)
                                }
                            }
                        ))
                        .focused($fieldInFocus, equals: .title)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.tertiarySystemBackground)))
                        if !shareManager.title.isEmpty {
                            Button(action: {
                                shareManager.title = ""
                                if let displayRecord = shareManager.displayRecord {
                                    shareManager.saveLocalCache(title: "", content: shareManager.content, for: displayRecord.recordID)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.gray.opacity(0.6))
                            }
                            .padding(.trailing, 8)
                            .accessibilityLabel("Clear title")
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal, 8)

                // Content Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Content")
                        .font(.title3)
                        .fontWeight(.semibold)
                    HStack(alignment: .top) {
                        TextField("Enter content...", text: Binding(
                            get: { shareManager.content },
                            set: {
                                shareManager.content = $0
                                if let displayRecord = shareManager.displayRecord {
                                    shareManager.saveLocalCache(title: shareManager.title, content: $0, for: displayRecord.recordID)
                                }
                            }
                        ), axis: .vertical)
                        .lineLimit(3...)
                        .focused($fieldInFocus, equals: .content)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.tertiarySystemBackground)))
                        if !shareManager.content.isEmpty {
                            Button(action: {
                                shareManager.content = ""
                                if let displayRecord = shareManager.displayRecord {
                                    shareManager.saveLocalCache(title: shareManager.title, content: "", for: displayRecord.recordID)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.gray.opacity(0.6))
                            }
                            .padding(.trailing, 8)
                            .accessibilityLabel("Clear content")
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal, 8)


                if locationPermissionDenied {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Location permission denied. Your current location wasn't captured when creating this note.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(Color.yellow.opacity(0.18))
                    .cornerRadius(10)
                }

                // Collaboration/Map Card
                SWCollaborationWithMapView(
                    share: shareManager.share,
                    container: shareManager.container,
                    image: selectedImage
                )
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
                .padding(.horizontal, 8)

                Spacer(minLength: 24)
            }
            .padding(.top, 24)
        }
        .onChange(of: shareManager.displayRecord) { _, newRecord in
            guard let newRecord = newRecord else { return }
            // Only update if the user does not have unsaved changes
            if !hasUnsavedChanges {
                shareManager.title = newRecord.title
                shareManager.content = newRecord.content
            }
        }
        .navigationTitle(shareManager.displayRecord?.title ?? "(Untitled)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            ToolbarItem(placement: .topBarTrailing, content: {
                if let share = self.shareManager.share {
                    _SWCollaborationView(share: share, container: self.shareManager.container, image: selectedImage, showSharingController: $showSharingController)
                        .frame(width: 36, height: 36)
                        .sheet(isPresented: $showSharingController, content: {
                            _UICloudSharingController(
                                share: share,
                                container: self.shareManager.container,
                                itemTitle: "Collaboration Time!",
                                onSaveShareFail: { error in
                                    print("save share failed: \(error)")
                                    shareManager.error = error
                                },
                                onSaveShareSuccess: {
                                    Task {
                                        do {
                                            try await shareManager.cloudSharingControllerDidSaveShare()
                                        } catch(let error) {
                                            print("shareManager.cloudSharingControllerDidSaveShare error: \(error)")
                                            shareManager.error = error
                                        }
                                    }
                                },
                                onShareStop:  {
                                    Task {
                                        do {
                                            try await shareManager.cloudSharingControllerDidStopSharing()
                                        } catch(let error) {
                                            print("shareManager.cloudSharingControllerDidStopSharing error: \(error)")
                                            shareManager.error = error
                                        }
                                    }
                                }
                            )
                            .ignoresSafeArea()
                        })
                }
            })
            ToolbarItem(placement: .topBarTrailing, content: {
                ShareLink(item: self.shareManager.sharedNoteTransferable, preview: SharePreview(self.shareManager.title, image: Image(systemName: "square.and.pencil")))
            })
        })
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if fieldInFocus != nil {
                    Button("Dismiss") {
                        fieldInFocus = nil
                    }
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                        isUploading = true
                    }
                    do {
                        try await shareManager.uploadImage(image)
                    } catch {
                        print("Failed to upload image: \(error)")
                    }
                    await MainActor.run {
                        isUploading = false
                    }
                }
            }
        }
        .task {
            if !cacheLoaded, let displayRecord = shareManager.displayRecord, let cache = shareManager.loadLocalCache(for: displayRecord.recordID) {
                await MainActor.run {
                    shareManager.title = cache.title
                    shareManager.content = cache.content
                    cacheLoaded = true
                }
            }
            loadPersistedImageIfNeeded()
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                Task {
                    await MainActor.run {
                        selectedImage = image
                        isUploading = true
                    }
                    do {
                        try await shareManager.uploadImage(image)
                    } catch {
                        print("Failed to upload camera image: \(error)")
                    }
                    await MainActor.run {
                        isUploading = false
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showImageFullScreen) {
            if let selectedImage = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                        .ignoresSafeArea()
                        .offset(y: dragOffset)
                        .opacity(Double(1.0 - min(abs(dragOffset) / 200, 0.4)))
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .updating($dragOffset) { value, state, _ in
                                    if value.translation.height > 0 {
                                        state = value.translation.height
                                    }
                                }
                                .onEnded { value in
                                    if value.translation.height > 120 {
                                        showImageFullScreen = false
                                        hasDraggedToDismiss = true
                                    }
                                }
                        )
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Button(action: {
                                showImageFullScreen = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .padding()
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Button(action: {
                                ImageSaveHelper.shared.onComplete = { error in
                                    if let error = error {
                                        saveResultMessage = "Save failed: \(error.localizedDescription)"
                                    } else {
                                        saveResultMessage = "Image saved to your photos."
                                    }
                                    showSaveResult = true
                                }
                                UIImageWriteToSavedPhotosAlbum(selectedImage, ImageSaveHelper.shared, #selector(ImageSaveHelper.saveCompletionHandler(_:didFinishSavingWithError:contextInfo:)), nil)
                            }) {
                                Image(systemName: "square.and.arrow.down")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .padding()
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                        }
                        HStack {
                            Spacer(minLength: 0)
                            Text("swipe down to dismiss")
                                .font(.footnote)
                                .foregroundColor(Color.white.opacity(0.8))
                                .frame(height: 40)
                            Spacer()
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 4)
                    }
                }
                .alert(isPresented: $showSaveResult) {
                    Alert(title: Text("Save Image"), message: Text(saveResultMessage ?? ""), dismissButton: .default(Text("OK")))
                }
            }
        }
    }
}

class ImageSaveHelper: NSObject {
    static let shared = ImageSaveHelper()
    var onComplete: ((Error?) -> Void)?

    @objc func saveCompletionHandler(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
        onComplete?(error)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let sourceType: UIImagePickerController.SourceType
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

