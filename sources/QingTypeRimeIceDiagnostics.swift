import Foundation
import Yams

enum QingTypeRimeIceDiagnostics {
  static func run(api: RimeApi_stdbool, package: URL) -> Bool {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("qingtype-ice-engine-\(UUID())")
    var initialized = false
    var session: RimeSessionId = 0
    func stop() {
      if session != 0 { _ = api.destroy_session(session); session = 0 }
      if initialized { api.finalize(); initialized = false }
    }
    defer { stop(); try? FileManager.default.removeItem(at: directory) }
    do {
      var checks = 0
      func expect(_ condition: Bool, _ name: String) throws {
        guard condition else { throw SettingsError.invalid("FAIL: \(name)") }
        checks += 1; print("PASS: \(name)")
      }
      var settings = QingTypeSettings()
      settings.rimeIce = try QingTypeRimeIce.install(from: package, into: directory, provenance: "isolated test")
      settings.schema = "rime_ice"
      settings.pageSize = 7
      settings.useShift = false
      settings.personalWords = [.init(text: "清言星河样词", pinyin: "qing yan xing he yang ci", weight: 50000)]
      settings.phrases = [.init(code: "qqing", text: "清言快捷短语")]
      if let path = ProcessInfo.processInfo.environment["QINGTYPE_RIME_ICE_TEST_MODEL"] {
        let model = try QingTypeContent.importGrammar(from: URL(fileURLWithPath: path), into: directory)
        settings.models = [model]; settings.activeModelID = model.id
      }
      func save() throws {
        try settings.save(to: directory)
        let path = directory.appendingPathComponent("rime_ice.custom.yaml")
        var object = try Yams.load(yaml: String(contentsOf: path, encoding: .utf8)) as! [String: Any]
        var patch = object["patch"] as! [String: Any]
        patch["translator/enable_user_dict"] = false
        object["patch"] = patch
        try (QingTypeSettings.managedHeader + Yams.dump(object: object)).write(to: path, atomically: true, encoding: .utf8)
      }
      func deploy() throws {
        stop()
        let report = try QingTypeMaintenance.deploy(api: api, directory: directory)
        try expect(report.success, "full Rime Ice package compiles with all dependencies")
        api.initialize(nil); initialized = true
        session = api.create_session()
        try expect(session != 0 && api.select_schema(session, "rime_ice"), "Rime Ice schema starts in an isolated real engine")
      }
      func candidates(_ input: String) -> [QingTypeCandidate] {
        _ = api.process_key(session, Int32(XK_Escape), 0)
        for key in input.utf8 { _ = api.process_key(session, Int32(key), 0) }
        return QingTypeCandidateSource.read(api: api, session: session, startingAt: 0, limit: 128)
      }
      try save(); try deploy()
      try expect(candidates("nihao").contains { $0.text == "你好" }, "official Chinese dictionary produces nihao candidates")
      var context = RimeContext_stdbool.rimeStructInit()
      let gotContext = api.get_context(session, &context)
      let pageSize = context.menu.page_size
      if gotContext { _ = api.free_context(&context) }
      try expect(gotContext && pageSize == 7, "QingType candidate page size survives package-default isolation")
      let personal = candidates("qingyanxingheyangci")
      try expect(personal.contains { $0.text == "清言星河样词" }, "personal entries join the actual Rime Ice main dictionary")
      try expect(api.select_candidate(session, personal.first { $0.text == "清言星河样词" }!.index), "personal Rime Ice candidate can be selected")
      var commit = RimeCommit.rimeStructInit()
      let got = api.get_commit(session, &commit)
      let text = commit.text.map { String(cString: $0) }
      if got { _ = api.free_commit(&commit) }
      try expect(got && text == "清言星河样词", "personal Rime Ice selection commits exact text")
      checks += try QingTypeInputModeDiagnostics.checkCapsLock(api: api, session: session, profile: "Rime Ice with Shift disabled")
      checks += try QingTypeInputModeDiagnostics.checkEditingKeys(api: api, session: session, profile: "Rime Ice", useShift: settings.useShift)
      checks += try QingTypeInputModeDiagnostics.checkCandidatePunctuation(api: api, session: session, profile: "Rime Ice", settings: settings)
      try expect(candidates("hello").contains { $0.text.lowercased() == "hello" }, "English dependency is loaded")
      let dates = candidates("rq").map(\.text)
      try expect(dates.contains { $0.range(of: "^20[0-9]{2}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil }, "Lua date translator executes")
      try expect(candidates("nl").contains { $0.text.contains("年") && $0.text.contains("月") }, "Lua lunar translator loads its static database")
      try expect(candidates("qqing").contains { $0.text == "清言快捷短语" }, "existing quick phrases work with Rime Ice")
      stop()
      api.initialize(nil); initialized = true; session = api.create_session()
      _ = api.select_schema(session, "rime_ice")
      try expect(candidates("qingyanxingheyangci").contains { $0.text == "清言星河样词" }, "personal entries remain after engine restart")
      stop()
      settings.personalWords = []
      try save(); try deploy()
      try expect(!candidates("qingyanxingheyangci").contains { $0.text == "清言星河样词" }, "removing the fixed personal source works after Rime Ice redeployment")
      let compiled = try Yams.load(yaml: String(contentsOf: directory.appendingPathComponent("build/rime_ice.schema.yaml"), encoding: .utf8)) as! [String: Any]
      let translator = compiled["translator"] as? [String: Any]
      try expect(translator?["user_dict"] as? String == "rime_ice", "Rime Ice learning database identity is stable")
      if let model = settings.activeModel {
        try expect((compiled["grammar"] as? [String: Any])?["language"] as? String == model.language, "selected local language model is preserved in Rime Ice")
      }
      print("PASS: \(checks) Rime Ice engine integration checks; actual application typing remains manual acceptance")
      return true
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
  }
}
