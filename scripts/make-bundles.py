import plistlib
import sys
from pathlib import Path
from version import product_version

app, settings = map(Path, sys.argv[1:])
version = product_version()
source = plistlib.loads(Path('resources/Info.plist').read_bytes())

def rename(value):
    if isinstance(value, dict):
        return {rename(k): rename(v) for k, v in value.items() if not k.startswith('SU')}
    if isinstance(value, list):
        return [rename(v) for v in value]
    if isinstance(value, str):
        return (value.replace('im.rime.inputmethod.Squirrel', 'org.qingtype.inputmethod.QingType')
                .replace('$(PRODUCT_BUNDLE_IDENTIFIER)', 'org.qingtype.inputmethod.QingType')
                .replace('$(CURRENT_PROJECT_VERSION)', version)
                .replace('Squirrel', 'QingType').replace('rime.pdf', 'qingtype-menu.pdf'))
    return value

info = rename(source)
info.update(CFBundleDisplayName='清言', CFBundleName='清言', CFBundleShortVersionString=version, CFBundleVersion=version,
            CFBundleIconFile='QingType.icns', LSMinimumSystemVersion='14.0')
# Sandboxed text clients resolve the endpoint using the full bundle identifier.
info['InputMethodConnectionName'] = info['CFBundleIdentifier'] + '_Connection'
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
for language in ('zh-Hans', 'zh-Hant', 'en'):
    folder = app / f'Contents/Resources/{language}.lproj'
    folder.mkdir(parents=True, exist_ok=True)
    display = '清言' if language.startswith('zh') else 'QingType'
    (folder / 'InfoPlist.strings').write_text(
        f'"CFBundleName" = "{display}";\n"CFBundleDisplayName" = "{display}";\n'
        f'"org.qingtype.inputmethod.QingType.Hans" = "{display}";\n'
        f'"org.qingtype.inputmethod.QingType.Hant" = "{display} · 繁體";\n')
settings_info = dict(CFBundleIdentifier='org.qingtype.settings', CFBundleExecutable='QingTypeSettings',
                     CFBundleName='清言设置', CFBundleDisplayName='清言设置', CFBundleVersion=version,
                     CFBundleShortVersionString=version, CFBundlePackageType='APPL',
                     CFBundleIconFile='QingType.icns', NSPrincipalClass='NSApplication',
                     NSHighResolutionCapable=True, LSMinimumSystemVersion='14.0', LSUIElement=True)
(settings / 'Contents/Info.plist').write_bytes(plistlib.dumps(settings_info))
