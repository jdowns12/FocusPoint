/*
 Author: Jadon Downs
 Created on: 6-10-25
 Description: Displays and manages lists of user and shared notes, including navigation and thumbnail support, using SwiftUI.
*/

import SwiftUI
import CloudKit
import UIKit

/// A small view for showing a thumbnail from a CKRecord (if it has the image asset)
struct RecordThumbnailView: View {
    let record: CKRecord
    let size: CGFloat
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.secondarySystemBackground))
                    Image(systemName: "photo")
                        .font(.system(size: size * 0.5))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .frame(width: size, height: size)
            }
        }
        .onAppear {
            loadImageIfNeeded()
        }
    }

    private func loadImageIfNeeded() {
        guard image == nil else { return }
        if let asset = record[CloudManager.imageKey] as? CKAsset, let url = asset.fileURL {
            DispatchQueue.global(qos: .userInitiated).async {
                if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.image = uiImage
                    }
                }
            }
        }
    }
}

struct LocationCityStateView: View {
    let record: CKRecord
    @State private var cityState: String? = nil

    var body: some View {
        Text(cityState ?? "No location")
            .font(.caption)
            .foregroundStyle(cityState == nil ? .tertiary : .secondary)
            .italic(cityState == nil)
            .onAppear {
                guard cityState == nil,
                      let location = record[CloudManager.locationKey] as? CLLocation else {
                    return
                }
                let geo = CLGeocoder()
                geo.reverseGeocodeLocation(location) { placemarks, _ in
                    if let placemark = placemarks?.first {
                        let city = placemark.locality ?? ""
                        let state = placemark.administrativeArea ?? ""
                        let name = ([city, state].filter { !$0.isEmpty }).joined(separator: ", ")
                        DispatchQueue.main.async {
                            self.cityState = name.isEmpty ? nil : name
                        }
                    }
                }
            }
    }
}

struct MyNotesListView: View {
    @Environment(CloudManager.self) private var manager
    @State private var activateNewDetail = false
    @State private var lastNavigatedRecordID: CKRecord.ID? = nil
    @Binding var newlyCreatedRecordID: CKRecord.ID?
    
    func deleteMyNote(at offsets: IndexSet) {
        Task {
            for index in offsets {
                try? await manager.deleteCKRecord(manager.myRecords[index].recordID)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink(
                destination: RecordDetailView()
                    .onAppear {
                        if let record = manager.displayRecord {
                            manager.setDisplayRecordAndUpdateTitleContent(record)
                        }
                    }
                    .onDisappear {
                        activateNewDetail = false
                        newlyCreatedRecordID = nil
                    },
                isActive: $activateNewDetail
            ) {
                EmptyView()
            }
            .hidden()

            Text("My Notes")
                .font(.largeTitle)
                .bold()
                .padding(.top)
                .padding(.horizontal)
            List {
                ForEach(manager.myRecords, id: \.recordID) { record in
                    NavigationLink(
                        destination: RecordDetailView()
                            .onAppear { manager.setDisplayRecordAndUpdateTitleContent(record) },
                        label: {
                            HStack(alignment: .top, spacing: 12) {
                                RecordThumbnailView(record: record, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.title)
                                    Text(record.content)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    LocationCityStateView(record: record)
                                }
                            }
                        }
                    )
                    .disabled(record.recordID == newlyCreatedRecordID && activateNewDetail)
                }
                .onDelete(perform: deleteMyNote)
            }
            .listStyle(.insetGrouped)
        }
        .task {
            try? await manager.refreshAllRecords()
        }
        .onChange(of: manager.displayRecord) { newValue in
            // Only trigger programmatic navigation for a newly created record
            if let record = newValue, record.isOwner, record.recordID != lastNavigatedRecordID, record.recordID == newlyCreatedRecordID {
                activateNewDetail = true
                lastNavigatedRecordID = record.recordID
            }
        }
    }
}

struct SharedNotesListView: View {
    @Environment(CloudManager.self) private var manager
    
    func deleteSharedNote(at offsets: IndexSet) {
        Task {
            for index in offsets {
                try? await manager.deleteCKRecord(manager.sharedWithMe[index].recordID)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shared Notes")
                .font(.largeTitle)
                .bold()
                .padding(.top)
                .padding(.horizontal)
            List {
                ForEach(manager.sharedWithMe, id: \.recordID) { record in
                    NavigationLink(
                        destination: RecordDetailView()
                            .onAppear { manager.setDisplayRecordAndUpdateTitleContent(record) }
                    ) {
                        HStack(alignment: .top, spacing: 12) {
                            RecordThumbnailView(record: record, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.title)
                                Text(record.content)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                LocationCityStateView(record: record)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteSharedNote)
            }
            .listStyle(.insetGrouped)
        }
        .task {
            try? await manager.refreshAllRecords()
        }
    }
}
