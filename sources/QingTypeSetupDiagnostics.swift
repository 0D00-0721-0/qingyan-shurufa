import Foundation
import Yams

enum QingTypeSetupDiagnostics {
  static func run(api: RimeApi_stdbool) -> Bool {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("qingtype-factory-\(UUID())")
    var initialized = false
    var session: RimeSessionId = 0
    func stop() {
      if session != 0 { _ = api.destroy_session(session); session = 0 }
      if initialized { api.finalize(); initialized = false }
    }
    defer { stop(); try? FileManager.default.removeItem(at: root) }
    do {
      var checks = 0
      func expect(_ condition: Bool, _ name: String) throws {
        guard condition else { throw SettingsError.invalid("FAIL: \(name)") }; checks += 1; print("PASS: \(name)")
      }
      let settings = QingTypeSettings()
      try settings.save(to: root)
      let report = try QingTypeMaintenance.deploy(api: api, directory: root)
      try expect(report.success && report.modelLanguage == nil, "factory profile deploys from bundled resources without optional downloads")
      api.initialize(nil); initialized = true
      session = api.create_session()
      try expect(session != 0 && api.select_schema(session, settings.schema), "factory simplified pinyin starts")
      for key in "nihao".utf8 { _ = api.process_key(session, Int32(key), 0) }
      let candidates = QingTypeCandidateSource.read(api: api, session: session, startingAt: 0, limit: 64)
      try expect(candidates.contains { $0.text == "你好" }, "factory nihao produces 你好 without Rime Ice or Wanxiang")
      try expect(api.select_candidate(session, candidates.first { $0.text == "你好" }!.index), "factory candidate can be selected")
      var commit = RimeCommit.rimeStructInit()
      let got = api.get_commit(session, &commit)
      let text = commit.text.map { String(cString: $0) }
      if got { _ = api.free_commit(&commit) }
      try expect(got && text == "你好", "factory selection commits exact Chinese text")
      checks += try QingTypeInputModeDiagnostics.checkCapsLock(api: api, session: session, profile: "factory")
      checks += try QingTypeInputModeDiagnostics.checkEditingKeys(api: api, session: session, profile: "factory", useShift: settings.useShift)
      checks += try QingTypeInputModeDiagnostics.checkCandidatePunctuation(api: api, session: session, profile: "factory", settings: settings)
      let saved = try QingTypeSettings.load(from: root)
      try expect(saved.rimeIce == nil && saved.models.isEmpty && saved.dictionaries.isEmpty && saved.useSystemCandidates,
                 "first use leaves optional components absent and native candidates enabled")
      stop()
      // Exercise the actual deployment entry point with a synthetic model in the isolated profile.
      let fixture = root.appendingPathComponent("fixture.gram")
      var fixtureBytes = Data(repeating: 0x61, count: 2048)
      fixtureBytes.replaceSubrange(0..<17, with: Data("Rime::Grammar/1.0".utf8))
      fixtureBytes.replaceSubrange(36..<44, with: [1, 0, 0, 0, 4, 0, 0, 0])
      try fixtureBytes.write(to: fixture)
      let fixtureModel = try QingTypeContent.importGrammar(from: fixture, into: root)
      var withModel = settings
      withModel.models = [fixtureModel]; withModel.activeModelID = fixtureModel.id
      try withModel.save(to: root)
      let config = root.appendingPathComponent("settings.json")
      let compiledSchema = root.appendingPathComponent("build/\(settings.schema).schema.yaml")
      let savedConfig = try Data(contentsOf: config)
      let compiledBefore = try Data(contentsOf: compiledSchema)
      try Data("corrupted model".utf8).write(to: root.appendingPathComponent(fixtureModel.language + ".gram"))
      var modelRejected = false
      do { _ = try QingTypeMaintenance.deploy(api: api, directory: root) }
      catch { modelRejected = error.localizedDescription.contains("模型校验失败") }
      try expect(modelRejected, "deployment rejects a model corrupted after configuration was saved")
      let configAfter = try Data(contentsOf: config)
      let compiledAfter = try Data(contentsOf: compiledSchema)
      try expect(configAfter == savedConfig && compiledAfter == compiledBefore,
                 "model verification fails before altering settings or compiled schema")
      guard var compiled = try Yams.load(yaml: String(decoding: compiledBefore, as: UTF8.self)) as? [String: Any] else {
        throw SettingsError.invalid("fixture schema is invalid")
      }
      compiled["grammar"] = ["language": fixtureModel.language, "collocation_prism": "qingtype_luna_pinyin_simp.prism"]
      let compiledWithModel = Data((try Yams.dump(object: compiled)).utf8)
      try compiledWithModel.write(to: compiledSchema, options: .atomic)
      let fallback = try QingTypeRuntimeModel.prepare(in: root)
      guard let stage = fallback.stagingDirectory else { throw SettingsError.invalid("missing model fallback") }
      defer { try? FileManager.default.removeItem(at: stage.deletingLastPathComponent()) }
      let runtimeDelegate = SquirrelApplicationDelegate()
      defer { runtimeDelegate.shutdownRime() }
      try expect(runtimeDelegate.startRime(fullCheck: false, directory: root, logDirectory: root),
                 "normal startup entry accepts a safe model fallback")
      session = api.create_session()
      try expect(session != 0 && api.select_schema(session, settings.schema), "fallback starts the real engine with an isolated staging directory")
      for key in "nihao".utf8 { _ = api.process_key(session, Int32(key), 0) }
      try expect(QingTypeCandidateSource.read(api: api, session: session, startingAt: 0, limit: 64).contains { $0.text == "你好" },
                 "fallback still produces Chinese candidates without the damaged model")
      var schemaConfig = RimeConfig()
      let opened = api.schema_open(settings.schema, &schemaConfig)
      let language = opened ? api.config_get_cstring(&schemaConfig, "grammar/language").map { String(cString: $0) } : nil
      if opened { _ = api.config_close(&schemaConfig) }
      try expect(opened && (language == nil || language == ""), "fallback engine schema does not reference the damaged model")
      try expect(QingTypeRuntimeModel.readStatus(in: root)?.message != nil, "fallback records an actionable startup warning")
      _ = api.destroy_session(session); session = 0
      runtimeDelegate.shutdownRime()
      try expect(runtimeDelegate.startRime(fullCheck: true, directory: root, logDirectory: root),
                 "reload also uses the safe fallback when the model is damaged")
      var reloadedConfig = RimeConfig()
      let reloaded = api.schema_open(settings.schema, &reloadedConfig)
      let reloadedLanguage = reloaded ? api.config_get_cstring(&reloadedConfig, "grammar/language").map { String(cString: $0) } : nil
      if reloaded { _ = api.config_close(&reloadedConfig) }
      try expect(reloaded && (reloadedLanguage == nil || reloadedLanguage == ""), "reload does not recompile the damaged model into the fallback")
      runtimeDelegate.shutdownRime()
      let fallbackSettings = try Data(contentsOf: config)
      let fallbackSchema = try Data(contentsOf: compiledSchema)
      try expect(fallbackSettings == savedConfig && fallbackSchema == compiledWithModel,
                 "fallback leaves the saved configuration and original compiled schema intact")
      try compiledBefore.write(to: compiledSchema, options: .atomic)
      try settings.save(to: root)
      try expect(runtimeDelegate.startRime(fullCheck: false, directory: root, logDirectory: root), "valid model-free settings start normally")
      api.join_maintenance_thread()
      try expect(QingTypeRuntimeModel.readStatus(in: root)?.message == nil, "normal startup clears the fallback warning")
      runtimeDelegate.shutdownRime()
      if let path = ProcessInfo.processInfo.environment["QINGTYPE_FACTORY_TEST_MODEL"] {
        var enhanced = settings
        let model = try QingTypeContent.importGrammar(from: URL(fileURLWithPath: path), into: root)
        enhanced.models = [model]; enhanced.activeModelID = model.id
        try enhanced.save(to: root)
        let enhancedReport = try QingTypeMaintenance.deploy(api: api, directory: root)
        try expect(enhancedReport.success && enhancedReport.modelLanguage == model.language, "Wanxiang can deploy independently of Rime Ice")
        try expect(runtimeDelegate.startRime(fullCheck: false, directory: root, logDirectory: root), "verified real model starts through the normal input-service entry")
        api.join_maintenance_thread()
        try expect(QingTypeRuntimeModel.readStatus(in: root)?.message == nil, "verified real model does not trigger a fallback warning")
        session = api.create_session(); _ = api.select_schema(session, enhanced.schema)
        for key in "nihao".utf8 { _ = api.process_key(session, Int32(key), 0) }
        try expect(QingTypeCandidateSource.read(api: api, session: session, startingAt: 0, limit: 64).contains { $0.text == "你好" }, "basic pinyin with only the optional model produces Chinese candidates")
        _ = api.destroy_session(session); session = 0
        runtimeDelegate.shutdownRime()
      }
      print("PASS: \(checks) offline factory engine checks")
      return true
    } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
  }
}
