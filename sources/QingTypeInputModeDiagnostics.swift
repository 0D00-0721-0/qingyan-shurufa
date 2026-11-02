import AppKit
import Carbon

enum QingTypeInputModeDiagnostics {
  // Exercise the real engine with the Caps Lock translation used by the controller.
  // Callers provide an isolated profile; no events are sent to another application.
  static func checkCapsLock(api: RimeApi_stdbool, session: RimeSessionId, profile: String) throws -> Int {
    var checks = 0
    func expect(_ value: Bool, _ message: String) throws {
      guard value else { throw SettingsError.invalid("FAIL: \(profile): \(message)") }
      checks += 1
      print("PASS: \(profile): \(message)")
    }
    func committedText() -> String? {
      var commit = RimeCommit.rimeStructInit()
      guard api.get_commit(session, &commit) else { return nil }
      defer { _ = api.free_commit(&commit) }
      return commit.text.map { String(cString: $0) }
    }
    let capsKey = SquirrelKeycode.osxKeycodeToRime(keycode: UInt16(kVK_CapsLock), keychar: nil, shift: false, caps: false)
    func pressCapsLock(enabled: Bool) {
      let flags: NSEvent.ModifierFlags = enabled ? [.capsLock] : []
      // NSFlagsChanged already carries the new lock state; Rime expects the old one.
      let modifiers = SquirrelKeycode.osxModifiersToRime(modifiers: flags) ^ kLockMask.rawValue
      QingTypeInputModeSwitch.prepare(api: api, session: session, key: capsKey, modifiers: modifiers)
      _ = api.process_key(session, Int32(capsKey), Int32(modifiers))
    }
    func type(_ keys: [Int32]) {
      for key in keys { _ = api.process_key(session, key, 0) }
    }
    let nihao = "nihao".utf8.map { Int32($0) }
    api.set_option(session, "ascii_mode", false)
    type(nihao)
    api.set_caret_pos(session, 2)
    QingTypeInputModeSwitch.prepare(api: api, session: session, key: UInt32(XK_Shift_L), modifiers: 0)
    QingTypeInputModeSwitch.prepare(api: api, session: session, key: capsKey, modifiers: kReleaseMask.rawValue)
    QingTypeInputModeSwitch.prepare(api: api, session: session, key: capsKey, modifiers: kLockMask.rawValue)
    try expect(api.get_caret_pos(session) == 2, "unrelated, release and return-to-Chinese events keep the caret")
    var status = RimeStatus_stdbool.rimeStructInit()
    guard api.get_status(session, &status) else { throw SettingsError.invalid("Missing test schema status") }
    let schemaID = status.schema_id.map { String(cString: $0) }
    _ = api.free_status(&status)
    var schema = RimeConfig()
    guard let schemaID, api.schema_open(schemaID, &schema) else { throw SettingsError.invalid("Missing test schema") }
    do {
      defer { _ = api.config_close(&schema) }
      var previous = RimeConfig()
      guard api.config_get_item(&schema, "ascii_composer", &previous) else { throw SettingsError.invalid("Cannot save test binding") }
      defer { _ = api.config_set_item(&schema, "ascii_composer", &previous); _ = api.config_close(&previous) }
      guard api.config_set_string(&schema, "ascii_composer/switch_key/Caps_Lock", "commit_text") else {
        throw SettingsError.invalid("Cannot set test binding")
      }
      QingTypeInputModeSwitch.prepare(api: api, session: session, key: capsKey, modifiers: 0)
      try expect(api.get_caret_pos(session) == 2, "an explicit schema switch policy is not replaced by the default policy")
    }
    let cases: [(keys: [Int32], raw: String, name: String)] = [
      (nihao, "nihao", "plain pinyin"),
      ("nihaox".utf8.map { Int32($0) } + [XK_BackSpace], "nihao", "edited pinyin"),
      (nihao + [XK_Left], "nihao", "pinyin with a moved caret"),
      ("xi'an".utf8.map { Int32($0) }, "xi'an", "explicit syllable separator")
    ]
    for item in cases {
      api.clear_composition(session)
      api.set_option(session, "ascii_mode", false)
      type(item.keys)
      try expect(api.get_input(session).map { String(cString: $0) } == item.raw, "\(item.name) reaches the engine intact")
      pressCapsLock(enabled: true)
      try expect(committedText() == item.raw, "Caps Lock commits \(item.name) as the exact original letters")
      try expect(api.get_option(session, "ascii_mode") &&
                 (api.get_input(session).map { String(cString: $0) } ?? "").isEmpty,
                 "Caps Lock enters English mode with no leftover composition")
      _ = api.process_key(session, Int32(capsKey), Int32(kReleaseMask.rawValue | kLockMask.rawValue))
      pressCapsLock(enabled: false)
      try expect(committedText() == nil && !api.get_option(session, "ascii_mode"),
                 "release and switching back neither duplicate text nor leave English mode active")
    }
    pressCapsLock(enabled: true)
    try expect(committedText() == nil && api.get_option(session, "ascii_mode"),
               "switching with an empty composition does not insert text")
    pressCapsLock(enabled: false)
    type(nihao + [XK_Escape])
    pressCapsLock(enabled: true)
    try expect(committedText() == nil, "switching after Escape does not resurrect cancelled pinyin")
    pressCapsLock(enabled: false)
    type(nihao)
    try expect(QingTypeCandidateSource.read(api: api, session: session, startingAt: 0, limit: 64).contains { $0.text == "你好" },
               "switching back preserves normal Chinese candidates")
    api.clear_composition(session)
    return checks
  }

  static func checkCandidatePunctuation(api: RimeApi_stdbool, session: RimeSessionId,
                                        profile: String, settings: QingTypeSettings) throws -> Int {
    var checks = 0
    func expect(_ value: Bool, _ message: String) throws {
      guard value else { throw SettingsError.invalid("FAIL: \(profile): \(message)") }
      checks += 1; print("PASS: \(profile): \(message)")
    }
    func consume() -> String? {
      var commit = RimeCommit.rimeStructInit()
      guard api.get_commit(session, &commit) else { return nil }
      defer { _ = api.free_commit(&commit) }
      return commit.text.map { String(cString: $0) }
    }
    _ = NSApplication.shared
    let presenter = QingTypeCandidatePresenter(showsWindow: false, reduceMotion: { true })
    defer { presenter.hide(); api.clear_composition(session) }
    func reset() throws -> [QingTypeCandidate] {
      presenter.hide(); api.clear_composition(session); _ = consume()
      api.set_option(session, "ascii_mode", false)
      for key in "ni".utf8 { _ = api.process_key(session, Int32(key), 0) }
      let candidates = QingTypeCandidateSource.read(api: api, session: session, startingAt: 0)
      guard candidates.count > settings.pageSize + 2 else { throw SettingsError.invalid("Missing punctuation test candidates") }
      presenter.update(candidates: candidates, highlighted: 0, settings: settings,
                       caretRect: NSRect(x: 300, y: 500, width: 1, height: 24), composition: "ni")
      return candidates
    }
    for (key, punctuation, modifiers) in [(XK_comma, "，", UInt32(0)), (XK_question, "？", kShiftMask.rawValue), (XK_exclam, "！", kShiftMask.rawValue)] {
      let candidates = try reset()
      _ = presenter.handleKey(code: 125, text: nil)
      _ = presenter.handleKey(code: 124, text: nil)
      let selected = presenter.window.selectedIndex
      let expected = candidates.first { $0.index == selected }!.text
      var context = RimeContext_stdbool.rimeStructInit()
      let got = api.get_context(session, &context)
      let page = context.menu.page_no
      if got { _ = api.free_context(&context) }
      try expect(selected == 1 && got && page == 0 && consume() == nil,
                 "grid navigation changes only the UI before an engine key")
      guard presenter.prepareForEngineKey(modifiers: modifiers, highlight: { api.highlight_candidate(session, $0) }) else {
        throw SettingsError.invalid("Cannot synchronize punctuation test selection")
      }
      _ = api.process_key(session, key, Int32(modifiers))
      try expect(consume() == expected + punctuation, "\(punctuation) commits the visible arrow-selected candidate")
      try expect((api.get_input(session).map { String(cString: $0) } ?? "").isEmpty && consume() == nil,
                 "punctuation clears composition without a second commit")
    }
    let candidates = try reset()
    presenter.expand()
    let later = candidates[settings.pageSize + 1]
    presenter.window.highlight(later.index)
    let body = presenter.window.bodyIdentity
    let frames = presenter.window.allCellFrames
    try expect(presenter.prepareForEngineKey(modifiers: kShiftMask.rawValue, highlight: { api.highlight_candidate(session, $0) }),
               "an implicit commit can synchronize a candidate beyond the engine page")
    try expect(presenter.window.bodyIdentity == body && presenter.window.allCellFrames == frames &&
               presenter.window.selectedIndex == later.index,
               "last-moment synchronization does not rebuild or move the visible grid")
    _ = api.process_key(session, Int32(XK_question), Int32(kShiftMask.rawValue))
    try expect(consume() == later.text + "？", "a later-page hovered candidate is preserved by punctuation")
    let compact = try reset()
    presenter.window.highlight(compact[1].index)
    try expect(presenter.prepareForEngineKey(modifiers: 0, highlight: { api.highlight_candidate(session, $0) }),
               "collapsed hover selection also synchronizes before an implicit commit")
    _ = api.process_key(session, Int32(XK_comma), 0)
    try expect(consume() == compact[1].text + "，", "collapsed punctuation matches the hovered candidate")
    let periodCandidates = try reset(); presenter.window.highlight(1)
    guard presenter.prepareForEngineKey(modifiers: 0, highlight: { api.highlight_candidate(session, $0) }) else {
      throw SettingsError.invalid("Cannot prepare period binding test")
    }
    _ = api.process_key(session, Int32(XK_period), 0)
    let periodCommit = consume()
    var periodContext = RimeContext_stdbool.rimeStructInit()
    let hasPeriodContext = api.get_context(session, &periodContext)
    let periodPage = periodContext.menu.page_no
    if hasPeriodContext { _ = api.free_context(&periodContext) }
    if settings.schema == "rime_ice" {
      try expect(periodCommit == periodCandidates[1].text + "。", "Rime Ice keeps its configured period commit")
    } else {
      try expect(periodCommit == nil && hasPeriodContext && periodPage == 1 &&
                 api.get_input(session).map({ String(cString: $0) }) == "ni",
                 "the base schema keeps period as Page Down without committing input")
    }
    _ = try reset(); presenter.window.highlight(1)
    var calls = 0
    for modifiers in [kControlMask.rawValue, kAltMask.rawValue, kSuperMask.rawValue, kReleaseMask.rawValue] {
      let ready = presenter.prepareForEngineKey(modifiers: modifiers) { _ in calls += 1; return true }
      try expect(ready && calls == 0, "host shortcut or release event leaves engine highlight untouched")
    }
    try expect(!presenter.prepareForEngineKey(modifiers: 0, highlight: { _ in false }) && consume() == nil,
               "failed synchronization prevents an implicit commit of another candidate")
    try expect(presenter.prepareForEngineKey(modifiers: 0, highlight: { api.highlight_candidate(session, $0) }),
               "a failed synchronization can be retried without consuming composition")
    api.set_caret_pos(session, 1)
    let key = QingTypeKeyboardInput.prepare(api: api, session: session, key: UInt32(XK_Return), modifiers: 0)
    _ = api.process_key(session, Int32(key), 0)
    try expect(consume() == "ni", "collapsed Return still commits all raw letters after UI selection")
    presenter.hide()
    try expect(presenter.prepareForEngineKey(modifiers: 0, highlight: { _ in false }),
               "a hidden or empty presenter has no selection to synchronize")
    return checks
  }

  static func checkEditingKeys(api: RimeApi_stdbool, session: RimeSessionId,
                               profile: String, useShift: Bool) throws -> Int {
    var checks = 0
    var commits = [String]()
    func expect(_ value: Bool, _ message: String) throws {
      guard value else { throw SettingsError.invalid("FAIL: \(profile): \(message)") }
      checks += 1
      print("PASS: \(profile): \(message)")
    }
    func consume() {
      var commit = RimeCommit.rimeStructInit()
      if api.get_commit(session, &commit) {
        if let text = commit.text { commits.append(String(cString: text)) }
        _ = api.free_commit(&commit)
      }
    }
    @discardableResult func send(_ key: Int32, _ modifiers: UInt32 = 0) -> Bool {
      let prepared = QingTypeKeyboardInput.prepare(api: api, session: session, key: UInt32(key), modifiers: modifiers)
      let handled = api.process_key(session, Int32(prepared), Int32(modifiers))
      consume()
      return handled
    }
    func input() -> String { api.get_input(session).map { String(cString: $0) } ?? "" }
    func reset(_ text: String = "nihao") {
      api.clear_composition(session)
      api.set_option(session, "ascii_mode", false)
      commits = []
      for key in text.utf8 { send(Int32(key)) }
    }
    for (name, keys, expected) in [
      ("plain Return", [XK_Return], "nihao"),
      ("Return after moving left", [XK_Left, XK_Return], "nihao"),
      ("keypad Enter", [XK_KP_Enter], "nihao"),
      ("keypad Enter after moving left", [XK_Left, XK_KP_Enter], "nihao"),
      ("Backspace then Return", [XK_BackSpace, XK_Return], "niha"),
      ("Home then Return", [XK_Home, XK_Return], "nihao"),
      ("End then Return", [XK_Left, XK_End, XK_Return], "nihao")
    ] {
      reset()
      var handled = false
      for key in keys { handled = send(key) }
      try expect(handled && commits == [expected] && input().isEmpty,
                 "\(name) commits all remaining raw input exactly once")
      try expect(!send(keys.last ?? XK_Return) && commits == [expected],
                 "a later Enter remains available to the app without duplicating input")
    }
    reset(); api.set_caret_pos(session, 2); send(XK_Delete)
    try expect(input() == "niao" && commits.isEmpty, "forward Delete removes the character at an explicit composition caret")
    send(XK_Return)
    try expect(commits == ["niao"] && input().isEmpty, "Return preserves every remaining character after forward Delete")
    reset(); api.set_caret_pos(session, 2)
    var untouched = true
    for modifiers in [kControlMask.rawValue, kAltMask.rawValue, kSuperMask.rawValue, kReleaseMask.rawValue] {
      let key = QingTypeKeyboardInput.prepare(api: api, session: session, key: UInt32(XK_KP_Enter), modifiers: modifiers)
      untouched = untouched && key == UInt32(XK_KP_Enter) && api.get_caret_pos(session) == 2
    }
    try expect(untouched && input() == "nihao", "application shortcuts and release events do not normalize Enter or move the caret")
    reset("xi'an"); send(XK_Return)
    try expect(commits == ["xi'an"], "Return preserves an explicit syllable separator")
    reset(); send(XK_Left); send(XK_Return, kShiftMask.rawValue)
    try expect(commits.count == 1 && commits[0].replacingOccurrences(of: " ", with: "") == "nihao",
               "Shift-Return retains its script formatting without dropping the suffix")
    reset(); send(XK_Left)
    send(XK_Shift_L, kShiftMask.rawValue); send(XK_Shift_L, kReleaseMask.rawValue)
    try expect(api.get_option(session, "ascii_mode") == useShift && input() == "nihao" && commits.isEmpty,
               "a lone Shift obeys the existing preference and does not discard composition")
    send(XK_Return)
    try expect(commits == ["nihao"] && !api.get_option(session, "ascii_mode"),
               "Return finishes temporary English input without truncating or sticking in English")
    reset(); send(XK_Shift_L, kShiftMask.rawValue); send(XK_A, kShiftMask.rawValue)
    send(XK_Shift_L, kReleaseMask.rawValue)
    try expect(!api.get_option(session, "ascii_mode") && input() == "nihaoA" && commits.isEmpty,
               "Shift with a letter does not accidentally toggle English mode")
    reset(); send(XK_Escape)
    try expect(input().isEmpty && commits.isEmpty && !send(XK_Return),
               "Escape cancels without output and an empty Return passes through")
    reset()
    let beforeHome = api.get_caret_pos(session)
    let handledHome = send(XK_a, kControlMask.rawValue)
    try expect(api.get_caret_pos(session) == (handledHome ? 0 : beforeHome) && input() == "nihao" && commits.isEmpty,
               "Control-A moves to the beginning or passes unchanged to the host")
    let beforeEnd = api.get_caret_pos(session)
    let handledEnd = send(XK_e, kControlMask.rawValue)
    try expect(api.get_caret_pos(session) == (handledEnd ? 5 : beforeEnd) && input() == "nihao" && commits.isEmpty,
               "Control-E moves to the end or passes unchanged to the host")
    reset(); send(XK_BackSpace, kControlMask.rawValue)
    try expect(input() == "ni" && commits.isEmpty, "Control-Backspace deletes the last syllable without committing text")
    reset("ni")
    let candidates = QingTypeCandidateSource.read(api: api, session: session, startingAt: 0, limit: 16)
    guard candidates.count > 2 else { throw SettingsError.invalid("Missing keyboard test candidates") }
    send(XK_2)
    try expect(commits == [candidates[1].text] && input().isEmpty, "an engine number key commits its actual numbered candidate")
    reset("ni"); send(XK_Tab)
    try expect(input() == "ni" && commits.isEmpty, "Tab navigation does not discard or commit composition")
    send(XK_Tab, kShiftMask.rawValue)
    try expect(input() == "ni" && commits.isEmpty, "Shift-Tab navigation does not discard or commit composition")
    reset("ni"); send(XK_Page_Down)
    var context = RimeContext_stdbool.rimeStructInit()
    let paged = api.get_context(session, &context)
    let page = context.menu.page_no
    if paged { _ = api.free_context(&context) }
    try expect(paged && page > 0 && input() == "ni" && commits.isEmpty, "Page Down advances candidates without changing input")
    send(XK_Page_Up)
    let returned = api.get_context(session, &context)
    let back = context.menu.page_no
    if returned { _ = api.free_context(&context) }
    try expect(returned && back == 0 && input() == "ni" && commits.isEmpty, "Page Up returns without changing input")
    reset(); send(XK_space)
    try expect(commits == ["你好"] && input().isEmpty, "Space still commits the ordinary Chinese candidate")
    reset(); send(XK_comma)
    try expect(commits == ["你好，"] && input().isEmpty, "Chinese punctuation keeps the selected word and punctuation together")
    api.clear_composition(session)
    api.set_option(session, "ascii_mode", false)
    return checks
  }
}
