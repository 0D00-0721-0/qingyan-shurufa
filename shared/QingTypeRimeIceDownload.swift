import Foundation

struct RimeIceDownload {
  var directory: URL
  var root: URL
  var provenance: String
  var sha256: String
}

enum QingTypeRimeIceDownload {
  static func official(_ update: QingTypeRimeIceUpdate, progress: @escaping @Sendable (QingTypeTransferProgress) -> Void) async throws -> RimeIceDownload {
    let downloaded = try await QingTypeDownloads.download(asset: update.asset, repository: QingTypeRimeIceUpdates.repository,
      release: update.release, limit: QingTypeRimeIceUpdates.downloadLimit, progress: progress)
    do {
      let root = try extract(downloaded.file, to: downloaded.directory.appendingPathComponent("package"))
      return RimeIceDownload(directory: downloaded.directory, root: root,
        provenance: "iDvel/rime-ice · \(downloaded.release)", sha256: downloaded.sha256)
    } catch {
      try? FileManager.default.removeItem(at: downloaded.directory)
      throw error
    }
  }

  // Preflight both central and local headers before invoking the system extractor.
  // No encrypted, linked, duplicate, traversing, ZIP64, or unbounded entries.
  static func validateZIP(_ data: Data) throws {
    func fail() -> SettingsError { .invalid("雾凇 ZIP 包损坏、路径不安全或超出资源限制。") }
    func u16(_ offset: Int) throws -> Int {
      guard offset >= 0, offset + 2 <= data.count else { throw fail() }
      return Int(data[offset]) | (Int(data[offset + 1]) << 8)
    }
    func u32(_ offset: Int) throws -> Int {
      try u16(offset) | (u16(offset + 2) << 16)
    }
    guard data.count >= 22, data.count <= 128 * 1024 * 1024 else { throw fail() }
    var end: Int?
    for index in stride(from: data.count - 22, through: max(0, data.count - 65557), by: -1) {
      if try u32(index) == 0x06054b50, try index + 22 + u16(index + 20) == data.count { end = index; break }
    }
    guard let end, try u16(end + 4) == 0, try u16(end + 6) == 0 else { throw fail() }
    let count = try u16(end + 10)
    let start = try u32(end + 16)
    guard count > 0, count < 10000, try u16(end + 8) == count,
          start >= 0, try start + u32(end + 12) == end else { throw fail() }
    var offset = start, names = Set<String>(), total = 0
    for _ in 0..<count {
      guard try u32(offset) == 0x02014b50 else { throw fail() }
      let flags = try u16(offset + 8), method = try u16(offset + 10)
      let compressed = try u32(offset + 20), size = try u32(offset + 24)
      let nameLength = try u16(offset + 28), extra = try u16(offset + 30), comment = try u16(offset + 32)
      let next = offset + 46 + nameLength + extra + comment
      guard nameLength > 0, next <= end, flags & 1 == 0, [0, 8].contains(method),
            compressed < 0xffffffff, size <= 128 * 1024 * 1024,
            try u16(offset + 34) == 0 else { throw fail() }
      let bytes = data.subdata(in: (offset + 46)..<(offset + 46 + nameLength))
      guard let name = String(data: bytes, encoding: .utf8),
            !name.hasPrefix("/"), !name.contains("\\"), !name.contains(":"),
            !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
            !name.split(separator: "/", omittingEmptySubsequences: false).dropLast(name.hasSuffix("/") ? 1 : 0).contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
            names.insert(name.lowercased()).inserted else { throw fail() }
      let mode = (try u32(offset + 38) >> 16) & 0xf000
      guard [0, 0x4000, 0x8000].contains(mode) else { throw fail() }
      let local = try u32(offset + 42)
      guard local < start, try u32(local) == 0x04034b50,
            try u16(local + 6) == flags, try u16(local + 8) == method,
            try u16(local + 26) == nameLength else { throw fail() }
      let dataStart = try local + 30 + nameLength + u16(local + 28)
      guard dataStart <= start, dataStart + compressed <= start,
            data.subdata(in: (local + 30)..<(local + 30 + nameLength)) == bytes else { throw fail() }
      total += size
      guard total <= 512 * 1024 * 1024 else { throw fail() }
      offset = next
    }
    guard offset == end else { throw fail() }
  }

  static func extract(_ archive: URL, to destination: URL) throws -> URL {
    try validateZIP(Data(contentsOf: archive, options: .mappedIfSafe))
    guard !FileManager.default.fileExists(atPath: destination.path) else { throw SettingsError.invalid("解压目标必须是新目录。") }
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    task.arguments = ["-x", "-k", archive.path, destination.path]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    try task.run(); task.waitUntilExit()
    guard task.terminationStatus == 0 else { throw SettingsError.invalid("雾凇方案解压失败。") }
    if FileManager.default.fileExists(atPath: destination.appendingPathComponent("rime_ice.schema.yaml").path) { return destination }
    let children = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil)
    guard children.count == 1, FileManager.default.fileExists(atPath: children[0].appendingPathComponent("rime_ice.schema.yaml").path) else {
      throw SettingsError.invalid("完整包中没有雾凇方案入口。")
    }
    return children[0]
  }
}
