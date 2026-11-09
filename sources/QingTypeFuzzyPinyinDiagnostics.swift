import Foundation
import Yams

enum QingTypeFuzzyPinyinDiagnostics {
  private struct Pair {
    var rule: FuzzyPinyinRule
    var left: String
    var right: String
    var leftKeys: String
    var rightKeys: String
    var leftText: String
    var rightText: String
  }
  // Characters are unchanged by simplified/traditional conversion.
  private static let pairs: [Pair] = [
    .init(rule: .zZh, left: "za", right: "zha", leftKeys: "za", rightKeys: "va", leftText: "匝", rightText: "扎"),
    .init(rule: .cCh, left: "ca", right: "cha", leftKeys: "ca", rightKeys: "ia", leftText: "擦", rightText: "叉"),
    .init(rule: .sSh, left: "sa", right: "sha", leftKeys: "sa", rightKeys: "ua", leftText: "撒", rightText: "沙"),
    .init(rule: .nL, left: "na", right: "la", leftKeys: "na", rightKeys: "la", leftText: "拿", rightText: "拉"),
    .init(rule: .fH, left: "fa", right: "ha", leftKeys: "fa", rightKeys: "ha", leftText: "法", rightText: "哈"),
    .init(rule: .anAng, left: "ban", right: "bang", leftKeys: "bj", rightKeys: "bh", leftText: "班", rightText: "邦"),
    .init(rule: .enEng, left: "ben", right: "beng", leftKeys: "bf", rightKeys: "bg", leftText: "本", rightText: "崩"),
    .init(rule: .inIng, left: "bin", right: "bing", leftKeys: "bb", rightKeys: "bk", leftText: "彬", rightText: "冰"),
    .init(rule: .ianIang, left: "lian", right: "liang", leftKeys: "lm", rightKeys: "ll", leftText: "廉", rightText: "良"),
    .init(rule: .uanUang, left: "guan", right: "guang", leftKeys: "gr", rightKeys: "gl", leftText: "官", rightText: "光")
  ]

  static func run(api: RimeApi_stdbool, package: URL?) -> Bool {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("qingtype-fuzzy-engine-\(UUID())")
    var initialized = false
    var session: RimeSessionId = 0
    var checks = 0
    func stop() {
      if session != 0 { _ = api.destroy_session(session); session = 0 }
      if initialized { api.finalize(); initialized = false }
    }
    defer { stop(); try? FileManager.default.removeItem(at: root) }
    do {
      func expect(_ value: Bool, _ name: String) throws {
        guard value else { throw SettingsError.invalid("FAIL: \(name)") }
        checks += 1; print("PASS: \(name)")
      }
      var profiles = ["luna_pinyin_simp", "luna_pinyin", "qingtype_double_pinyin"]
      if package != nil { profiles.append("rime_ice") }
      for schema in profiles {
        let directory = root.appendingPathComponent(schema)
        let isDouble = schema == "qingtype_double_pinyin"
        var settings = QingTypeSettings()
        settings.schema = schema
        settings.phrases = [.init(code: "qqing", text: "清言快捷短语")]
        settings.personalWords = pairs.flatMap { pair in
          [PersonalWord(text: pair.leftText + "清言", pinyin: pair.left + " qing yan", weight: 50000),
           PersonalWord(text: pair.rightText + "清言", pinyin: pair.right + " qing yan", weight: 50000)]
        } + [.init(text: "拿沙班清言", pinyin: "na sha ban qing yan", weight: 50000),
             .init(text: "清言模糊甲", pinyin: "qing yan mo hu jia", weight: 10000),
             .init(text: "清言模糊乙", pinyin: "qing yan mo hu jia", weight: 1)]
        if let package, schema == "rime_ice" {
          settings.rimeIce = try QingTypeRimeIce.install(from: package, into: directory, provenance: "isolated fuzzy test")
        }
        if schema != "luna_pinyin", let path = ProcessInfo.processInfo.environment["QINGTYPE_FUZZY_TEST_MODEL"] {
          let model = try QingTypeContent.importGrammar(from: URL(fileURLWithPath: path), into: directory)
          settings.models = [model]; settings.activeModelID = model.id
        }
        func start() throws {
          var traits = RimeTraits.rimeStructInit()
          traits.setCString(Bundle.main.sharedSupportPath!, to: \.shared_data_dir)
          traits.setCString(directory.path, to: \.user_data_dir)
          traits.setCString(directory.path, to: \.log_dir)
          traits.setCString("rime.qingtype.fuzzy-test", to: \.app_name)
          api.setup(&traits); api.initialize(nil); initialized = true
          session = api.create_session()
          try expect(session != 0 && api.select_schema(session, schema), "\(schema): isolated engine starts")
        }
        func deploy() throws -> [String] {
          stop(); try settings.save(to: directory)
          let report = try QingTypeMaintenance.deploy(api: api, directory: directory)
          try expect(report.success, "\(schema): fuzzy configuration deploys")
          let yaml = try Yams.load(yaml: String(contentsOf: directory.appendingPathComponent("build/\(schema).schema.yaml"), encoding: .utf8)) as! [String: Any]
          let translator = yaml["translator"] as! [String: Any]
          try expect(translator["user_dict"] as? String == (schema == "rime_ice" ? "rime_ice" : "qingtype_main"), "\(schema): learning database identity is unchanged")
          if let model = settings.activeModel {
            let grammar = yaml["grammar"] as? [String: Any]
            try expect(grammar?["language"] as? String == model.language && grammar?["collocation_prism"] as? String == "qingtype_" + schema + ".prism",
                       "\(schema): fuzzy deployment retains the selected model and matching prism")
          }
          let algebra = (yaml["speller"] as? [String: Any])?["algebra"] as? [String] ?? []
          try start()
          return algebra
        }
        func candidates(_ input: String) -> [QingTypeCandidate] {
          api.clear_composition(session)
          for key in input.utf8 { _ = api.process_key(session, Int32(key), 0) }
          return QingTypeCandidateSource.read(api: api, session: session, startingAt: 0, limit: 256)
        }
        func code(_ pair: Pair, right: Bool) -> String {
          (isDouble ? (right ? pair.rightKeys : pair.leftKeys) : (right ? pair.right : pair.left)) + (isDouble ? "qkyj" : "qingyan")
        }
        func checkPairs(enabled: Set<FuzzyPinyinRule>) throws {
          for pair in pairs {
            let left = candidates(code(pair, right: false)).map(\.text)
            let right = candidates(code(pair, right: true)).map(\.text)
            try expect(left.contains(pair.leftText + "清言") && right.contains(pair.rightText + "清言"), "\(schema): \(pair.rule.rawValue) retains both exact spellings")
            try expect(left.contains(pair.rightText + "清言") == enabled.contains(pair.rule) && right.contains(pair.leftText + "清言") == enabled.contains(pair.rule),
                       "\(schema): \(pair.rule.rawValue) matches both directions only when enabled")
          }
        }
        func records() throws -> [String] {
          stop()
          return try QingTypeLearningMaintenance.backup(api: api, directory: directory).snapshots.flatMap { snapshot in
            String(decoding: snapshot.data, as: UTF8.self).split(separator: "\n").filter { !$0.hasPrefix("#") }.map { snapshot.name + ":" + $0 }
          }.sorted()
        }
        let originalAlgebra = try deploy()
        try expect(!originalAlgebra.isEmpty, "\(schema): original algebra is present")
        try checkPairs(enabled: [])
        let learningCode = isDouble ? "qkyjmohujx" : "qingyanmohujia"
        for _ in 0..<12 {
          let learned = candidates(learningCode).first { $0.text == "清言模糊乙" }
          guard let learned, api.select_candidate(session, learned.index) else { throw SettingsError.invalid("FAIL: fuzzy fixture learning selection") }
          var commit = RimeCommit.rimeStructInit()
          if api.get_commit(session, &commit) { _ = api.free_commit(&commit) }
        }
        try expect(candidates(learningCode).first?.text == "清言模糊乙", "\(schema): seed real learned ranking before fuzzy changes")
        let learnedBefore = try records()
        try expect(!learnedBefore.isEmpty, "\(schema): learned database contains actual records")
        settings.fuzzyPinyin.enabled = true
        settings.fuzzyPinyin.rules = Set(FuzzyPinyinRule.allCases)
        let enabledAlgebra = try deploy()
        try expect(enabledAlgebra == settings.fuzzyPinyin.algebra + originalAlgebra, "\(schema): rules precede all original abbreviation/correction/key-mapping rules")
        try checkPairs(enabled: settings.fuzzyPinyin.rules)
        try expect(candidates("na").contains { $0.text == "拉" } && candidates("la").contains { $0.text == "拿" },
                   "\(schema): fuzzy spellings also produce single-character candidates")
        try expect(candidates(isDouble ? "lasabhqkyj" : "lasabangqingyan").contains { $0.text == "拿沙班清言" }, "\(schema): combined initial and final fuzzy matches compose a phrase")
        if !isDouble {
          try expect(candidates("lqy").contains { $0.text == "拿清言" }, "\(schema): fuzzy initials also work with abbreviation")
        }
        try expect(candidates(isDouble ? "nihc" : "nihao").contains { $0.text == "你好" } && candidates("qqing").contains { $0.text == "清言快捷短语" }, "\(schema): ordinary input and quick phrases remain available")
        if schema == "rime_ice" {
          try expect(candidates("rq").contains { $0.text.range(of: "^20[0-9]{2}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil } && candidates("hello").contains { $0.text.lowercased() == "hello" }, "Rime Ice: fuzzy pinyin preserves Lua date and English dependencies")
        }
        try expect(candidates(learningCode).first?.text == "清言模糊乙", "\(schema): fuzzy enable preserves learned ranking")
        stop(); try start()
        try expect(candidates(code(pairs[3], right: true)).contains { $0.text == "拿清言" }, "\(schema): fuzzy matching survives engine restart")
        settings.fuzzyPinyin.enabled = false
        let disabledAlgebra = try deploy()
        try expect(disabledAlgebra == originalAlgebra, "\(schema): immediate master off restores original compiled algebra")
        try checkPairs(enabled: [])
        try expect(try QingTypeSettings.load(from: directory).fuzzyPinyin.rules.count == pairs.count, "\(schema): master off retains all selected groups")
        try expect(candidates(learningCode).first?.text == "清言模糊乙", "\(schema): fuzzy disable preserves learned ranking")
        try expect(try records() == learnedBefore, "\(schema): toggling fuzzy leaves actual learned words and weights intact")
        settings.fuzzyPinyin.enabled = true; settings.fuzzyPinyin.rules = [.anAng]
        _ = try deploy()
        try checkPairs(enabled: [.anAng])
        let fuzzyWord = candidates(code(pairs[5], right: true)).first { $0.text == "班清言" }
        try expect(fuzzyWord.map { api.select_candidate(session, $0.index) } == true,
                   "\(schema): a candidate found through a fuzzy spelling can be selected")
        var commit = RimeCommit.rimeStructInit()
        let gotCommit = api.get_commit(session, &commit)
        let committed = commit.text.map { String(cString: $0) }
        if gotCommit { _ = api.free_commit(&commit) }
        try expect(gotCommit && committed == "班清言", "\(schema): fuzzy selection commits the exact intended text")
        stop()
      }
      print("PASS: \(checks) fuzzy pinyin real-engine checks across \(profiles.count) schemas; isolated data only")
      return true
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
  }
}
