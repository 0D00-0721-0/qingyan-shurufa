import AppKit
import SwiftUI

extension SettingsModel {
  func refreshInstallation() {
    refreshRuntimeModelStatus()
    installationStatus = InstallationService.status()
    installedVersion = installationStatus?.installedVersion
    refreshUninstallState()
    refreshModelFileStates()
    // The full signature check runs off the main thread; a broken install then
    // switches the button to "修复安装" instead of "已安装".
    Task.detached {
      let full = InstallationService.status(verifyingSignature: true)
      await MainActor.run {
        self.installationStatus = full
        self.installedVersion = full.installedVersion
      }
    }
  }

  var installAction: QingTypeInstallAction {
    guard let status = installationStatus else { return .install }
    return QingTypeInstallationCheck.action(for: status)
  }

  var installTitle: String {
    switch installAction {
    case .install: return "安装并启用清言"
    case .update: return "更新输入法"
    case .repair: return "修复安装"
    case .deployOnly: return inputEnabled ? "已安装" : "启用清言"
    case .blockedNewer: return "已安装较新版本"
    case .reinstall: return "重新安装"
    }
  }

  func installInputMethod() {
    guard !busy, !loadFailed else { return }
    guard !isDirty else { failed = true; message = "请先保存当前更改，再安装或修复输入法。"; return }
    busy = true; failed = false
    message = installAction == .deployOnly ? "正在重新部署基础中文输入…" : "正在安装清言并准备基础中文输入…"
    Task {
      defer { busy = false; refreshInstallation() }
      do {
        deployment = try await InstallationService.install(mode: .automatic)
        settings = try .load(); saved = settings
        inputEnabled = (try? await InstallationService.inputAvailable()) ?? false
        message = inputEnabled ? "清言已安装并启用，可以从系统输入菜单选择清言开始输入。" : "清言已安装。请打开键盘设置添加清言，再开始输入。"
      } catch { failed = true; message = error.localizedDescription }
    }
  }

  func reinstallInputMethod() {
    guard !busy, !loadFailed else { return }
    guard !isDirty else { failed = true; message = "请先保存当前更改，再重新安装输入法。"; return }
    busy = true; failed = false; message = "正在重新安装清言输入法…"
    Task {
      defer { busy = false; refreshInstallation() }
      do {
        deployment = try await InstallationService.install(mode: .reinstall)
        settings = try .load(); saved = settings
        inputEnabled = (try? await InstallationService.inputAvailable()) ?? false
        message = inputEnabled ? "清言输入法已重新安装并启用。" : "清言已重新安装。请打开键盘设置添加清言，再开始输入。"
      } catch { failed = true; message = error.localizedDescription }
    }
  }

  func checkWanxiangUpdate() {
    guard !busy, !loadFailed, inputReady else { return }
    guard !isDirty else { failed = true; message = "请先保存当前更改，再安装万象模型。"; return }
    let original = saved
    busy = true; failed = false; canCancelDownload = true
    checkingComponentUpdate = true
    transferProgress = nil; message = "正在检查万象模型更新…"
    componentTask = Task {
      defer { busy = false; checkingComponentUpdate = false; canCancelDownload = false; transferProgress = nil; componentTask = nil }
      var downloaded: QingTypeDownloadedAsset?
      defer { if let downloaded { try? FileManager.default.removeItem(at: downloaded.directory) } }
      do {
        let update = try await QingTypeWanxiang.checkUpdate(schema: original.schema, models: original.models, directory: QingTypePaths.userDirectory)
        try Task.checkCancellation()
        guard try QingTypeSettings.load() == original else { throw SettingsError.invalid("设置已被其他程序修改，请重开清言后重试。") }
        if update.installed != nil {
          message = "已安装的万象模型已是官方最新版本，无需下载。"
          return
        }
        checkingComponentUpdate = false; message = "正在下载万象模型…"
        downloaded = try await QingTypeWanxiang.download(update) { [self] progress in
          Task { @MainActor in if self.canCancelDownload { self.transferProgress = progress; self.message = "正在下载万象模型…" } }
        }
        try Task.checkCancellation()
        canCancelDownload = false; transferProgress = nil; message = "正在校验模型并启用…"
        guard try QingTypeSettings.load() == original else { throw SettingsError.invalid("设置已被其他程序修改，请重开清言后重试。") }
        let file = downloaded!.file
        let expectedSHA256 = downloaded!.sha256
        var model = try await Task.detached { try QingTypeContent.importGrammar(from: file, into: QingTypePaths.userDirectory, expectedSHA256: expectedSHA256) }.value
        model.source = downloaded!.repository; model.release = downloaded!.release
        var updated = original
        // An official update supersedes the previous official model for the same
        // variant. Remove that record (and later its file) so repeated updates do
        // not stack up several entries with the same display name.
        let superseded = QingTypeModelAssets.supersededOfficialModels(
          in: original.models, replacing: model, repository: QingTypeWanxiang.repository)
        updated.models.removeAll { asset in superseded.contains { $0.id == asset.id } }
        updated.models.removeAll { $0.id == model.id }
        updated.models.append(model)
        updated.activeModelID = model.id
        let report = try await DeploymentService.apply(updated)
        settings = updated; saved = updated; deployment = report
        refreshModelFileStates()
        for old in superseded where !updated.models.contains(where: { $0.id == old.id }) {
          try? FileManager.default.removeItem(at: QingTypePaths.userDirectory.appendingPathComponent(old.language + ".gram"))
        }
        message = superseded.isEmpty ? "万象模型已启用，之后输入可离线使用。"
          : "万象模型已启用，并移除了 \(superseded.count) 个旧官方版本。"
      } catch {
        if Task.isCancelled || (error as? URLError)?.code == .cancelled {
          message = checkingComponentUpdate ? "已取消模型更新检查。" : "已取消下载，当前输入设置保持不变。"
        }
        else { failed = true; message = error.localizedDescription }
      }
    }
  }

  func selectInstalledIce() {
    guard !busy, settings.rimeIce != nil else { return }
    settings.schema = "rime_ice"; save()
  }
  func selectQingType() {
    guard !busy, inputReady else { return }
    Task {
      do {
        _ = try await InstallationService.command(["--select-input-source"])
        message = try await InstallationService.state().selected ? "已选择清言，可以开始输入。" : "请从系统输入菜单选择清言。"
        failed = false
      } catch { failed = true; message = error.localizedDescription }
    }
  }
  func openKeyboardSettings() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!) }
}

struct WelcomePage: View {
  @ObservedObject var model: SettingsModel
  @State private var confirmReinstall = false
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 18) {
        Image(systemName: "character.bubble.fill").font(.system(size: 44)).foregroundStyle(.tint)
        VStack(alignment: .leading, spacing: 5) {
          Text("从一句“你好”开始").font(.title2.weight(.semibold))
          Text("基础中文输入随应用提供，增强组件按需安装。")
            .font(.callout).foregroundStyle(.secondary)
        }
      }.padding(.bottom, 2)
      GroupBox("清言输入法") {
        VStack(alignment: .leading, spacing: 12) {
          Label(model.inputEnabled ? "已准备好中文输入" : "安装并启用基础中文输入", systemImage: model.inputEnabled ? "checkmark.circle.fill" : "keyboard")
            .font(.headline)
          Text("内置全拼与小鹤双拼。完成安装后，从系统输入菜单选择“清言”即可输入。")
            .font(.callout).foregroundStyle(.secondary)
          HStack {
            if InstallationService.payload != nil || model.installedVersion != nil {
              if model.installAction == .deployOnly && model.inputEnabled {
                Label(model.installTitle, systemImage: "checkmark.circle.fill")
                  .font(.callout).foregroundStyle(.secondary)
                Button("重新安装…") { confirmReinstall = true }
                  .disabled(model.busy || model.loadFailed)
              } else if model.installAction == .blockedNewer {
                Label("已安装较新版本 \(model.installedVersion ?? "")", systemImage: "checkmark.circle.fill")
                  .font(.callout).foregroundStyle(.secondary)
              } else if model.installAction == .reinstall {
                Button("重新安装…") { confirmReinstall = true }
                  .buttonStyle(.borderedProminent).disabled(model.busy || model.loadFailed)
              } else {
                Button(model.installTitle, action: model.installInputMethod).buttonStyle(.borderedProminent)
                  .disabled(model.busy || model.loadFailed || model.installAction == .blockedNewer)
              }
            }
            Button("打开键盘设置", action: model.openKeyboardSettings).disabled(model.busy)
            if let version = model.installedVersion, model.installAction != .deployOnly {
              Text("已安装 \(version)").font(.caption).foregroundStyle(.secondary)
            }
          }
          if model.installAction == .reinstall {
            Text("已安装程序与安装包版本相同，但内容不同。请确认后重新安装。")
              .font(.caption).foregroundStyle(.secondary)
          }
          if model.inputReady { Button("切换到清言", action: model.selectQingType).disabled(model.busy) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
      }
      VStack(alignment: .leading, spacing: 6) {
        Text("按需添加").font(.headline)
        Text("两项都可以跳过，之后随时回来安装。候选窗始终使用清言的原生界面。")
          .font(.callout).foregroundStyle(.secondary)
        if !model.inputReady { Text("请先安装或更新清言，再选择增强组件。").font(.caption).foregroundStyle(.secondary) }
      }
      GroupBox {
        VStack(alignment: .leading, spacing: 12) {
          Label("雾凇拼音", systemImage: "text.book.closed").font(.headline)
          Text("增加雾凇词库、英文混输、拼写纠错及日期等扩展。")
            .font(.callout).foregroundStyle(.secondary)
          HStack {
            if model.settings.rimeIce != nil {
              Label("已安装", systemImage: "checkmark.circle.fill").font(.callout).foregroundStyle(.secondary)
              if model.settings.schema != "rime_ice" { Button("使用雾凇拼音", action: model.selectInstalledIce) }
              else { Text("正在使用").font(.callout).foregroundStyle(.secondary) }
            } else {
              Button("安装并使用雾凇") { model.installRimeIce(activate: true) }
            }
            Link("了解雾凇", destination: URL(string: "https://github.com/iDvel/rime-ice")!)
          }.disabled(model.busy || !model.inputReady)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
      }
      WanxiangCard(model: model)
      Text("下载组件需要网络；日常输入、个人词库和已安装的模型均在本机运行。")
        .font(.caption).foregroundStyle(.secondary)
    }.onAppear { model.refreshInstallation() }
    .alert("重新安装清言输入法？", isPresented: $confirmReinstall) {
      Button("取消", role: .cancel) {}
      Button("重新安装") { model.reinstallInputMethod() }
    } message: {
      Text("会中断当前输入，重新复制程序并重新部署；个人词库、学习记录和设置保留。")
    }
  }
}

struct WanxiangCard: View {
  @ObservedObject var model: SettingsModel
  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 12) {
        Label("万象语言模型", systemImage: "brain").font(.headline)
        Text("为拼音整句候选提供本地语言模型。按当前方案选择简体或繁体，下载约 400 MB。")
          .font(.callout).foregroundStyle(.secondary)
        HStack {
          if let active = model.settings.activeModel {
            let fileState = model.modelFileStates[active.id]
            let broken = fileState != nil && fileState != .present
            Label(broken ? "模型文件缺失或已损坏：\(active.name)"
                         : model.runtimeModelWarning == nil ? "已启用：\(active.name)" : "最近启动未启用：\(active.name)",
                  systemImage: broken || model.runtimeModelWarning != nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
              .font(.callout).foregroundStyle(.secondary)
          }
          Button(model.settings.models.isEmpty ? "下载安装并启用万象" : "检查模型更新", action: model.checkWanxiangUpdate)
            .disabled(model.busy || !model.inputReady)
        }
        Link("模型来源与许可", destination: URL(string: "https://github.com/amzxyz/rime-wanxiang-data")!)
          .font(.caption)
      }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
    }
  }
}
