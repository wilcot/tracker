import Foundation
import os

enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.app"
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
