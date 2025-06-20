/*
 Author: Jadon Downs
 Created on: 6-10-25
 Description: SwiftUI representable for UICloudSharingController, handling CloudKit sharing and delegate events.
*/

import SwiftUI
import CloudKit

struct CloudSharingView: UIViewControllerRepresentable {
    var container: CKContainer
    var share: CKShare
    var rootRecord: CKRecord
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let sharingController = UICloudSharingController(share: share, container: container)
        sharingController.delegate = context.coordinator
        return sharingController
    }
    
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {
        // No update needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        var parent: CloudSharingView
        
        init(parent: CloudSharingView) {
            self.parent = parent
        }
        
        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Failed to save share: \(error.localizedDescription)")
            parent.isPresented = false
        }
        
        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            print("Successfully saved share")
            parent.isPresented = false
        }
        
        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            print("Stopped sharing")
            parent.isPresented = false
        }
        
        func itemTitle(for csc: UICloudSharingController) -> String? {
            return parent.rootRecord["title"] as? String ?? "Shared Item"
        }
        
        func cloudSharingController(_ csc: UICloudSharingController, previewForSharingContext sharingContext: UICloudSharingController.SharingContext) -> UIViewController? {
            return nil
        }
    }
}
