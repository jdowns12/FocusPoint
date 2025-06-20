import SwiftUI
import MapKit
import CloudKit

class ImageCacheLoader {
    static let shared = ImageCacheLoader()
    private var cache: [CKRecord.ID: UIImage] = [:]
    private let queue = DispatchQueue(label: "ImageCacheLoader.background")

    func image(for record: CKRecord, completion: @escaping (UIImage?) -> Void) {
        if let cached = cache[record.recordID] {
            completion(cached)
            return
        }
        queue.async {
            let image = NoteAnnotation.loadImage(for: record)
            DispatchQueue.main.async {
                if let image = image {
                    self.cache[record.recordID] = image
                }
                completion(image)
            }
        }
    }
}

// Extend IdentifiableRecord so it can be used in NavigationStack and sheets
struct IdentifiableRecord: Identifiable, Equatable, Hashable {
    let record: CKRecord
    var id: String { record.recordID.recordName }
    static func == (lhs: IdentifiableRecord, rhs: IdentifiableRecord) -> Bool {
        lhs.record.recordID == rhs.record.recordID
    }
}

struct NotesMapView: View {
    @Environment(CloudManager.self) private var manager
    private let imageLoader = ImageCacheLoader.shared
    @State private var pinImages: [String: UIImage] = [:] // recordName: image
    
    @State private var selectedRecord: IdentifiableRecord? = nil
    @State private var showBottomSheet = false
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.00902),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var isMapCameraUserControlled = false

    private var recordsWithLocation: [CKRecord] {
        (manager.myRecords + manager.sharedWithMe)
            .filter { $0[CloudManager.locationKey] is CLLocation }
    }
    private var pins: [NoteAnnotation] {
        recordsWithLocation.compactMap { record in
            guard let loc = record[CloudManager.locationKey] as? CLLocation else { return nil }
            let isShared = manager.sharedWithMe.contains { $0.recordID == record.recordID }
            let image = pinImages[record.recordID.recordName] // Only use preloaded image
            return NoteAnnotation(coordinate: loc.coordinate, record: record, isShared: isShared, image: image)
        }
    }
    
    private var clusteredPins: [NoteAnnotation] {
        guard !pins.isEmpty else { return [] }
        let thresholdLat = region.span.latitudeDelta / 10
        let thresholdLon = region.span.longitudeDelta / 10
        
        var clusters: [[NoteAnnotation]] = []
        
        pins.forEach { pin in
            if let clusterIndex = clusters.firstIndex(where: { cluster in
                cluster.contains(where: { other in
                    abs(other.coordinate.latitude - pin.coordinate.latitude) < thresholdLat &&
                    abs(other.coordinate.longitude - pin.coordinate.longitude) < thresholdLon
                })
            }) {
                clusters[clusterIndex].append(pin)
            } else {
                clusters.append([pin])
            }
        }
        
        // For each cluster pick the most recent record by creationDate
        return clusters.compactMap { cluster in
            cluster.max(by: { ($0.record.creationDate ?? Date.distantPast) < ($1.record.creationDate ?? Date.distantPast) })
        }
    }

    private func computeRegion(for pins: [NoteAnnotation]) -> MKCoordinateRegion? {
        guard !pins.isEmpty else { return nil }
        let lats = pins.map { $0.coordinate.latitude }.sorted()
        let lons = pins.map { $0.coordinate.longitude }.sorted()
        let q1Lat = lats[lats.count / 4], q3Lat = lats[(3 * lats.count) / 4]
        let iqrLat = q3Lat - q1Lat
        let q1Lon = lons[lons.count / 4], q3Lon = lons[(3 * lons.count) / 4]
        let iqrLon = q3Lon - q1Lon
        let filtered = pins.filter {
            abs($0.coordinate.latitude  - q1Lat) <= 1.5 * iqrLat &&
            abs($0.coordinate.latitude  - q3Lat) <= 1.5 * iqrLat &&
            abs($0.coordinate.longitude - q1Lon) <= 1.5 * iqrLon &&
            abs($0.coordinate.longitude - q3Lon) <= 1.5 * iqrLon
        }
        let used = filtered.isEmpty ? pins : filtered
        let latitudes = used.map { $0.coordinate.latitude }
        let longitudes = used.map { $0.coordinate.longitude }
        let avgLat = latitudes.reduce(0, +) / Double(latitudes.count)
        let avgLon = longitudes.reduce(0, +) / Double(longitudes.count)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (latitudes.max()! - latitudes.min()!) * 2.5),
            longitudeDelta: max(0.01, (longitudes.max()! - longitudes.min()!) * 2.5)
        )
        return MKCoordinateRegion(center: .init(latitude: avgLat, longitude: avgLon), span: span)
    }

    private func resetToPins() {
        if let newRegion = computeRegion(for: clusteredPins) {
            region = newRegion
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MapKitWrapper(
                    region: $region,
                    userControlled: $isMapCameraUserControlled,
                    selectedRecord: $selectedRecord,
                    showBottomSheet: $showBottomSheet,
                    annotations: clusteredPins,
                    manager: manager
                )
                .onAppear {
                    resetToPins()
                    for record in recordsWithLocation {
                        if pinImages[record.recordID.recordName] == nil {
                            imageLoader.image(for: record) { image in
                                if let image = image {
                                    pinImages[record.recordID.recordName] = image
                                }
                            }
                        }
                    }
                }
                .onChange(of: clusteredPins) { newPins in
                    // Removed resetToPins() call here as per instructions
                }
                .onChange(of: recordsWithLocation) { newRecords in
                    for record in newRecords {
                        if pinImages[record.recordID.recordName] == nil {
                            imageLoader.image(for: record) { image in
                                if let image = image {
                                    pinImages[record.recordID.recordName] = image
                                }
                            }
                        }
                    }
                }
                if clusteredPins.isEmpty {
                    Text("No notes with locations yet.")
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(14)
                }
            }
            .navigationTitle("Notes Map")
            .sheet(isPresented: $showBottomSheet) {
                if let selectedRecord {
                    RecordDetailView()
                        .environment(manager)
                } else {
                    EmptyView()
                }
            }
        }
    }
}

struct MapKitWrapper: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var userControlled: Bool
    @Binding var selectedRecord: IdentifiableRecord?
    @Binding var showBottomSheet: Bool
    var annotations: [NoteAnnotation]
    let manager: CloudManager

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)
        mapView.gestureRecognizers?.forEach { gr in
            if let pan = gr as? UIPanGestureRecognizer {
                pan.addTarget(context.coordinator, action: #selector(Coordinator.handleGesture(_:)))
            }
            if let pinch = gr as? UIPinchGestureRecognizer {
                pinch.addTarget(context.coordinator, action: #selector(Coordinator.handleGesture(_:)))
            }
        }
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.setRegion(region, animated: false)
        uiView.removeAnnotations(uiView.annotations)
        uiView.addAnnotations(annotations)
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapKitWrapper
        init(_ parent: MapKitWrapper) { self.parent = parent }

        @objc func handleGesture(_ gr: UIGestureRecognizer) {
            if gr.state == .began { parent.userControlled = true }
        }
        
        class NoteImageAnnotationView: MKAnnotationView {
            static let basePinImage = UIImage(systemName: "mappin.circle.fill")
            let imageView = UIImageView()
            let pinImageView = UIImageView()
            
            private var lastImageId: String? = nil
            
            override var annotation: MKAnnotation? {
                willSet {
                    guard let note = newValue as? NoteAnnotation else { return }
                    
                    // Cross-fade animation for imageView's image if image changed
                    if note.image != imageView.image {
                        // Animation region: cross-fade imageView image
                        UIView.animate(withDuration: 0.25, animations: {
                            self.imageView.alpha = 0
                        }, completion: { _ in
                            self.imageView.image = note.image
                            UIView.animate(withDuration: 0.25) {
                                self.imageView.alpha = 1
                            }
                        })
                    }
                    
                    // Set pin tint based on shared status
                    if note.isShared {
                        pinImageView.image = UIImage(systemName: "mappin.circle.fill")?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
                    } else {
                        pinImageView.image = UIImage(systemName: "mappin.circle.fill")?.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
                    }
                    
                    // Set borderColor based on shared status
                    if note.isShared {
                        imageView.layer.borderColor = UIColor.systemBlue.cgColor
                    } else {
                        imageView.layer.borderColor = UIColor.systemRed.cgColor
                    }
                    
                    // Bounce animation if annotation's id changed (new cluster representative)
                    if lastImageId != note.id {
                        lastImageId = note.id
                        // Animation region: bounce scale up and back for both imageView and pinImageView
                        imageView.transform = CGAffineTransform.identity
                        pinImageView.transform = CGAffineTransform.identity
                        UIView.animate(withDuration: 0.15,
                                       animations: {
                            self.imageView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
                            self.pinImageView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
                        }, completion: { _ in
                            UIView.animate(withDuration: 0.15) {
                                self.imageView.transform = CGAffineTransform.identity
                                self.pinImageView.transform = CGAffineTransform.identity
                            }
                        })
                    }
                    
                    setNeedsLayout()
                }
            }
            
            override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
                super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
                setup()
            }
            
            required init?(coder aDecoder: NSCoder) {
                super.init(coder: aDecoder)
                setup()
            }
            
            private func setup() {
                // imageView: small thumbnail above pin
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.layer.cornerRadius = 6
                imageView.layer.borderColor = UIColor.white.cgColor
                imageView.layer.borderWidth = 1
                addSubview(imageView)
                
                pinImageView.contentMode = .scaleAspectFit
                addSubview(pinImageView)
                
                // Make entire annotation view and subviews user interactive for tap recognition
                isUserInteractionEnabled = true
                imageView.isUserInteractionEnabled = true
                pinImageView.isUserInteractionEnabled = true
            }
            
            override func layoutSubviews() {
                super.layoutSubviews()
                
                let imageSize: CGFloat = 48
                let pinWidth: CGFloat = 32
                let overlap: CGFloat = 10
                
                let newImageFrame = CGRect(x: (bounds.width - imageSize) / 2, y: 0, width: imageSize, height: imageSize)
                let newPinFrame = CGRect(x: (bounds.width - pinWidth) / 2, y: newImageFrame.maxY - overlap, width: pinWidth, height: 32)
                
                // Animation region: smooth movement/resize of imageView and pinImageView frames if changed
                if imageView.frame != newImageFrame || pinImageView.frame != newPinFrame {
                    UIView.animate(withDuration: 0.25) {
                        self.imageView.frame = newImageFrame
                        self.pinImageView.frame = newPinFrame
                    }
                } else {
                    imageView.frame = newImageFrame
                    pinImageView.frame = newPinFrame
                }
                
                // Expand bounds if needed so both subviews are inside and tappable
                let combinedHeight = imageView.frame.height + pinImageView.frame.height - overlap
                let combinedWidth = max(imageView.frame.width, pinImageView.frame.width)
                bounds = CGRect(x: 0, y: 0, width: combinedWidth, height: combinedHeight)
                
                // Do NOT set self.frame here. Let MapKit size and position the view.
                centerOffset = CGPoint(x: 0, y: -combinedHeight / 2)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let note = annotation as? NoteAnnotation else { return nil }
            let id = "NoteImagePin"
            if let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? NoteImageAnnotationView {
                view.annotation = annotation
                return view
            } else {
                let view = NoteImageAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.canShowCallout = false
                return view
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let ann = view.annotation as? NoteAnnotation else { return }
            parent.manager.setDisplayRecordAndUpdateTitleContent(ann.record)
            parent.selectedRecord = IdentifiableRecord(record: ann.record)
            parent.showBottomSheet = true
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }
    }
}

class NoteAnnotation: NSObject, MKAnnotation, Identifiable {
    let coordinate: CLLocationCoordinate2D
    let record: CKRecord
    let isShared: Bool
    let image: UIImage?
    var id: String { record.recordID.recordName }
    init(coordinate: CLLocationCoordinate2D, record: CKRecord, isShared: Bool, image: UIImage?) {
        self.coordinate = coordinate
        self.record = record
        self.isShared = isShared
        self.image = image
    }
    
    static func loadImage(for record: CKRecord) -> UIImage? {
        // Note: For production, thumbnails should be loaded or decoded asynchronously and cached, not on the main thread.
        
        if let asset = record[CloudManager.imageKey] as? CKAsset,
           let url = asset.fileURL {
            do {
                let data = try Data(contentsOf: url)
                if let image = UIImage(data: data) {
                    return image
                }
            } catch {
                return nil
            }
        }
        if let asset = record["thumbnail"] as? CKAsset,
           let url = asset.fileURL {
            do {
                let data = try Data(contentsOf: url)
                if let image = UIImage(data: data) {
                    return image
                }
            } catch {
                return nil
            }
        }
        if let asset = record["photo"] as? CKAsset,
           let url = asset.fileURL {
            do {
                let data = try Data(contentsOf: url)
                if let image = UIImage(data: data) {
                    return image
                }
            } catch {
                return nil
            }
        }
        return nil
    }
}

