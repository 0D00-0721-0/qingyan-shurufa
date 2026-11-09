import AppKit
import SwiftUI

extension SettingsModel {
  func chooseRimeIceFolder() {
    guard !busy, !loadFailed else { return }
    let panel = NSOpenPanel()
    panel.title = "导入完整雾凇方案"
    panel.message = "选择包含 rime_ice.schema.yaml、英文及拆字方案、词典与 Lua 资源的文件夹。"
    panel.prompt = "安装方案"
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    installRimeIce(folder: url)
  }

  func checkRimeIceUpdate() {
    guard !busy, !loadFailed, inputReady else { return }
    let original = saved
    pendingRimeIceUpdate = nil
    busy = true; failed = false; canCancelDownload = true
    checkingComponentUpdate = true; transferProgress = nil
    message = "正在检查雾凇更新…"
    componentTask = Task {
      defer { busy = false; checkingComponentUpdate = false; canCancelDownload = false; componentTask = nil }
      do {
        let update = try await QingTypeRimeIceUpdates.check(installed: original.rimeIce, directory: QingTypePaths.userDirectory)
        try Task.checkCancellation()
        guard try QingTypeSettings.load() == original else { throw SettingsError.invalid("设置已被其他程序修改，请重开清言后重试。") }
        if update.upToDate {
          message = "雾凇已是最新版本（\(update.installedVersion ?? "已安装")），无需下载。"
        } else {
          pendingRimeIceUpdate = update
          message = "发现雾凇更新，等待确认安装。"
        }
      } catch {
        if Task.isCancelled || (error as? URLError)?.code == .cancelled { message = "已取消雾凇更新检查。" }
        else { failed = true; message = error.localizedDescription }
      }
    }
  }

  func installRimeIce(folder: URL? = nil, activate: Bool = false, update: QingTypeRimeIceUpdate? = nil) {
    guard !busy, !loadFailed, inputReady else { return }
    guard !isDirty else { failed = true; message = "请先保存当前更改，再安装雾凇。"; return }
    let original = saved
    let hadInstalled = original.rimeIce != nil
    guard folder != nil || update != nil || !hadInstalled else { return }
    pendingRimeIceUpdate = nil
    busy = true; failed = false
    message = folder == nil ? "正在准备下载雾凇官方完整包…" : "正在校验雾凇完整方案…"
    canCancelDownload = folder == nil; transferProgress = nil
    componentTask = Task {
      defer { busy = false; canCancelDownload = false; transferProgress = nil; componentTask = nil }
      var downloaded: RimeIceDownload?
      defer { if let downloaded { try? FileManager.default.removeItem(at: downloaded.directory) } }
      do {
        guard try QingTypeSettings.load() == original else { throw SettingsError.invalid("设置已被其他程序修改，请重开清言后重试。") }
        if folder == nil {
          let package: QingTypeRimeIceUpdate
          if let update { package = update }
          else { package = try await QingTypeRimeIceUpdates.check(installed: nil, directory: QingTypePaths.userDirectory) }
          try Task.checkCancellation()
          message = "正在下载并校验雾凇官方完整包…"
          downloaded = try await QingTypeRimeIceDownload.official(package) { [self] progress in
            Task { @MainActor in if self.canCancelDownload { self.transferProgress = progress } }
          }
        }
        try Task.checkCancellation()
        canCancelDownload = false; transferProgress = nil
        guard let root = folder ?? downloaded?.root else { throw SettingsError.invalid("找不到雾凇方案文件。") }
        message = "正在安装雾凇依赖并验证当前方案…"
        let result = try await DeploymentService.installRimeIce(from: root, saved: original,
          provenance: downloaded?.provenance ?? "本地方案文件夹", sha256: downloaded?.sha256, activate: activate)
        saved = result.settings
        settings = result.settings
        deployment = result.report
        if let warning = result.backupWarning {
          failed = true; message = warning
        } else if result.settings.schema == "rime_ice" {
          message = hadInstalled ? "雾凇拼音已更新，正在使用。" : "雾凇拼音已安装并启用。"
        } else {
          message = hadInstalled ? "雾凇拼音已更新。选择“雾凇拼音”并保存应用即可使用。"
            : "雾凇已安装。选择“雾凇拼音”并保存应用即可使用。"
        }
      } catch {
        if Task.isCancelled || (error as? URLError)?.code == .cancelled { message = "已取消下载，当前输入设置保持不变。" }
        else { failed = true; message = error.localizedDescription }
      }
    }
  }

  func revealRimeIceHistory() {
    do {
      let backups = QingTypePaths.userDirectory.appendingPathComponent("backups")
      let history = try QingTypeBackupRetention.unmarkedBackups(in: backups, prefix: "rime-ice-")
      if history.isEmpty { failed = false; message = "没有未标记的雾凇历史备份。" }
      else { NSWorkspace.shared.activateFileViewerSelecting(history) }
    } catch { failed = true; message = error.localizedDescription }
  }
}

struct RimeIceSection: View {
  @ObservedObject var model: SettingsModel
  var body: some View {
    Section("雾凇拼音") {
      if let asset = model.settings.rimeIce {
        LabeledContent("已安装方案", value: "雾凇拼音 · \(asset.version)")
        Text("\(asset.source) · \(asset.files.count) 个资源文件")
          .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
      } else {
        Text("安装官方完整方案，包含中文词库、英文、拆字反查及 Lua 扩展。")
          .font(.callout).foregroundStyle(.secondary)
      }
      HStack {
        if model.settings.rimeIce == nil { Button("下载并安装官方方案") { model.installRimeIce() } }
        else { Button("检查雾凇更新", action: model.checkRimeIceUpdate) }
        Button("从方案文件夹导入…", action: model.chooseRimeIceFolder)
        Link("上游项目", destination: URL(string: "https://github.com/iDvel/rime-ice")!)
      }.disabled(model.busy || model.loadFailed || !model.inputReady)
      if let update = model.pendingRimeIceUpdate {
        let size = ByteCountFormatter.string(fromByteCount: update.asset.size, countStyle: .file)
        let date = update.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "更新时间未知"
        LabeledContent("官方完整包", value: "\(update.release) · \(date) · \(size)")
        Button("下载并安装更新") { model.installRimeIce(update: update) }
          .disabled(model.busy || model.loadFailed || !model.inputReady)
      }
      Button("在访达查看历史备份…", action: model.revealRimeIceHistory)
        .disabled(model.busy)
      Text("安装后可在上方选择雾凇拼音；个人词库、快捷短语和已启用的简体语言模型会一同使用。")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
}
