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
        let guided: Int
        let confirmed: Int
        var id: Date { date }
    }

    private var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -(period.dayCount - 1), to: Calendar.current.startOfDay(for: Date()))!
    }
    private var records: [RestRecord] {
        store.state.records.filter { $0.date >= startDate && $0.date <= Date() }
    }
    private var guided: [RestRecord] { records.filter { $0.kind == .guided } }
    private var confirmedCount: Int { records.filter { $0.kind == .confirmed }.count }
    private var skippedCount: Int { records.filter { $0.kind == .skipped }.count }
    private var activeDays: Int {
        Set(records.filter { $0.kind != .skipped }.map { Calendar.current.startOfDay(for: $0.date) }).count
    }
    private var totalSeconds: Int { guided.reduce(0) { $0 + $1.durationSeconds } }
    private var days: [DayTotal] {
        (0..<period.dayCount).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: offset, to: startDate)!
            let onDay = records.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            return DayTotal(date: date, guided: onDay.filter { $0.kind == .guided }.count,
                            confirmed: onDay.filter { $0.kind == .confirmed }.count)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                Picker("History period", selection: $period) {
                    ForEach(HistoryPeriod.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if records.isEmpty { emptyState } else {
                    chartCard
                    metricsGrid
                    activityList
                }
                Text("Your history records timers and breaks you confirm. It doesn’t measure your eyesight or verify where you looked.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background)
        .foregroundStyle(AppTheme.cream)
        .navigationTitle("Your rhythm")
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR RHYTHM").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(AppTheme.sage)
            Text("Small rests.\nRoom to breathe.").font(AppTheme.title(36))
            Text("A little space for your eyes, over time.")
                .font(.subheadline).foregroundStyle(AppTheme.secondary)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(guided.count + confirmedCount)").font(AppTheme.title(54)).monospacedDigit()
                    Text("recorded rests").font(.subheadline).foregroundStyle(AppTheme.secondary)
                }
                Spacer()
                Text(period == .week ? "PAST 7 DAYS" : "PAST 30 DAYS")
                    .font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(AppTheme.sage)
            }
            Chart(days) { day in
                BarMark(x: .value("Date", day.date, unit: .day), y: .value("Rests", day.guided))
                    .foregroundStyle(by: .value("Type", "Timed"))
                    .cornerRadius(3)
                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue("\(day.guided) timed rests")
                BarMark(x: .value("Date", day.date, unit: .day), y: .value("Rests", day.confirmed))
                    .foregroundStyle(by: .value("Type", "Confirmed"))
                    .cornerRadius(3)
                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue("\(day.confirmed) confirmed breaks")
            }
            .chartForegroundStyleScale(["Timed": AppTheme.sage, "Confirmed": AppTheme.cream.opacity(0.55)])
            .chartLegend(position: .bottom, alignment: .leading, spacing: 14)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 7)) { _ in
                    AxisValueLabel(format: period == .week ? .dateTime.weekday(.narrow) : .dateTime.day())
                        .foregroundStyle(AppTheme.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(AppTheme.cream.opacity(0.08))
                    AxisValueLabel().foregroundStyle(AppTheme.secondary)
                }
            }
            .frame(height: 184)
        }
        .padding(22)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 26))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 14) {
            metric(value: "\(guided.count)", label: "Timed rests", symbol: "timer")
            metric(value: String(format: "%.1f", Double(totalSeconds) / 60), label: "Minutes of timed rest", symbol: "leaf")
            metric(value: "\(activeDays) / \(period.dayCount)", label: "Days with a rest", symbol: "calendar")
            metric(value: "\(confirmedCount)", label: "Breaks you confirmed", symbol: "checkmark.circle")
        }
    }

    private func metric(value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.body).foregroundStyle(AppTheme.sage).accessibilityHidden(true)
            Text(value).font(AppTheme.title(32)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(AppTheme.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(18)
        .background(AppTheme.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    private var activityList: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Space for real life").font(AppTheme.title(23))
                Spacer()
                Text("\(skippedCount) skips").font(.subheadline).foregroundStyle(AppTheme.secondary)
            }
            Text("Some moments aren’t right for a pause. Skips are recorded separately, without resetting your progress.")
                .font(.subheadline).foregroundStyle(AppTheme.secondary)
            Divider().overlay(AppTheme.cream.opacity(0.1))
            Text("RECENT ACTIVITY").font(.caption2.weight(.semibold)).tracking(1.5).foregroundStyle(AppTheme.sage)
            ForEach(Array(records.sorted { $0.date > $1.date }.prefix(5))) { record in
                HStack(spacing: 14) {
                    Image(systemName: record.kind == .guided ? "leaf" : record.kind == .confirmed ? "checkmark.circle" : "arrow.turn.up.right")
                        .foregroundStyle(AppTheme.sage).frame(width: 24).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.kind == .guided ? "Timed rest" : record.kind == .confirmed ? "Break confirmed" : "Skipped pause")
                            .font(.subheadline)
                        Text(record.date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(.caption).foregroundStyle(AppTheme.secondary)
                    }
                    Spacer()
                    if record.kind == .guided {
                        Text("\(record.durationSeconds)s").font(.caption.monospacedDigit()).foregroundStyle(AppTheme.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "leaf").font(.system(size: 40, weight: .ultraLight)).foregroundStyle(AppTheme.sage)
            Text("Your next pause\nis a good beginning.").font(AppTheme.title(30))
            Text("Complete a timed rest or confirm a break to start your history. There’s no score to catch up to.")
                .foregroundStyle(AppTheme.secondary)
            PrimaryButton(title: "Take a rest", action: { store.startBreak() })
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 26))
    }
}
