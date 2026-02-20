import UIKit

extension TrackedObject: Orderable {

    var order: String? {
        get { sortOrder }
        set { sortOrder = newValue }
    }

    var displayColor: UIColor? {
        ObjectColorCodec.uiColor(from: colorHex)
    }

    var displayIconName: String {
        iconName ?? "cube.fill"
    }
}

// MARK: - Icon Catalog

enum ObjectIconCatalog {

    struct IconGroup: Sendable {
        let title: String
        let icons: [String]
    }

    static let groups: [IconGroup] = [
        IconGroup(title: "General", icons: [
            "cube.fill", "star.fill", "heart.fill", "bookmark.fill",
            "tag.fill", "flag.fill", "bolt.fill", "flame.fill",
        ]),
        IconGroup(title: "Animals", icons: [
            "pawprint.fill", "dog.fill", "cat.fill", "bird.fill",
            "fish.fill", "hare.fill", "tortoise.fill", "ant.fill",
        ]),
        IconGroup(title: "Nature", icons: [
            "leaf.fill", "tree.fill", "mountain.2.fill", "drop.fill",
            "sun.max.fill", "moon.fill", "cloud.fill", "snowflake",
        ]),
        IconGroup(title: "Tech", icons: [
            "desktopcomputer", "laptopcomputer", "iphone", "applewatch",
            "headphones", "gamecontroller.fill", "camera.fill", "tv.fill",
        ]),
        IconGroup(title: "Transport", icons: [
            "car.fill", "bicycle", "bus.fill", "airplane",
            "ferry.fill", "fuelpump.fill", "scooter", "skateboard.fill",
        ]),
        IconGroup(title: "Home", icons: [
            "house.fill", "bed.double.fill", "fork.knife", "cup.and.saucer.fill",
            "washer.fill", "lightbulb.fill", "key.fill", "wrench.fill",
        ]),
        IconGroup(title: "Fitness", icons: [
            "figure.run", "dumbbell.fill", "soccerball", "basketball.fill",
            "tennisball.fill", "figure.hiking", "figure.pool.swim", "medal.fill",
        ]),
    ]

    static var allIcons: [String] {
        groups.flatMap(\.icons)
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
