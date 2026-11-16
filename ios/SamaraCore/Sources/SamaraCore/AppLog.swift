import Foundation

/// Rotating text log. About 1 MB, current file plus one previous file. No personal data.
public struct AppLog: Sendable {
    public let directory: URL
    public let byteCap: Int
    private let currentName = "log.txt"
    private let previousName = "log.1.txt"

    public init(directory: URL, byteCap: Int = 1_000_000) {
        self.directory = directory
        self.byteCap = byteCap
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func append(_ message: String, at date: Date = Date()) {
        let line = Self.stamp(date) + " " + message.replacingOccurrences(of: "\n", with: " ") + "\n"
        let added = Data(line.utf8)
        let current = directory.appendingPathComponent(currentName)
        let existing = (try? Data(contentsOf: current)) ?? Data()
        if !existing.isEmpty && existing.count + added.count > byteCap {
            rotate()
        }
        let target = directory.appendingPathComponent(currentName)
        if FileManager.default.fileExists(atPath: target.path),
           let handle = try? FileHandle(forWritingTo: target) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: added)
        } else {
            try? added.write(to: target)
        }
    }

    /// One .txt of the previous file, then the current file, for the share sheet.
    public func exportFile() throws -> URL {
        let previous = (try? String(contentsOf: directory.appendingPathComponent(previousName), encoding: .utf8)) ?? ""
        let current = (try? String(contentsOf: directory.appendingPathComponent(currentName), encoding: .utf8)) ?? ""
        let body = previous + current
        let url = directory.appendingPathComponent("samara-log.txt")
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    public static func stamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func rotate() {
        let current = directory.appendingPathComponent(currentName)
        let previous = directory.appendingPathComponent(previousName)
        try? FileManager.default.removeItem(at: previous)
        try? FileManager.default.moveItem(at: current, to: previous)
    }
}
