import Foundation
import Yams

@main
struct SettingsSafetyTests {
  static func main() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("qingtype-settings-test-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    var checks = 0
    func expect(_ value: Bool, _ message: String) throws {
      guard value else { throw SettingsError.invalid("FAIL: \(message)") }
      checks += 1
    }
    func rejects(_ operation: () throws -> Void) throws {
      do { try operation() }
      catch { checks += 1; return }
      throw SettingsError.invalid("Expected a rejected write")
    }

    var settings = QingTypeSettings()
    settings.phrases = [.init(code: "jj", text: "继续加油")]
    try settings.save(to: root)
    let restored = try QingTypeSettings.load(from: root)
    try expect(restored == settings, "settings and Unicode phrases survive restart")

    let defaultsURL = root.appendingPathComponent("default.custom.yaml")
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_700_000_000)],
                                          ofItemAtPath: defaultsURL.path)
    let previousDate = try FileManager.default.attributesOfItem(atPath: defaultsURL.path)[.modificationDate] as? Date
    settings.phrases[0].text = "继续加油呀"
    try settings.save(to: root)
    let updatedDate = try FileManager.default.attributesOfItem(atPath: defaultsURL.path)[.modificationDate] as? Date
    try expect(previousDate != nil && updatedDate == previousDate, "a phrase edit preserves the timestamp of unchanged shared Rime defaults")
    let updatedPhrase = try String(contentsOf: root.appendingPathComponent("custom_phrase.txt"), encoding: .utf8)
    try expect(updatedPhrase.contains("继续加油呀\tjj\t"), "a phrase edit still writes the changed phrase table")

    for useShift in [true, false] {
      var configured = settings
      configured.useShift = useShift
      let files = try configured.generatedFiles()
      let object = try Yams.load(yaml: String(decoding: files["default.custom.yaml"] ?? Data(), as: UTF8.self)) as? [String: Any]
      let patch = object?["patch"] as? [String: Any]
      try expect(patch?["ascii_composer/switch_key/Caps_Lock"] as? String == "commit_code" &&
                 patch?["ascii_composer/switch_key/Shift_L"] as? String == (useShift ? "inline_ascii" : "noop") &&
                 patch?["ascii_composer/switch_key/Shift_R"] as? String == (useShift ? "inline_ascii" : "noop"),
                 "Caps Lock preserves raw input independently of the Shift preference")
    }

    let originalJSON = try Data(contentsOf: root.appendingPathComponent("settings.json"))
    settings.phrases.append(.init(code: "bad\ncode", text: "不能写入"))
    try rejects { try settings.save(to: root) }
    let unchanged = try Data(contentsOf: root.appendingPathComponent("settings.json"))
    try expect(originalJSON == unchanged, "invalid data leaves saved state intact")
    settings.phrases.removeLast()

    settings.phrases.append(.init(code: "jj", text: "重复编码"))
    try rejects { try settings.save(to: root) }
    settings.phrases.removeLast()

    let patchURL = root.appendingPathComponent("squirrel.custom.yaml")
    let handEdited = Data("patch:\n  style/font_point: 23\n".utf8)
    try handEdited.write(to: patchURL)
    settings.fontSize = 24
    try rejects { try settings.save(to: root) }
    let retained = try Data(contentsOf: patchURL)
    let retainedJSON = try Data(contentsOf: root.appendingPathComponent("settings.json"))
    try expect(retained == handEdited && retainedJSON == originalJSON,
               "manual configuration remains untouched and no partial settings commit occurs")

    try FileManager.default.removeItem(at: patchURL)
    try settings.save(to: root)
    let backups = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("backups"), includingPropertiesForKeys: nil)
    try expect(try backups.contains { try Data(contentsOf: $0.appendingPathComponent("settings.json")) == originalJSON },
               "previous configuration can be recovered from backup")
    try Data("broken JSON".utf8).write(to: root.appendingPathComponent("settings.json"))
    try rejects { _ = try QingTypeSettings.load(from: root) }
    try expect(QingTypePaths.userDirectory.lastPathComponent == "QingType", "dedicated user directory")
    print("PASS: \(checks) settings safety checks")
  }
}
