import Foundation
import Yams

struct RimeIceFile: Codable, Equatable { var path: String; var sha256: String }
struct RimeIceAsset: Codable, Equatable {
  var version: String
  var source: String
  var archiveSHA256: String?
  var tables: [String]
  var files: [RimeIceFile]
  var installedAt = Date()
}

struct RimeIceRollbackRecord: Codable, Equatable {
  var previousManifest: Data?
  var installedFiles: [RimeIceFile]
  /// Files that existed before this install and were overwritten.
  var replaced: Set<String>
  /// Files this install created; only these may be removed by a rollback.
  var created: Set<String>
}

struct RimeIceInstallation {
  var asset: RimeIceAsset
  var backup: URL
  var rollback: RimeIceRollbackRecord
}

struct RimeIceRecoveryError: LocalizedError {
  var details: String
  var errorDescription: String? { details }
}

enum QingTypeRimeIce {
  static let manifestName = "scheme-packages/rime-ice.json"
  static let dictionaryName = "qingtype_ice_main"
  static let licensePath = "scheme-packages/rime-ice-LICENSE.txt"
  static let rollbackRecordName = "rollback.json"
  private static let schemas = ["rime_ice", "melt_eng", "radical_pinyin"]
  private static let resourceDirectories = Set(["cn_dicts", "en_dicts", "lua", "opencc"])
  private static let rootFiles = Set(["rime_ice.schema.yaml", "melt_eng.schema.yaml", "radical_pinyin.schema.yaml", "rime_ice.dict.yaml", "melt_eng.dict.yaml", "radical_pinyin.dict.yaml", "symbols_v.yaml", "symbols_caps_v.yaml", "qingtype_ice_defaults.yaml"])

  static func safePath(_ path: String) -> Bool {
    !path.hasPrefix("/") && !path.contains("\\") && !path.split(separator: "/").contains(where: { $0 == ".." || $0 == "." || $0.hasPrefix(".") }) &&
      path.range(of: "^[A-Za-z0-9_./-]+$", options: .regularExpression) != nil
  }
  static func managedPath(_ path: String) -> Bool {
    safePath(path) && (path == licensePath || rootFiles.contains(path) || resourceDirectories.contains(String(path.split(separator: "/").first ?? "")))
  }
  static func validate(_ asset: RimeIceAsset) throws {
    guard !asset.files.isEmpty, asset.files.count < 10000,
          Set(asset.files.map(\.path)).count == asset.files.count,
          asset.files.allSatisfy({ managedPath($0.path) && $0.sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil }),
          asset.tables.first == "rime_ice", Set(asset.tables).count == asset.tables.count,
          asset.tables.allSatisfy({ safePath($0) && ($0 == "rime_ice" || $0.hasPrefix("cn_dicts/")) }) else {
      throw SettingsError.invalid("雾凇方案清单不合法，请重新安装完整方案。")
    }
    let files = Set(asset.files.map(\.path))
    guard Set(schemas.map { $0 + ".schema.yaml" } + [licensePath, "qingtype_ice_defaults.yaml", "melt_eng.dict.yaml", "radical_pinyin.dict.yaml"] + asset.tables.map { $0 + ".dict.yaml" }).isSubset(of: files) else {
      throw SettingsError.invalid("雾凇方案清单缺少必要依赖。")
    }
  }
  static func installed(in directory: URL) -> RimeIceAsset? {
    guard let data = try? Data(contentsOf: directory.appendingPathComponent(manifestName)),
          let asset = try? JSONDecoder().decode(RimeIceAsset.self, from: data), (try? validate(asset)) != nil else { return nil }
    return asset
  }

  static func verifyInstalled(_ asset: RimeIceAsset, in directory: URL) throws {
    try QingTypePaths.checkDirectory(directory)
    try validate(asset)
    let manifest = try destination(manifestName, in: directory)
    let values = try manifest.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true,
          try JSONDecoder().decode(RimeIceAsset.self, from: Data(contentsOf: manifest)) == asset else {
      throw SettingsError.invalid("雾凇清单与当前设置不一致，请先备份并检查方案文件。")
    }
    for file in asset.files {
      try Task.checkCancellation()
      let path = try destination(file.path, in: directory)
      guard let attributes = try? path.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
            attributes.isRegularFile == true, attributes.isSymbolicLink != true,
            try QingTypeContent.digest(of: path, checkingCancellation: true) == file.sha256 else {
        throw SettingsError.invalid("雾凇资源缺失或已修改：\(file.path)。原文件已保留，请先备份并检查后重新安装。")
      }
    }
  }

  private static func destination(_ name: String, in directory: URL) throws -> URL {
    guard safePath(name) else { throw SettingsError.invalid("不安全的资源目标路径。") }
    var path = directory
    for component in name.split(separator: "/") {
      path.appendPathComponent(String(component))
      if (try? path.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
        throw SettingsError.invalid("目标资源路径包含链接：\(name)")
      }
    }
    return path
  }

  static func install(from source: URL, into directory: URL, provenance: String = "本地方案文件夹", archiveSHA256: String? = nil) throws -> RimeIceAsset {
    try installPackage(from: source, into: directory, provenance: provenance, archiveSHA256: archiveSHA256).asset
  }

  static func installPackage(from source: URL, into directory: URL, provenance: String = "本地方案文件夹", archiveSHA256: String? = nil) throws -> RimeIceInstallation {
    try QingTypePaths.checkDirectory(directory)
    let manager = FileManager.default
    let root = source.resolvingSymlinksInPath().standardizedFileURL
    guard root != directory.resolvingSymlinksInPath().standardizedFileURL else { throw SettingsError.invalid("请选择方案来源目录，不能选择清言自己的数据目录。") }
    func sourceURL(_ name: String) throws -> URL {
      guard safePath(name) else { throw SettingsError.invalid("方案包含不安全路径：\(name)") }
      let url = root.appendingPathComponent(name)
      let resolved = url.resolvingSymlinksInPath().standardizedFileURL
      let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
      guard resolved.pathComponents.starts(with: root.pathComponents), values.isSymbolicLink != true,
            values.isRegularFile == true, (values.fileSize ?? 0) <= 128 * 1024 * 1024 else {
        throw SettingsError.invalid("方案文件缺失、为链接或超出大小限制：\(name)")
      }
      return url
    }
    func yaml(_ name: String) throws -> [String: Any] {
      guard let result = try Yams.load(yaml: String(contentsOf: sourceURL(name), encoding: .utf8)) as? [String: Any] else {
        throw SettingsError.invalid("无法解析方案文件：\(name)")
      }
      return result
    }
    var parsedSchemas: [String: [String: Any]] = [:]
    for schema in schemas {
      let object = try yaml(schema + ".schema.yaml")
      guard let metadata = object["schema"] as? [String: Any], metadata["schema_id"] as? String == schema else {
        throw SettingsError.invalid("方案 ID 与文件名不匹配：\(schema)")
      }
      let dependencies = metadata["dependencies"] as? [String] ?? []
      guard dependencies.allSatisfy(schemas.contains) else { throw SettingsError.invalid("这个雾凇版本有未支持的方案依赖，请更新清言。") }
      parsedSchemas[schema] = object
    }
    var visiting = Set<String>(), visited = Set<String>()
    var dictionaryFiles = Set<String>(), iceTables: [String] = []
    func collect(_ name: String, forIce: Bool) throws {
      guard safePath(name), !visiting.contains(name) else { throw SettingsError.invalid("词典路径不安全或有循环依赖：\(name)") }
      if forIce && !iceTables.contains(name) { iceTables.append(name) }
      if visited.contains(name) { return }
      visiting.insert(name)
      defer { visiting.remove(name) }
      let url = try sourceURL(name + ".dict.yaml")
      let text = try String(contentsOf: url, encoding: .utf8)
      guard let end = text.range(of: "\n..."), let header = try Yams.load(yaml: String(text[..<end.lowerBound])) as? [String: Any],
            let headerName = header["name"], String(describing: headerName) == name || String(describing: headerName) == URL(fileURLWithPath: name).lastPathComponent else { throw SettingsError.invalid("词典头部不完整或名称不匹配：\(name)") }
      let imports = header["import_tables"] as? [String] ?? []
      if header["import_tables"] != nil && !(header["import_tables"] is [String]) { throw SettingsError.invalid("词典依赖列表不合法：\(name)") }
      dictionaryFiles.insert(name + ".dict.yaml")
      for entry in imports { try collect(entry, forIce: forIce) }
      visited.insert(name)
    }
    try collect("rime_ice", forIce: true)
    try collect("melt_eng", forIce: false)
    try collect("radical_pinyin", forIce: false)
    var sourceNames = dictionaryFiles
    for name in schemas { sourceNames.insert(name + ".schema.yaml") }
    sourceNames.insert("default.yaml")
    sourceNames.insert("LICENSE")
    for name in ["symbols_v.yaml", "symbols_caps_v.yaml"] where manager.fileExists(atPath: root.appendingPathComponent(name).path) { sourceNames.insert(name) }
    for folder in resourceDirectories {
      let url = root.appendingPathComponent(folder)
      guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
            let iterator = manager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else {
        throw SettingsError.invalid("缺少雾凇资源目录：\(folder)")
      }
      for case let file as URL in iterator {
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true else { throw SettingsError.invalid("方案资源不能包含符号链接。") }
        guard values.isRegularFile == true else { continue }
        // macOS's enumerator can return /private/var for a root spelled /var.
        let canonical = file.resolvingSymlinksInPath().standardizedFileURL
        let name = canonical.pathComponents.dropFirst(root.pathComponents.count).joined(separator: "/")
        guard ["yaml", "lua", "txt", "json", "ocd2"].contains(file.pathExtension.lowercased()) || name == "lua/lunar.db" else { continue }
        _ = try sourceURL(name)
        sourceNames.insert(name)
      }
    }
    let engine = parsedSchemas["rime_ice"]?["engine"] as? [String: Any] ?? [:]
    for component in engine.values.compactMap({ $0 as? [String] }).flatMap({ $0 }) where component.hasPrefix("lua_") {
      guard let at = component.range(of: "@*") else { throw SettingsError.invalid("请选择使用 Lua 模块加载语法的新版雾凇。") }
      let module = component[at.upperBound...].split(separator: "@").first.map(String.init) ?? ""
      let name = "lua/" + module.replacingOccurrences(of: ".", with: "/") + ".lua"
      guard sourceNames.contains(name) else { throw SettingsError.invalid("缺少 Lua 模块：\(name)") }
      if module == "lunar", !sourceNames.contains("lua/lunar.db") { throw SettingsError.invalid("缺少雾凇农历静态资源 lua/lunar.db。") }
    }
    // Namespacing only the package defaults prevents it from replacing QingType's
    // default.yaml, squirrel.yaml, phrases, or the existing Xiaohe base schema.
    func namespaced(_ value: Any, key: String = "") -> Any {
      if let values = value as? [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in values { result[key] = namespaced(value, key: key) }
        return result
      }
      if let values = value as? [Any] { return values.map { namespaced($0) } }
      if let value = value as? String {
        if value.hasPrefix("default:/") { return "qingtype_ice_defaults:/" + value.dropFirst("default:/".count) }
        if key == "import_preset" && value == "default" { return "qingtype_ice_defaults" }
      }
      return value
    }
    let stage = directory.appendingPathComponent(".ice-stage-\(UUID())", isDirectory: true)
    try manager.createDirectory(at: stage, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: stage) }
    var files: [RimeIceFile] = []
    var total = 0
    for name in sourceNames.sorted() {
      let original = try sourceURL(name)
      let destinationName = name == "default.yaml" ? "qingtype_ice_defaults.yaml" : name == "LICENSE" ? licensePath : name
      guard managedPath(destinationName) else { throw SettingsError.invalid("不支持的雾凇资源路径：\(name)") }
      let target = stage.appendingPathComponent(destinationName)
      try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
      if name.hasSuffix(".schema.yaml"), let schema = parsedSchemas[name.replacingOccurrences(of: ".schema.yaml", with: "")] {
        try Yams.dump(object: namespaced(schema)).write(to: target, atomically: true, encoding: .utf8)
      } else { try manager.copyItem(at: original, to: target) }
      total += (try target.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
      guard total <= 512 * 1024 * 1024, files.count < 10000 else { throw SettingsError.invalid("雾凇方案包超过资源限制。") }
      files.append(.init(path: destinationName, sha256: try QingTypeContent.digest(of: target)))
    }
    let version = ((parsedSchemas["rime_ice"]?["schema"] as? [String: Any])?["version"]).map { String(describing: $0) } ?? "unknown"
    let asset = RimeIceAsset(version: version, source: provenance, archiveSHA256: archiveSHA256, tables: iceTables, files: files)
    try validate(asset)
    let previous = installed(in: directory)
    let oldHashes = Dictionary(uniqueKeysWithValues: (previous?.files ?? []).map { ($0.path, $0.sha256) })
    for name in files.map(\.path) + [manifestName, "backups"] {
      _ = try destination(name, in: directory)
    }
    var changed: [RimeIceFile] = []
    var replaced = Set<String>(), created = Set<String>()
    for file in files {
      let target = directory.appendingPathComponent(file.path)
      if manager.fileExists(atPath: target.path) {
        guard target.resolvingSymlinksInPath().standardizedFileURL.pathComponents.starts(with: directory.resolvingSymlinksInPath().standardizedFileURL.pathComponents),
              (try target.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else { throw SettingsError.invalid("目标资源路径包含链接：\(file.path)") }
        let current = try QingTypeContent.digest(of: target)
        guard current == file.sha256 || current == oldHashes[file.path] else { throw SettingsError.invalid("\(file.path) 已存在且不属于当前托管版本，保留原文件；请先备份并处理冲突。") }
        if current == file.sha256 { continue }
        replaced.insert(file.path)
      } else {
        created.insert(file.path)
      }
      changed.append(file)
    }
    let backup = directory.appendingPathComponent("backups/rime-ice-\(UUID())", isDirectory: true)
    let manifestURL = directory.appendingPathComponent(manifestName)
    let previousManifest = manager.fileExists(atPath: manifestURL.path) ? try Data(contentsOf: manifestURL) : nil
    let record = RimeIceRollbackRecord(previousManifest: previousManifest, installedFiles: files, replaced: replaced, created: created)
    var written: [String] = []
    do {
      if previousManifest != nil && !changed.isEmpty {
        try manager.createDirectory(at: backup, withIntermediateDirectories: true)
        for path in replaced {
          let saved = backup.appendingPathComponent(path)
          try manager.createDirectory(at: saved.deletingLastPathComponent(), withIntermediateDirectories: true)
          try manager.copyItem(at: destination(path, in: directory), to: saved)
          guard try QingTypeContent.digest(of: saved) == oldHashes[path] else {
            throw SettingsError.invalid("雾凇文件在备份期间被修改：\(path)。")
          }
        }
        try JSONEncoder().encode(record).write(to: backup.appendingPathComponent(rollbackRecordName), options: .atomic)
      }
      for file in changed {
        let target = try destination(file.path, in: directory)
        let current = manager.fileExists(atPath: target.path) ? try QingTypeContent.digest(of: target) : nil
        guard current == (replaced.contains(file.path) ? oldHashes[file.path] : nil) else {
          throw SettingsError.invalid("雾凇文件在安装期间被修改：\(file.path)。")
        }
        try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contentsOf: stage.appendingPathComponent(file.path)).write(to: target, options: .atomic)
        written.append(file.path)
      }
      let manifest = directory.appendingPathComponent(manifestName)
      try manager.createDirectory(at: manifest.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(asset).write(to: manifest, options: .atomic)
    } catch {
      var recoveryErrors: [String] = []
      for name in written.reversed() {
        let target = directory.appendingPathComponent(name)
        do {
          if replaced.contains(name) { try Data(contentsOf: backup.appendingPathComponent(name)).write(to: target, options: .atomic) }
          else { try manager.removeItem(at: target) }
        } catch { recoveryErrors.append("\(name): \(error.localizedDescription)") }
      }
      if !recoveryErrors.isEmpty {
        throw RimeIceRecoveryError(details: "雾凇资源写入失败且恢复未完成，输入服务应保持停止。备份：\(backup.path)。\(error.localizedDescription)；\(recoveryErrors.joined(separator: "；"))")
      }
      throw error
    }
    return RimeIceInstallation(asset: asset, backup: backup, rollback: record)
  }

  /// Promote a backup only after deployment and verification of the old resource set.
  static func retainRollbackPoint(_ installation: RimeIceInstallation, in directory: URL) throws {
    let rollback = installation.rollback
    guard let manifest = rollback.previousManifest, !rollback.replaced.isEmpty || !rollback.created.isEmpty else { return }
    let record = try Data(contentsOf: destination(rollbackRecordName, in: installation.backup))
    guard try JSONDecoder().decode(RimeIceRollbackRecord.self, from: record) == rollback else {
      throw SettingsError.invalid("雾凇回退清单校验失败。")
    }
    let previous = try JSONDecoder().decode(RimeIceAsset.self, from: manifest)
    try validate(previous)
    for file in previous.files {
      let root = rollback.replaced.contains(file.path) ? installation.backup : directory
      let url = try destination(file.path, in: root)
      let values = try url.resourceValues(forKeys: [.isRegularFileKey])
      guard !rollback.created.contains(file.path), values.isRegularFile == true,
            try QingTypeContent.digest(of: url) == file.sha256 else {
        throw SettingsError.invalid("雾凇旧版资源校验失败：\(file.path)。")
      }
    }
    try QingTypeBackupRetention.markOwned(installation.backup)
    _ = try QingTypeBackupRetention.prune(in: installation.backup.deletingLastPathComponent(), prefixes: ["rime-ice-"],
      keeping: 1, preserving: installation.backup)
  }

  // A failed activation restores package resources as well as generated settings.
  // Refuse to discard edits made by another program during deployment.
  static func rollback(_ installation: RimeIceInstallation, in directory: URL) throws {
    let manager = FileManager.default
    for file in installation.rollback.installedFiles {
      let current = try QingTypeContent.digest(of: destination(file.path, in: directory))
      guard current == file.sha256 else { throw SettingsError.invalid("\(file.path) 在安装期间被修改，未覆盖它。备份：\(installation.backup.path)") }
    }
    for file in installation.rollback.installedFiles.reversed() {
      let target = try destination(file.path, in: directory)
      if installation.rollback.replaced.contains(file.path) {
        try Data(contentsOf: installation.backup.appendingPathComponent(file.path)).write(to: target, options: .atomic)
      } else if installation.rollback.created.contains(file.path) {
        try manager.removeItem(at: target)
      }
    }
    let manifest = try destination(manifestName, in: directory)
    if let previous = installation.rollback.previousManifest { try previous.write(to: manifest, options: .atomic) }
    else { try manager.removeItem(at: manifest) }
  }
}
