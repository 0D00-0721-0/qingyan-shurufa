import Foundation

@main
struct MaintenanceTests {
  static func main() throws {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("qingtype-maintenance-test-\(UUID())")
    try fm.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? fm.removeItem(at: root) }
    var checks = 0
    func expect(_ value: Bool, _ label: String) throws { guard value else { throw SettingsError.invalid("FAIL: \(label)") }; checks += 1 }
    func rejects(_ block: () throws -> Void) throws {
      do { try block() } catch { checks += 1; return }
      throw SettingsError.invalid("Expected rejected maintenance operation")
    }
    func app(_ url: URL, version: String, kind: QingTypeProgramKind = .application) throws -> URL {
      try fm.createDirectory(at: url.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
      let info = ["CFBundleIdentifier": kind.bundleID, "CFBundleExecutable": kind.executable, "CFBundleShortVersionString": version]
      try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: url.appendingPathComponent("Contents/Info.plist"))
      let executable = url.appendingPathComponent("Contents/MacOS/" + kind.executable)
      try Data("synthetic test bundle \(version)".utf8).write(to: executable)
      try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
      return url
    }
    func validate(_ url: URL) throws { _ = try QingTypeProgramMaintenance.version(at: url, kind: .application) }
    let old = try app(root.appendingPathComponent("Applications/清言.app"), version: "0.5.0")
    let new = try app(root.appendingPathComponent("new/清言.app"), version: "0.6.0")
    let data = root.appendingPathComponent("Library/QingType")
    let db = data.appendingPathComponent("qingtype_main.userdb")
    try fm.createDirectory(at: db, withIntermediateDirectories: true)
    let sentinel = Data("private dictionary and learning sentinel".utf8)
    try sentinel.write(to: db.appendingPathComponent("CURRENT"))
    try sentinel.write(to: data.appendingPathComponent("settings.json"))
    let receipt = try QingTypeProgramMaintenance.installApplication(source: new, destination: old, backups: data.appendingPathComponent("backups/one"), validate: validate)
    try expect(try QingTypeProgramMaintenance.version(at: old, kind: .application) == "0.6.0" && receipt.previousVersion == "0.5.0", "application upgrade installs the new version with an exact previous-version receipt")
    try expect(try QingTypeContent.digest(of: URL(fileURLWithPath: receipt.archive)) == receipt.archiveSHA256, "previous application archive has a recoverable verified checksum")
    try expect(try Data(contentsOf: db.appendingPathComponent("CURRENT")) == sentinel && Data(contentsOf: data.appendingPathComponent("settings.json")) == sentinel, "application replacement leaves preferences and learning bytes unchanged")
    let newer = try app(root.appendingPathComponent("newer/清言.app"), version: "0.6.1")
    try rejects {
      _ = try QingTypeProgramMaintenance.installApplication(source: newer, destination: old, backups: data.appendingPathComponent("backups/failure")) { url in
        try validate(url)
        if url == old, try QingTypeProgramMaintenance.version(at: url, kind: .application) == "0.6.1" { throw SettingsError.invalid("injected installed-bundle failure") }
      }
    }
    try expect(try QingTypeProgramMaintenance.version(at: old, kind: .application) == "0.6.0", "post-replacement validation failure restores the previous runnable program")
    let previous = try app(root.appendingPathComponent("older/清言.app"), version: "0.4.0")
    try rejects { _ = try QingTypeProgramMaintenance.installApplication(source: previous, destination: old, backups: data.appendingPathComponent("backups/downgrade"), validate: validate) }
    let alias = root.appendingPathComponent("alias.app")
    try fm.createSymbolicLink(at: alias, withDestinationURL: new)
    try rejects { _ = try QingTypeProgramMaintenance.version(at: alias, kind: .application) }
    let archive = URL(fileURLWithPath: receipt.archive)
    let zip = try Data(contentsOf: archive)
    try Data("corrupt archive".utf8).write(to: archive)
    try rejects { try QingTypeProgramMaintenance.restoreApplication(receipt, validate: validate) }
    try zip.write(to: archive)
    try QingTypeProgramMaintenance.restoreApplication(receipt, validate: validate)
    try expect(try QingTypeProgramMaintenance.version(at: old, kind: .application) == "0.5.0", "verified archive rollback restores the actual old program")

    func release(_ version: String, draft: Bool = false, architecture: String = "arm64") -> QingTypeAppRelease {
      let tag = "v\(version)-preview.1"
      return .init(tag_name: tag, draft: draft, prerelease: true,
                   html_url: URL(string: "https://github.com/0D00-0721-0/qingyan-shurufa/releases/tag/\(tag)")!,
                   assets: [.init(name: "QingType-\(version)-\(architecture).dmg",
                                  browser_download_url: URL(string: "https://github.com/0D00-0721-0/qingyan-shurufa/releases/download/\(tag)/QingType-\(version)-\(architecture).dmg")!,
                                  size: 100, digest: "sha256:" + String(repeating: "a", count: 64))])
    }
    try expect(QingTypeAppUpdates.choose([release("0.6.9"), release("0.6.10")], architecture: "arm64")?.version == "0.6.10", "numeric release ordering selects 0.6.10 after 0.6.9")
    try expect(QingTypeAppUpdates.choose([release("9.0.0", draft: true), release("0.6.0")], architecture: "arm64")?.version == "0.6.0", "draft releases cannot become update candidates")
    try expect(QingTypeAppUpdates.choose([release("0.6.0", architecture: "x86_64")], architecture: "arm64") == nil, "updates never select the wrong CPU architecture")
    var missingHash = release("0.6.0"); missingHash.assets[0].digest = nil
    try expect(QingTypeAppUpdates.choose([missingHash], architecture: "arm64") == nil, "unsigned metadata without an asset checksum is refused")
    var external = release("0.6.0"); external.assets[0].browser_download_url = URL(string: "https://example.com/app.dmg")!
    try expect(QingTypeAppUpdates.choose([external], architecture: "arm64") == nil, "update downloads are restricted to the QingType repository")
    var badTag = release("0.6.0"); badTag.tag_name = "main"
    try expect(QingTypeAppUpdates.choose([badTag], architecture: "arm64") == nil, "non-version release tags cannot install programs")
    let captured = try JSONDecoder().decode([QingTypeAppRelease].self,
      from: Data(contentsOf: URL(fileURLWithPath: "tests/fixtures/qingtype-release-renamed.json")))
    try expect(QingTypeAppUpdates.choose(captured, architecture: "arm64")?.tag == "v0.6.5-preview.1",
               "actual canonical GitHub metadata remains selectable after the repository rename")
    let capturedAsset = captured[0].assets[0]
    try expect(try QingTypeDownloads.validateDownload(capturedAsset, repository: QingTypeAppUpdates.repository,
                                                      limit: QingTypeAppUpdates.downloadLimit) == String(capturedAsset.digest!.dropFirst(7)),
               "the selected renamed-repository asset also passes the production download gate")
    for repository in ["someone/qingyan-shurufa", "0D00-0721-0/qingyan-shurufa-extra", "0D00-0721-0/qingtype"] {
      var unsupported = captured[0]
      unsupported.html_url = URL(string: "https://github.com/\(repository)/releases/tag/\(unsupported.tag_name)")!
      unsupported.assets[0].browser_download_url = URL(string: "https://github.com/\(repository)/releases/download/\(unsupported.tag_name)/\(capturedAsset.name)")!
      try expect(QingTypeAppUpdates.choose([unsupported], architecture: "arm64") == nil,
                 "a different owner, similar name or obsolete repository cannot supply an app update")
      try rejects {
        _ = try QingTypeDownloads.validateDownload(unsupported.assets[0], repository: repository,
                                                   limit: QingTypeAppUpdates.downloadLimit)
      }
    }
    for repository in ["iDvel/rime-ice", "amzxyz/rime-wanxiang-data"] {
      let component = QingTypeRelease.Asset(name: "component.zip",
        browser_download_url: URL(string: "https://github.com/\(repository)/releases/download/latest/component.zip")!,
        size: 100, digest: "sha256:" + String(repeating: "a", count: 64))
      try expect(try QingTypeDownloads.validateDownload(component, repository: repository, limit: 100) == String(repeating: "a", count: 64),
                 "the existing optional-component download source remains allowed")
    }
    try expect(!QingTypeMaintenancePreferences().checkUpdatesOnLaunch, "factory first launch does not contact the update service")
    var privateSettings = QingTypeSettings()
    privateSettings.personalWords = [.init(text: "PRIVATE_WORD_DO_NOT_EXPORT", pinyin: "ce shi", weight: 100)]
    privateSettings.phrases = [.init(code: "private", text: "PRIVATE_PHRASE_DO_NOT_EXPORT")]
    let summary = String(decoding: try JSONSerialization.data(withJSONObject: QingTypeDiagnosticSummary.configuration(privateSettings)), as: UTF8.self)
    try expect(!summary.contains("PRIVATE_") && !summary.contains("ce shi") && summary.contains("personalWordCount"), "diagnostics export only counts and flags, never private word or phrase contents")

    let input = try app(root.appendingPathComponent("Library/Input Methods/QingType.app"), version: "0.6.0", kind: .inputService)
    let allowed = [old, input, data]
    let staged = root.appendingPathComponent("Library/清言卸载备份-one")
    _ = try QingTypeProgramMaintenance.stageUninstall(items: [.init(url: old, kind: .application), .init(url: input, kind: .inputService)], allowed: allowed, userData: data, staging: staged)
    try expect(!fm.fileExists(atPath: old.path) && !fm.fileExists(atPath: input.path) && fm.fileExists(atPath: db.path), "default uninstall moves both programs and preserves user data")
    try expect(fm.fileExists(atPath: staged.appendingPathComponent("恢复说明.txt").path), "recoverable uninstall contains readable restoration instructions")
    try QingTypeProgramMaintenance.undoStagedUninstall(staged, allowed: allowed)
    try expect(fm.fileExists(atPath: old.path) && fm.fileExists(atPath: input.path), "recycling failure can restore all staged programs")
    var moves = 0
    try rejects {
      _ = try QingTypeProgramMaintenance.stageUninstall(items: [.init(url: old, kind: .application), .init(url: data, kind: nil)], allowed: allowed, userData: data, staging: root.appendingPathComponent("Library/清言卸载备份-failure")) {
        moves += 1; if moves == 2 { throw SettingsError.invalid("injected data move failure") }
      }
    }
    try expect(try Data(contentsOf: data.appendingPathComponent("settings.json")) == sentinel && Data(contentsOf: db.appendingPathComponent("CURRENT")) == sentinel && fm.fileExists(atPath: old.path), "partial uninstall restores programs, preferences and learning exactly")
    try rejects { _ = try QingTypeProgramMaintenance.stageUninstall(items: [.init(url: new, kind: .application)], allowed: allowed, userData: data, staging: root.appendingPathComponent("bad")) }
    let dataAlias = root.appendingPathComponent("Library/linked-profile")
    try fm.createSymbolicLink(at: dataAlias, withDestinationURL: data)
    try rejects { _ = try QingTypeSettings.load(from: dataAlias) }
    try rejects { try QingTypeSettings().save(to: dataAlias) }
    try expect(try Data(contentsOf: data.appendingPathComponent("settings.json")) == sentinel, "profile symlink rejection never rewrites original settings")
    print("PASS: \(checks) program update, rollback, uninstall recovery, catalog and profile-boundary checks")
  }
}
