import SwiftUI

// Варианты дизайна панели в трее — только для сравнения (превью), в приложение не подключены.

/// Тестовые данные: одинаковые для всех вариантов.
struct PanelSample: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let colors: [Color]
    let left: TimeInterval
    let total: TimeInterval
    let clock: String

    static let items: [PanelSample] = [
        .init(title: "Posture", symbol: "figure.stand", colors: ReminderAnimation.arrowUp.colors, left: 252, total: 1200, clock: "14:32"),
        .init(title: "Blink", symbol: "eye.fill", colors: ReminderAnimation.blink.colors, left: 580, total: 1200, clock: "14:38"),
        .init(title: "Desk combo", symbol: "square.stack.3d.up.fill",
              colors: [Color(red: 0.55, green: 0.35, blue: 0.95), Color(red: 0.30, green: 0.70, blue: 0.95)], left: 1085, total: 1800, clock: "14:46"),
        .init(title: "Break", symbol: "cup.and.saucer.fill",
              colors: [Color(red: 1.00, green: 0.55, blue: 0.22), Color(red: 1.00, green: 0.80, blue: 0.36)], left: 2490, total: 3600, clock: "15:10"),
    ]
}

private func mmss(_ t: TimeInterval) -> String { formatCountdown(t) }

private struct Ring: View {
    let progress: Double
    let color: Color
    var width: CGFloat = 3
    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.1), lineWidth: width)
            Circle().trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

private struct PanelHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            AppIcon(symbol: "arrow.up", colors: [Color(red: 1.00, green: 0.45, blue: 0.58), Color(red: 0.62, green: 0.40, blue: 0.95)], size: 26)
            Text("Pinok").font(.headline)
            Spacer()
            Image(systemName: "gearshape.fill")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 30, height: 30)
                .glassEffect(.regular, in: Circle())
        }
    }
}

private struct ActionButton: View {
    let title: String
    let symbol: String
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold))
            Text(title).font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
    }
}

private struct Footer: View {
    var body: some View {
        HStack {
            Text("Today: 6 reminders · 1 break").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("Quit").font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - A. Текущий

struct PanelVariantA: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader()
            VStack(spacing: 6) {
                ForEach(PanelSample.items) { i in
                    HStack(spacing: 10) {
                        ZStack {
                            Ring(progress: i.left / i.total, color: i.colors[0])
                            Image(systemName: i.symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(i.colors[0])
                        }
                        .frame(width: 30, height: 30)
                        Text(i.title)
                        Spacer()
                        Text(mmss(i.left)).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
                }
            }
            HStack(spacing: 8) {
                Label("Break", systemImage: "cup.and.saucer.fill")
                Label("Pause", systemImage: "pause.fill")
            }
            .font(.callout)
            .labelStyle(.titleAndIcon)
            .padding(.vertical, 2)
            Text("Skip next break").font(.callout).foregroundStyle(Color.accentColor)
            Divider()
            Footer()
        }
        .padding(16).frame(width: 320)
    }
}

// MARK: - B. «Следующее» крупно

struct PanelVariantB: View {
    var body: some View {
        let next = PanelSample.items[0]
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader()
            // Главное: что будет следующим и когда
            HStack(spacing: 14) {
                ZStack {
                    Ring(progress: next.left / next.total, color: .white, width: 5)
                    Image(systemName: next.symbol).font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT").font(.caption2.weight(.bold)).tracking(1).opacity(0.8)
                    Text(next.title).font(.title3.weight(.semibold))
                    Text("in \(mmss(next.left))").font(.system(size: 26, weight: .bold, design: .rounded)).monospacedDigit()
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: next.colors, startPoint: .topLeading, endPoint: .bottomTrailing)))

            // Остальное — мелко
            VStack(spacing: 8) {
                ForEach(PanelSample.items.dropFirst()) { i in
                    HStack(spacing: 8) {
                        Image(systemName: i.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(i.colors[0]).frame(width: 18)
                        Text(i.title).font(.callout)
                        Spacer()
                        Text(mmss(i.left)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                ActionButton(title: "Break", symbol: "cup.and.saucer.fill")
                ActionButton(title: "Pause", symbol: "pause.fill")
            }
            Divider()
            Footer()
        }
        .padding(16).frame(width: 320)
    }
}

// MARK: - C. Лента времени

struct PanelVariantC: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader()
            Text("Today").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(PanelSample.items.enumerated()), id: \.element.id) { index, i in
                    HStack(alignment: .top, spacing: 12) {
                        Text(i.clock).font(.callout.weight(.semibold)).monospacedDigit()
                            .frame(width: 46, alignment: .leading)
                        VStack(spacing: 0) {
                            Circle().fill(i.colors[0]).frame(width: 12, height: 12)
                                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2))
                            if index < PanelSample.items.count - 1 {
                                Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 2, height: 34)
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Label(i.title, systemImage: i.symbol).font(.callout.weight(index == 0 ? .semibold : .regular))
                            Text("in \(Int((i.left / 60).rounded(.up))) min").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            HStack(spacing: 8) {
                ActionButton(title: "Break", symbol: "cup.and.saucer.fill")
                ActionButton(title: "Pause", symbol: "pause.fill")
            }
            Divider()
            Footer()
        }
        .padding(16).frame(width: 320)
    }
}

// MARK: - D. Одно кольцо (минимум)

struct PanelVariantD: View {
    var body: some View {
        let next = PanelSample.items[0]
        VStack(spacing: 14) {
            PanelHeader()
            ZStack {
                Ring(progress: next.left / next.total, color: next.colors[0], width: 8)
                VStack(spacing: 2) {
                    Image(systemName: next.symbol).font(.system(size: 22, weight: .semibold)).foregroundStyle(next.colors[0])
                    Text(mmss(next.left)).font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(next.title).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)

            // Остальное — маленькие «таблетки»
            HStack(spacing: 6) {
                ForEach(PanelSample.items.dropFirst()) { i in
                    HStack(spacing: 4) {
                        Image(systemName: i.symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(i.colors[0])
                        Text("\(Int((i.left / 60).rounded(.up)))m").font(.caption).monospacedDigit()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
            }

            HStack(spacing: 18) {
                ForEach([("cup.and.saucer.fill", "Break"), ("pause.fill", "Pause")], id: \.0) { s, title in
                    VStack(spacing: 4) {
                        Image(systemName: s).font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular, in: Circle())
                        Text(title).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
            Footer()
        }
        .padding(16).frame(width: 320)
    }
}

// MARK: - E. Плитки

struct PanelVariantE: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(PanelSample.items.enumerated()), id: \.element.id) { index, i in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ZStack {
                                Ring(progress: i.left / i.total, color: i.colors[0], width: 3)
                                Image(systemName: i.symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(i.colors[0])
                            }
                            .frame(width: 32, height: 32)
                            Spacer()
                            if index == 0 {
                                Text("NEXT").font(.system(size: 9, weight: .bold)).tracking(0.8)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(i.colors[0].opacity(0.18)))
                                    .foregroundStyle(i.colors[0])
                            }
                        }
                        Text(i.title).font(.callout.weight(.semibold)).lineLimit(1)
                        Text(mmss(i.left)).font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(index == 0 ? i.colors[0] : .clear, lineWidth: 2))
                }
            }
            HStack(spacing: 8) {
                ActionButton(title: "Break", symbol: "cup.and.saucer.fill")
                ActionButton(title: "Pause", symbol: "pause.fill")
            }
            Divider()
            Footer()
        }
        .padding(16).frame(width: 320)
    }
}

// MARK: - Превью

private struct PanelFrame<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(20)
    }
}

#Preview("Panel A · current", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantA() } }
#Preview("Panel B · next up", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantB() } }
#Preview("Panel C · timeline", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantC() } }
#Preview("Panel D · one ring", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantD() } }
#Preview("Panel E · tiles", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantE() } }

// MARK: - Без обратного отсчёта (F–I)

/// Тестовые данные без таймеров: что включено и как часто.
struct CalmSample: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let colors: [Color]
    let every: String
    let clock: String
    let on: Bool

    static let items: [CalmSample] = [
        .init(title: "Posture", symbol: "figure.stand", colors: ReminderAnimation.arrowUp.colors, every: "every 20 min", clock: "14:32", on: true),
        .init(title: "Blink", symbol: "eye.fill", colors: ReminderAnimation.blink.colors, every: "every 20 min", clock: "14:38", on: true),
        .init(title: "Water", symbol: "drop.fill", colors: ReminderAnimation.water.colors, every: "every 1 h", clock: "15:02", on: true),
        .init(title: "Desk combo", symbol: "square.stack.3d.up.fill",
              colors: [Color(red: 0.55, green: 0.35, blue: 0.95), Color(red: 0.30, green: 0.70, blue: 0.95)], every: "every 30 min", clock: "14:46", on: true),
        .init(title: "Tongue", symbol: "mouth.fill", colors: ReminderAnimation.tongueUp.colors, every: "every 30 min", clock: "—", on: false),
    ]
    static let breakColors = [Color(red: 1.00, green: 0.55, blue: 0.22), Color(red: 1.00, green: 0.80, blue: 0.36)]
}

private struct StatusPill: View {
    var paused = false
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(paused ? Color.orange : Color.green).frame(width: 8, height: 8)
            Text(paused ? "Paused until 16:00" : "Pinok is on").font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill((paused ? Color.orange : Color.green).opacity(0.14)))
    }
}

private struct CalmRow: View {
    let item: CalmSample
    var trailing: String?
    var body: some View {
        HStack(spacing: 10) {
            AppIcon(symbol: item.symbol, colors: item.colors, size: 24)
                .saturation(item.on ? 1 : 0).opacity(item.on ? 1 : 0.5)
            Text(item.title).opacity(item.on ? 1 : 0.5)
            Spacer()
            Text(trailing ?? (item.on ? item.every : "Off"))
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}

/// Три крупные плитки внизу — понравились пользователю в B/C/E.
private struct BigActions: View {
    var paused = false
    var body: some View {
        HStack(spacing: 8) {
            tile("Break", "cup.and.saucer.fill")
            tile(paused ? "Resume" : "Pause", paused ? "play.fill" : "pause.fill")
        }
    }
    private func tile(_ title: String, _ symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).frame(height: 22)
            Text(title).font(.callout.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.07)))
    }
}

// F. Статус и список
struct PanelVariantF: View {
    var paused = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader()
            HStack {
                StatusPill(paused: paused)
                Spacer()
            }
            VStack(spacing: 10) {
                ForEach(CalmSample.items) { CalmRow(item: $0) }
            }
            .opacity(paused ? 0.5 : 1)
            Divider()
            HStack(spacing: 10) {
                AppIcon(symbol: "cup.and.saucer.fill", colors: CalmSample.breakColors, size: 24)
                Text("Breaks")
                Spacer()
                Text("every 1 h · 5 min").font(.callout).foregroundStyle(.secondary)
            }
            .opacity(paused ? 0.5 : 1)
            BigActions(paused: paused)
            Divider()
            Footer()
        }
        .padding(16).frame(width: 320)
    }
}

// G. Карточка статуса
struct PanelVariantG: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").font(.title2)
                    Text("Pinok is on").font(.title3.weight(.semibold))
                }
                Text("4 reminders · breaks every 1 h").font(.callout).opacity(0.9)
            }
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.72, blue: 0.52), Color(red: 0.20, green: 0.58, blue: 0.85)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)))

            Text("Reminders").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(CalmSample.items) { i in
                    VStack(spacing: 4) {
                        AppIcon(symbol: i.symbol, colors: i.colors, size: 36)
                            .saturation(i.on ? 1 : 0).opacity(i.on ? 1 : 0.45)
                            .overlay(alignment: .bottomTrailing) {
                                Circle().fill(i.on ? Color.green : Color(white: 0.6))
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                                    .offset(x: 3, y: 3)
                            }
                        Text(i.title).font(.system(size: 10)).lineLimit(1).foregroundStyle(.secondary)
                    }
                }
            }
            BigActions()
            Divider()
            Footer()
        }
        .padding(16).frame(width: 320)
    }
}

// H. Расписание (только время на часах)
struct PanelVariantH: View {
    var body: some View {
        let schedule = CalmSample.items.filter(\.on).sorted { $0.clock < $1.clock }
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader()
            StatusPill()
            Text("Next").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(schedule.enumerated()), id: \.element.id) { index, i in
                    HStack(alignment: .center, spacing: 12) {
                        Text(i.clock).font(.callout.weight(.semibold)).monospacedDigit().frame(width: 46, alignment: .leading)
                        Circle().fill(i.colors[0]).frame(width: 10, height: 10)
                        Label(i.title, systemImage: i.symbol).font(.callout)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                HStack(alignment: .center, spacing: 12) {
                    Text("15:10").font(.callout.weight(.bold)).monospacedDigit().frame(width: 46, alignment: .leading)
                    Circle().fill(CalmSample.breakColors[0]).frame(width: 10, height: 10)
                    Label("Break · 5 min", systemImage: "cup.and.saucer.fill").font(.callout.weight(.semibold))
                    Spacer()
                }
                .padding(.vertical, 8).padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 10).fill(CalmSample.breakColors[0].opacity(0.14)))
            }
            BigActions()
            Divider()
            Footer()
        }
        .padding(16).frame(width: 320)
    }
}

// I. Переключатели прямо в трее
struct PanelVariantI: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeader()
            StatusPill()
            VStack(spacing: 8) {
                ForEach(CalmSample.items) { i in
                    HStack(spacing: 10) {
                        AppIcon(symbol: i.symbol, colors: i.colors, size: 22)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(i.title).font(.callout)
                            Text(i.every).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: .constant(i.on)).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                    }
                }
                Divider()
                HStack(spacing: 10) {
                    AppIcon(symbol: "cup.and.saucer.fill", colors: CalmSample.breakColors, size: 22)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Breaks").font(.callout)
                        Text("every 1 h · 5 min").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: .constant(true)).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }
            }
            BigActions()
            Divider()
            Footer()
        }
        .padding(16).frame(width: 320)
    }
}

#Preview("Panel F · status list", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantF() } }
#Preview("Panel F · paused", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantF(paused: true) } }
#Preview("Panel G · status card", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantG() } }
#Preview("Panel H · schedule", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantH() } }
#Preview("Panel I · switches", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantI() } }

// MARK: - G, доработка: «Pinok» только один раз

/// G1 — без верхней строки: иконка и шестерёнка внутри карточки.
/// G2 — строка «Pinok» со статусом справа, карточка показывает только итог.
struct PanelVariantGx: View {
    enum Style { case noHeader, headerPill }
    var style: Style
    var paused = false

    private var gradient: [Color] {
        paused ? [Color(red: 1.00, green: 0.60, blue: 0.25), Color(red: 0.95, green: 0.42, blue: 0.40)]
               : [Color(red: 0.16, green: 0.72, blue: 0.52), Color(red: 0.20, green: 0.58, blue: 0.85)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if style == .headerPill {
                HStack(spacing: 10) {
                    AppIcon(symbol: "arrow.up", colors: [Color(red: 1.00, green: 0.45, blue: 0.58), Color(red: 0.62, green: 0.40, blue: 0.95)], size: 26)
                    Text("Pinok").font(.headline)
                    HStack(spacing: 5) {
                        Circle().fill(paused ? Color.orange : Color.green).frame(width: 7, height: 7)
                        Text(paused ? "Paused" : "On").font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill((paused ? Color.orange : Color.green).opacity(0.15)))
                    Spacer()
                    gear(onCard: false)
                }
            }
            card
            Text("Reminders").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            icons.opacity(paused ? 0.5 : 1)
            BigActions(paused: paused)
            Divider()
            Footer()
        }
        .padding(16).frame(width: 320)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if style == .noHeader {
                    AppIcon(symbol: "arrow.up", colors: [Color(red: 1.00, green: 0.45, blue: 0.58), Color(red: 0.62, green: 0.40, blue: 0.95)], size: 30)
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    Text(paused ? "Pinok is paused" : "Pinok is on").font(.title3.weight(.semibold))
                } else {
                    Text(paused ? "Paused until 16:00" : "4 reminders are on").font(.title3.weight(.semibold))
                }
                Spacer()
                if style == .noHeader { gear(onCard: true) }
            }
            Text(style == .noHeader
                 ? (paused ? "Until 16:00" : "4 reminders · breaks every 1 h")
                 : (paused ? "Reminders and breaks wait" : "Breaks every 1 h · 5 min"))
                .font(.callout).opacity(0.9)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)))
    }

    private func gear(onCard: Bool) -> some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(onCard ? Color.white : Color.primary)
            .frame(width: 30, height: 30)
            .background(Circle().fill(onCard ? Color.white.opacity(0.22) : Color.primary.opacity(0.07)))
    }

    private var icons: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
            ForEach(CalmSample.items) { i in
                VStack(spacing: 4) {
                    AppIcon(symbol: i.symbol, colors: i.colors, size: 36)
                        .saturation(i.on ? 1 : 0).opacity(i.on ? 1 : 0.45)
                        .overlay(alignment: .bottomTrailing) {
                            Circle().fill(i.on ? Color.green : Color(white: 0.6))
                                .frame(width: 10, height: 10)
                                .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                                .offset(x: 3, y: 3)
                        }
                    Text(i.title).font(.system(size: 10)).lineLimit(1).foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview("Panel G1 · no header", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantGx(style: .noHeader) } }
#Preview("Panel G2 · header pill", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantGx(style: .headerPill) } }

// MARK: - J. Отсчёт только до перерыва (по референсу пользователя)

struct PanelVariantJ: View {
    var tab = 0          // 0 — Now, 1 — Stats
    var paused = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                HStack(spacing: 2) {
                    segment("Now", selected: tab == 0)
                    segment("Stats", selected: tab == 1)
                }
                .padding(3)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
                HStack {
                    AppIcon(symbol: "arrow.up", colors: [Color(red: 1.00, green: 0.45, blue: 0.58), Color(red: 0.62, green: 0.40, blue: 0.95)], size: 24)
                    Spacer()
                    Image(systemName: "gearshape.fill").font(.system(size: 16, weight: .medium))
                }
            }
            if tab == 0 { now } else { stats }
            Divider()
            HStack {
                Text(paused ? "Paused until 16:00" : "Pinok is on").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Quit").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16).frame(width: 340)
    }

    private func segment(_ title: String, selected: Bool) -> some View {
        Text(title).font(.callout.weight(.semibold))
            .padding(.horizontal, 18).padding(.vertical, 5)
            .background(Capsule().fill(selected ? Color.primary.opacity(0.12) : .clear))
    }

    private var now: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Image(systemName: paused ? "pause.circle.fill" : "cup.and.saucer.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(paused ? Color.orange : CalmSample.breakColors[0])
                Text(paused ? "Pinok is paused" : "Break in").font(.callout).foregroundStyle(.secondary)
                Text(paused ? "until 16:00" : "29:54")
                    .font(.system(size: paused ? 28 : 46, weight: .bold, design: .rounded)).monospacedDigit()
            }
            .padding(.top, 4)
            HStack(spacing: 6) {
                pill(paused ? "Resume" : "Start now", filled: true)
                if !paused {
                    pill("+1 min"); pill("+5 min"); pill("+10 min")
                }
            }
            VStack(spacing: 8) {
                row(symbol: "bolt.fill", colors: [Color(red: 0.95, green: 0.72, blue: 0.20), Color(red: 0.85, green: 0.55, blue: 0.10)],
                    title: "Work time", value: "30 min")
                row(symbol: "cup.and.saucer.fill", colors: CalmSample.breakColors,
                    title: "Next break", value: "5 min · Stretch")
                HStack(spacing: 10) {
                    Text("Reminders").font(.callout)
                    Spacer()
                    HStack(spacing: -4) {
                        ForEach(CalmSample.items.filter(\.on)) { i in
                            AppIcon(symbol: i.symbol, colors: i.colors, size: 22)
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5))
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
                if !paused {
                    row(symbol: "pause.fill", colors: [Color(white: 0.55), Color(white: 0.40)],
                        title: "Pause", value: "30 min · 1 h · Tomorrow")
                }
            }
            .opacity(paused ? 0.6 : 1)
        }
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                statTile("6", "reminders")
                statTile("1", "break")
                statTile("2 h 10", "work time")
            }
            Text("Today").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(Array(CalmSample.items.filter(\.on).enumerated()), id: \.element.id) { n, i in
                HStack(spacing: 10) {
                    AppIcon(symbol: i.symbol, colors: i.colors, size: 22)
                    Text(i.title).font(.callout)
                    Spacer()
                    Capsule().fill(i.colors[0]).frame(width: CGFloat([60, 48, 24, 36][n % 4]), height: 6)
                    Text("\([5, 4, 2, 3][n % 4])").font(.callout).monospacedDigit().frame(width: 16, alignment: .trailing)
                }
            }
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
    }

    private func pill(_ title: String, filled: Bool = false) -> some View {
        Text(title).font(.callout.weight(.semibold))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(Color.primary.opacity(filled ? 0.12 : 0)))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(filled ? 0 : 0.2)))
    }

    private func row(symbol: String, colors: [Color], title: String, value: String) -> some View {
        HStack(spacing: 10) {
            AppIcon(symbol: symbol, colors: colors, size: 26)
            Text(title).font(.callout)
            Spacer()
            Text(value).font(.callout.weight(.medium)).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}

#Preview("Panel J · break countdown", traits: .sizeThatFitsLayout) { PanelFrame { PanelVariantJ() } }

// MARK: - Статистика: варианты S1–S4 (с приложениями)

struct AppUsageSample: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let minutes: Int
    let color: Color

    static let items: [AppUsageSample] = [
        .init(name: "Xcode", path: "/Applications/Xcode.app", minutes: 142, color: Color(red: 0.20, green: 0.55, blue: 0.95)),
        .init(name: "Safari", path: "/Applications/Safari.app", minutes: 78, color: Color(red: 0.25, green: 0.75, blue: 0.85)),
        .init(name: "Terminal", path: "/System/Applications/Utilities/Terminal.app", minutes: 51, color: Color(white: 0.35)),
        .init(name: "Telegram", path: "/Applications/Telegram.app", minutes: 34, color: Color(red: 0.30, green: 0.65, blue: 0.95)),
        .init(name: "Mail", path: "/System/Applications/Mail.app", minutes: 17, color: Color(red: 0.95, green: 0.60, blue: 0.20)),
    ]
    static var total: Int { items.map(\.minutes).reduce(0, +) + 9 }   // 9 мин — «Другие»
    var icon: NSImage { NSWorkspace.shared.icon(forFile: path) }
}

private func hm(_ minutes: Int) -> String {
    minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
}

private struct StatsHeader: View {
    var body: some View {
        ZStack {
            HStack(spacing: 2) {
                Text("Now").font(.callout.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 5)
                Text("Stats").font(.callout.weight(.semibold)).padding(.horizontal, 16).padding(.vertical, 5)
                    .background(Capsule().fill(Color.primary.opacity(0.12)))
            }
            .padding(3).background(Capsule().fill(Color.primary.opacity(0.06)))
            HStack {
                AppIcon(symbol: "arrow.up", colors: [Color(red: 1.00, green: 0.45, blue: 0.58), Color(red: 0.62, green: 0.40, blue: 0.95)], size: 24)
                Spacer()
                Image(systemName: "gearshape.fill").font(.system(size: 16, weight: .medium))
            }
        }
    }
}

private struct SmallTile: View {
    let value: String; let label: String; var tint: Color = .primary
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(tint)
            Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}

private struct AppRow: View {
    let app: AppUsageSample; let top: Int
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
            Text(app.name).font(.callout)
            Spacer()
            Capsule().fill(app.color).frame(width: 80 * CGFloat(app.minutes) / CGFloat(top), height: 6)
            Text(hm(app.minutes)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
                .frame(width: 78, alignment: .trailing)
        }
    }
}

private struct StatsFooter: View {
    var body: some View {
        VStack(spacing: 10) {
            Divider()
            HStack { Spacer(); Text("Quit").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

// S1. Текущая статистика + список приложений
struct StatsVariant1: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsHeader()
            Text("Today").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                SmallTile(value: "4", label: "Breaks done")
                SmallTile(value: "1", label: "Skipped")
                SmallTile(value: "2", label: "Postponed")
            }
            HStack {
                Text("At the computer").font(.callout)
                Spacer()
                Text(hm(AppUsageSample.total)).font(.callout.weight(.semibold))
            }
            .padding(10).background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
            Text("Apps").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(AppUsageSample.items) { AppRow(app: $0, top: AppUsageSample.items[0].minutes) }
            }
            StatsFooter()
        }
        .padding(16).frame(width: 340)
    }
}

// S2. Итог дня крупно + полоса по приложениям
struct StatsVariant2: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatsHeader()
            VStack(spacing: 2) {
                Text("At the computer today").font(.callout).foregroundStyle(.secondary)
                Text(hm(AppUsageSample.total)).font(.system(size: 38, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(AppUsageSample.items) { a in
                        Rectangle().fill(a.color)
                            .frame(width: (g.size.width - 10) * CGFloat(a.minutes) / CGFloat(AppUsageSample.total))
                    }
                    Rectangle().fill(Color.primary.opacity(0.15))
                }
            }
            .frame(height: 12).clipShape(Capsule())
            VStack(spacing: 7) {
                ForEach(AppUsageSample.items.prefix(4)) { a in
                    HStack(spacing: 8) {
                        Circle().fill(a.color).frame(width: 8, height: 8)
                        Image(nsImage: a.icon).resizable().frame(width: 18, height: 18)
                        Text(a.name).font(.callout)
                        Spacer()
                        Text(hm(a.minutes)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            HStack(spacing: 8) {
                SmallTile(value: "4", label: "Breaks", tint: Color(red: 0.16, green: 0.65, blue: 0.45))
                SmallTile(value: "1", label: "Skipped")
                SmallTile(value: "12", label: "Reminders")
            }
            StatsFooter()
        }
        .padding(16).frame(width: 340)
    }
}

// S3. Ритм дня: лента часов с работой и перерывами
struct StatsVariant3: View {
    // 9:00–18:00 по 15 минут: 0 — не за компьютером, 1 — работа, 2 — перерыв
    private let slots: [Int] = [1,1,1,1, 1,1,1,2, 1,1,1,1, 1,2,1,1, 0,0,0,0, 1,1,1,1, 1,1,1,1, 1,1,2,1, 1,1,1,1]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatsHeader()
            HStack(alignment: .firstTextBaseline) {
                Text(hm(AppUsageSample.total)).font(.system(size: 28, weight: .bold, design: .rounded))
                Text("at the computer").foregroundStyle(.secondary)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(Array(slots.enumerated()), id: \.offset) { _, v in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(v == 2 ? CalmSample.breakColors[0] : (v == 1 ? Color.accentColor.opacity(0.75) : Color.primary.opacity(0.08)))
                            .frame(height: v == 2 ? 26 : 20)
                    }
                }
                .frame(height: 26)
                HStack {
                    Text("9:00"); Spacer(); Text("12:00"); Spacer(); Text("15:00"); Spacer(); Text("now")
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                Label("Work", systemImage: "square.fill").foregroundStyle(Color.accentColor)
                Label("Break", systemImage: "square.fill").foregroundStyle(CalmSample.breakColors[0])
                Label("Away", systemImage: "square.fill").foregroundStyle(.secondary)
            }
            .font(.caption).labelStyle(.titleAndIcon)
            HStack(spacing: 8) {
                SmallTile(value: "4", label: "Breaks")
                SmallTile(value: "1 h 50", label: "Longest work")
            }
            Text("Top apps").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(AppUsageSample.items.prefix(4)) { a in
                    VStack(spacing: 3) {
                        Image(nsImage: a.icon).resizable().frame(width: 32, height: 32)
                        Text(hm(a.minutes).replacingOccurrences(of: " min", with: "m").replacingOccurrences(of: " h ", with: "h "))
                            .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            StatsFooter()
        }
        .padding(16).frame(width: 340)
    }
}

// S4. Кольцо «перерывы по плану» + приложения
struct StatsVariant4: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatsHeader()
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 10)
                    Circle().trim(from: 0, to: 4.0 / 5.0)
                        .stroke(LinearGradient(colors: [Color(red: 0.16, green: 0.72, blue: 0.52), Color(red: 0.20, green: 0.58, blue: 0.85)],
                                               startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("4/5").font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("breaks").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Good rhythm").font(.headline)
                    Text("1 break skipped, 2 postponed").font(.callout).foregroundStyle(.secondary)
                    Text("\(hm(AppUsageSample.total)) at the computer").font(.callout).foregroundStyle(.secondary)
                }
            }
            Text("Apps").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(AppUsageSample.items.prefix(4)) { AppRow(app: $0, top: AppUsageSample.items[0].minutes) }
            }
            Text("Reminders").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(Array(CalmSample.items.filter(\.on).enumerated()), id: \.element.id) { n, i in
                    HStack(spacing: 4) {
                        Image(systemName: i.symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(i.colors[0])
                        Text("\([5, 4, 2, 3][n % 4])").font(.caption).monospacedDigit()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                }
            }
            StatsFooter()
        }
        .padding(16).frame(width: 340)
    }
}

// MARK: - Рендер вариантов в PNG (флаг --render-variants <папка>)

enum DesignVariantRenderer {
    /// Настоящая панель из трея — для README и проверки вида.
    @MainActor
    static func renderPanel(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (name, view) in [("panel-now", AnyView(MenuContent())), ("panel-stats", AnyView(MenuContent(tab: .stats)))] {
            for (mode, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                write(view, appearance: appearance, to: "\(dir)/\(name)-\(mode).png")
            }
        }
    }

    @MainActor
    private static func write(_ view: AnyView, appearance: NSAppearance.Name, to path: String) {
        let host = NSHostingView(rootView: PanelFrame { view }.background(Color(nsColor: .windowBackgroundColor)))
        host.appearance = NSAppearance(named: appearance)
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        host.display()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    @MainActor
    static func renderAll(to dir: String) {
        let views: [(String, AnyView)] = [
            ("a", AnyView(PanelVariantA())), ("b", AnyView(PanelVariantB())), ("c", AnyView(PanelVariantC())),
            ("d", AnyView(PanelVariantD())), ("e", AnyView(PanelVariantE())), ("f", AnyView(PanelVariantF())),
            ("fp", AnyView(PanelVariantF(paused: true))), ("g", AnyView(PanelVariantG())),
            ("h", AnyView(PanelVariantH())), ("i", AnyView(PanelVariantI())),
            ("g1", AnyView(PanelVariantGx(style: .noHeader))), ("g1p", AnyView(PanelVariantGx(style: .noHeader, paused: true))),
            ("g2", AnyView(PanelVariantGx(style: .headerPill))), ("g2p", AnyView(PanelVariantGx(style: .headerPill, paused: true))),
            ("s1", AnyView(StatsVariant1())), ("s2", AnyView(StatsVariant2())),
            ("s3", AnyView(StatsVariant3())), ("s4", AnyView(StatsVariant4())),
            ("j", AnyView(PanelVariantJ())), ("js", AnyView(PanelVariantJ(tab: 1))), ("jp", AnyView(PanelVariantJ(paused: true))),
        ]
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (name, view) in views {
            for (mode, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let host = NSHostingView(rootView: PanelFrame { view }.background(Color(nsColor: .windowBackgroundColor)))
                host.appearance = NSAppearance(named: appearance)
                let size = host.fittingSize
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless,
                                      backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: appearance)
                window.contentView = host
                host.frame = NSRect(origin: .zero, size: size)
                host.layoutSubtreeIfNeeded()
                host.display()
                guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: URL(fileURLWithPath: "\(dir)/\(name)-\(mode).png"))
                }
            }
        }
    }
}
