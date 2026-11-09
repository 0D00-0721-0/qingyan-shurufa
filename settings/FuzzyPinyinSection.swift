import SwiftUI

struct FuzzyPinyinSection: View {
  @Binding var settings: QingTypeFuzzyPinyin

  var body: some View {
    Section("模糊拼音") {
      Toggle("启用模糊拼音", isOn: $settings.enabled)
      Text("按发音习惯选择需要互通的读音，支持内置全拼、小鹤双拼和雾凇拼音。保存并应用后生效。")
        .font(.callout).foregroundStyle(.secondary)
      DisclosureGroup("选择模糊音（已选 \(settings.rules.count) 组）") {
        VStack(alignment: .leading, spacing: 12) {
          rules(initials: true, title: "声母")
          rules(initials: false, title: "韵母")
        }.padding(.vertical, 6)
      }.disabled(!settings.enabled)
      if settings.enabled && settings.rules.isEmpty {
        Text("请展开上方列表，选择需要启用的模糊音。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Text("关闭总开关会保留已选项。候选顺序仍由词频、学习记录和已启用的语言模型决定。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private func rules(initials: Bool, title: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.callout.weight(.medium))
      LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                          GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 8) {
        ForEach(FuzzyPinyinRule.allCases.filter { $0.isInitial == initials }) { rule in
          Toggle(isOn: Binding(
            get: { settings.rules.contains(rule) },
            set: { enabled in
              if enabled { settings.rules.insert(rule) }
              else { settings.rules.remove(rule) }
            }
          )) {
            VStack(alignment: .leading, spacing: 2) {
              Text(rule.label)
              Text(rule.example).font(.caption).foregroundStyle(.secondary)
            }
          }.toggleStyle(.checkbox)
        }
      }
    }
  }
}
