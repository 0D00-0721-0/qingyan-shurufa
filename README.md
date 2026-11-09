# 清言输入法 · QingType

<p align="center">
  <strong>让 Rime 在 macOS 上更容易安装、配置和管理。</strong>
</p>

<p align="center">
  <a href="https://github.com/0D00-0721-0/qingyan-shurufa/releases">下载最新预览版</a> ·
  <a href="https://github.com/0D00-0721-0/qingyan-shurufa/issues/new">反馈问题 / 提交建议</a> ·
  <a href="docs/INSTALLATION.md">安装指南</a>
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple%20Silicon-arm64-blue">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-native-orange?logo=swift">
  <img alt="GPL-3.0" src="https://img.shields.io/badge/license-GPL--3.0-green">
  <img alt="Latest release" src="https://img.shields.io/github/v/release/0D00-0721-0/qingyan-shurufa?include_prereleases">
  <img alt="GitHub stars" src="https://img.shields.io/github/stars/0D00-0721-0/qingyan-shurufa?style=social">
</p>

**QingType（清言）** 是一款基于 [Rime](https://rime.im/) 与 [鼠须管 Squirrel](https://github.com/rime/squirrel) 的开源 macOS 中文输入法。它通过原生 macOS 界面，把输入方案、词库、学习数据和本地语言模型的常用管理流程整合起来。

> **当前源码版本为 0.6.6。** 预览版支持 Apple Silicon（M 系列）Mac，要求 macOS 14 或更高版本。下载前请阅读预览版说明和已知限制。

## 下载与安装

[查看 GitHub 预览版](https://github.com/0D00-0721-0/qingyan-shurufa/releases)

1. 在 Releases 页面下载 DMG 安装包（普通用户请下载 Assets 中的安装包，不要下载 Source code）。
2. 打开 DMG，将「清言.app」拖入「应用程序」文件夹。
3. 打开清言，在「开始使用」中点击「安装并启用清言」。
4. 安装完成后，点击「切换到清言」，或从 macOS 输入法菜单选择清言。

基础全拼和小鹤双拼随应用提供，不需要预先安装鼠须管，也不需要先下载雾凇或语言模型。雾凇拼音和万象语言模型是可选组件，可在应用内按需安装。

### 首次打开与预览版须知

当前 GitHub 预览包使用临时签名，**尚未完成 Apple Developer ID 签名与公证**。macOS 可能显示安全提示或阻止首次打开。请仅从本仓库 Releases 下载，并仔细核对发布说明；不要从不明来源下载所谓的修复包。

已知限制：
- 目前仅支持 Apple Silicon（arm64），最低系统版本为 macOS 14。
- 部分应用兼容性、多显示器、休眠恢复和长期运行场景仍在持续验收。
- 在 macOS 27.0.1 上，系统 API 限制可能导致输入源无法由卸载流程自动停用和恢复。若系统无法确认输入源已停用，卸载流程会中止；请勿强制删除仍在使用的输入法组件。
- 预览版尚未完成干净系统上的完整安装、升级、卸载验收，不应视为已覆盖所有环境的正式稳定版。

详细说明见[安装指南](docs/INSTALLATION.md)与[兼容性矩阵](docs/COMPATIBILITY.md)。

## 功能亮点

| 功能 | 说明 |
| --- | --- |
| 原生 macOS 体验 | 基于 Rime/Squirrel，提供原生设置与管理界面 |
| 拼音输入方案 | 内置全拼简体、全拼繁体和小鹤双拼简体 |
| [模糊拼音](docs/FUZZY_PINYIN.md) | 在输入设置中逐组选择平翘舌、n/l、f/h 与前后鼻音，支持内置方案和雾凇，默认关闭 |
| 雾凇拼音 | 在应用内下载安装、导入和管理雾凇方案 |
| 个人词库 | 新增、编辑、删除、搜索、排序、去重，支持 CSV/TSV/TXT 导入与导出 |
| 自动学习 | 使用 Rime 用户词典调整候选排序，支持备份、导出、合并恢复和重置 |
| 词库导入 | 导入 Rime `.dict.yaml`，检查依赖并支持同目录引用的词库 |
| 本地语言模型 | 下载、校验、启用万象模型，也支持本地 `.gram` 文件导入 |
| 快捷短语 | 管理自定义编码与短语 |
| 维护工具 | 检查更新、备份更新、卸载引导和不包含输入内容的诊断摘要 |

## 数据与隐私

- 清言的数据目录为 `~/Library/QingType`。
- 导入的模型和词库会复制到清言自己的数据目录，原始文件不会被修改。
- 用户导入的词库、模型和学习数据不会随项目源码上传。
- 诊断摘要不包含输入内容。提交问题前，请自行检查日志、截图和附件，避免泄露个人信息。

更多说明：[学习数据与隐私](docs/LEARNING.md) · [个人词库](docs/PERSONAL_DICTIONARY.md) · [维护与更新](docs/MAINTENANCE.md)

## 获取帮助与参与项目

- **遇到问题或发现 Bug：** [提交 Bug 反馈](https://github.com/0D00-0721-0/qingyan-shurufa/issues/new?template=bug_report.yml)
- **提出功能建议：** [提交功能建议](https://github.com/0D00-0721-0/qingyan-shurufa/issues/new?template=feature_request.yml)
- **查看已知问题：** [Issues 列表](https://github.com/0D00-0721-0/qingyan-shurufa/issues)
- **查看版本与更新：** [GitHub Releases](https://github.com/0D00-0721-0/qingyan-shurufa/releases)
- **参与开发：** [贡献指南](CONTRIBUTING.md)
- **报告安全漏洞：** [安全问题报告](SECURITY.md)

提交反馈时，请尽量提供清言版本、macOS 版本、芯片型号、复现步骤、预期结果和实际结果。请勿上传真实输入内容、个人词库、模型文件或包含隐私的诊断数据。

## 本机开发

需要 macOS、Swift 工具链和 macOS SDK。使用 Xcode 或 Command Line Tools 均可。

```sh
git clone https://github.com/0D00-0721-0/qingyan-shurufa.git
cd qingtype

./scripts/build-dev.sh
./scripts/test.sh
./scripts/package-app.sh
open "build/distribution/清言.app"
```

构建脚本会按 `dependencies/runtime.lock.json` 获取固定版本的 Rime 运行库，并校验下载内容。默认不会安装鼠须管，也不会读取现有鼠须管用户配置。运行库来源、哈希和许可信息见[固定依赖说明](docs/DEPENDENCIES.md)。

开发安装与卸载：

```sh
./scripts/install-dev.sh
./scripts/uninstall-dev.sh
```

卸载脚本会保留用户数据；如需删除数据，请先阅读应用内维护说明。不要手动删除仍被 macOS 注册或使用的输入法组件。

## 项目文档

- [安装、选装与打包说明](docs/INSTALLATION.md)
- [雾凇拼音安装与数据保护](docs/RIME_ICE.md)
- [个人词库格式与验收](docs/PERSONAL_DICTIONARY.md)
- [学习数据、隐私与验收](docs/LEARNING.md)
- [维护、更新与卸载](docs/MAINTENANCE.md)
- [兼容性矩阵](docs/COMPATIBILITY.md)
- [第三方组件与许可](THIRD_PARTY.md)
- [项目路线图](ROADMAP.md)
- [当前进度](PROGRESS.md)
- [贡献指南](CONTRIBUTING.md)
- [安全问题报告](SECURITY.md)

## 版本与许可证

当前源码版本以仓库根目录 `VERSION` 为准。版本发布记录见 [Releases](https://github.com/0D00-0721-0/qingyan-shurufa/releases)。

清言主项目采用 GPL-3.0。项目包含 Rime/Squirrel 等第三方组件，各组件保留其自身许可证；详见 [THIRD_PARTY.md](THIRD_PARTY.md)。

---

<p align="center">如果 QingType 对你有帮助，欢迎点亮 ⭐ Star，提交反馈，或分享给其他 Mac / Rime 用户。</p>
