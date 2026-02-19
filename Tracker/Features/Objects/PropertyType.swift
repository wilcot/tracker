import UIKit

enum PropertyType: String, CaseIterable, Sendable {
    case string = "string"
    case integer = "integer"
    case date = "date"
    case description = "description"
    case boolean = "boolean"

    var displayName: String {
        switch self {
        case .string: return "Text"
        case .integer: return "Number"
        case .date: return "Date"
        case .description: return "Description"
        case .boolean: return "Boolean"
        }
    }

    var subtitle: String {
        switch self {
        case .string: return "Plain text, names, or labels"
        case .integer: return "Whole numbers and counts"
        case .date: return "Dates, deadlines, or milestones"
        case .description: return "Long-form notes or details"
        case .boolean: return "Yes / no, true / false toggles"
        }
    }

    var systemImage: String {
        switch self {
        case .string: return "text.cursor"
        case .integer: return "number"
        case .date: return "calendar"
        case .description: return "doc.text"
        case .boolean: return "switch.2"
        }
    }

    var accentColor: UIColor {
        switch self {
        case .string:      return UIColor(red: 0x4F/255, green: 0x46/255, blue: 0xE5/255, alpha: 1)
        case .integer:     return UIColor(red: 0x25/255, green: 0x63/255, blue: 0xEB/255, alpha: 1)
        case .date:        return UIColor(red: 0xE1/255, green: 0x1D/255, blue: 0x48/255, alpha: 1)
        case .description: return UIColor(red: 0x05/255, green: 0x96/255, blue: 0x69/255, alpha: 1)
        case .boolean:     return UIColor(red: 0xD9/255, green: 0x77/255, blue: 0x06/255, alpha: 1)
        }
    }

    var backgroundColor: UIColor {
        switch self {
        case .string:      return UIColor(red: 0xEE/255, green: 0xF2/255, blue: 0xFF/255, alpha: 1)
        case .integer:     return UIColor(red: 0xDB/255, green: 0xEA/255, blue: 0xFE/255, alpha: 1)
        case .date:        return UIColor(red: 0xFF/255, green: 0xE4/255, blue: 0xE6/255, alpha: 1)
        case .description: return UIColor(red: 0xD1/255, green: 0xFA/255, blue: 0xE5/255, alpha: 1)
        case .boolean:     return UIColor(red: 0xFE/255, green: 0xF3/255, blue: 0xC7/255, alpha: 1)
        }
    }
}
