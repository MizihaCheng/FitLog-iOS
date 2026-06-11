import SwiftUI

struct TrendsView: View {
    @EnvironmentObject var store: FitStore

    var body: some View {
        NavigationStack {
            Text("数据趋势")
                .navigationTitle("趋势")
        }
    }
}
