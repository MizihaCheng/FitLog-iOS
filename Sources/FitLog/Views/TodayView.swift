import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: FitStore

    var body: some View {
        NavigationStack {
            Text("今日训练")
                .navigationTitle("今日")
        }
    }
}
