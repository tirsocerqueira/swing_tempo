import Charts
import SwiftUI

struct StatisticsView: View {
    let sessions: [TrainingSession]

    private var totalSwings: Int {
        sessions.reduce(0) { $0 + $1.swingCount }
    }

    private var totalDurationSeconds: Double {
        sessions.reduce(0) { $0 + $1.durationSeconds }
    }

    private var tempoCounts: [TempoCount] {
        let grouped = Dictionary(grouping: sessions) {
            Int(($0.tempoRatio * 10).rounded())
        }
        return grouped.map { ratioTenths, sessions in
            TempoCount(
                ratio: Double(ratioTenths) / 10,
                sessionCount: sessions.count
            )
        }
        .sorted { $0.ratio < $1.ratio }
    }

    private var dailySwingCounts: [DailySwingCount] {
        let grouped = Dictionary(grouping: sessions) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return grouped.map { date, sessions in
            DailySwingCount(
                date: date,
                swingCount: sessions.reduce(0) { $0 + $1.swingCount }
            )
        }
        .sorted { $0.date < $1.date }
    }

    private var mostPracticedTempo: String {
        guard let tempo = tempoCounts.max(by: {
            $0.sessionCount < $1.sessionCount
        }) else {
            return "—"
        }
        return tempo.label
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Estadísticas")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                if sessions.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        metric(title: "SWINGS", value: "\(totalSwings)")
                        metric(title: "TIEMPO", value: durationLabel)
                        metric(title: "SESIONES", value: "\(sessions.count)")
                        metric(title: "TEMPO TOP", value: mostPracticedTempo)
                    }

                    chartCard(title: "Evolución de swings") {
                        Chart(dailySwingCounts) { item in
                            AreaMark(
                                x: .value("Fecha", item.date),
                                y: .value("Swings", item.swingCount)
                            )
                            .foregroundStyle(golfGreen.opacity(0.16).gradient)
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("Fecha", item.date),
                                y: .value("Swings", item.swingCount)
                            )
                            .foregroundStyle(golfGreen)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            .interpolationMethod(.catmullRom)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 190)
                    }

                    chartCard(title: "Sesiones por tempo") {
                        Chart(tempoCounts) { item in
                            SectorMark(
                                angle: .value("Sesiones", item.sessionCount),
                                innerRadius: .ratio(0.58),
                                angularInset: 2
                            )
                            .foregroundStyle(
                                by: .value("Tempo", item.label)
                            )
                        }
                        .chartLegend(position: .bottom, spacing: 12)
                        .frame(height: 230)
                    }
                }
            }
            .padding(22)
        }
        .background(Color(red: 0.035, green: 0.055, blue: 0.045))
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(golfGreen)
            Text("Aún no hay estadísticas")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Text("Completa una sesión para empezar a ver tu evolución.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private var durationLabel: String {
        let minutes = Int(totalDurationSeconds / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return hours > 0 ? "\(hours) h \(remainingMinutes) min" : "\(minutes) min"
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(golfGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private func chartCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            content()
        }
        .padding(18)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }

    private var golfGreen: Color {
        Color(red: 0.37, green: 0.91, blue: 0.48)
    }
}

private struct TempoCount: Identifiable {
    let ratio: Double
    let sessionCount: Int

    var id: Double { ratio }
    var label: String {
        ratio.rounded() == ratio
            ? "\(Int(ratio)):1"
            : String(format: "%.1f:1", ratio)
    }
}

private struct DailySwingCount: Identifiable {
    let date: Date
    let swingCount: Int

    var id: Date { date }
}
