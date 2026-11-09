# 模糊拼音

打开清言设置的「输入设置」，开启「模糊拼音」，展开「选择模糊音」，勾选需要互通的读音，再点「保存并应用」。默认关闭，不会自动改变已有输入习惯；关闭总开关会保留勾选的组合。

支持内置全拼简体、全拼繁体、小鹤双拼简体与已安装的雾凇拼音。不需要下载额外词库或模型，雾凇仍是独立的可选组件。

| 类型 | 可选组合 |
| --- | --- |
| 声母 | z ↔ zh、c ↔ ch、s ↔ sh、n ↔ l、f ↔ h |
| 韵母 | an ↔ ang、en ↔ eng、in ↔ ing、ian ↔ iang、uan ↔ uang |

各组为双向匹配。例如开启 n/l 后，输入 `na` 也能匹配 `la` 的候选；原来的正确拼写继续有效。an/ang 与 ian/iang、uan/uang 分别选择。

候选顺序继续由 Rime 的词频、学习记录及已启用的语言模型决定，不保证精确读音候选永远排在模糊读音前面。模糊音与按错键纠错分别处理，原有简拼与纠错规则保留。

保存使用现有的配置校验、备份和部署恢复流程。有手工维护且没有清言管理标记的配置时会停止写入。模糊音开关不重命名或清空学习数据库。

## 开发验证

`scripts/test.sh` 包含设置迁移、分组配置、手工配置保护、失败恢复及隔离真实引擎回归。引擎测试比较编译后的完整规则，验证简体继承只插入一次、规则位于简拼/双拼映射之前，以及开关后实际学习记录和排序保留。

```sh
./scripts/build-dev.sh
QINGTYPE_REQUIRE_RIME_ICE_TEST=1 \
QINGTYPE_RIME_ICE_TEST_PACKAGE="$PWD/build/rime-ice-fixture" ./scripts/test.sh
```

专项引擎测试可使用本地已验证的简体模型副本，模型只导入临时测试目录：

```sh
QINGTYPE_RIME_ICE_TEST_PACKAGE="$PWD/build/rime-ice-fixture" \
QINGTYPE_FUZZY_TEST_MODEL=/path/to/wanxiang-lts-zh-hans.gram \
build/QingType.app/Contents/MacOS/QingType --fuzzy-pinyin-engine-test
```

隔离引擎与界面检查不能替代实际安装后的真人输入验收；各 macOS 版本、宿主应用及长期输入体验需要分别记录。
