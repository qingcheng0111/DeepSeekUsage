import Foundation

/// 时间维度：用量统计的时间范围选择（顶部「时间维度」下拉）
/// 所有范围按平台统计口径（北京时间）計日；end 为「次日 00:00」，即左闭右开区间。
enum TimeDimension: Equatable, Hashable {
    case today
    case yesterday
    case last7Days
    case last30Days
    case thisMonth
    case lastMonth
    case custom(start: Date, end: Date)   // 含 start 与 end 两个自然日（startOfDay 归一）

    /// 面板左列预设（顺序与需求参考图一致）
    static let presets: [TimeDimension] = [
        .today, .yesterday, .last7Days, .last30Days, .thisMonth, .lastMonth,
    ]

    /// 面板显示名
    var pickerLabel: String {
        switch self {
        case .today: return "今天"
        case .yesterday: return "昨天"
        case .last7Days: return "近 7 天"
        case .last30Days: return "近 30 天"
        case .thisMonth: return "本月"
        case .lastMonth: return "上月"
        case .custom: return "自定义"
        }
    }

    /// 指标标签前缀（「今日费用」「本月请求」…；自定义为「区间」）
    var metricLabel: String {
        switch self {
        case .today: return "今日"
        case .yesterday: return "昨日"
        case .last7Days: return "近7天"
        case .last30Days: return "近30天"
        case .thisMonth: return "本月"
        case .lastMonth: return "上月"
        case .custom: return "区间"
        }
    }

    /// 是否为自定义区间
    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }

    /// 顶部按钮上的短标签（自定义时显示日期范围）
    var shortLabel: String {
        switch self {
        case .custom(let s, let e):
            return "\(Self.mmdd.string(from: s))–\(Self.mmdd.string(from: e))"
        default:
            return pickerLabel
        }
    }

    /// 计算时间范围（Unix 用 Date；[start 当日 00:00, end 次日 00:00)，平台时区）
    func range(now: Date = Date()) -> (start: Date, end: Date) {
        let cal = MonthUsage.platformCalendar
        let todayStart = cal.startOfDay(for: now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: todayStart)!
        switch self {
        case .today:
            return (todayStart, tomorrow)
        case .yesterday:
            let s = cal.date(byAdding: .day, value: -1, to: todayStart)!
            return (s, todayStart)
        case .last7Days:
            let s = cal.date(byAdding: .day, value: -6, to: todayStart)!
            return (s, tomorrow)
        case .last30Days:
            let s = cal.date(byAdding: .day, value: -29, to: todayStart)!
            return (s, tomorrow)
        case .thisMonth:
            let comps = cal.dateComponents([.year, .month], from: now)
            let s = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1))!
            let e = cal.date(byAdding: .month, value: 1, to: s)!
            return (s, e)
        case .lastMonth:
            let comps = cal.dateComponents([.year, .month], from: now)
            let thisStart = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1))!
            let s = cal.date(byAdding: .month, value: -1, to: thisStart)!
            return (s, thisStart)
        case .custom(let a, let b):
            let s = cal.startOfDay(for: min(a, b))
            let eDay = cal.startOfDay(for: max(a, b))
            let e = cal.date(byAdding: .day, value: 1, to: eDay)!
            return (s, e)
        }
    }

    /// 顶部范围文字（如 10/01–10/31；end 为次日 00:00，展示末日后移一天）
    func rangeText(now: Date = Date()) -> String {
        let r = range(now: now)
        let cal = MonthUsage.platformCalendar
        let lastDay = cal.date(byAdding: .day, value: -1, to: r.end) ?? r.end
        return "\(Self.mmdd.string(from: r.start))–\(Self.mmdd.string(from: lastDay))"
    }

    /// 自定义区间最长天数（含首尾自然日）
    static let customMaxDays = 30

    /// 限制自定义区间不超过 30 天（含首尾）：起点优先，超出时终点向后截断；反序自动归一
    static func clampCustom(start: Date, end: Date) -> (start: Date, end: Date) {
        let cal = MonthUsage.platformCalendar
        let s = cal.startOfDay(for: min(start, end))
        var e = cal.startOfDay(for: max(start, end))
        if let maxEnd = cal.date(byAdding: .day, value: customMaxDays - 1, to: s), e > maxEnd {
            e = maxEnd
        }
        return (s, e)
    }

    /// MM/dd（平台时区）
    static let mmdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM/dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = MonthUsage.platformTimeZone
        return f
    }()
}
