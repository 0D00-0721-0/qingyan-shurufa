#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${QINGTYPE_REQUIRE_RIME_ICE_TEST:-0}" == "1" ]] &&
   [[ -z "${QINGTYPE_RIME_ICE_TEST_PACKAGE:-}" || ! -f "${QINGTYPE_RIME_ICE_TEST_PACKAGE:-}/rime_ice.schema.yaml" ]]; then
  echo "FAIL: required Rime Ice test fixture is missing or invalid" >&2
  exit 1
fi
python3 tests/TestRunnerTests.py
python3 tests/VersionTests.py
python3 tests/BuildIdentityTests.py
python3 tests/AcceptanceBuildTests.py
python3 tests/MemoryMonitorTests.py
python3 scripts/version.py check-bundles build/QingType.app 'build/QingType.app/Contents/Applications/QingType Settings.app'
mkdir -p build
swiftc -parse-as-library -swift-version 5 sources/QingTypeInputSafety.swift tests/InputSafetyTests.swift -framework AppKit -o build/input-safety-tests
build/input-safety-tests
yaml_build_dir=$(swift build --package-path dependencies -c release --show-bin-path)
yaml_flags=(-I "$yaml_build_dir" -I "$yaml_build_dir/Modules" -I dependencies/.build/checkouts/Yams/Sources/CYaml/include -L "$yaml_build_dir" -lQingTypeYAML)
swiftc -parse-as-library -swift-version 5 sources/InputSource.swift shared/*.swift tests/InputSourceQueryTests.swift "${yaml_flags[@]}" -framework InputMethodKit -o build/input-source-query-tests
build/input-source-query-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/SettingsSafetyTests.swift "${yaml_flags[@]}" -o build/settings-tests
build/settings-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/FuzzyPinyinTests.swift "${yaml_flags[@]}" -o build/fuzzy-pinyin-tests
build/fuzzy-pinyin-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/ContentTests.swift "${yaml_flags[@]}" -o build/content-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/RuntimeModelTests.swift "${yaml_flags[@]}" -o build/runtime-model-tests
build/runtime-model-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/ContentMemoryTests.swift "${yaml_flags[@]}" -o build/content-memory-tests
QINGTYPE_MEMORY_REPORT="$PWD/build/content-memory-report.json" build/content-memory-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/PersonalDictionaryTests.swift "${yaml_flags[@]}" -o build/personal-dictionary-tests
build/personal-dictionary-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/RimeIceTests.swift "${yaml_flags[@]}" -o build/rime-ice-tests
build/rime-ice-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/SetupTests.swift "${yaml_flags[@]}" -o build/setup-tests
build/setup-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/InstallationTransactionTests.swift "${yaml_flags[@]}" -o build/installation-transaction-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/InstallationStatusTests.swift "${yaml_flags[@]}" -o build/installation-status-tests
build/installation-status-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/MaintenanceRecoveryTests.swift "${yaml_flags[@]}" -o build/maintenance-recovery-tests
build/maintenance-recovery-tests
build/installation-transaction-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/UninstallSafetyTests.swift "${yaml_flags[@]}" -o build/uninstall-safety-tests
build/uninstall-safety-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/GuidedUninstallTests.swift "${yaml_flags[@]}" -o build/guided-uninstall-tests
build/guided-uninstall-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/WanxiangUpdateTests.swift "${yaml_flags[@]}" -o build/wanxiang-update-tests
build/wanxiang-update-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/MetadataRequestTests.swift "${yaml_flags[@]}" -o build/metadata-request-tests
build/metadata-request-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/LearningTests.swift "${yaml_flags[@]}" -o build/learning-tests
build/learning-tests
swiftc -parse-as-library -swift-version 5 shared/*.swift tests/MaintenanceTests.swift "${yaml_flags[@]}" -o build/maintenance-tests
build/maintenance-tests
build/content-tests
build/QingType.app/Contents/MacOS/QingType --engine-smoke-test
build/QingType.app/Contents/MacOS/QingType --factory-engine-test
build/QingType.app/Contents/MacOS/QingType --personal-dictionary-engine-test
build/QingType.app/Contents/MacOS/QingType --fuzzy-pinyin-engine-test
if [[ -n "${QINGTYPE_RIME_ICE_TEST_PACKAGE:-}" ]]; then
  build/QingType.app/Contents/MacOS/QingType --rime-ice-engine-test "$QINGTYPE_RIME_ICE_TEST_PACKAGE"
else
  echo "SKIP: Rime Ice engine integration (fixture not supplied)"
fi
build/QingType.app/Contents/MacOS/QingType --candidate-ui-test
python3 tests/EngineMemoryTests.py
build/QingType.app/Contents/MacOS/QingType --learning-engine-test
python3 tests/InputSourceCacheTests.py
build/QingType.app/Contents/MacOS/QingType --status > build/input-source-status.json
python3 - <<'PY'
from pathlib import Path
import plistlib
import json
app = Path('build/QingType.app/Contents')
info = plistlib.loads((app / 'Info.plist').read_bytes())
assert info['CFBundleIdentifier'] == 'org.qingtype.inputmethod.QingType'
assert info['InputMethodConnectionName'] == info['CFBundleIdentifier'] + '_Connection'
assert info['InputMethodServerControllerClass'] == 'QingType.QingTypeInputController', info
assert not any(key.startswith('SU') for key in info)
assert (app / 'Applications/QingType Settings.app/Contents/MacOS/QingTypeSettings').is_file()
settings_info = plistlib.loads((app / 'Applications/QingType Settings.app/Contents/Info.plist').read_bytes())
assert settings_info['CFBundleShortVersionString'] == info['CFBundleShortVersionString']
assert settings_info.get('LSUIElement') is True, 'Settings must be able to show windows without a Dock icon'
assert json.loads(Path('build/input-source-status.json').read_text())['controllerClassFound']
print('PASS: input source identity, settings bundle, and update isolation')
PY
codesign --verify --deep --strict build/QingType.app
