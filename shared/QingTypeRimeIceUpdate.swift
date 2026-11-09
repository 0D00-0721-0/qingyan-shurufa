import Foundation

struct QingTypeRimeIceUpdate {
  var release: String
  var asset: QingTypeRelease.Asset
  var sha256: String
  var installedVersion: String?
  var upToDate: Bool

  var updatedAt: Date? {
    asset.updated_at.flatMap { ISO8601DateFormatter().date(from: $0) }
  }
}

/// Checks the official package before downloading it. The installed archive
/// checksum is the only reliable identity: upstream moves the release tag.
enum QingTypeRimeIceUpdates {
  static let repository = "iDvel/rime-ice"
  static let filename = "full.zip"
  static let downloadLimit: Int64 = 128 * 1024 * 1024

  static func check(installed: RimeIceAsset?, directory: URL, session: URLSession? = nil) async throws -> QingTypeRimeIceUpdate {
    let release = try await QingTypeDownloads.release(repository: repository, tag: "latest", session: session)
    try Task.checkCancellation()
    let worker = Task.detached(priority: .utility) {
      try inspect(release: release, installed: installed, directory: directory)
    }
    return try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
  }

  static func inspect(release: QingTypeRelease, installed: RimeIceAsset?, directory: URL) throws -> QingTypeRimeIceUpdate {
    guard let asset = release.assets.first(where: { $0.name == filename }) else {
      throw SettingsError.invalid("官方发行中没有找到雾凇完整包。")
    }
    let sha256 = try asset.validate(repository: repository, limit: downloadLimit)
    if let installed, installed.archiveSHA256 == sha256 {
      try QingTypeRimeIce.verifyInstalled(installed, in: directory)
    }
    return .init(release: release.tag_name, asset: asset, sha256: sha256,
                 installedVersion: installed?.version,
                 upToDate: installed?.archiveSHA256 == sha256)
  }
}
