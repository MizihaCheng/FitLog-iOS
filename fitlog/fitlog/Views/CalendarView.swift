import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var store: FitStore

    var body: some View {
        NavigationStack {
            Text("训练日历")
                .navigationTitle("日历")
        }
    }
}
