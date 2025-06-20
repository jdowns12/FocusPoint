import SwiftUI

struct SettingsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Settings")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 16)

                Text("Don't forget to report bugs and feature requests in the Feedback tab and join our Discord community below for first hand assistance!")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundStyle(.primary)

                Link(destination: URL(string: "https://discord.gg/MSs56Uq5rf")!) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.accentColor)
                        Text("Join our Discord Community")
                            .foregroundColor(.accentColor)
                    }
                    .font(.headline)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }

                // Blank customizable field
                Text("Features Planned has been moved to the feedback tab. Please use the green plus button to submit feedback (bugs or requests) this will go to me directly. Utilize the voting system by upvoting and submitting the features you care about the most. Note: I currently have the free version of WishKit- meaning I can only display 5 requests at a time but I am able to see all requests and bugs.")

                Text("Known Bugs/Quirks:\n1. Selecting current location may take a few moments. You may need to click the 'current location' text a few times.\n2. Take a photo is a little odd looking. this may change. \n3. Location pins may jitter in color on map view.\n4. May encounter an errors when sharing from or with someone on ios 26.\n5. You must have iCloud storage for this to work - storing on icloud is safe and secure so this is the only way I will save data.")
                

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    SettingsView()
}
