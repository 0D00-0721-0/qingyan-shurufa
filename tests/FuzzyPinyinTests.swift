import Foundation
import Yams

@main
struct FuzzyPinyinTests {
  static func main() async throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent("qingtype-fuzzy-settings-\(UUID())")
    defer { try? manager.removeItem(at: root) }
    var checks = 0
    func expect(_ condition: @autoclosure () throws -> Bool, _ name: String) throws {
      guard try condition() else { throw SettingsError.invalid("FAIL: \(name)") }
      checks += 1
    }
    func patch(_ files: [String: Data], _ schema: String) throws -> [String: Any] {
      let yaml = try Yams.load(yaml: String(decoding: files[schema + ".custom.yaml"]!, as: UTF8.self)) as! [String: Any]
      return yaml["patch"] as! [String: Any]
    }
    let legacy = try JSONDecoder().decode(QingTypeSettings.self, from: Data("{\"fontSize\":21}".utf8))
    try expect(!legacy.fuzzyPinyin.enabled && legacy.fuzzyPinyin.rules.isEmpty && legacy.fontSize == 21,
               "old settings migrate with fuzzy pinyin disabled")
    let partial = try JSONDecoder().decode(QingTypeSettings.self, from: Data("{\"fuzzyPinyin\":{}}".utf8))
    try expect(partial.fuzzyPinyin == QingTypeFuzzyPinyin(), "partial fuzzy preferences have safe defaults")
    do {
      _ = try JSONDecoder().decode(QingTypeSettings.self, from: Data("{\"fuzzyPinyin\":{\"rules\":[\"unknown\"]}}".utf8))
      throw SettingsError.invalid("FAIL: unknown fuzzy rule accepted")
    } catch is DecodingError { checks += 1 }

    var settings = QingTypeSettings()
    let defaults = try settings.generatedFiles()
    settings.fuzzyPinyin.rules = Set(FuzzyPinyinRule.allCases)
    try expect(settings.fuzzyPinyin.algebra.isEmpty, "selected rules are inactive while master switch is off")
    for (name, bytes) in defaults where name != "settings.json" {
      try expect(try settings.generatedFiles()[name] == bytes, "disabled fuzzy pinyin preserves \(name)")
    }
    settings.fuzzyPinyin.enabled = true
    let enabled = try settings.generatedFiles()
    for schema in ["luna_pinyin_simp", "luna_pinyin", "qingtype_double_pinyin"] {
      let value = try patch(enabled, schema)
      let inserted = value.keys.filter { $0.hasPrefix("speller/algebra/") }.sorted().compactMap { value[$0] as? String }
      try expect(inserted == (schema == "luna_pinyin_simp" ? [] : settings.fuzzyPinyin.algebra),
                 "\(schema) inserts rules once, allowing simplified pinyin to inherit its parent patch")
      try expect(value["translator/user_dict"] as? String == "qingtype_main" && value["translator/prism"] as? String == "qingtype_" + schema,
                 "\(schema) keeps database and prism identity")
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    var reverseOrder = QingTypeFuzzyPinyin()
    reverseOrder.enabled = true
    for rule in FuzzyPinyinRule.allCases.reversed() { reverseOrder.rules.insert(rule) }
    try expect(try encoder.encode(reverseOrder) == encoder.encode(settings.fuzzyPinyin), "selection insertion order does not change encoded settings")

    // These overlaps are easy to miss with suffix-only an/ang rules.
    func variants(_ input: String, _ rules: [String]) throws -> Set<String> {
      var result: Set<String> = [input]
      for rule in rules {
        let parts = rule.split(separator: "/", omittingEmptySubsequences: false)
        let regex = try NSRegularExpression(pattern: String(parts[1]))
        for spelling in Array(result) {
          result.insert(regex.stringByReplacingMatches(in: spelling, range: NSRange(spelling.startIndex..., in: spelling), withTemplate: String(parts[2])))
        }
      }
      return result
    }
    try expect(try variants("ban", FuzzyPinyinRule.anAng.algebra).contains("bang") && variants("bang", FuzzyPinyinRule.anAng.algebra).contains("ban"), "an/ang works in both directions")
    for input in ["lian", "liang", "guan", "guang"] {
      try expect(try variants(input, FuzzyPinyinRule.anAng.algebra) == [input], "an/ang does not enable a different final: \(input)")
    }
    for rule in FuzzyPinyinRule.allCases {
      var one = QingTypeFuzzyPinyin()
      one.enabled = true; one.rules = [rule]
      try expect(one.algebra.count == 2 && one.schemaPatch.count == 2, "\(rule.rawValue) can be enabled independently")
    }

    settings.personalWords = [.init(text: "清言测试", pinyin: "qing yan ce shi", weight: 100)]
    try settings.save(to: root)
    try expect(try QingTypeSettings.load(from: root) == settings, "master switch and all selections survive save/reload")
    let sentinelURL = root.appendingPathComponent("qingtype_main.userdb/CURRENT")
    try manager.createDirectory(at: sentinelURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let sentinel = Data("isolated-learning-sentinel".utf8)
    try sentinel.write(to: sentinelURL)
    let before = try settings.generatedFiles()
    var draft = settings
    draft.fuzzyPinyin.enabled = false
    var calls = 0
    do {
      _ = try await QingTypeConfigurationApply.apply(draft, to: root) {
        calls += 1
        return .init(success: calls > 1, settingsHash: "fixture", schema: settings.schema, dictionaryCount: 0,
                     message: "injected fuzzy deployment failure", logDirectory: root.path)
      }
      throw SettingsError.invalid("FAIL: unsuccessful deploy accepted")
    } catch let error as QingTypeApplyError {
      try expect(error.configurationRestored && error.recoveryVerified && calls == 2, "failed fuzzy deployment restores and verifies prior settings")
    }
    try expect(try before.allSatisfy { try Data(contentsOf: root.appendingPathComponent($0.key)) == $0.value }, "fuzzy rollback restores all generated files")
    try expect(try Data(contentsOf: sentinelURL) == sentinel, "fuzzy save/rollback preserves learning data")
    try draft.save(to: root)
    let disabled = try QingTypeSettings.load(from: root)
    try expect(!disabled.fuzzyPinyin.enabled && disabled.fuzzyPinyin.rules == settings.fuzzyPinyin.rules, "master off preserves selections after restart")
    let manualURL = root.appendingPathComponent("luna_pinyin_simp.custom.yaml")
    let manual = Data("patch:\n  speller/algebra: []\n".utf8)
    try manual.write(to: manualURL)
    var rejected = false
    do { try settings.save(to: root) } catch { rejected = true }
    try expect(rejected && (try Data(contentsOf: manualURL)) == manual && (try QingTypeSettings.load(from: root)) == disabled,
               "fuzzy settings cannot overwrite a hand-maintained schema patch")
    print("PASS: \(checks) fuzzy pinyin settings, migration, rule independence and recovery checks")
  }
}
