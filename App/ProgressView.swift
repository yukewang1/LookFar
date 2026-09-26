import SwiftUI
import Charts

struct ProgressView: View {
    let store: AppStore
    @State private var period = HistoryPeriod.week

    private enum HistoryPeriod: String, CaseIterable, Identifiable {
        case week = "Week", month = "Month"
        var id: Self { self }
        var dayCount: Int { self == .week ? 7 : 30 }
    }

    private struct DayTotal: Identifiable {
        let date: Date
        let records: [RestRecord]
        var guidedCount: Int { records.filter { $0.kind == .guided }.count }
        var id: Date { date }
    }

    private struct HistorySnapshot {
        let days: [DayTotal]
        let metrics: RestMetrics
        let garden: RestGarden
        let isEmpty: Bool

        init(records: [RestRecord], dayCount: Int, now: Date, calendar: Calendar) {
            let today = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today)!
            let end = calendar.date(byAdding: .day, value: 1, to: today)!
            let included = records.filter { $0.date >= start && $0.date <= now }
            let byDay = Dictionary(grouping: included) { calendar.startOfDay(for: $0.date) }
            days = (0..<dayCount).map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: start)!
                return DayTotal(date: date, records: (byDay[date] ?? []).sorted { $0.date > $1.date })
            }
            metrics = RestMetrics(records: included, start: start, end: end, calendar: calendar)
            garden = RestGarden(records: records, asOf: now, calendar: calendar)
            isEmpty = included.isEmpty
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            let history = HistorySnapshot(records: store.state.records, dayCount: period.dayCount,
                                          now: .now, calendar: .current)
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    growthSummary(history.garden)
                    Picker("History period", selection: $period) {
                        ForEach(HistoryPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if history.isEmpty {
                        emptyState
                    } else {
                        chartCard(history)
                        metricsGrid(history.metrics)
                        activityList(history.days)
                    }
                }
                .padding(24)
                .padding(.bottom, 24)
            }
        }
        .background(AppTheme.background)
        .foregroundStyle(AppTheme.cream)
        .navigationTitle("Progress")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionEyebrow(text: "Progress")
            Text("See your habit\ntake root.").font(AppTheme.title(36))
            Text("Small pauses add up to a little more space for your eyes.")
                .font(.subheadline).foregroundStyle(AppTheme.secondary)
        }
    }

    private func growthSummary(_ garden: RestGarden) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 24) {
                growthMetric(value: garden.totalTreeCount, label: "Total trees grown", symbol: "tree.fill")
                Divider().overlay(AppTheme.cream.opacity(0.1))
                growthMetric(value: garden.currentStreak, label: "Day streak", symbol: "sun.max")
            }
            .fixedSize(horizontal: false, vertical: true)
            Text("Every completed rest grows a tree. Today’s forest starts fresh each day; your rest history stays here.")
                .font(.caption).foregroundStyle(AppTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 26))
    }

    private func growthMetric(value: Int, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(AppTheme.sage).accessibilityHidden(true)
            Text("\(value)").font(AppTheme.title(38)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func chartCard(_ history: HistorySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(history.metrics.guidedCount)").font(AppTheme.title(54)).monospacedDigit()
                        .accessibilityIdentifier("progress.completedCount")
                    Text("completed breaks").font(.subheadline).foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                Text("PAST \(period.dayCount) DAYS")
                    .font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(AppTheme.sage)
            }
            Chart(history.days) { day in
                BarMark(x: .value("Date", day.date, unit: .day), y: .value("Rests", day.guidedCount))
                    .foregroundStyle(AppTheme.sage)
                    .cornerRadius(3)
                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue("\(day.guidedCount) completed rests")
            }
            .chartYScale(domain: 0...max(3, history.days.map(\.guidedCount).max() ?? 0))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 7)) { _ in
                    AxisValueLabel(format: period == .week ? .dateTime.weekday(.narrow) : .dateTime.day())
                        .foregroundStyle(AppTheme.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(AppTheme.cream.opacity(0.08))
                    if let count = value.as(Int.self) {
                        AxisValueLabel { Text("\(count)").foregroundStyle(AppTheme.secondary) }
                    }
                }
            }
            .frame(height: 184)
        }
        .padding(22)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 26))
    }

    private func metricsGrid(_ metrics: RestMetrics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 14) {
            metric(value: duration(metrics.guidedSeconds), label: "Time resting", symbol: "timer")
            metric(value: "\(metrics.guidedCount)", label: "Trees in this period", symbol: "tree")
        }
    }

    private func metric(value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(AppTheme.sage).accessibilityHidden(true)
            Text(value).font(AppTheme.title(30)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption).foregroundStyle(AppTheme.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(18)
        .background(AppTheme.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    private func activityList(_ days: [DayTotal]) -> some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            Text("Your history").font(AppTheme.title(26))
            ForEach(days.reversed().filter { !$0.records.isEmpty }) { day in
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(day.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if day.guidedCount > 0 {
                            Label("\(day.guidedCount) \(day.guidedCount == 1 ? "tree" : "trees") grown", systemImage: "tree.fill")
                                .font(.caption).foregroundStyle(AppTheme.sage)
                        }
                    }
                    ForEach(day.records) { record in
                        HStack(spacing: 14) {
                            Image(systemName: record.kind == .guided ? "leaf" : record.kind == .confirmed ? "checkmark.circle" : "arrow.turn.up.right")
                                .foregroundStyle(AppTheme.sage).frame(width: 24).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.kind == .guided ? "Rest completed" : record.kind == .confirmed ? "Break confirmed" : "Reminder skipped")
                                    .font(.subheadline)
                                Text(record.date.formatted(.dateTime.hour().minute()))
                                    .font(.caption).foregroundStyle(AppTheme.secondary)
                            }
                            Spacer()
                            if record.kind == .guided {
                                Text(duration(record.durationSeconds)).font(.caption.monospacedDigit()).foregroundStyle(AppTheme.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(20)
                .background(AppTheme.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 22))
            }
            Text("Confirmed breaks and skipped reminders stay in your history. Trees grow from completed guided rests.")
                .font(.caption).foregroundStyle(AppTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "chart.bar").font(.system(size: 40, weight: .ultraLight)).foregroundStyle(AppTheme.sage)
            Text("A little pause.\nA growing habit.").font(AppTheme.title(30))
            Text("No rests recorded in the past \(period.dayCount) days. Each completed rest will appear here and add a tree to that day’s forest.")
                .foregroundStyle(AppTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 26))
    }

    private func duration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes == 0 { return "\(remainder)s" }
        if remainder == 0 { return "\(minutes)m" }
        return "\(minutes)m \(remainder)s"
    }
}
