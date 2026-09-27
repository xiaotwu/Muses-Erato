import Foundation

enum RecapRange: String, CaseIterable, Sendable, Equatable {
    case day, week, month, allTime

    var label: String {
        switch self {
        case .day: tr("Today", "今天")
        case .week: tr("This Week", "本周")
        case .month: tr("This Month", "本月")
        case .allTime: tr("All Time", "全部")
        }
    }

    func startDate(from now: Date, calendar: Calendar = .current) -> Date {
        displayInterval(from: now, calendar: calendar, earliest: nil).start
    }

    func displayInterval(from now: Date, calendar: Calendar = .current,
                         earliest: Date?) -> DateInterval {
        switch self {
        case .day:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return .init(start: start, end: end)
        case .week:
            if let value = calendar.dateInterval(of: .weekOfYear, for: now) { return value }
            let start = calendar.startOfDay(for: now)
            return .init(start: start,
                         end: calendar.date(byAdding: .day, value: 7, to: start) ?? now)
        case .month:
            if let value = calendar.dateInterval(of: .month, for: now) { return value }
            let start = calendar.startOfDay(for: now)
            return .init(start: start,
                         end: calendar.date(byAdding: .month, value: 1, to: start) ?? now)
        case .allTime:
            let start = calendar.startOfDay(for: earliest ?? now)
            let end = calendar.date(byAdding: .day, value: 1,
                                    to: calendar.startOfDay(for: now)) ?? now
            return .init(start: start, end: end)
        }
    }
}
