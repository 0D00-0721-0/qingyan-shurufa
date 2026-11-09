import Foundation
import Yams

enum QingTypePaths {
  static let userDirectory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/QingType", isDirectory: true)
  static let reloadNotification = Notification.Name("QingTypeReloadNotification")
  static func checkDirectory(_ directory: URL) throws {
    guard (try? directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true else {
      throw SettingsError.invalid("清言数据目录包含符号链接，已停止操作以保护原始文件。")
    }
  }
}

struct QuickPhrase: Codable, Equatable, Identifiable {
  var id = UUID()
  var code: String
  var text: String
}

struct QingTypeSettings: Codable, Equatable {
  var schema = "luna_pinyin_simp"
  var layout = "linear"
  var fontSize = 16
  var pageSize = 5
  var inlinePreedit = true
  var useShift = true
  var learningEnabled = true
  var fuzzyPinyin = QingTypeFuzzyPinyin()
  var phrases: [QuickPhrase] = []
  var personalWords: [PersonalWord] = []
  var useSystemCandidates = true
  var dictionaries: [DictionaryAsset] = []
  var models: [GrammarAsset] = []
  var activeModelID: String?
  var rimeIce: RimeIceAsset?

  var activeModel: GrammarAsset? { models.first { $0.id == activeModelID } }

  init() {}

  enum CodingKeys: String, CodingKey {
    case schema, layout, fontSize, pageSize, inlinePreedit, useShift, learningEnabled, phrases, personalWords
    case useSystemCandidates, dictionaries, models, activeModelID, rimeIce, fuzzyPinyin
  }

  init(from decoder: Decoder) throws {
    self.init()
    let values = try decoder.container(keyedBy: CodingKeys.self)
    schema = try values.decodeIfPresent(String.self, forKey: .schema) ?? schema
    layout = try values.decodeIfPresent(String.self, forKey: .layout) ?? layout
    fontSize = try values.decodeIfPresent(Int.self, forKey: .fontSize) ?? fontSize
    pageSize = try values.decodeIfPresent(Int.self, forKey: .pageSize) ?? pageSize
    inlinePreedit = try values.decodeIfPresent(Bool.self, forKey: .inlinePreedit) ?? inlinePreedit
    useShift = try values.decodeIfPresent(Bool.self, forKey: .useShift) ?? useShift
    learningEnabled = try values.decodeIfPresent(Bool.self, forKey: .learningEnabled) ?? true
    fuzzyPinyin = try values.decodeIfPresent(QingTypeFuzzyPinyin.self, forKey: .fuzzyPinyin) ?? QingTypeFuzzyPinyin()
    phrases = try values.decodeIfPresent([QuickPhrase].self, forKey: .phrases) ?? []
    personalWords = try (values.decodeIfPresent([PersonalWord].self, forKey: .personalWords) ?? []).map { try $0.normalized() }
    useSystemCandidates = try values.decodeIfPresent(Bool.self, forKey: .useSystemCandidates) ?? true
    dictionaries = try values.decodeIfPresent([DictionaryAsset].self, forKey: .dictionaries) ?? []
    models = try values.decodeIfPresent([GrammarAsset].self, forKey: .models) ?? []
    activeModelID = try values.decodeIfPresent(String.self, forKey: .activeModelID)
    rimeIce = try values.decodeIfPresent(RimeIceAsset.self, forKey: .rimeIce)
  }

  static let managedHeader = "# Managed by QingType Settings.\n"

  static func load(from directory: URL = QingTypePaths.userDirectory) throws -> Self {
    try QingTypePaths.checkDirectory(directory)
    let url = directory.appendingPathComponent("settings.json")
    guard FileManager.default.fileExists(atPath: url.path) else { return Self() }
    return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
  }

  static func ensureInitialConfiguration() throws {
    let directory = QingTypePaths.userDirectory
    let settings = try load(from: directory)
    let files = ["settings.json", "default.custom.yaml", "squirrel.custom.yaml", "custom_phrase.txt", "qingtype_main.dict.yaml"] +
      (settings.personalWords.isEmpty ? [] : [QingTypePersonalDictionary.tableName + ".dict.yaml"])
    if files.contains(where: { !FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) }) {
      try settings.save(to: directory)
    }
  }

  func validate() throws {
    try QingTypePersonalDictionary.validate(personalWords)
    if let rimeIce { try QingTypeRimeIce.validate(rimeIce) }
    guard schema != "rime_ice" || rimeIce != nil else { throw SettingsError.invalid("请先安装完整雾凇方案，再选择雾凇拼音。") }
    guard ["luna_pinyin_simp", "luna_pinyin", "qingtype_double_pinyin", "rime_ice"].contains(schema),
          ["linear", "stacked"].contains(layout), (12...32).contains(fontSize),
          (3...9).contains(pageSize) else {
      throw SettingsError.invalid("设置值超出支持范围。")
    }
    var codes = Set<String>()
    for dictionary in dictionaries {
      guard !dictionary.tables.isEmpty, dictionary.tables.allSatisfy({
        $0.range(of: "^qingtype_dict_[a-f0-9]+_[0-9]+$", options: .regularExpression) != nil
      }) else { throw SettingsError.invalid("词库清单中的文件名不合法，请重新导入。") }
    }
    if let activeModelID {
      guard let model = models.first(where: { $0.id == activeModelID }),
            model.language == "qingtype_model_" + model.sha256,
            model.sha256.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else {
        throw SettingsError.invalid("未找到所选模型，请重新导入。")
      }
      if (model.variant == "hans" && schema == "luna_pinyin") ||
          (model.variant == "hant" && schema != "luna_pinyin") {
        throw SettingsError.invalid("所选模型的简繁类型与输入方案不同，请更换模型或输入方案。")
      }
    }
    for phrase in phrases {
      guard !phrase.code.isEmpty, phrase.code.utf8.allSatisfy({ (97...122).contains($0) }),
            !phrase.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !phrase.text.contains(where: { $0 == "\n" || $0 == "\r" || $0 == "\t" }) else {
        throw SettingsError.invalid("短语编码只能包含小写英文字母，内容不能为空或包含换行、制表符。")
      }
      guard codes.insert(phrase.code).inserted else {
        throw SettingsError.invalid("短语编码“\(phrase.code)”重复，请使用不同编码。")
      }
    }
  }

  func generatedFiles() throws -> [String: Data] {
    try validate()
    let shift = useShift ? "inline_ascii" : "noop"
    let defaults = """
    \(Self.managedHeader)patch:
      schema_list:
        - schema: \(schema)
      menu/page_size: \(pageSize)
      ascii_composer/switch_key/Caps_Lock: commit_code
      ascii_composer/switch_key/Shift_L: \(shift)
      ascii_composer/switch_key/Shift_R: \(shift)

    """
    let appearance = """
    \(Self.managedHeader)patch:
      show_notifications_when: never
      style/color_scheme: native
      style/color_scheme_dark: native
      style/candidate_list_layout: \(layout)
      style/text_orientation: horizontal
      style/inline_preedit: \(useSystemCandidates || inlinePreedit)
      style/inline_candidate: false
      style/font_point: \(fontSize)
      style/label_font_point: \(max(11, fontSize - 5))
      style/comment_font_point: \(max(12, fontSize - 3))
      style/candidate_format: "[label]  [candidate] [comment]"
      style/corner_radius: 10
      style/hilited_corner_radius: 6
      style/border_width: -4
      style/border_height: -4
      style/line_spacing: 5
      style/spacing: 7
      style/translucency: true
      style/memorize_size: true
      style/show_paging: false

    """
    let phraseText = Self.managedHeader + "# 编码需为小写英文字母。\n" +
      phrases.map { "\($0.text)\t\($0.code)\t10000\n" }.joined()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var files = ["settings.json": try encoder.encode(self),
            "default.custom.yaml": Data(defaults.utf8),
            "squirrel.custom.yaml": Data(appearance.utf8),
            "custom_phrase.txt": Data(phraseText.utf8)]
    files[QingTypePersonalDictionary.tableName + ".dict.yaml"] = try QingTypePersonalDictionary.dictionaryData(personalWords)
    let personalTables = personalWords.isEmpty ? [] : [QingTypePersonalDictionary.tableName]
    let tables = personalTables + ["luna_pinyin"] + dictionaries.filter(\.enabled).flatMap(\.tables)
    let dictionary: [String: Any] = ["name": "qingtype_main", "version": "0.2", "sort": "by_weight",
                                     "use_preset_vocabulary": true, "import_tables": tables]
    files["qingtype_main.dict.yaml"] = Data((Self.managedHeader + "---\n" + (try Yams.dump(object: dictionary)) + "...\n").utf8)
    if let rimeIce {
      var iceDictionary = dictionary
      iceDictionary["name"] = QingTypeRimeIce.dictionaryName
      iceDictionary["import_tables"] = personalTables + rimeIce.tables + dictionaries.filter(\.enabled).flatMap(\.tables)
      files[QingTypeRimeIce.dictionaryName + ".dict.yaml"] = Data((Self.managedHeader + "---\n" + (try Yams.dump(object: iceDictionary)) + "...\n").utf8)
    }
    for schemaID in ["luna_pinyin_simp", "luna_pinyin", "qingtype_double_pinyin"] + (rimeIce == nil ? [] : ["rime_ice"]) {
      let prism = "qingtype_" + schemaID
      var patch: [String: Any] = ["translator/dictionary": schemaID == "rime_ice" ? QingTypeRimeIce.dictionaryName : "qingtype_main", "translator/prism": prism,
                                   "translator/user_dict": schemaID == "rime_ice" ? "rime_ice" : "qingtype_main",
                                   "translator/enable_user_dict": learningEnabled,
                                   "grammar/language": activeModel?.language ?? ""]
      if schemaID == "rime_ice" {
        patch["translator/user_dict"] = "rime_ice"
        patch["radical_reverse_lookup/dictionary"] = QingTypeRimeIce.dictionaryName
      }
      if activeModel != nil {
        patch["grammar/collocation_prism"] = prism + ".prism"
        patch["translator/contextual_suggestions"] = false
      }
      // The simplified schema inherits luna_pinyin including its custom patch.
      // Insert once on the parent; inserting again here would duplicate rules.
      if schemaID != "luna_pinyin_simp" {
        for (key, rule) in fuzzyPinyin.schemaPatch { patch[key] = rule }
      }
      files[schemaID + ".custom.yaml"] = Data((Self.managedHeader + (try Yams.dump(object: ["patch": patch]))).utf8)
    }
    return files
  }

  func verifyActiveModel(in directory: URL) throws {
    if let activeModel {
      let url = directory.appendingPathComponent(activeModel.language + ".gram")
      let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      guard values.isRegularFile == true, values.isSymbolicLink != true,
            try QingTypeContent.digest(of: url) == activeModel.sha256 else {
        throw SettingsError.invalid("已选模型校验失败，请重新导入；原设置未更改。")
      }
    }
  }

  // All files are validated before writing. Restore previous contents if a write fails.
  // Refuse to replace a manually maintained patch without the management header.
  func save(to directory: URL = QingTypePaths.userDirectory) throws {
    try QingTypePaths.checkDirectory(directory)
    let files = try generatedFiles()
    let manager = FileManager.default
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    var required: [String] = dictionaries.filter(\.enabled).flatMap(\.tables).map { $0 + ".dict.yaml" }
    if let activeModel { required.append(activeModel.language + ".gram") }
    if let rimeIce { required.append(contentsOf: rimeIce.files.map(\.path)) }
    for name in required where !manager.fileExists(atPath: directory.appendingPathComponent(name).path) {
      throw SettingsError.invalid("缺少已启用的文件：\(name)，请重新导入。")
    }
    try verifyActiveModel(in: directory)
    var previous: [String: Data] = [:]
    for name in files.keys {
      let url = directory.appendingPathComponent(name)
      if manager.fileExists(atPath: url.path) {
        let contents = try Data(contentsOf: url)
        if name != "settings.json", !contents.starts(with: Data(Self.managedHeader.utf8)) {
          throw SettingsError.invalid("\(name) 含有手动配置。请先移走或备份这个文件，再保存设置。")
        }
        previous[name] = contents
      }
    }
    // Rime treats source timestamps as cache keys. Rewriting a shared patch
    // with identical content invalidates the compiled indexes of its dependents.
    let changed = files.keys.filter { name in
      if files[name] != previous[name] { return true }
      let url = directory.appendingPathComponent(name)
      return (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }.sorted()
    guard !changed.isEmpty else { return }
    // Save a recovery copy of the last configuration before changing it.
    if !previous.isEmpty {
      let backup = directory.appendingPathComponent("backups/\(UUID().uuidString)", isDirectory: true)
      try manager.createDirectory(at: backup, withIntermediateDirectories: true)
      for (name, data) in previous { try data.write(to: backup.appendingPathComponent(name), options: .atomic) }
    }
    var written: [String] = []
    do {
      for name in changed {
        try files[name]!.write(to: directory.appendingPathComponent(name), options: .atomic)
        written.append(name)
      }
    } catch {
      for name in written {
        let url = directory.appendingPathComponent(name)
        if let data = previous[name] { try? data.write(to: url, options: .atomic) }
        else { try? manager.removeItem(at: url) }
      }
      throw error
    }
  }
}

enum SettingsError: LocalizedError {
  case invalid(String)
  var errorDescription: String? {
    switch self { case .invalid(let message): return message }
  }
}
