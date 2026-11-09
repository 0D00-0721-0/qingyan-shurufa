import Foundation

private actor HashGate {
  private var released = false
  private var continuation: CheckedContinuation<Void, Never>?
  func wait() async {
    if released { return }
    await withCheckedContinuation { continuation = $0 }
  }
  func release() {
    released = true; continuation?.resume(); continuation = nil
  }
}

private final class MetadataProtocol: URLProtocol {
  static let lock = NSLock()
  static var action: ((MetadataProtocol) -> Void)?
  static var started = false
  static var stopped = false
  static func configure(_ callback: @escaping (MetadataProtocol) -> Void) {
    lock.lock(); defer { lock.unlock() }
    action = callback; started = false; stopped = false
  }
  static func status() -> (Bool, Bool) {
    lock.lock(); defer { lock.unlock() }; return (started, stopped)
  }
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    Self.lock.lock(); Self.started = true; let action = Self.action; Self.lock.unlock()
    action?(self)
  }
  override func stopLoading() { Self.lock.lock(); Self.stopped = true; Self.lock.unlock() }
  func respond(_ status: Int, headers: [String: String] = [:], data: Data = Data("{\"tag_name\":\"LTS\",\"assets\":[]}".utf8)) {
    client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
  }
}

@main
struct MetadataRequestTests {
  static func main() async throws {
    var checks = 0
    func expect(_ condition: Bool, _ name: String) throws {
      guard condition else { throw SettingsError.invalid("FAIL: \(name)") }; checks += 1
    }
    let configuration = QingTypeDownloads.metadataConfiguration()
    try expect(configuration.timeoutIntervalForRequest == 10 && configuration.timeoutIntervalForResource == 15 && !configuration.waitsForConnectivity,
               "metadata has an overall 15-second limit, not only an idle timeout")
    configuration.protocolClasses = [MetadataProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    func release() async throws -> QingTypeRelease {
      try await QingTypeDownloads.release(repository: QingTypeWanxiang.repository, tag: "LTS", session: session)
    }
    MetadataProtocol.configure { $0.respond(200) }
    try expect(try await release().tag_name == "LTS", "valid metadata still loads through the bounded request")
    for (code, headers, expected) in [(403, ["X-RateLimit-Remaining": "0"], "限制"), (429, [:], "限制"), (500, [:], "无法读取")] {
      MetadataProtocol.configure { $0.respond(code, headers: headers) }
      var message = ""
      do { _ = try await release() } catch { message = error.localizedDescription }
      try expect(message.contains(expected), "HTTP \(code) reports a specific failure and never claims the model is current")
    }
    MetadataProtocol.configure { $0.client?.urlProtocol($0, didFailWithError: URLError(.timedOut)) }
    var timeoutMessage = ""
    do { _ = try await release() } catch { timeoutMessage = error.localizedDescription }
    try expect(timeoutMessage.contains("超时") && timeoutMessage.contains("15"), "timeout ends with a bounded, readable error")
    MetadataProtocol.configure { $0.respond(200, data: Data("invalid JSON".utf8)) }
    var rejected = false
    do { _ = try await release() } catch { rejected = true }
    try expect(rejected, "malformed metadata does not continue into a download")
    MetadataProtocol.configure { _ in } // Deliberately never finish the response.
    let pending = Task { try await release() }
    for _ in 0..<100 {
      if MetadataProtocol.status().0 { break }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    try expect(MetadataProtocol.status().0, "cancellation fixture reached an active request")
    let started = Date(); pending.cancel()
    var cancelled = false
    do { _ = try await pending.value }
    catch { cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled }
    try expect(cancelled && Date().timeIntervalSince(started) < 1, "cancel immediately ends an in-flight metadata request")
    MetadataProtocol.configure { $0.respond(200) }
    try expect(try await release().tag_name == "LTS", "a cancelled check does not poison the next attempt")

    let checkDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("qingtype-ice-metadata-\(UUID())")
    try FileManager.default.createDirectory(at: checkDirectory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: checkDirectory) }
    let checksum = String(repeating: "a", count: 64)
    let iceMetadata = Data("""
      {"tag_name":"nightly","assets":[{"name":"full.zip","size":1024,"digest":"sha256:\(checksum)",
      "updated_at":"2026-10-31T12:01:58Z","browser_download_url":"https://github.com/iDvel/rime-ice/releases/download/nightly/full.zip"}]}
      """.utf8)
    MetadataProtocol.configure { request in
      if request.request.url?.path == "/repos/iDvel/rime-ice/releases/latest" { request.respond(200, data: iceMetadata) }
      else { request.respond(500) }
    }
    let ice = try await QingTypeRimeIceUpdates.check(installed: nil, directory: checkDirectory, session: session)
    try expect(!ice.upToDate && ice.asset.size == 1024 && ice.sha256 == checksum && ice.updatedAt != nil,
               "Rime Ice check returns the exact downloadable asset, size, checksum and publication time")
    try expect(try FileManager.default.contentsOfDirectory(atPath: checkDirectory.path).isEmpty,
               "Rime Ice metadata check creates no resources or backup")

    let file = FileManager.default.temporaryDirectory.appendingPathComponent("qingtype-hash-cancel-\(UUID())")
    try Data("isolated hash cancellation fixture".utf8).write(to: file)
    defer { try? FileManager.default.removeItem(at: file) }
    let original = try QingTypeContent.digest(of: file)
    let gate = HashGate()
    let hashTask = Task.detached { await gate.wait(); return try QingTypeContent.digest(of: file, checkingCancellation: true) }
    hashTask.cancel(); await gate.release()
    var hashCancelled = false
    do { _ = try await hashTask.value } catch is CancellationError { hashCancelled = true }
    try expect(hashCancelled, "local model hashing also honors cancellation")
    let recoveryGate = HashGate()
    let recoveryHash = Task.detached { await recoveryGate.wait(); return try QingTypeContent.digest(of: file) }
    recoveryHash.cancel(); await recoveryGate.release()
    try expect(try await recoveryHash.value == original, "recovery hashes keep their existing non-interruptible behavior")
    print("PASS: \(checks) metadata deadline, rate-limit, cancellation and hash recovery checks")
  }
}
