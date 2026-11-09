import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers

@main
struct QingTypeSettingsApp: App {
  @StateObject private var model = SettingsModel()
  var body: some Scene {
    WindowGroup("清言设置") {
      SettingsView(model: model).frame(minWidth: 760, minHeight: 560)
    }
    .windowResizability(.contentMinSize)
    .defaultSize(width: 820, height: 620)
    .commands { CommandGroup(replacing: .newItem) {} }
  }
}

@MainActor
final class SettingsModel: ObservableObject {
  @Published var sampleText = ""
  @Published var section: SettingsSection? = .welcome
  @Published var settings = QingTypeSettings()
  @Published var saved = QingTypeSettings()
  @Published var message: String?
  @Published var failed = false
  @Published var loadFailed = false
  @Published var busy = false
  @Published var deployment: QingTypeDeploymentReport?
  @Published var installedVersion: String?
  @Published var installationStatus: QingTypeInstallationStatus?
  @Published var inputEnabled = false
  @Published var uninstallDecision: QingTypeUninstallDecision = .checking
  var uninstallRefreshGeneration = 0
  @Published var transferProgress: QingTypeTransferProgress?
  @Published var canCancelDownload = false
  @Published var checkingComponentUpdate = false
  @Published var pendingRimeIceUpdate: QingTypeRimeIceUpdate?
  @Published var learningSummary = "正在读取本机学习数据…"
  @Published var maintenance = QingTypeMaintenancePreferences()
  @Published var appUpdate: QingTypeAppUpdate?
  @Published var updateSummary: String?
  @Published var runtimeModelWarning: String?
  @Published var modelFileStates: [String: QingTypeModelFileState] = [:]
  var componentTask: Task<Void, Never>?


  init() {
    do {
      settings = try .load(); saved = settings
      if let data = try? Data(contentsOf: QingTypePaths.userDirectory.appendingPathComponent("deployment.json")) {
        deployment = try? JSONDecoder().decode(QingTypeDeploymentReport.self, from: data)
      }
    }
    catch { loadFailed = true; failed = true; message = "无法读取设置：\(error.localizedDescription)" }
    refreshRuntimeModelStatus()
    refreshInstallation()
    refreshModelFileStates()
    do {
      maintenance = try .load()
      if try ProgramMaintenanceService.pendingUpdate() != nil { completePendingAppUpdate() }
      else if maintenance.checkUpdatesOnLaunch { checkAppUpdates(automatic: true) }
    } catch { failed = true; message = error.localizedDescription }
  }

  var isDirty: Bool { settings != saved }
  func refreshRuntimeModelStatus() {
    runtimeModelWarning = QingTypeRuntimeModel.readStatus(in: QingTypePaths.userDirectory)?.message
  }

  /// Hashing a model is expensive (hundreds of MB), so it never runs from a
  /// SwiftUI body: the result is cached and refreshed in the background.
  func refreshModelFileStates() {
    let models = settings.models
    let directory = QingTypePaths.userDirectory
    Task.detached {
      var states: [String: QingTypeModelFileState] = [:]
      for model in models { states[model.id] = QingTypeContent.modelFileState(model, in: directory) }
      let result = states
      await MainActor.run { self.modelFileStates = result }
    }
  }
  var inputReady: Bool {
    guard inputEnabled, let installedVersion, let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return false }
    return installedVersion.compare(current, options: .numeric) != .orderedAscending
  }
  var deploymentIsCurrent: Bool {
    guard let deployment, !isDirty else { return false }
    return (try? QingTypeContent.digest(of: QingTypePaths.userDirectory.appendingPathComponent("settings.json"))) == deployment.settingsHash
  }

  func save() {
    guard !busy, !loadFailed else { return }
    let draft = settings
    do { try draft.validate() }
    catch { failed = true; message = error.localizedDescription; return }
    busy = true
    failed = false
    message = "正在编译词库并检查语言模型…"
    Task {
      defer { busy = false }
      do {
        let report = try await DeploymentService.apply(draft)
        saved = draft
        deployment = report
        message = report.message
        refreshModelFileStates()
      } catch {
        failed = true
        message = error.localizedDescription
        if let restored = try? QingTypeSettings.load() { saved = restored }
      }
    }
  }

  func chooseImport(model: Bool) {
    let panel = NSOpenPanel()
    panel.title = model ? "导入语言模型" : "导入词库"
    panel.prompt = "导入"
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = !model
    panel.allowedContentTypes = [UTType(filenameExtension: model ? "gram" : "yaml") ?? .data]
    panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Rime")
    guard panel.runModal() == .OK else { return }
    importFiles(panel.urls, model: model)
  }

  var existingWanxiang: URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Rime/wanxiang-lts-zh-hans.gram")
  }

  func importFiles(_ urls: [URL], model: Bool) {
    guard !busy else { return }
    busy = true
    failed = false
    message = model ? "正在校验并导入语言模型…" : "正在导入词库与依赖…"
    Task {
      defer { busy = false }
      do {
        if model {
          let imported = try await Task.detached {
            try urls.map { try QingTypeContent.importGrammar(from: $0, into: QingTypePaths.userDirectory) }
          }.value
          for item in imported {
            if !settings.models.contains(where: { $0.id == item.id }) { settings.models.append(item) }
            settings.activeModelID = item.id
          }
        } else {
          let imported = try await Task.detached {
            try urls.map { try QingTypeContent.importDictionary(from: $0, into: QingTypePaths.userDirectory) }
          }.value
          settings.dictionaries.append(contentsOf: imported)
        }
        refreshModelFileStates()
        message = "已导入，点击“保存并应用”后生效。"
      } catch { failed = true; message = error.localizedDescription }
    }
  }

  func previewSystemCandidates() {
    let task = Process()
    task.executableURL = DeploymentService.inputMethodURL().appendingPathComponent("Contents/MacOS/QingType")
    task.arguments = ["--preview-system"]
    do { try task.run() }
    catch { failed = true; message = error.localizedDescription }
  }

  func showFolder() {
    do {
      try FileManager.default.createDirectory(at: QingTypePaths.userDirectory, withIntermediateDirectories: true)
      NSWorkspace.shared.open(QingTypePaths.userDirectory)
    } catch { failed = true; message = error.localizedDescription }
  }

  var installed: Bool {
    FileManager.default.fileExists(atPath: FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Input Methods/QingType.app").path)
  }
}

enum SettingsSection: String, CaseIterable, Identifiable {
  case welcome = "开始使用", input = "输入", appearance = "外观", personal = "个人词库", learning = "自动学习", dictionaries = "导入词库", models = "语言模型", phrases = "快捷短语", maintenance = "维护与更新", about = "关于与安装"
  var id: String { rawValue }
  var icon: String {
    switch self {
    case .welcome: return "hand.wave"
    case .input: return "keyboard"
    case .appearance: return "textformat.size"
    case .personal: return "text.book.closed"
    case .learning: return "clock.arrow.circlepath"
    case .maintenance: return "wrench.and.screwdriver"
    case .dictionaries: return "books.vertical"
    case .models: return "brain"
    case .phrases: return "text.bubble"
    case .about: return "info.circle"
    }
  }
}

struct SettingsView: View {
  @ObservedObject var model: SettingsModel
  private var section: SettingsSection? { model.section }

  var body: some View {
    NavigationSplitView {
      List(SettingsSection.allCases, selection: $model.section) { item in
        Label(item.rawValue, systemImage: item.icon).tag(item)
      }
      .navigationSplitViewColumnWidth(180)
      .safeAreaInset(edge: .bottom) {
        HStack(spacing: 10) {
          Image(systemName: "character.bubble.fill").font(.title2).foregroundStyle(.tint)
          VStack(alignment: .leading, spacing: 3) {
            Text("清言").font(.headline)
            Text("QingType").font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
        }.padding(16)
      }
    } detail: {
      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
              Text((section ?? .input).rawValue).font(.system(size: 27, weight: .bold, design: .rounded))
              Text(subtitle).foregroundStyle(.secondary)
            }
            .padding(.top, 6)
            Group {
              switch section ?? .input {
              case .welcome: WelcomePage(model: model)
              case .input: inputPage
              case .appearance: appearancePage
              case .personal: PersonalDictionaryPage(model: model)
              case .learning: LearningPage(model: model)
              case .maintenance: MaintenancePage(model: model)
              case .dictionaries: dictionariesPage
              case .models: modelsPage
              case .phrases: phrasesPage
              case .about: aboutPage
              }
            }.disabled(section != .welcome && section != .about && section != .maintenance && (!model.inputReady || model.busy))
          }.padding(28).frame(maxWidth: 780, alignment: .leading)
        }
        Divider()
        if model.canCancelDownload {
          HStack {
            if let progress = model.transferProgress {
              ProgressView(value: progress.fraction)
              Text("\(ByteCountFormatter.string(fromByteCount: progress.received, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: progress.total, countStyle: .file))")
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
            } else { Spacer() }
            Button(model.checkingComponentUpdate ? "取消检查" : "取消下载") { model.componentTask?.cancel() }
          }.padding(.horizontal, 16).padding(.top, 10)
        }
        HStack {
          if model.busy { ProgressView().controlSize(.small) }
          if model.isDirty && !model.failed && !model.busy {
            Text("有未保存的更改").font(.callout).foregroundStyle(.secondary)
          } else if let message = model.message {
            Label(message, systemImage: model.failed ? "exclamationmark.circle" : "checkmark.circle")
              .font(.callout).foregroundStyle(model.failed ? Color.red : Color.secondary)
              .textSelection(.enabled)
          } else {
            Text(model.isDirty ? "有未保存的更改" : "输入由本地 Rime 引擎处理")
              .font(.callout).foregroundStyle(.secondary)
          }
          Spacer(minLength: 12)
          Button("保存并应用", action: model.save)
            .buttonStyle(.borderedProminent).keyboardShortcut("s", modifiers: .command)
            .disabled(model.loadFailed || model.busy || !model.inputReady)
        }.padding(16)
      }
      .background(Color(nsColor: .windowBackgroundColor))
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      model.refreshRuntimeModelStatus()
      model.refreshUninstallState()
    }
    .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String))
      .merge(with: DistributedNotificationCenter.default().publisher(for: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)))
      .receive(on: RunLoop.main)) { _ in
      model.refreshUninstallState()
    }
    .onChange(of: model.section) { _, section in
      if section == .models || section == .welcome { model.refreshModelFileStates() }
    }
  }

  private var subtitle: String {
    switch section ?? .input {
    case .welcome: return "先开始输入，再选择适合自己的增强组件。"
    case .input: return "选好输入习惯，安心写下每一句。"
    case .appearance: return "候选窗随系统明暗模式与高亮颜色变化。"
    case .personal: return "管理词语、拼音和词频，保存后参与日常输入。"
    case .learning: return "保留选词习惯，管理学习记录与备份。"
    case .maintenance: return "获取新版清言，或保留数据安全卸载。"
    case .dictionaries: return "添加专业词与个人词库，让输入更懂你的用词。"
    case .models: return "使用万象等本地语言模型，参与整句候选排序。"
    case .phrases: return "用一小段字母，输入经常说的话。"
    case .about: return "基于 Rime 与鼠须管构建的开源 Mac 输入法。"
    }
  }

  private var inputPage: some View {
    Form {
      Section("拼音方案") {
        Picker("输入方案", selection: $model.settings.schema) {
          Text("全拼 · 简体中文").tag("luna_pinyin_simp")
          Text("全拼 · 繁体中文").tag("luna_pinyin")
          Text("小鹤双拼 · 简体中文").tag("qingtype_double_pinyin")
          if model.settings.rimeIce != nil { Text("雾凇拼音 · 简体中文").tag("rime_ice") }
        }
        Stepper("每页候选数：\(model.settings.pageSize)", value: $model.settings.pageSize, in: 3...9)
      }
      FuzzyPinyinSection(settings: $model.settings.fuzzyPinyin)
      RimeIceSection(model: model)
      Section("试打") {
        TextField("切换到清言，在这里输入拼音", text: $model.sampleText, axis: .vertical)
          .lineLimit(2...4).accessibilityLabel("试打输入框")
        Text("请先在系统输入菜单中选择清言。这里的文字只用于试打，不会保存。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Section("按键习惯") {
        Toggle("按 Shift 切换中英文", isOn: $model.settings.useShift)
        Text("空格确认候选，数字键选词；减号与等号翻页。")
          .font(.callout).foregroundStyle(.secondary)
      }
    }.formStyle(.grouped).fixedSize(horizontal: false, vertical: true)
  }

  private var appearancePage: some View {
    VStack(alignment: .leading, spacing: 18) {
      if model.settings.useSystemCandidates {
        GroupBox {
          VStack(alignment: .leading, spacing: 12) {
            Label("原生样式候选窗", systemImage: "macwindow").font(.headline)
            Text("单行与展开网格使用同一个 AppKit 窗口，随系统调整明暗与高亮颜色。")
              .font(.callout).foregroundStyle(.secondary)
            Button("前往试打") { model.section = .input }
          }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }
      } else { CandidatePreview(settings: model.settings) }
      Form {
        Section("候选窗") {
          Toggle("使用原生样式候选窗", isOn: $model.settings.useSystemCandidates)
          Picker("排列", selection: $model.settings.layout) {
            Text("横排").tag("linear")
            Text("竖排").tag("stacked")
          }.pickerStyle(.segmented)
          Stepper("候选字号：\(model.settings.fontSize)", value: $model.settings.fontSize, in: 12...32)
          if !model.settings.useSystemCandidates {
            Toggle("在文稿中显示正在输入的拼音", isOn: $model.settings.inlinePreedit)
          }
        }
      }.formStyle(.grouped).fixedSize(horizontal: false, vertical: true)
      Text(model.settings.useSystemCandidates ? "原生样式候选窗在文稿中显示正在输入的拼音。保存后切换到清言即可试打。" : "上方为自定义候选窗示意，实际效果请在输入框中验证。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }

  private var dictionariesPage: some View {
    VStack(alignment: .leading, spacing: 18) {
      GroupBox("基础词库") {
        Label("明月拼音 · 内置", systemImage: "checkmark.circle.fill")
          .frame(maxWidth: .infinity, alignment: .leading).padding(10)
      }
      GroupBox("我的词库") {
        VStack(alignment: .leading, spacing: 14) {
          if model.settings.dictionaries.isEmpty {
            Text("导入 .dict.yaml 格式的 Rime 词库，可包含同一文件夹内的依赖词库。")
              .foregroundStyle(.secondary)
          }
          ForEach($model.settings.dictionaries) { $dictionary in
            Toggle(isOn: $dictionary.enabled) {
              VStack(alignment: .leading, spacing: 4) {
                Text(dictionary.name)
                Text("\(dictionary.wordCount) 条 · \(dictionary.tables.count) 个词库文件")
                  .font(.caption).foregroundStyle(.secondary)
              }
            }
          }
          Button("导入词库…", systemImage: "plus") { model.chooseImport(model: false) }
            .disabled(model.busy)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
      }
      Text("勾选需要启用的词库，再点“保存并应用”。导入的词条会与基础词库一起参与全拼和双拼输入。")
        .font(.callout).foregroundStyle(.secondary)
      deploymentStatus
    }
  }

  private var modelsPage: some View {
    VStack(alignment: .leading, spacing: 18) {
      WanxiangCard(model: model)
      GroupBox("语言模型") {
        VStack(alignment: .leading, spacing: 14) {
          Picker("当前模型", selection: Binding(
            get: { model.settings.activeModelID ?? "" },
            set: { model.settings.activeModelID = $0.isEmpty ? nil : $0 })) {
              Text("不使用模型").tag("")
              ForEach(model.settings.models) { asset in Text(asset.name).tag(asset.id) }
            }
          if let asset = model.settings.activeModel {
            Text("\(ByteCountFormatter.string(fromByteCount: asset.byteCount, countStyle: .file)) · \(asset.variant == "hant" ? "繁体中文" : asset.variant == "hans" ? "简体中文" : "自定义模型") · 本地运行")
              .font(.callout).foregroundStyle(.secondary)
            if let state = model.modelFileStates[asset.id], state != .present {
              Label("模型文件缺失或已损坏，请重新导入或检查模型更新。", systemImage: "exclamationmark.triangle.fill")
                .font(.callout).foregroundStyle(.orange)
            }
          }
          Button("导入模型…", systemImage: "square.and.arrow.down") { model.chooseImport(model: true) }
            .disabled(model.busy)
          if FileManager.default.fileExists(atPath: model.existingWanxiang.path) {
            Button("从现有 Rime 导入万象模型") { model.importFiles([model.existingWanxiang], model: true) }
              .disabled(model.busy)
          }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
      }
      Text("支持 Rime 的 .gram 模型。简体模型应配合简体输入方案；模型文件导入后，需要重新部署并由引擎加载才能生效。")
        .font(.callout).foregroundStyle(.secondary)
      Link("万象模型项目", destination: URL(string: "https://github.com/amzxyz/RIME-LMDG")!)
      deploymentStatus
    }
  }

  private var deploymentStatus: some View {
    GroupBox("应用状态") {
      VStack(alignment: .leading, spacing: 10) {
        if let warning = model.runtimeModelWarning {
          Label("最近一次输入服务启动：\(warning)", systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(Color.orange)
        }
        if let report = model.deployment, model.deploymentIsCurrent {
          Label(report.message, systemImage: report.success ? "checkmark.circle.fill" : "exclamationmark.circle")
            .foregroundStyle(report.success ? Color.secondary : Color.orange)
          Text("上次检查：\(report.completedAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption).foregroundStyle(.secondary)
          Button("查看部署日志") { NSWorkspace.shared.open(URL(fileURLWithPath: report.logDirectory)) }
        } else {
          Text("保存并应用后，这里会显示实际的词库编译和模型加载结果。")
            .font(.callout).foregroundStyle(.secondary)
        }
      }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
    }
  }

  private var phrasesPage: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("编码使用小写英文字母，例如输入“jj”得到“继续加油”。")
        .font(.callout).foregroundStyle(.secondary)
      if model.settings.phrases.isEmpty {
        VStack(spacing: 10) {
          Image(systemName: "text.badge.plus").font(.largeTitle).foregroundStyle(.secondary)
          Text("添加你的第一条短语").font(.headline)
          Text("常用句、地址和专业术语都可以放在这里。")
            .font(.callout).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 32)
      }
      ForEach($model.settings.phrases) { $phrase in
        HStack(alignment: .top) {
          TextField("编码", text: $phrase.code).frame(width: 90)
            .accessibilityLabel("短语编码")
          TextField("短语内容", text: $phrase.text).accessibilityLabel("短语内容")
          Button {
            model.settings.phrases.removeAll { $0.id == phrase.id }
          } label: { Image(systemName: "minus.circle") }
            .buttonStyle(.borderless).help("删除短语").accessibilityLabel("删除短语")
        }.textFieldStyle(.roundedBorder)
      }
      Button("添加短语", systemImage: "plus") {
        model.settings.phrases.append(QuickPhrase(code: "", text: ""))
      }
    }
  }

  private var aboutPage: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 16) {
        Image(systemName: "character.bubble.fill").font(.system(size: 44)).foregroundStyle(.tint)
        VStack(alignment: .leading, spacing: 5) {
          Text("清言输入法").font(.title2.bold())
          Text("\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "版本未知")")
            .foregroundStyle(.secondary)
        }
      }
      GroupBox("启用输入法") {
        VStack(alignment: .leading, spacing: 12) {
          Label(model.installed ? "已安装到当前用户的输入法目录" : "尚未安装输入法程序",
                systemImage: model.installed ? "checkmark.circle.fill" : "circle.dashed")
          Text(model.installed
            ? "打开系统设置，在“键盘 → 文本输入 → 编辑”中添加“清言”。如果没有出现，请注销后重新登录。"
            : "前往“开始使用”，点击“安装并启用清言”。")
            .font(.callout).foregroundStyle(.secondary)
          Button("打开键盘设置") {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)
          }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
      }
      GroupBox("配置与词库") {
        VStack(alignment: .leading, spacing: 10) {
          Text("配置保存在 ~/Library/QingType。每次保存会备份上一次设置；快捷短语与用户词频均保留在本机。")
            .font(.callout).foregroundStyle(.secondary)
          Button("打开配置文件夹", action: model.showFolder)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
      }
      Text("致谢 Rime、鼠须管及小鹤双拼方案的贡献者。项目沿用 GPL-3.0 许可；组件来源见项目内 THIRD_PARTY.md。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
}

struct CandidatePreview: View {
  var settings: QingTypeSettings
  private let candidates = ["你好", "拟好", "你", "呢", "泥"]
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("候选窗预览").font(.caption).foregroundStyle(.secondary)
        Spacer()
        Text("ni hao").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
      }
      VStack(alignment: .leading, spacing: 8) {
        if !settings.inlinePreedit {
          Text("ni hao").font(.system(size: CGFloat(settings.fontSize))).foregroundStyle(.secondary).padding(.horizontal, 8)
        }
        if settings.layout == "linear" {
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { ForEach(0..<min(settings.pageSize, 5), id: \.self) { candidate($0) } }
            HStack(spacing: 4) { ForEach(0..<3, id: \.self) { candidate($0) } }
          }
        } else {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<min(settings.pageSize, 5), id: \.self) { candidate($0) }
          }
        }
      }
      .padding(6).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
      .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, lineWidth: 0.5))
      .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
      .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
    }
    .padding(18)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    .accessibilityElement(children: .combine)
  }

  private func candidate(_ index: Int) -> some View {
    HStack(spacing: 7) {
      Text("\(index + 1)").font(.system(size: CGFloat(max(11, settings.fontSize - 5))))
        .opacity(index == 0 ? 0.8 : 0.55)
      Text(candidates[index]).font(.system(size: CGFloat(settings.fontSize)))
    }
    .padding(.horizontal, 9).padding(.vertical, 5)
    .foregroundStyle(index == 0 ? Color(nsColor: .alternateSelectedControlTextColor) : Color.primary)
    .background(index == 0 ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6))
  }
}
