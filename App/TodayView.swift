import SwiftUI

struct TodayView: View {
    @Bindable var store: AppStore
    let openSettings: () -> Void
    let openProgress: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            let garden = RestGarden(records: store.state.records, asOf: .now)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text(Brand.name).font(AppTheme.title(29))
                            Spacer()
                            Button(action: openSettings) {
                                Image(systemName: "slider.horizontal.3").font(.title3)
                                    .frame(width: 46, height: 46)
                                    .background(AppTheme.cream.opacity(0.07), in: Circle())
                            }.accessibilityLabel("Settings")
                        }.id("todayHeader")

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Today's forest")
                                .font(AppTheme.title(34)).accessibilityAddTraits(.isHeader)
                            Text("A tree for every rest. A fresh forest each day.")
                                .font(.subheadline).foregroundStyle(AppTheme.secondary)
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            DailyForest(trees: garden.trees)
                            Text(garden.treeCount == 0
                                 ? "Your first tree starts with a \(store.monitoring.restSeconds)-second rest."
                                 : "\(garden.treeCount) \(garden.treeCount == 1 ? "tree" : "trees") planted today. Every rest adds another.")
                                .font(.caption).foregroundStyle(AppTheme.secondary)
                                .accessibilityIdentifier("todayTreeStatus")
                        }

                        TodayScreenTimeView(monitoring: store.monitoring)

                        HStack(spacing: 12) {
                            dailyMetric(value: "\(garden.treeCount)", label: "Breaks today", symbol: "eye")
                            dailyMetric(value: restTime(garden.trees.reduce(0) { $0 + $1.durationSeconds }), label: "Time resting", symbol: "leaf")
                        }

                        Button(garden.treeCount == 0 ? "Take a quiet break" : "Take another break") {
                            store.startBreak()
                        }
                        .font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.sage)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("quickRest")

                        Button(action: openProgress) {
                            HStack(spacing: 10) {
                                Image(systemName: "chart.bar.xaxis").foregroundStyle(AppTheme.sage)
                                Text("\(garden.currentStreak)-day streak").font(.subheadline)
                                Spacer()
                                Text("View progress").font(.caption)
                                Image(systemName: "arrow.right").font(.caption)
                            }.padding(.vertical, 14).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("viewProgress")

                        Button(action: openSettings) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: store.monitoring.isEnabled ? "checkmark.shield" : "clock")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(store.monitoring.isEnabled ? "Break reminders are on" : "Break reminders need attention")
                                        .font(.subheadline.weight(.medium))
                                    Text(store.monitoring.isEnabled
                                         ? "A gentle pause after \(store.monitoring.usageMinutes) minutes of screen use, any time of day or night."
                                         : "Open Settings to check what needs attention.")
                                        .font(.caption).foregroundStyle(AppTheme.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption)
                            }.padding(18).background(AppTheme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
                        }.buttonStyle(.plain).accessibilityIdentifier("monitoringSettings")
                    }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 30)
                }.scrollIndicators(.hidden)
                    .onChange(of: garden.trees.last?.id) { _, treeID in
                        if treeID != nil {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                                proxy.scrollTo("todayHeader", anchor: .top)
                            }
                        }
                    }
            }
        }.background(AppTheme.background).foregroundStyle(AppTheme.cream)
    }

    private func dailyMetric(value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: symbol)
                .font(.caption).foregroundStyle(AppTheme.secondary)
            Text(value).font(AppTheme.title(31)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(AppTheme.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .combine)
    }

    private func restTime(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }
}

private struct DailyForest: View {
    let trees: [RestRecord]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24).fill(AppTheme.surface.opacity(0.45))

                Ellipse()
                    .fill(AppTheme.sage.opacity(0.045))
                    .frame(width: geometry.size.width * 1.4, height: 115)
                    .position(x: geometry.size.width * 0.6, y: 155)
                    .accessibilityHidden(true)
                Ellipse()
                    .fill(AppTheme.sage.opacity(0.07))
                    .frame(width: geometry.size.width * 1.3, height: 75)
                    .position(x: geometry.size.width * 0.4, y: 168)
                    .accessibilityHidden(true)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .bottom, spacing: 0) {
                            ForEach(Array(trees.enumerated()), id: \.element.id) { index, tree in
                                treeView(tree, index: index).id(tree.id)
                            }
                        }
                        .frame(minWidth: geometry.size.width - 28, minHeight: 174, alignment: .bottom)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 24)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: trees.count)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: trees.last?.id) { _, treeID in
                        if let treeID {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                                proxy.scrollTo(treeID, anchor: .trailing)
                            }
                        }
                    }
                }

                HStack {
                    Text("\(trees.count) \(trees.count == 1 ? "tree" : "trees") today")
                        .font(.caption.weight(.medium)).monospacedDigit()
                        .foregroundStyle(AppTheme.sage)
                        .accessibilityIdentifier("treeCount")
                    Spacer()
                    if CGFloat(trees.count) * 62 > geometry.size.width - 28 {
                        Label("Explore", systemImage: "arrow.left.and.right")
                            .font(.caption2).foregroundStyle(AppTheme.secondary)
                            .accessibilityLabel("Swipe horizontally to explore every tree")
                    }
                }.padding(17)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .frame(height: 205)
    }

    private func treeView(_ tree: RestRecord, index: Int) -> some View {
        VStack(spacing: -3) {
            Image(systemName: "tree.fill")
                .font(.system(size: CGFloat(52 + (index % 3) * 8), weight: .regular))
                .foregroundStyle(AppTheme.sage.opacity(index.isMultiple(of: 3) ? 1 : 0.8))
                .zIndex(1)
            Ellipse().fill(AppTheme.background.opacity(0.3)).frame(width: 43, height: 9)
        }
        .frame(width: 62)
        .padding(.bottom, index.isMultiple(of: 2) ? 5 : 18)
        .transition(.scale(scale: 0.75, anchor: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tree \(index + 1), planted after your \(tree.date.formatted(date: .omitted, time: .shortened)) rest")
    }
}
