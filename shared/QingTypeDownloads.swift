import Foundation

struct QingTypeTransferProgress {
  var received: Int64
  var total: Int64
  var fraction: Double { total > 0 ? min(1, Double(received) / Double(total)) : 0 }
}

struct QingTypeRelease: Decodable {
  var tag_name: String
  var assets: [Asset]
  struct Asset: Decodable {
    var name: String
    var browser_download_url: URL
    var size: Int64
    var digest: String?
    var updated_at: String? = nil
    func validate(repository: String, limit: Int64) throws -> String {
      guard size > 0, size <= limit, browser_download_url.scheme == "https",
            browser_download_url.host == "github.com",
            browser_download_url.path.hasPrefix("/\(repository)/releases/download/"),
            let digest, digest.range(of: "^sha256:[a-f0-9]{64}$", options: .regularExpression) != nil else {
        throw SettingsError.invalid("官方资源缺少有效的大小或 SHA-256 校验信息，请稍后重试或更新清言。")
      }
      return String(digest.dropFirst(7))
    }
  }
}

struct QingTypeDownloadedAsset {
  var directory: URL
  var file: URL
  var sha256: String
  var release: String
  var repository: String
}

enum QingTypeDownloads {
  private final class ProgressDelegate: NSObject, URLSessionDownloadDelegate {
    let limit: Int64
    let progress: @Sendable (QingTypeTransferProgress) -> Void
    init(limit: Int64, progress: @escaping @Sendable (QingTypeTransferProgress) -> Void) { self.limit = limit; self.progress = progress }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
      if totalBytesWritten > limit || totalBytesExpectedToWrite > limit { downloadTask.cancel(); return }
      progress(.init(received: totalBytesWritten, total: totalBytesExpectedToWrite))
    }
  }

  static func metadataConfiguration() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 10
    configuration.timeoutIntervalForResource = 15
    configuration.waitsForConnectivity = false
    return configuration
  }

  static func release(repository: String, tag: String, session providedSession: URLSession? = nil) async throws -> QingTypeRelease {
    // Callers use an internal catalog; no user-controlled URLs or credentials.
    guard ["iDvel/rime-ice", "amzxyz/rime-wanxiang-data"].contains(repository),
          ["latest", "LTS"].contains(tag) else { throw SettingsError.invalid("未知的组件来源。") }
    let suffix = tag == "latest" ? "latest" : "tags/" + tag
    var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/\(suffix)")!)
    request.timeoutInterval = 10
    request.setValue("QingType", forHTTPHeaderField: "User-Agent")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    let session = providedSession ?? URLSession(configuration: metadataConfiguration())
    defer { if providedSession == nil { session.invalidateAndCancel() } }
    let data: Data
    let response: URLResponse
    do { (data, response) = try await session.data(for: request) }
    catch let error as URLError where error.code == .timedOut {
      throw SettingsError.invalid("检查官方更新超时，请稍后重试（最长等待 15 秒）。")
    }
    let http = response as? HTTPURLResponse
    if http?.statusCode == 429 || (http?.statusCode == 403 && http?.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0") {
      throw SettingsError.invalid("GitHub 暂时限制检查请求，请稍后再试。现有设置保持不变。")
    }
    guard http?.statusCode == 200, data.count < 2 * 1024 * 1024 else {
      throw SettingsError.invalid("无法读取官方组件信息，请检查网络后重试，也可以从本地文件导入。")
    }
    return try JSONDecoder().decode(QingTypeRelease.self, from: data)
  }

  static func download(repository: String, tag: String, filename: String, limit: Int64,
                       progress: @escaping @Sendable (QingTypeTransferProgress) -> Void = { _ in }) async throws -> QingTypeDownloadedAsset {
    let release = try await release(repository: repository, tag: tag)
    guard let asset = release.assets.first(where: { $0.name == filename }),
          filename == URL(fileURLWithPath: filename).lastPathComponent else { throw SettingsError.invalid("官方发行中没有找到所需组件。") }
    return try await download(asset: asset, repository: repository, release: release.tag_name, limit: limit, progress: progress)
  }

  static func validateDownload(_ asset: QingTypeRelease.Asset, repository: String, limit: Int64) throws -> String {
    guard ["iDvel/rime-ice", "amzxyz/rime-wanxiang-data", QingTypeAppUpdates.repository].contains(repository),
          asset.name == URL(fileURLWithPath: asset.name).lastPathComponent else { throw SettingsError.invalid("未知的下载来源。") }
    return try asset.validate(repository: repository, limit: limit)
  }

  static func download(asset: QingTypeRelease.Asset, repository: String, release: String, limit: Int64,
                       progress: @escaping @Sendable (QingTypeTransferProgress) -> Void = { _ in }) async throws -> QingTypeDownloadedAsset {
    let hash = try validateDownload(asset, repository: repository, limit: limit)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 1800
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    let delegate = ProgressDelegate(limit: asset.size, progress: progress)
    let (file, response) = try await session.download(from: asset.browser_download_url, delegate: delegate)
    defer { try? FileManager.default.removeItem(at: file) }
    try Task.checkCancellation()
    guard (response as? HTTPURLResponse)?.statusCode == 200,
          try file.resourceValues(forKeys: [.fileSizeKey]).fileSize == Int(asset.size),
          try QingTypeContent.digest(of: file) == hash else {
      throw SettingsError.invalid("下载的组件与官方大小或 SHA-256 不符，已停止安装，请重试。")
    }
    try Task.checkCancellation()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("qingtype-download-\(UUID())")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    do {
      let target = directory.appendingPathComponent(asset.name)
      try FileManager.default.moveItem(at: file, to: target)
      return .init(directory: directory, file: target, sha256: hash, release: release, repository: repository)
    } catch { try? FileManager.default.removeItem(at: directory); throw error }
  }
}

enum QingTypeWanxiang {
  static let repository = "amzxyz/rime-wanxiang-data"
  static let downloadLimit: Int64 = 1024 * 1024 * 1024
  struct Update {
    var release: String
    var asset: QingTypeRelease.Asset
    var installed: GrammarAsset?
  }
  static func filename(schema: String) -> String { "wanxiang-lts-zh-" + (schema == "luna_pinyin" ? "hant" : "hans") + ".gram" }
  static func checkUpdate(schema: String, models: [GrammarAsset], directory: URL) async throws -> Update {
    let release = try await QingTypeDownloads.release(repository: repository, tag: "LTS")
    try Task.checkCancellation()
    let worker = Task.detached {
      try inspect(release: release, schema: schema, models: models, directory: directory)
    }
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await worker.value
    } onCancel: { worker.cancel() }
  }

  // Inspect the same metadata that will be used for the download. LTS is a
  // mutable upstream tag; fetching it again could select a different asset.
  static func inspect(release: QingTypeRelease, schema: String, models: [GrammarAsset], directory: URL) throws -> Update {
    try QingTypePaths.checkDirectory(directory)
    guard release.tag_name == "LTS",
          let asset = release.assets.first(where: { $0.name == filename(schema: schema) }) else {
      throw SettingsError.invalid("官方发行中没有找到当前输入方案所需的万象模型。")
    }
    let hash = try asset.validate(repository: repository, limit: downloadLimit)
    var result = Update(release: release.tag_name, asset: asset, installed: nil)
    guard let model = models.first(where: { $0.id == hash && $0.sha256 == hash && $0.language == "qingtype_model_" + hash }) else { return result }
    let file = directory.appendingPathComponent("qingtype_model_\(hash).gram")
    guard FileManager.default.fileExists(atPath: file.path) else { return result }
    let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true else {
      throw SettingsError.invalid("本地万象模型未通过文件校验，已停止更新检查，现有文件未改动。")
    }
    guard Int64(values.fileSize ?? 0) == asset.size,
          try QingTypeContent.digest(of: file, checkingCancellation: true) == hash else { return result }
    result.installed = model
    return result
  }

  static func download(_ update: Update, progress: @escaping @Sendable (QingTypeTransferProgress) -> Void = { _ in }) async throws -> QingTypeDownloadedAsset {
    try await QingTypeDownloads.download(asset: update.asset, repository: repository, release: update.release, limit: downloadLimit, progress: progress)
  }

  static func download(schema: String, progress: @escaping @Sendable (QingTypeTransferProgress) -> Void = { _ in }) async throws -> QingTypeDownloadedAsset {
    try await QingTypeDownloads.download(repository: repository, tag: "LTS", filename: filename(schema: schema), limit: downloadLimit, progress: progress)
  }
}
