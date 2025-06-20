/*
 Author: Jadon Downs
 Created on: 6-10-25
 Description: Adds computed properties and helpers to CKRecord for title, content, ownership, and last modified metadata display.
*/

// Project-wide CKRecord extensions for CloudManager compatibility

import SwiftUI
import CloudKit


extension CKRecord {
    var title: String {
        self.value(forKey: CloudManager.titleKey) as? String ?? "(Untitled)"
    }
    
    var content: String {
        self.value(forKey: CloudManager.contentKey) as? String ?? ""
    }
    
    var isOwner: Bool {
        self.creatorUserRecordID?.recordName == CKCurrentUserDefaultName
    }
    
    var lastModifiedDateString: String? {
        guard let modificationDate = self.modificationDate else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        return dateFormatter.string(from: modificationDate)
    }
    
    func lastModifiedUserName(_ share: CKShare) -> String? {

        guard let participant = share.participants.first(where: {$0.userIdentity.userRecordID == self.lastModifiedUserRecordID}) else {
            return nil
        }
        
        if participant.role == .owner {
            return "(Me)"
        }
        
        
        guard let nameComponents = participant.userIdentity.nameComponents else {
            return nil
        }
        
        var name = ""
        
        if let givenName = nameComponents.givenName {
            name += "\(givenName)"
        }
        
        if let familyName = nameComponents.familyName {
            if !name.isEmpty {
                name += " "
            }
            name += "\(familyName)"
        }
                
        return name.isEmpty ? nil : name
    }
}

