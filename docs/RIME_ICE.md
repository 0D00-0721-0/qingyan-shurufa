# 雾凇拼音方案

在清言设置的「输入 → 雾凇拼音」点击「下载并安装官方方案」。下载来源是
[iDvel/rime-ice 的官方 Release](https://github.com/iDvel/rime-ice/releases)，
读取 `full.zip` 的发行信息并校验大小及 SHA-256。安装成功后，在上方「输入方案」
选择「雾凇拼音 · 简体中文」，点击「保存并应用」。安装本身保留当前选中的方案。

网络不便时，可以从官方仓库或完整包取得文件，解压后用「从方案文件夹导入…」。
选择的文件夹应直接包含 `rime_ice.schema.yaml`、`melt_eng.schema.yaml`、
`radical_pinyin.schema.yaml`、对应词典、`default.yaml`、`LICENSE` 和
`cn_dicts` / `en_dicts` / `lua` / `opencc`。只有中文 `.dict.yaml` 的不完整目录不能作为完整方案安装。
本地导入会运行其中的 Rime Lua 模块，请使用可信来源。

## 与现有功能的关系

- 个人词库、已启用的导入词库并入受管理的 `qingtype_ice_main` 主词典。
  个人词条优先列入词表，避免重复词条的固定词频被基础词典遮盖。
- 快捷短语继续使用清言自己的 `custom_phrase.txt`。
- 已启用的简体 `.gram` 模型继续生成当前方案的 `grammar/language` 与拼音索引配置。
  雾凇的英文、日期、拆字、Emoji 等功能来自其完整方案及 Lua/OpenCC 依赖。
- 用户学习词典的逻辑名称固定为 `rime_ice`。固定词库的增删不会删除已学习的同名词。
- 目前接入雾凇全拼。原有小鹤双拼保持独立；没有把雾凇自带的其他双拼方案一并注册。

## 文件保护与更新

资源只安装到 `~/Library/QingType`，不会写入原 `~/Library/Rime`。
安装器使用三份方案文件、词典、Lua、OpenCC 和符号资源的白名单，不复制用户数据库、
其他 `.custom.yaml`、客户端 `squirrel.yaml` 或上游 `custom_phrase.txt`。
包内的 `default.yaml` 改名为 `qingtype_ice_defaults.yaml`，并重写相关引用，
避免改变已有全拼、小鹤方案的默认行为。

`scheme-packages/rime-ice.json` 记录来源、版本、可用时的发行包 SHA-256、每个文件的 SHA-256，
原许可证保存为 `scheme-packages/rime-ice-LICENSE.txt`。官方 `nightly` 标签会变化，
因此记录包哈希比仅记录标签更准确。

已有方案可点「检查雾凇更新」。有更新时会显示官方完整包的更新时间与大小，点「下载并安装更新」才下载并部署。

更新前备份将被替换的文件并记录旧清单，保护与上一份清单不符的手工修改。
安装时短暂退出输入服务，写入资源及设置后验证当前方案；部署失败时恢复资源、配置，
再次验证恢复。恢复不成功时保持输入服务停止，并报告备份位置。
下载与校验在停止输入服务之前进行。

成功部署并校验上一版资源后，清言保留一份托管回退点。未标记的历史备份可用「在访达查看历史备份」定位。

## 开发验证

`scripts/test.sh` 始终运行合成包的隔离、依赖、清单、恢复、路径及 ZIP 校验测试。
真实上游包的引擎测试可用：

```sh
QINGTYPE_RIME_ICE_TEST_PACKAGE=/absolute/path/to/rime-ice ./scripts/test.sh
# 可选：同时用指定简体模型验证方案配置与加载（文件仅复制到临时测试目录）
QINGTYPE_RIME_ICE_TEST_MODEL=/absolute/path/to/model.gram \
  build/QingType.app/Contents/MacOS/QingType --rime-ice-engine-test /absolute/path/to/rime-ice
```

CI 使用固定的上游提交，避免 `nightly` 更新使回归样本漂移。
真实应用中的组合输入、候选窗和上屏体验仍属于人工验收；引擎测试不能替代它。

安装/清单/备份思路参考 [Squirrel Panel](https://github.com/wolfprince12/squirrel-Panel)
的 `DictionaryPackageManager`、`SchemaCatalog` 与 `RimeIceConfigStore`，
在清言自己的数据目录和部署事务中独立实现。来源与许可见 `THIRD_PARTY.md`。
