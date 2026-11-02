import AppKit

// Own both presentations in a single nonactivating window. An arrow over an
// IMKCandidates window cannot reliably share its geometry or window lifetime.
final class QingTypeCandidatePresenter {
  let window: QingTypeExpandedCandidates
  private(set) var isExpanded = false
  var onSelect: ((Int) -> Void)?
  private var candidates: [QingTypeCandidate] = []
  private var settings = QingTypeSettings()
  private var caretRect = NSRect.zero
  private var highlighted = 0
  private var engineHighlight = 0
  private var composition = ""
  private let showsWindow: Bool

  init(showsWindow: Bool = true, visibleScreen: ((NSRect) -> NSRect)? = nil, reduceMotion: (() -> Bool)? = nil) {
    window = QingTypeExpandedCandidates(visibleScreen: visibleScreen, reduceMotion: reduceMotion)
    self.showsWindow = showsWindow
    window.onToggle = { [weak self] in self?.toggle() }
    window.onPick = { [weak self] index in
      guard let self, self.candidates.contains(where: { $0.index == index }) else { return }
      self.onSelect?(index)
    }
    window.onHighlight = { [weak self] index in self?.highlighted = index }
  }

  func update(candidates: [QingTypeCandidate], highlighted: Int, settings: QingTypeSettings, caretRect: NSRect, composition: String = "") {
    guard !candidates.isEmpty else { hide(); return }
    let resetSelection = self.candidates != candidates || engineHighlight != highlighted || self.composition != composition
    self.candidates = candidates
    self.settings = settings
    self.composition = composition
    engineHighlight = highlighted
    if resetSelection {
      self.highlighted = candidates.contains(where: { $0.index == highlighted }) ? highlighted : candidates[0].index
    }
    if QingTypeCandidatePlacement.isUsable(caretRect) { self.caretRect = caretRect }
    render()
  }

  private func render(animate: Bool = false) {
    guard !candidates.isEmpty, QingTypeCandidatePlacement.isUsable(caretRect) else { return }
    window.present(candidates: candidates, highlighted: highlighted, caretRect: caretRect,
                   fontSize: settings.fontSize, pageSize: settings.pageSize,
                   expanded: isExpanded, vertical: settings.layout != "linear", show: showsWindow, animate: animate)
  }

  func toggle() { isExpanded ? collapse() : expand() }
  func expand() {
    guard !isExpanded, !candidates.isEmpty, window.hasMoreCandidates else { return }
    isExpanded = true
    render(animate: true)
  }
  func collapse() {
    guard isExpanded else { return }
    isExpanded = false
    render(animate: true)
  }

  func handleKey(_ event: NSEvent) -> Bool {
    guard event.type == .keyDown,
          event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return false }
    return handleKey(code: event.keyCode, text: event.charactersIgnoringModifiers)
  }

  func prepareForEngineKey(modifiers: UInt32, highlight: (Int) -> Bool) -> Bool {
    let passThrough = kReleaseMask.rawValue | kControlMask.rawValue | kAltMask.rawValue | kSuperMask.rawValue
    guard modifiers & passThrough == 0, !candidates.isEmpty, highlighted != engineHighlight else { return true }
    guard candidates.contains(where: { $0.index == highlighted }), highlight(highlighted) else { return false }
    // Hover and grid navigation stay local. Synchronize only immediately before
    // Rime handles a key, so implicit commits use the visible selection without
    // changing the displayed page while the user is browsing it.
    engineHighlight = highlighted
    return true
  }

  func handleKey(code: UInt16, text: String?) -> Bool {
    guard !candidates.isEmpty else { return false }
    switch code {
    case 53:
      guard isExpanded else { return false }
      collapse()
    case 125 where !isExpanded:
      expand()
      return isExpanded
    case 123, 124:
      guard isExpanded else { return false }
      window.move(horizontal: code == 123 ? -1 : 1, vertical: 0)
    case 125: window.move(horizontal: 0, vertical: 1)
    case 126:
      if !isExpanded { return false }
      window.move(horizontal: 0, vertical: -1)
    case 36, 76:
      // Rime uses Return to commit raw pinyin in the collapsed presentation.
      guard isExpanded else { return false }
      window.pickSelected()
    case 49: window.pickSelected()
    default:
      guard let text, text.count == 1, let number = Int(text), (1...9).contains(number) else { return false }
      // Never let Rime select a hidden page entry after adaptive layout has
      // reduced the number of visible choices. Unavailable digits are ignored.
      _ = window.pickNumber(number)
      return true
    }
    highlighted = window.selectedIndex
    return true
  }

  func hide() {
    window.orderOut(nil)
    isExpanded = false
    candidates = []
    caretRect = .zero
  }
}
