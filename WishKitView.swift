/*
 Author: Jadon Downs
 Created on: 6-10-25
 Description: Integrates and displays the WishKit feedback UI using SwiftUI.
*/

import SwiftUI
import WishKit

struct WishKitView: View {
    init() {
        WishKit.configure(with: "55B1C4EF-31E7-4353-9206-9159CCBEFCB4")
    }

    var body: some View {
        // Show WishKit feedback UI
        WishKit.FeedbackListView()
    }
}

#if DEBUG
#Preview {
    WishKitView()
}
#endif

// Notes:
// 1. Make sure you've integrated WishKitSwiftUI via Swift Package Manager in Xcode: File > Add Packages > https://github.com/wishkit/wishkit-ios

