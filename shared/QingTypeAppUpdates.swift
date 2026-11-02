import Foundation

struct QingTypeAppRelease: Decodable {
  var tag_name: String
  var draft: Bool
  var prerelease: Bool
  var html_url: URL
  var assets: [QingTypeRelease.Asset]
  var version: String? {
    guard tag_name.range(of: "^v[0-9]+\\.[0-9]+\\.[0-9]+(-preview\\.[0-9]+)?$", options: .regularExpression) != nil else { return nil }
    return String(tag_name.dropFirst().split(separator: "-")[0])
  }
}

struct QingTypeAppUpdate {
  var version: String
  var tag: String
  var page: URL
  var asset: QingTypeRelease.Asset
}

struct QingTypeMaintenancePreferences: Codable {
  var checkUpdatesOnLaunch = false
  var lastChecked: Date?
  static var directory: URL { QingTypePaths.userDirectory.appendingPathComponent("maintenance") }
  static var file: URL { directory.appendingPathComponent("preferences.json") }
  static func load() throws -> Self {
    try QingTypePaths.checkDirectory(QingTypePaths.userDirectory)
    guard FileManager.default.fileExists(atPath: file.path) else { return Self() }
    return try JSONDecoder().decode(Self.self, from: Data(contentsOf: file))
  }
  func save() throws {
    try QingTypePaths.checkDirectory(QingTypePaths.userDirectory)
    try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    try JSONEncoder().encode(self).write(to: Self.file, options: .atomic)
  }
}

enum QingTypeAppUpdates {
  static let repository = "0D00-0721-0/qingyan-shurufa"
  static let downloadLimit: Int64 = 256 * 1024 * 1024
  static var architecture: String {
    #if arch(arm64)
    return "arm64"
    #else
    return "x86_64"
    #endif
  }
  static func choose(_ releases: [QingTypeAppRelease], architecture: String = architecture) -> QingTypeAppUpdate? {
    releases.compactMap { release -> QingTypeAppUpdate? in
      guard !release.draft, let version = release.version,
            release.html_url.scheme == "https", release.html_url.host == "github.com",
            release.html_url.path == "/\(repository)/releases/tag/\(release.tag_name)",
            let asset = release.assets.first(where: { $0.name == "QingType-\(version)-\(architecture).dmg" }),
            (try? asset.validate(repository: repository, limit: downloadLimit)) != nil else { return nil }
      return .init(version: version, tag: release.tag_name, page: release.html_url, asset: asset)
    }.max { $0.version.compare($1.version, options: .numeric) == .orderedAscending }
  }
  static func check() async throws -> QingTypeAppUpdate? {
    var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=30")!)
    request.timeoutInterval = 45
    request.setValue("QingType", forHTTPHeaderField: "User-Agent")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    let config = URLSessionConfiguration.ephemeral
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel() }
    let (data, response) = try await session.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 2 * 1024 * 1024 else {
      throw SettingsError.invalid("无法检查清言更新，请稍后重试。")
    }
    return choose(try JSONDecoder().decode([QingTypeAppRelease].self, from: data))
  }
  static func download(_ update: QingTypeAppUpdate, progress: @escaping @Sendable (QingTypeTransferProgress) -> Void) async throws -> QingTypeDownloadedAsset {
    try await QingTypeDownloads.download(asset: update.asset, repository: repository, release: update.tag, limit: downloadLimit, progress: progress)
  }
}
