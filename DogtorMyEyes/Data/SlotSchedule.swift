import Foundation

/// A recurring demo opening expressed in the clinic's local wall-clock time, relative to "today".
struct SlotTemplate: Codable, Hashable {
    let dayOffset: Int
    let hour: Int
    let minute: Int
}

enum SlotSchedule {
    /// Materializes templates into concrete dates in `timeZone`, dropping anything at or before `now`.
    static func slots(from templates: [SlotTemplate], in timeZone: TimeZone, relativeTo now: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfToday = calendar.startOfDay(for: now)

        let dates = templates.compactMap { template -> Date? in
            guard template.dayOffset >= 0,
                  (0..<24).contains(template.hour),
                  (0..<60).contains(template.minute),
                  let day = calendar.date(byAdding: .day, value: template.dayOffset, to: startOfToday)
            else { return nil }
            return calendar.date(bySettingHour: template.hour, minute: template.minute, second: 0, of: day)
        }

        return Array(Set(dates)).filter { $0 > now }.sorted()
    }
}

enum SlotFormatter {
    /// Formats a slot in the clinic's time zone with an explicit zone label, so the time matches what the clinic sees.
    static func string(
        for date: Date,
        in timeZone: TimeZone,
        date dateStyle: Date.FormatStyle.DateStyle = .abbreviated,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        var style = Date.FormatStyle(date: dateStyle, time: .shortened)
        style.timeZone = timeZone
        style.locale = locale
        let formatted = date.formatted(style)
        guard let zone = timeZone.abbreviation(for: date) else { return formatted }
        return "\(formatted) \(zone)"
    }
}
