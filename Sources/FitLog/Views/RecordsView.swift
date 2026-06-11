import SwiftUI

struct RecordsView: View {
    @EnvironmentObject var store: FitStore

    var body: some View {
        NavigationStack {
            Text("历史记录")
                .navigationTitle("记录")
        }
    }
}
