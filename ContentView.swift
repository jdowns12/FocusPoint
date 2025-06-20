import SwiftUI
import CloudKit
import WishKit

struct ContentView: View {

    @State private var shareManager: CloudManager = .shared
    @State private var selectedTab: Int = 0
    @State private var showingFeedback = false
    @State private var newlyCreatedRecordID: CKRecord.ID? = nil
    
    private func refreshCurrentTab() {
        switch selectedTab {
        case 0:
            Task { try? await CloudManager.shared.refreshAllRecords() }
        case 1:
            Task { try? await CloudManager.shared.refreshAllRecords() } // Adjust if SharedNotes has its own refresh logic
        case 2:
            Task { try? await CloudManager.shared.refreshAllRecords() } // Adjust if NotesMapView has its own refresh logic
        default:
            break
        }
    }
    
    private func addNewRecordToCurrentTab() {
        switch selectedTab {
        case 0:
            Task {
                if let record = try? await CloudManager.shared.createNewCKRecord() {
                    newlyCreatedRecordID = record.recordID
                }
            }
        case 1:
            Task { try? await CloudManager.shared.createNewCKRecord() } // Adjust if needed
        case 2:
            Task { try? await CloudManager.shared.createNewCKRecord() } // Adjust if needed for NotesMapView
        default:
            break
        }
    }
    
    var body: some View {
        Group {
            if shareManager.accountStatus != .available {
                ContentUnavailableView(label: {
                    Label("iCloud Not Available", systemImage: "questionmark.app")
                }, description: {
                    Text("Please Sign in to your iCloud account!")
                        .multilineTextAlignment(.center)
                }, actions: {
                    if let settingURL = URL(string: UIApplication.openSettingsURLString) {
                        Button(action: {
                            UIApplication.shared.open(settingURL)
                        }, label: {
                            Text("Settings")
                        })
                    }
                })
            } else {
                NavigationStack {
                    TabView(selection: $selectedTab) {
                        NavigationStack {
                            MyNotesListView(newlyCreatedRecordID: $newlyCreatedRecordID)
                                .environment(shareManager)
                                .navigationTitle("My Notes")
                        }
                        .tabItem {
                            Label("My Notes", systemImage: "note.text")
                        }
                        .tag(0)
                        
                        NavigationStack {
                            SharedNotesListView()
                                .environment(shareManager)
                                .navigationTitle("Shared with me")
                        }
                        .tabItem {
                            Label("Shared", systemImage: "person.2")
                        }
                        .tag(1)
                        
                        NavigationStack {
                            NotesMapView()
                                .environment(shareManager)
                                .navigationTitle("Notes Map")
                        }
                        .tabItem {
                            Label("Map", systemImage: "map")
                        }
                        .tag(2)
                        
                        NavigationStack {
                            SettingsView()
                        }
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(3)
                        
                        Color.clear
                            .tabItem {
                                Label("Feedback", systemImage: "message")
                            }
                            .tag(4)
                    }
                    .onChange(of: selectedTab) { newValue in
                        if newValue == 4 {
                            showingFeedback = true
                            selectedTab = 0
                        }
                    }
                    .fullScreenCover(isPresented: $showingFeedback) {
                        NavigationStack {
                            WishKitView()
                                .navigationTitle("Feedback")
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarLeading) {
                                        Button(action: {
                                            showingFeedback = false
                                        }, label: {
                                            Label("Back", systemImage: "chevron.left")
                                        })
                                    }
                                }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            if selectedTab == 0 || selectedTab == 1 || selectedTab == 2 {
                                Button(action: refreshCurrentTab) {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            if selectedTab == 0 || selectedTab == 1 || selectedTab == 2 {
                                Button(action: addNewRecordToCurrentTab) {
                                    Image(systemName: "plus")
                                }
                            }
                        }
                    }
                }
            }
        }
        .alert("Oops!", isPresented: $shareManager.showError, actions: {
            Button(action: {
                shareManager.showError = false
            }, label: {
                Text("OK")
            })
        }, message: {
            Text("\(shareManager.error?.message ?? "Unknown Error")")
        })
    }
}

struct PreviewWrapper: View {
    @State private var selectedTab: Int = 0
    @State private var showingFeedback = false
    @State private var newlyCreatedRecordID: CKRecord.ID? = nil
    
    private func refreshCurrentTab() {
        switch selectedTab {
        case 0:
            Task { try? await CloudManager.shared.refreshAllRecords() }
        case 1:
            Task { try? await CloudManager.shared.refreshAllRecords() } // Adjust if SharedNotes has its own refresh logic
        case 2:
            Task { try? await CloudManager.shared.refreshAllRecords() } // Adjust if NotesMapView has its own refresh logic
        default:
            break
        }
    }
    
    private func addNewRecordToCurrentTab() {
        switch selectedTab {
        case 0:
            Task {
                if let record = try? await CloudManager.shared.createNewCKRecord() {
                    newlyCreatedRecordID = record.recordID
                }
            }
        case 1:
            Task { try? await CloudManager.shared.createNewCKRecord() } // Adjust if needed
        case 2:
            Task { try? await CloudManager.shared.createNewCKRecord() } // Adjust if needed for NotesMapView
        default:
            break
        }
    }
    
    var body: some View {
        Group {
            if CloudManager.shared.accountStatus != .available {
                ContentUnavailableView(label: {
                    Label("iCloud Not Available", systemImage: "questionmark.app")
                }, description: {
                    Text("Please Sign in to your iCloud account!")
                        .multilineTextAlignment(.center)
                }, actions: {
                    if let settingURL = URL(string: UIApplication.openSettingsURLString) {
                        Button(action: {
                            UIApplication.shared.open(settingURL)
                        }, label: {
                            Text("Settings")
                        })
                    }
                })
            } else {
                NavigationStack {
                    TabView(selection: $selectedTab) {
                        NavigationStack {
                            MyNotesListView(newlyCreatedRecordID: $newlyCreatedRecordID)
                                .environment(CloudManager.shared)
                                .navigationTitle("My Notes")
                        }
                        .tabItem {
                            Label("My Notes", systemImage: "note.text")
                        }
                        .tag(0)
                        
                        NavigationStack {
                            SharedNotesListView()
                                .environment(CloudManager.shared)
                                .navigationTitle("Shared with me")
                        }
                        .tabItem {
                            Label("Shared", systemImage: "person.2")
                        }
                        .tag(1)
                        
                        NavigationStack {
                            NotesMapView()
                                .environment(CloudManager.shared)
                                .navigationTitle("Notes Map")
                        }
                        .tabItem {
                            Label("Map", systemImage: "map")
                        }
                        .tag(2)
                        
                        NavigationStack {
                            SettingsView()
                        }
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(3)
                        
                        Color.clear
                            .tabItem {
                                Label("Feedback", systemImage: "message")
                            }
                            .tag(4)
                    }
                    .onChange(of: selectedTab) { newValue in
                        if newValue == 4 {
                            showingFeedback = true
                            selectedTab = 0
                        }
                    }
                    .fullScreenCover(isPresented: $showingFeedback) {
                        NavigationStack {
                            WishKitView()
                                .navigationTitle("Feedback")
                                .toolbar {
                                    ToolbarItem(placement: .navigationBarLeading) {
                                        Button(action: {
                                            showingFeedback = false
                                        }, label: {
                                            Label("Back", systemImage: "chevron.left")
                                        })
                                    }
                                }
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            if selectedTab == 0 || selectedTab == 1 || selectedTab == 2 {
                                Button(action: refreshCurrentTab) {
                                    Image(systemName: "arrow.clockwise")
                                }
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            if selectedTab == 0 || selectedTab == 1 || selectedTab == 2 {
                                Button(action: addNewRecordToCurrentTab) {
                                    Image(systemName: "plus")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    PreviewWrapper()
}
