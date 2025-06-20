import SwiftUI
import CloudKit

struct _UICloudSharingController: UIViewControllerRepresentable {
    var share: CKShare
    var container: CKContainer
    
    var itemTitle: String?
    var onSaveShareFail: ((Error) -> Void)
    var onSaveShareSuccess: (() -> Void)
    var onShareStop: (() -> Void)

    typealias UIViewControllerType = UICloudSharingController
    
    func makeUIViewController(context: Context) -> UIViewControllerType {
        let sharingController = UICloudSharingController(share: share, container: container)
        sharingController.delegate = context.coordinator
        return sharingController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var parent: _UICloudSharingController
        init(_ parent: _UICloudSharingController) {
            self.parent = parent
        }
                
        // Called when saving a share fails.
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: any Error) {
            print("\(#function): \(error)")
            self.parent.onSaveShareFail(error)
        }
        
        // Called when CloudKit successfully saves a share.
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            print("\(#function)")
            self.parent.onSaveShareSuccess()
        }
        
        // Called when sharing stops. This can be owner stopping or participant removing themselves.
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            print(#function)
            self.parent.onShareStop()
        }
        
        // Provides the title for the invitation screen.
        func itemTitle(for csc: UICloudSharingController) -> String? {
            return self.parent.itemTitle
        }
    }
}
