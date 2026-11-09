import Foundation

/// Keeps a bounded number of transaction backups. Only QingType-owned backup
/// directories are considered; files, symlinks and unrelated directories are
/// never touched, so a user's own copy is always safe.
enum QingTypeBackupRetention {
  private static let markerName = ".qingtype-owned-backup.json"
  private struct Manifest: Codable, Equatable {
    let name: String
    let entries: [String: String]
  }

  private static func ownedName(_ name: String, prefixes: [String]) -> Bool {
    prefixes.contains { prefix in
      name.hasPrefix(prefix) && UUID(uuidString: String(name.dropFirst(prefix.count))) != nil
    }
  }

  private static func contents(of directory: URL) throws -> [String: String] {
    var enumerationError: Error?
    guard let iterator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey], errorHandler: { _, error in
      enumerationError = error
      return false
    }) else {
      throw SettingsError.invalid("无法读取备份目录。")
    }
    let base = directory.standardizedFileURL.pathComponents
    var entries: [String: String] = [:]
    for case let item as URL in iterator {
      let components = item.standardizedFileURL.pathComponents
      guard components.starts(with: base) else { throw SettingsError.invalid("备份路径越界。") }
      let relative = components.dropFirst(base.count).joined(separator: "/")
      if relative == markerName { continue }
      let values = try item.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
      guard values.isSymbolicLink != true else { throw SettingsError.invalid("备份含有链接。") }
      if values.isDirectory == true { entries[relative] = "directory" }
      else if values.isRegularFile == true { entries[relative] = "sha256:" + (try QingTypeContent.digest(of: item)) }
      else { throw SettingsError.invalid("备份含有不支持的文件。") }
    }
    if let enumerationError { throw enumerationError }
    return entries
  }

  // Mark only a completed, newly created transaction backup. A copied, renamed
  // or subsequently edited backup no longer matches its manifest.
  static func markOwned(_ directory: URL) throws {
    let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    guard values.isDirectory == true, values.isSymbolicLink != true,
          ownedName(directory.lastPathComponent, prefixes: ["install-", "apply-", "rime-ice-"]) else {
      throw SettingsError.invalid("不是清言创建的事务备份。")
    }
    let manifest = Manifest(name: directory.lastPathComponent, entries: try contents(of: directory))
    try JSONEncoder().encode(manifest).write(to: directory.appendingPathComponent(markerName), options: .withoutOverwriting)
  }

  private static func isUnmodifiedOwnedBackup(_ directory: URL) -> Bool {
    let marker = directory.appendingPathComponent(markerName)
    guard let values = try? marker.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
          values.isRegularFile == true, values.isSymbolicLink != true,
          let data = try? Data(contentsOf: marker),
          let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
          manifest.name == directory.lastPathComponent,
          let current = try? contents(of: directory) else { return false }
    return current == manifest.entries
  }

  static func unmarkedBackups(in root: URL, prefix: String) throws -> [URL] {
    let manager = FileManager.default
    guard (try? root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
      throw SettingsError.invalid("备份目录包含符号链接。")
    }
    guard manager.fileExists(atPath: root.path) else { return [] }
    return try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]).filter { url in
      guard ownedName(url.lastPathComponent, prefixes: [prefix]),
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
            values.isDirectory == true, values.isSymbolicLink != true else { return false }
      return !manager.fileExists(atPath: url.appendingPathComponent(markerName).path)
    }
  }

  static func prune(in root: URL, prefixes: [String], keeping: Int, preserving: URL? = nil) throws -> [URL] {
    guard keeping >= 1 else { throw SettingsError.invalid("备份保留数量必须至少为 1。") }
    let manager = FileManager.default
    guard (try? root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
      throw SettingsError.invalid("备份目录包含符号链接，已停止清理。")
    }
    guard let entries = try? manager.contentsOfDirectory(
      at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey]) else {
      return []
    }
    var candidates: [(URL, Date)] = []
    for url in entries {
      let name = url.lastPathComponent
      guard ownedName(name, prefixes: prefixes) else { continue }
      let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey])
      guard values?.isDirectory == true, values?.isSymbolicLink != true, isUnmodifiedOwnedBackup(url) else { continue }
      candidates.append((url, values?.contentModificationDate ?? .distantPast))
    }
    candidates.sort { $0.1 > $1.1 }
    if let preserving {
      guard let index = candidates.firstIndex(where: { $0.0.standardizedFileURL.path == preserving.standardizedFileURL.path }) else { return [] }
      let retained = candidates.remove(at: index)
      candidates.insert(retained, at: 0)
    }
    var removed: [URL] = []
    for (url, _) in candidates.dropFirst(keeping) {
      do { try manager.removeItem(at: url); removed.append(url) }
      catch { continue }
    }
    return removed
  }
}
