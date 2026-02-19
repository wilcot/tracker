import UIKit

extension TrackedObject: Orderable {

    var order: String? {
        get { sortOrder }
        set { sortOrder = newValue }
    }

    var displayColor: UIColor? {
        ObjectColorCodec.uiColor(from: colorHex)
    }
}

// MARK: - Color Codec

enum ObjectColorCodec {
    static let palette: [String] = [
        "F94144", // Red
        "F3722C", // Orange
        "F9C74F", // Yellow
        "90BE6D", // Green
        "43AA8B", // Teal
        "577590", // Slate
        "4D96FF", // Blue
        "6C63FF", // Indigo
        "B5179E", // Purple
        "FF6B6B", // Coral
        "FFD166"  // Gold
    ]

    static func uiColor(from hex: String?) -> UIColor? {
        guard let hex, hex.count == 6, let value = Int(hex, radix: 16) else {
            return nil
        }
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    static func hex(from color: UIColor) -> String? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}
