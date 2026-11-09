import Foundation

enum FuzzyPinyinRule: String, Codable, CaseIterable, Identifiable {
  case zZh, cCh, sSh, nL, fH, anAng, enEng, inIng, ianIang, uanUang

  var id: String { rawValue }
  var isInitial: Bool {
    switch self {
    case .zZh, .cCh, .sSh, .nL, .fH: return true
    default: return false
    }
  }
  var label: String {
    switch self {
    case .zZh: return "z ↔ zh"
    case .cCh: return "c ↔ ch"
    case .sSh: return "s ↔ sh"
    case .nL: return "n ↔ l"
    case .fH: return "f ↔ h"
    case .anAng: return "an ↔ ang"
    case .enEng: return "en ↔ eng"
    case .inIng: return "in ↔ ing"
    case .ianIang: return "ian ↔ iang"
    case .uanUang: return "uan ↔ uang"
    }
  }
  var example: String {
    switch self {
    case .zZh: return "zong ↔ zhong"
    case .cCh: return "can ↔ chan"
    case .sSh: return "san ↔ shan"
    case .nL: return "nan ↔ lan"
    case .fH: return "fa ↔ ha"
    case .anAng: return "ban ↔ bang"
    case .enEng: return "ben ↔ beng"
    case .inIng: return "bin ↔ bing"
    case .ianIang: return "lian ↔ liang"
    case .uanUang: return "guan ↔ guang"
    }
  }

  // Derive alternate spellings before abbreviation or Xiaohe key mapping.
  // Unlike a rewrite, derivation also retains the original exact spelling.
  var algebra: [String] {
    switch self {
    case .zZh: return ["derive/^zh/z/", "derive/^z([^h])/zh$1/"]
    case .cCh: return ["derive/^ch/c/", "derive/^c([^h])/ch$1/"]
    case .sSh: return ["derive/^sh/s/", "derive/^s([^h])/sh$1/"]
    case .nL: return ["derive/^n/l/", "derive/^l/n/"]
    case .fH: return ["derive/^f/h/", "derive/^h/f/"]
    // Anchor the whole syllable so an/ang does not also enable ian/iang or uan/uang.
    case .anAng:
      return ["derive/^([bpmfdtnlgkhzcsrwy]|[zcs]h)?an$/$1ang/",
              "derive/^([bpmfdtnlgkhzcsrwy]|[zcs]h)?ang$/$1an/"]
    case .enEng:
      return ["derive/^([bpmfdtnlgkhzcsrwy]|[zcs]h)?en$/$1eng/",
              "derive/^([bpmfdtnlgkhzcsrwy]|[zcs]h)?eng$/$1en/"]
    case .inIng: return ["derive/in$/ing/", "derive/ing$/in/"]
    case .ianIang: return ["derive/ian$/iang/", "derive/iang$/ian/"]
    case .uanUang: return ["derive/uan$/uang/", "derive/uang$/uan/"]
    }
  }
}

struct QingTypeFuzzyPinyin: Codable, Equatable {
  var enabled = false
  var rules: Set<FuzzyPinyinRule> = []

  init() {}
  enum CodingKeys: String, CodingKey { case enabled, rules }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
    rules = try values.decodeIfPresent(Set<FuzzyPinyinRule>.self, forKey: .rules) ?? []
  }

  func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(enabled, forKey: .enabled)
    // Stable order keeps generated settings and deployment hashes reproducible.
    try values.encode(FuzzyPinyinRule.allCases.filter { rules.contains($0) }, forKey: .rules)
  }

  var algebra: [String] {
    enabled ? FuzzyPinyinRule.allCases.filter { rules.contains($0) }.flatMap(\.algebra) : []
  }

  var schemaPatch: [String: String] {
    // Rime applies patch map keys in lexical order. Padded insertion indices
    // prepend the rules in order, preserving the scheme's resolved algebra,
    // including inherited lists, spelling corrections and double-pinyin mapping.
    Dictionary(uniqueKeysWithValues: algebra.enumerated().map {
      (String(format: "speller/algebra/@before %04d", $0.offset), $0.element)
    })
  }
}
