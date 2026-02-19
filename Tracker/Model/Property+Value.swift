import CoreData
import Foundation

extension Property: Orderable {

    var order: String? {
        get { sortOrder }
        set { sortOrder = newValue }
    }
}

extension Property {

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var formattedTimestamp: String? {
        guard let timestamp else { return nil }
        return Self.dateTimeFormatter.string(from: timestamp)
    }

    var formattedUserTimestamp: String? {
        guard let userTimestamp else { return nil }
        return Self.dateTimeFormatter.string(from: userTimestamp)
    }

    /// Formatted value for display in the UI (e.g. list row subtitle).
    var displayValue: String? {
        guard let type = PropertyType(rawValue: type ?? "") else { return nil }
        switch type {
        case .string:
            let s = valueString?.trimmingCharacters(in: .whitespacesAndNewlines)
            return s?.isEmpty == true ? nil : s
        case .integer:
            guard let num = valueInteger else { return nil }
            return "\(num.int64Value)"
        case .date:
            guard let d = valueDate else { return nil }
            return Self.dateFormatter.string(from: d)
        }
    }

    /// Clears all value attributes so only one is used per type.
    func clearAllValues() {
        valueString = nil
        valueInteger = nil
        valueDouble = nil
        valueDate = nil
    }

    func setValue(string: String?) {
        clearAllValues()
        valueString = string
    }

    func setValue(integer: Int64?) {
        clearAllValues()
        valueInteger = integer.map { NSNumber(value: $0) }
    }

    func setValue(double: Double?) {
        clearAllValues()
        valueDouble = double.map { NSNumber(value: $0) }
    }

    func setValue(date: Date?) {
        clearAllValues()
        valueDate = date
    }
}
