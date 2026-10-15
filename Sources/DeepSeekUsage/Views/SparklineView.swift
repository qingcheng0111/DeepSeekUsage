import SwiftUI

/// Token 每日用量条目
struct TokenDailyEntry: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// 按天 Token 用量柱状图
/// 横轴：每个数据点都显示日期数字（30 天视图亦然）。
/// 通过「压缩柱间距 + 固定格宽 + 字号随格宽自适应」保证两位数字完整、不重叠、不截断。
/// 悬浮：鼠标移到任意柱子上，自动显示该日 Token 用量的小提示。
struct TokenDailyChart: View {
    let entries: [TokenDailyEntry]
    @State private var hoveredID: Date?

    var body: some View {
        GeometryReader { geo in
            let maxV = max(entries.map(\.value).max() ?? 0, 1)
            let count = entries.count
            let spacing: CGFloat = 1
            let cellWidth = count > 0
                ? max((geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count), 1)
                : 1
            // 格子窄（≈30 天视图，约 8–9pt）时用 6pt 保证两位数字完整；格子宽时用 7pt 更清晰
            let labelFontSize: CGFloat = cellWidth >= 20 ? 7 : 6
            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { _, entry in
                        VStack(spacing: 2) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(entry.value > 0 ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.08))
                                .frame(height: max(2, CGFloat(entry.value / maxV) * (geo.size.height - 12)))
                            // 每格都标注日期；minimumScaleFactor 兜底：极端窄格先缩字、不截断
                            Text(String(Calendar.current.component(.day, from: entry.date)))
                                .font(.system(size: labelFontSize))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .frame(width: cellWidth)
                        }
                        .frame(width: cellWidth)
                        .contentShape(Rectangle())
                        .onHover { h in
                            if h { hoveredID = entry.id }
                            else if hoveredID == entry.id { hoveredID = nil }
                        }
                    }
                }
                // 悬浮提示：显示该日 Token 用量（浮在图表上方；靠边自动收拢，不溢出面板）
                if let id = hoveredID, let index = entries.firstIndex(where: { $0.id == id }) {
                    let tooltipWidth: CGFloat = 92
                    let centerX = CGFloat(index) * (cellWidth + spacing) + cellWidth / 2
                    let clampedX = min(max(centerX, tooltipWidth / 2 - 4),
                                       max(geo.size.width - tooltipWidth / 2 + 4, tooltipWidth / 2))
                    Text("\(Self.monthDay.string(from: entries[index].date)) · \(Self.tokenString(entries[index].value))")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: tooltipWidth - 12)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(.regularMaterial))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.primary.opacity(0.10), lineWidth: 1))
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                        .position(x: clampedX, y: -9)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 42)
    }

    /// M/d（与横轴日号同一历法）
    private static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    /// Token 数值紧凑格式（与页面其它处一致：亿/万）
    private static func tokenString(_ n: Double) -> String {
        if n >= 1e8 { return String(format: "%.2f亿", n / 1e8) }
        if n >= 1e4 { return String(format: "%.1f万", n / 1e4) }
        if n == n.rounded() { return String(format: "%.0f", n) }
        return String(format: "%.1f", n)
    }
}
