import Foundation

public actor Archive {
    public let url: URL
    private var savedRevision: UInt64 = 0
    public init(url: URL) { self.url = url }
    public nonisolated static func decode(_ data: Data) throws -> Library {
        guard data.count <= 100_000_000 else { throw ResusError.invalid("This backup is too large to open.") }
        return try JSONDecoder().decode(Library.self, from: data).validated()
    }
    public nonisolated static func read(_ url: URL) throws -> Library {
        try decode(Data(contentsOf: url))
    }
    public nonisolated static func encode(_ library: Library) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(library.validated())
        guard data.count <= 100_000_000 else { throw ResusError.invalid("This library exceeds the 100 MB limit. Split large notes or remove unused cards before saving.") }
        return data
    }
    public func save(_ library: Library, revision: UInt64) throws {
        guard revision >= savedRevision else { return }
        let data = try Self.encode(library)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let previous = try Data(contentsOf: url)
            _ = try Self.decode(previous)
            try previous.write(to: url.appendingPathExtension("previous"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        savedRevision = revision
    }
    public func restore(_ library: Library) throws {
        let data = try Self.encode(library)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.copyItem(at: url, to: url.appendingPathExtension("before-restore-\(UUID().uuidString)"))
        }
        try data.write(to: url, options: .atomic)
    }
    public func previous() throws -> Library {
        try Self.read(url.appendingPathExtension("previous"))
    }
}
