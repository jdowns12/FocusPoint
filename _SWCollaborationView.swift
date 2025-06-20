/*
 Author: Jadon Downs
 Created on: 6-10-25
 Description: Implements UI components for selecting and saving map locations, managing iCloud sharing, and provides placeholder classes for future SharedWithYou collaboration integration.
*/

import CloudKit
import SwiftUI
import SharedWithYou
import CloudKit
import MapKit
import CoreLocation
import Combine
import Foundation

// NOTE: This file assumes that CloudManager.swift contains the following async function:
// @MainActor
// func uploadLocation(_ coordinate: CLLocationCoordinate2D) async throws {
//     guard let displayRecord else { throw _Error.noRecordSelectedForShare }
//     let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
//     displayRecord[CloudManager.locationKey] = location
//     let database = displayRecord.isOwner ? self.privateDatabase : self.sharedCloudDatabase
//     let saved = try await database.save(displayRecord)
//     self.displayRecord = saved
// }
// Make sure CloudManager.locationKey exists and the above method is implemented in CloudManager.swift.

import CoreLocation
import Foundation

// PLACEHOLDER: SWCollaborationView and registerCKShare are stub implementations so the project will compile without SharedWithYou/Collaboration support. Replace these with actual implementations when available.
class SWCollaborationView: UIView {
    init(itemProvider: NSItemProvider) {
        super.init(frame: .zero)
        // TODO: implement or link actual functionality
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func setShowManageButton(_ show: Bool) {}
    func setDetailViewListContent(_ viewProvider: @escaping () -> UIView) {}
}

extension NSItemProvider {
    func registerCKShare(_ share: CKShare, container: CKContainer, allowedSharingOptions: CKAllowedSharingOptions) {
        // TODO: implement or link actual functionality
    }
}
// End of placeholders.

struct _SWCollaborationView: UIViewRepresentable {
    var share: CKShare
    var container: CKContainer
    var image: UIImage?
    
    @Binding var showSharingController: Bool

    init(share: CKShare, container: CKContainer, image: UIImage?, showSharingController: Binding<Bool>) {
        self.share = share
        self.container = container
        self.image = image
        self._showSharingController = showSharingController
    }

    func makeUIView(context: Context) -> SWCollaborationView {
        let itemProvider = NSItemProvider()
        
        itemProvider.registerCKShare(share, container: container, allowedSharingOptions: CloudManager.sharingOption)
        let collaborationView = SWCollaborationView(itemProvider: itemProvider)
        
        collaborationView.setShowManageButton(false)
        collaborationView.setDetailViewListContent({
            let button = Button(action: {
                showSharingController = true
            }, label: {
                HStack {
                    Text("Manage Share")
                        .foregroundStyle(.foreground)
                    Spacer()
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(.link)
                }
            })
            let controller = UIHostingController(rootView: button)
            controller.view.backgroundColor = .clear // to blend with the UIKit background if needed
            return controller.view
        })
        
        return collaborationView
    }
    
    func updateUIView(_ uiView: SWCollaborationView, context: Context) {}
}

struct LocationPickerMapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D?
    @Binding var region: MKCoordinateRegion
    var showsUserLocation: Bool
    var isInteractive: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.setRegion(region, animated: false)
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isScrollEnabled = isInteractive
        mapView.isZoomEnabled = isInteractive
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.setRegion(region, animated: true)
        mapView.isScrollEnabled = isInteractive
        mapView.isZoomEnabled = isInteractive
        // Keep pin centered, but we don't add a real annotation. Optionally, update region binding.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPickerMapView
        init(parent: LocationPickerMapView) { self.parent = parent }
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.coordinate = mapView.centerCoordinate
            parent.region = mapView.region
        }
    }
}

struct SWCollaborationWithMapView: View {
    @Environment(CloudManager.self) private var cloudManager
    
    var share: CKShare?
    var container: CKContainer?
    var image: UIImage?
    
    @StateObject private var locationManager = LocationManager()
    
    @State private var selectedCoordinate: CLLocationCoordinate2D? = nil
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 37.334_900, longitude: -122.009_020), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
    @State private var showSharingController: Bool = false
    
    @State private var placeName: String? = nil
    @State private var isFetchingPlacename: Bool = false
    
    private var savedLocation: CLLocation? {
        cloudManager.displayRecord?[CloudManager.locationKey] as? CLLocation
    }
    
    private func fetchPlacename(for coordinate: CLLocationCoordinate2D?) {
        guard let coordinate else {
            self.placeName = nil
            return
        }
        self.isFetchingPlacename = true
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                self.isFetchingPlacename = false
                if let placemark = placemarks?.first {
                    let city = placemark.locality ?? ""
                    let state = placemark.administrativeArea ?? ""
                    self.placeName = ([city, state].filter { !$0.isEmpty }).joined(separator: ", ")
                } else {
                    self.placeName = nil
                }
            }
        }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                if locationManager.authorizationStatus == .denied {
                    Text("Location permission denied. Enable location access in Settings to use Current Location.")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(8)
                        .background(Color(.systemBackground).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                ZStack {
                    LocationPickerMapView(coordinate: $selectedCoordinate, region: $region, showsUserLocation: true, isInteractive: true)
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onAppear {
                            if let loc = savedLocation {
                                region.center = loc.coordinate
                                selectedCoordinate = loc.coordinate
                                fetchPlacename(for: loc.coordinate)
                            }
                        }
                        .onChange(of: savedLocation) { _, newValue in
                            if let loc = newValue {
                                region.center = loc.coordinate
                                selectedCoordinate = loc.coordinate
                                fetchPlacename(for: loc.coordinate)
                            }
                        }
                    Image(systemName: "mappin")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                }
                
                if isFetchingPlacename {
                    ProgressView("Fetching location...")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else if let placeName = placeName, !placeName.isEmpty {
                    Text(placeName)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 2)
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        locationManager.requestLocation()
                        if let userLocation = locationManager.currentLocation {
                            region.center = userLocation
                            selectedCoordinate = userLocation
                        }
                    }) {
                        Label("Current Location", systemImage: "location.fill")
                    }
                    .disabled(locationManager.authorizationStatus == .denied)
                    
                    Button(action: {
                        if let coordinate = selectedCoordinate {
                            Task {
                                try? await cloudManager.uploadLocation(coordinate)
                            }
                        }
                    }) {
                        Label("Save This Location", systemImage: "plus")
                    }
                }

                if let share = share, let container = container {
                    _SWCollaborationView(share: share, container: container, image: image, showSharingController: $showSharingController)
                }

                if let loc = savedLocation {
                    VStack(spacing: 4) {
                        Text("Saved Location:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Lat: \(loc.coordinate.latitude), Lon: \(loc.coordinate.longitude)")
                            .font(.footnote)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
            .padding()
        }
    }
}

// The map pin visually stays centered as the user pans the map,
// and the selectedCoordinate binding updates accordingly as the region changes.

