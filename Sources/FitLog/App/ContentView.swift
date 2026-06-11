import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今日", systemImage: "figure.strengthtraining.traditional") }
            RecordsView()
                .tabItem { Label("记录", systemImage: "list.bullet") }
            TrendsView()
                .tabItem { Label("趋势", systemImage: "chart.line.uptrend.xyaxis") }
            CalendarView()
                .tabItem { Label("日历", systemImage: "calendar") }
        }
    }
}
