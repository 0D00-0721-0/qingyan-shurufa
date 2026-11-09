# Local validation — 2026-10-27 — QingType 0.6.2

Environment: Apple Silicon, macOS 27.0.1, Swift 6.4. The machine now has Xcode
27.1 selected at `/Applications/Xcode.app/Contents/Developer`. The initial
prototype was built earlier with Command Line Tools alone.

## Fuzzy pinyin — 2026-11-02

Ten independently selectable bidirectional pairs are available in the native input
settings. The master defaults to off, preserves selections when disabled and safely
migrates legacy settings. Ordered Rime list insertion retains the original algebra;
the simplified schema inherits the parent's fuzzy rules exactly once. an/ang does
not implicitly enable ian/iang or uan/uang. Database and prism names stay stable.
Existing configuration ownership checks, backup and verified rollback are reused.

The standard arm64 build and complete `scripts/test.sh` pass with the required full
Ice fixture and no FAIL/SKIP. The settings suite adds 40 migration, selection,
deterministic encoding, manual-file protection and failed-deployment recovery checks.
The final dedicated engine suite passes 436 checks across simplified/traditional
Luna, Xiaohe and Ice: both directions, exact spellings, single characters, combined
rules, abbreviation, restart, immediate disable, independent an/ang, quick phrases,
Ice Lua/English and actual fuzzy selection/commit. Complete compiled algebra is
compared before/on/off; real learned entries, weights and ranking survive toggles.

With an isolated imported Wanxiang simplified model, 448 dedicated checks pass;
engine logs confirm loading the model. The three simplified schemes retain the
selected grammar language and corresponding prism; traditional Luna runs without
that incompatible simplified model. Existing factory (95), Ice (93), candidate (73)
and learning (65) checks also pass in the complete regression.

The actual SwiftUI section was mounted with isolated in-memory preferences for
visual and accessibility inspection. All ten checkboxes, selection count and
master disable/re-enable behavior were verified. The local development DMG passes
the standard packaging and DistributionTests checks, including strict ad hoc
signature verification, mounted content identity, optional/private data exclusion
and 95 packaged offline factory checks. Evidence is ignored under
`build/fuzzy-pinyin/`. No new CI or Release has been created. Real keyboard use,
other hosts and macOS 14/15/26 remain unverified for this feature. See
[usage and test commands](docs/FUZZY_PINYIN.md).

The subsequent authorized replacement installed both the normal application and
input service. An exclusive production data lock covered backup, replacement and
pre-start verification: all 1,263 user files/links matched the verified offline
copy before startup, with no manual configuration redeployment. Prior program ZIPs were
actually extracted and matched their original content and signatures. Eight build
records, complete app/input contents, strict signatures and the running image UUID
match the fixed development DMG (workingTreeClean=false is retained and explicitly
not treated as a clean release build). The new service starts from its installed
path, PID 69459, and remains the same instance after opening the normal settings
application. The actual input page shows fuzzy pinyin off with zero selections;
the existing Ice scheme, model and input source selection remain. No Save/Apply
was performed. After startup, user.yaml changed only in Rime's engine-maintained
last_build_time field; user settings and protected asset hashes match. Private installation evidence is ignored under
`build/fuzzy-pinyin/live-replacement/`. This establishes installation and settings
UI results, not real keyboard input acceptance.

## Caps Lock raw-pinyin commit — 2026-10-30

The previous generated configuration inherited `Caps_Lock: clear`, reproduced as
a failing real-engine test. It now uses commit_code. A second probe showed that
Rime commits only the prefix when the caret is in the middle; a narrowly scoped
Caps Lock preflight moves to the end only for an effective commit_code policy.
Schema overrides and other events retain their behavior. Each factory/Ice profile
passes 21 new engine checks, including Ice with Shift disabled. The complete local
suite passes with 275 PASS output lines and no FAIL/SKIP, including the unchanged
candidate and learning regressions. A clean df11bfa package passes strict DMG checks
and 39 packaged factory-engine checks; macOS 14/15/26 all pass
[CI 41061319357](https://github.com/0D00-0721-0/qingyan-shurufa/actions/runs/41061319357).

Both installed programs now match that fixed package and its running image.
Configuration was reapplied through the existing transaction, with settings values
unchanged and Caps Lock compiled as commit_code. Offline user-data/program backups
remain private; 66 protected file hashes match, and three learning database
directories remain. Database metadata/files rotate during deployment and startup;
byte-for-byte learning identity is not claimed. The user confirmed the requested
Codex 26.1027.30824 (22943) composer test: nihao candidates followed by Caps Lock
committing the literal nihao, then returning to Chinese and committing with Space.
Before/after snapshots match the same artifact, full contents and running instance;
this scoped result is recorded separately as F. Other hosts and real mid-composition
caret cases remain unverified. See [the scoped record](docs/CAPS_LOCK_VALIDATION.md).

## Independent QingType default-branch history — 2026-10-30

The maintainer explicitly selected a fresh main history after backing up the old
history. Root commit `ab03252` preserves the complete latest tree at `80f4709`,
including its recent README, contribution/security guidance and issue templates;
only PROGRESS.md differs. All product code, dependency pins and license/attribution
files are byte-identical. The local origin now uses the repository's current name,
`0D00-0721-0/qingyan-shurufa`.

A complete Git bundle, refs, release/asset inventory and local uncommitted notes
were saved outside the repository. An independent mirror restored from the bundle
contains the old remote main tree and all six release tags. After a push protected
by the exact old main SHA, the remote commit API reports one root commit authored
by `0D00-0721-0`; all six release tags, release records and asset identifiers,
sizes and digests are unchanged. The contributor-activity statistics API has now
recomputed to `0D00-0721-0` with one commit. The ordinary contributor-list API still
returns cached old authors; this is not reported as a completed homepage refresh.

Local validation passed: four version tests, one build-identity test, 20 acceptance
tests, a clean arm64 build, strict provenance/signature/mounted-DMG validation and
18 packaged offline-engine checks. Build, full regression and strict package checks
passed on macOS 14/15/26 Apple Silicon in
[CI 41057130972](https://github.com/0D00-0721-0/qingyan-shurufa/actions/runs/41057130972)
at root commit ab03252. Only validation documents follow this root commit.
The ordinary contributor list still reports 28 cached accounts; GitHub documents
that contributor displays may take about 24 hours to refresh after a history rewrite.
No installed input service,
user data, release asset or public version tag was replaced.

## Acceptance UUID and TIS query hardening — 2026-10-30

Two separate fixes, `8ea21c5` and `7b090b7`, are limited to the requested contracts:

- `verify_installation()` now validates independently supplied `diskImageUUID` and
  `runtimeImageUUID` on both runtime samples. Its public snapshot schema and
  artifact identity are unchanged. The old mismatch acceptance was reproduced
  before the fix. All 20 acceptance tests pass, including mismatches even with a
  legacy alias, missing/invalid/zero UUIDs, invalid process identities and a change
  in the second sample. The updated CLI also passed a real, read-only comparison
  against the existing fixed 6de81c0 DMG, installed bundles and running image;
  this is identity verification, not a new application-input acceptance.
- Normal TIS list queries use conditional bridging, per-element CF type checks
  and explicit errors. Missing/invalid identifier or Boolean properties propagate
  through the installer query methods and CLI/diagnostic boundaries. A confirmed
  absent source remains an ordinary unregistered result. All 67 new safe-query,
  property and propagation checks pass. `register()` and `guidedUninstallState()`
  bodies are unchanged. Real read-only status and guided-uninstall JSON match the
  installed service; diagnostic JSON remains readable.

The standard arm64 build and complete suite with the required Rime Ice fixture
passed: 233 PASS output lines, no FAIL/SKIP, including existing candidate, learning,
dictionary and installer/uninstaller regressions. A fresh clean 7b090b7 package
also passed strict provenance, signature, mounted-DMG and 18 offline-engine checks.
Logs and private snapshots are under ignored `build/hardening-*` paths.
[CI 41015405487](https://github.com/0D00-0721-0/qingtype/actions/runs/41015405487)
passed build, full regression and strict package checks at 7b090b7 on macOS
14/15/26 Apple Silicon. Subsequent edits only record validation.

Nil, malformed bridge and missing-property failures were injected into isolated
fixtures, not forced on the real OS. No live registration, enable/select, install,
uninstall or new GUI input acceptance was performed. The existing 6de81c0 service
was not replaced or restarted. Candidate/Rime behavior and installation UX are
unchanged; no Release assets or tags were changed.

## Upward candidate disclosure — 2026-10-29

The user's screenshot exposed a missing transition when the compact row fits below
the caret but expansion must move above it. The old same-side gate was reproduced
as a failing regression, then removed; an unchanged context now keeps its upper
placement when collapsing or refreshing. The local suite passed with 73 candidate
checks and 232 PASS output lines, no FAIL/SKIP. A clean 6de81c0 / 0.6.5 package passed
strict DMG checks and is installed as both programs, with matching full contents and
running image. All 1,248 files/links were identical to the offline snapshot before
service startup. The first retry used Apple Pinyin; after the user clarified this,
QingType Hans selection was verified and a fresh pre-test snapshot was captured.
The user then confirmed upward expand/collapse twice and Space committing Chinese
work normally in the original Codex 26.1023.51421 (22530) bottom composer. The
corrected before/after snapshots match the same artifact, full contents and running
instance, with QingType Hans enabled and selected at both checks. This scoped result
is recorded separately as E, without reusing the earlier TextEdit result.
[CI 40900147446](https://github.com/0D00-0721-0/qingtype/actions/runs/40900147446)
passed build, full regression, strict provenance and DMG checks on macOS 14/15/26
Apple Silicon at the installed product commit 6de81c0. Subsequent edits only record
validation; no Release assets or tags were changed. See
[the upward-animation record](docs/CANDIDATE_UPWARD_ANIMATION_VALIDATION.md).

## Candidate disclosure animation — 2026-10-29

The user accepted the preview video. A clean 1a4a5df / 0.6.5 build is now installed
as both the normal app and input service, anchored to a fixed DMG. Eight provenance
records, full bundle contents and the running image match. Before service startup,
all 1,247 user files/links matched the offline backup without additions, removals or
changes. The existing 53 candidate checks plus 13 animation/interruption checks pass;
the full local suite on the same product code passed with 225 PASS output lines and
no FAIL/SKIP. Strict package and offline-engine checks pass. The user confirmed
TextEdit 1.21 (419), a new document body: ni candidates, two expand/collapse cycles
and Space committing Chinese work normally. Before/after snapshots match the same
artifact, complete bundle contents and running instance. Long phrases and other
applications remain unverified.
[CI 40896020237](https://github.com/0D00-0721-0/qingtype/actions/runs/40896020237)
passed build, full regression, strict provenance and DMG checks on macOS 14/15/26
Apple Silicon at the installed product commit 1a4a5df. Subsequent edits only record
validation; no public Release assets or tags were changed.
See [the animation validation record](docs/CANDIDATE_ANIMATION_VALIDATION.md).

## Fixed acceptance artifact — 2026-10-29

A clean 24cf60a / 0.6.5 DMG now anchors the installed normal app, embedded payloads
and input service: eight provenance records agree, full trees match, and the running
image UUID matches disk. Before/after snapshots bracket the user's confirmation
that TextEdit 1.21 (419), a new document body, shows nihao candidates and commits
Chinese with Space. Other controls/actions remain unverified. The full local suite
passed (212 PASS output lines, no FAIL/SKIP), plus 14 acceptance tests and strict
mounted-package checks. Old mixed-version output was rejected without deleting
old DMGs. All 1,247 user files/links were preserved; only Rime build/check timestamps
changed at the installation checkpoint. Full fingerprints and boundaries are in
[the fixed-artifact record](docs/ACCEPTANCE_BUILD_VALIDATION.md).
[CI 40889155593](https://github.com/0D00-0721-0/qingtype/actions/runs/40889155593)
passed build, full regression, strict provenance and DMG checks on macOS 14/15/26
Apple Silicon at 14b8029. Only validation documents and CI policy differ from the
installed 24cf60a product; no Release asset or tag was changed.

## Memory regression and observation — 2026-10-29

The fourth stability item adds fresh-process 64/256/1024 MiB hash checks, repeated
verification and cancellation only after a synthetic file's offset advances, with
no surviving target descriptors. All checks passed; an isolated source copy with
the chunk autorelease pool removed retained 270,172,160 bytes on 256 MiB and was
rejected by the limit. Production hashing is unchanged. A clean 48f8f2e diagnostic
build completed 300.04 seconds / 15,061 isolated engine cycles, with 12,049 verified
commits, 2,151 edits and 3,012 cancellations. RSS ended 1.53 MiB above warm-up;
a separate 180-second sample measured 24.97–28.38 MiB physical footprint. Timing
storage stayed bounded at 8,192 samples. Full local regression passed (212 PASS
output lines, no FAIL/SKIP), as did strict package checks and 18 offline engine
checks. The existing clean 05c1bd5 service (PID 47899) has not been restarted. The user
cancelled the separate two-hour observation after about 19.89 minutes / 80 points;
its summary is incomplete and the 20:10 follow-up automation was deleted. Full results and
limitations are tracked in [the memory record](docs/MEMORY_VALIDATION.md). Neither
run is human application input acceptance; the two-hour check is cancelled, not passed.
[CI 40856055412](https://github.com/0D00-0721-0/qingtype/actions/runs/40856055412)
passed build, full regression and DMG checks on macOS 14/15/26 Apple Silicon at
df48c71. The subsequent commits only record validation and the user's cancellation.

## Candidate transition regression — 2026-10-29

The third item in the user's five stability recommendations adds 17 checks to the
existing candidate suite (53 total). Tests first reproduced callbacks from a hidden
session and a replaced button whose index was reused for different text. Commit
67cff01 rejects these stale actions while preserving the current window, layout and
normal selection behavior. The full pinned-fixture local suite passed with 207 PASS
output lines and no FAIL/SKIP. Display geometry injection and 1x/2x offscreen drawing
are internal checks, not real multi-display or cross-app input acceptance. The clean
05c1bd5 package passed mounted distribution and 53 candidate checks, and both installed
programs match that package. Before restarting the service, all 1,247 personal
files/links matched the offline snapshot, with no additions, removals or changes.
The service is running and QingType is enabled/selected; human input remains pending.
[CI 40850109938](https://github.com/0D00-0721-0/qingtype/actions/runs/40850109938)
passed build, full regression and package checks on macOS 14/15/26 Apple Silicon at
05c1bd5; the following record update changes documentation only. See
[the candidate regression record](docs/CANDIDATE_REGRESSION_VALIDATION.md).

## Guided uninstall and reinstall — 2026-10-29

The current guided workflow has now been exercised on the real macOS host: switch
away, remove the input source in System Settings, uninstall both programs, reinstall,
and re-add the source. All 1,153 existing user files/links were unchanged at uninstall;
logical exports of 678 records in three learning databases remained identical after
reinstallation. The app and script share the same state checks and file transaction.
See [the scoped validation record](docs/GUIDED_UNINSTALL_VALIDATION.md) for build
identities, automated regression results, source-notification checks and limitations.
The final installed build is clean c97c026 / 0.6.5; human candidate/Chinese-input
confirmation on that build remains pending. Source was pushed to main and
[CI 40846479704](https://github.com/0D00-0721-0/qingtype/actions/runs/40846479704)
passed build, full tests and package inspection on macOS 14/15/26 Apple Silicon at
57ed25a (only documentation differs from the installed c97c026). Historical pending
statements below refer to their recorded builds and dates.

## 0.6.5 preview publication — 2026-10-28

Commits 290f256 (version 0.6.5 with the memory fix) and a473f99 (guided uninstall)
were tagged `v0.6.5-preview.1`. Release workflow
[40712660525](https://github.com/0D00-0721-0/qingtype/actions/runs/40712660525) had
its macOS 15 package job cancelled by the runner after 15 minutes with no step logs;
macOS 14 and 26 passed, and after rerunning that job all three platforms and the
publish step succeeded.

The downloaded DMG (17,219,084 bytes, SHA-256
`4f49c8323b12dec9880ddaf90697eb4bffe72e1368d28e79a4f144ef6a0a52c4`) matched its
`.sha256` file and the GitHub asset digest. Both bundles report 0.6.5, BuildInfo is
clean a473f99/arm64/macOS 14.0, the ad-hoc signature verifies, and the mounted package
passed 18 offline engine checks plus `DistributionTests.py`. The source archive
(`0c3e05d775aa8992b371cf2a7b755de0a069b19efc9799d13332e9ebeb307a0a`) reports VERSION
0.6.5 and contains no learning databases, settings, models or absolute user paths. The
local app is a local 0.6.5 build, not the published binary; real keyboard input and the
graphical uninstall flow still need manual confirmation.

## Model verification memory fix — 2026-10-28

The 0.6.4 input service used 431 MB physical footprint and 522 MB RSS while Squirrel
with the same 398 MB model used 27.7 MB footprint. `vmmap` showed about 398 one-megabyte
malloc blocks. The startup model check hashed the `.gram` with 1 MB `FileHandle` reads,
and the bridged `Data` chunks stayed in the autorelease pool, so the whole model was
retained in the heap after verification. A standalone reproduction confirmed 406 MB RSS
after the same loop and 8 MB when each read was wrapped in `autoreleasepool`.

The loop now releases every chunk. The deployment worker peaks at 43 MB, the restarted
service reports 19.6 MB physical footprint and about 60 MB RSS with the same model still
loaded and deployed. The leak was introduced by the 0.6.3 startup verification (0.6.2 has
no such path) and is present in the published 0.6.4; the next release should carry the fix.

## 0.6.4 preview publication — 2026-10-28

Source commits abab3c5 (deploy before enabling), 413c0ba (installation state and
idempotency) and 88db9e0 (backup retention, signature checks, build recovery) were pushed
to `main`; CI
[40675623220](https://github.com/0D00-0721-0/qingtype/actions/runs/40675623220) passed on
macOS 14/15/26 Apple Silicon. Tag `v0.6.4-preview.1` and release workflow
[40676557697](https://github.com/0D00-0721-0/qingtype/actions/runs/40676557697) produced
the public prerelease
[v0.6.4-preview.1](https://github.com/0D00-0721-0/qingtype/releases/tag/v0.6.4-preview.1).

The downloaded DMG (17,111,132 bytes, SHA-256
`000349a8944f14d10084737bac894dc7909ce84a33d904833cddf99776b8adc6`) matched its `.sha256`
file and the GitHub asset digest. Both bundles report 0.6.4, BuildInfo is clean
88db9e0/arm64/macOS 14.0, the ad-hoc signature verifies, and the mounted package passed 18
offline engine checks plus `DistributionTests.py`. The source archive
(`a2865393eec2931e9ffbbe681436d644f25b3ab9d9a958f4b7f2363a84d2cc24`) reports VERSION 0.6.4
and contains no learning databases, settings, models or absolute user paths. The installed
`~/Applications/清言.app` was updated to the same build. A full GUI self-update
(check → download → verify → replace) and a real keyboard input check after this build have
not been performed yet.

## Installation state and idempotency audit — 2026-10-28

Before the audit, pressing "重新检查并启用" after a successful install always ran the
full transaction: copy the embedded bundle, back up the installed one, swap atomically,
register and enable the input source again, and redeploy. The final state was stable, but
the operation was not idempotent, and the UI had only `installedVersion` and
`inputEnabled` booleans. A corrupted installed bundle could not be repaired at all: the
installer compared versions first and threw when the old Info.plist was unreadable.

The installer now detects `notInstalled`, `installedSameVersion`, `installedOlderVersion`,
`installedNewerVersion` and `corrupted` from the filesystem (bundle identifier, executable,
required runtime library and dictionary, version comparison, leftover staging directories).
Equal and healthy installs only redeploy; the explicit "重新安装" entry performs the full
replace; newer installs are protected; corrupted installs are repairable. Post-deploy
verification re-checks the version and required files and throws, so the transaction rolls
back. Model status now reads the `.gram` file size and SHA-256 instead of trusting the
settings record alone, and a failed update check clears the previous candidate so no stale
install button remains.

`tests/InstallationStatusTests.swift` covers state detection, action mapping, verification,
leftover staging, downgrade refusal, repeated equal-version installs, corrupted repair and
the concurrent install lock; `tests/MaintenanceRecoveryTests.swift` covers backup retention,
build-artifact recovery and signature checks. The full regression passes 183 checks.

Backup retention keeps the newest three `install-*`/`apply-*` transaction directories and
never touches `learning-*`, `app-update-*`, plain files or symlinks; applying it on this Mac
reduced 51 transaction backups to 3 and the backup directory from 1.4 GB to 1.1 GB (the rest
is a deliberate acceptance snapshot). Status detection can run `codesign --verify --deep
--strict`; the settings app does it off the main thread and turns the action into "repair"
when it fails. A compile failure now moves derived `.bin`/`.yaml` files aside, rebuilds once
and restores them if the rebuild still fails.

Manual acceptance steps are listed in `docs/QA_CHECKLIST.md`. `app-update-*` backups still
accumulate because they are tied to pending update receipts; the signature check completes
asynchronously, so the first render may briefly show the file-level state; rapid clicking,
power loss and cross-application input still need real-machine checks.

## 0.6.4 update-lock fix — 2026-10-28

A real GUI self-update from 0.6.2 to 0.6.3 failed on this Mac. The installer
enabled the input source, macOS started the service, and that service held the
shared data lock, so the exclusive deployment worker failed with "清言正在输入或
管理数据". Rollback then swapped the new app into the staging directory and removed
it while the live service still ran from that path. Recovery stopped the orphan
service and re-ran `--deploy-user-data` with the installed 0.6.3; deployment
succeeded and the user confirmed Chinese input worked again. No user dictionaries,
learning databases or settings were modified.

The fix stops the service before every deployment attempt, restarts it from the
installed path after a successful install, and stops it before a rollback. The full
`scripts/test.sh` in required Rime Ice fixture mode passes (173 checks) on the local
0.6.4 build, and the DMG packaging plus `DistributionTests.py` pass. The real upgrade
test prepared a pending-update receipt matching the GUI flow, replaced the 0.6.3
application with the 0.6.4 build, and let the settings app finish the update while
the input service was running. The receipt was consumed in about seven seconds; the
installed input method reports 0.6.4, the service runs from
`~/Library/Input Methods/QingType.app`, no `.qingtype-stage-*` directory remains, and
deployment succeeded with a verified loaded model. The in-app download/verification
step and real keyboard input after the upgrade still need user confirmation.

A second failure appeared after that first fix, when the user pressed "重新检查并启用"
to reinstall 0.6.4 over itself. Deployment failed with `dictionary 'qingtype_main'
failed to compile` and wrote a 3,508-byte `qingtype_main.table.bin` where the healthy
file was 13,041,144 bytes; every later deployment then failed the same way. Root
cause: deployment still ran after the input source was enabled, so the service macOS
started compiled the same `build/` directory concurrently with the deployment worker.
Removing the truncated `qingtype_main.table.bin`, `qingtype_main.reverse.bin` and
`qingtype_luna_pinyin_simp.prism.bin` and re-running `--deploy-user-data` rebuilt the
13 MB table and succeeded.

The ordering is now explicit: back up the cache, stop the service, deploy, then
register and enable the input source, and finally start the service from the installed
path. The same automated GUI reinstall was repeated with the reordered build while the
service was running: the update receipt was consumed in about five seconds, the
installed method reports 0.6.4, the service runs from the installed path, the compiled
dictionary table stays 13,041,144 bytes, the newest deployment log has no errors, and
no staging directory remains. The full local regression still passes (173 checks).
The application does not yet detect and rebuild corrupted compiled artifacts
automatically; the fix removes the known concurrent-write cause only.

## 0.6.3 preview publication — 2026-10-28

Source commit 8eac967 (VERSION 0.6.3, clean working tree) passed the full local
regression in required Rime Ice fixture mode (173 checks, no failures, including
38 installation, 20 Wanxiang, 26 maintenance and 65 learning checks) and the
mounted local DMG check. Push CI
[40659394836](https://github.com/0D00-0721-0/qingtype/actions/runs/40659394836)
passed on macOS 14/15/26 Apple Silicon; tag `v0.6.3-preview.1` and release
workflow
[40660691036](https://github.com/0D00-0721-0/qingtype/actions/runs/40660691036)
produced the public prerelease
[v0.6.3-preview.1](https://github.com/0D00-0721-0/qingtype/releases/tag/v0.6.3-preview.1).

The downloaded DMG (16,974,171 bytes, SHA-256
`20eba9ef059da565869c4c2d7c6fefccc7bf4e96a1cc6c7a12039418816d1ec7`) matched its
`.sha256` file and the GitHub asset digest. Both bundles report 0.6.3, BuildInfo
is clean 8eac967/arm64/macOS 14.0, the ad-hoc signature verifies, and the
mounted package passed 18 offline engine checks plus `DistributionTests.py`
(identity, minimum OS, license hashes, no personal or optional data, offline
Chinese candidates). The source archive
(`2c9a6055714760e348ff1826ee2ac7737ddb093530f35fb4eafd2cc3454b62b4`) has
VERSION 0.6.3 and contains no learning databases, settings, models or absolute
user paths. The public package was not installed on this Mac, which still runs
the 0.6.2 development build; real uninstall, cross-application input,
multi-display/sleep/long-run behaviour and GUI self-update remain unverified.

## Wanxiang update checks and stalled requests — 0.6.2

Existing-model buttons now check the official LTS SHA-256 before downloading.
A matching registered local file is size/hash validated, then returns without
configuration edits, deployment or service restart. Metadata from the check is
reused for the download. Fresh/different models retain the existing verified
import/apply path. Inactive matching models keep the user's current selection.

Twenty isolated model checks pass, plus twelve metadata/request cancellation
checks: whole-resource versus idle timeout, rate limits, invalid responses,
cancelled in-flight requests, retry after cancellation and cancellable local
hashing. Recovery hashes remain non-interruptible by default. The full local
regression and mounted DMG checks pass. Real official metadata plus the cached
418MB model verified the matching/no-download branch in an isolated directory.

The old UI could keep saying "checking" while connecting to the model download,
and hid cancellation until the first received bytes. Metadata now uses a fresh
session with 10-second idle / 15-second resource limits. Cancellation is exposed
throughout checking and connecting; stage text changes before download begins.
The busy GUI was quit while leaving the input service running. Both installed
bundles were updated to 0.6.2 with all saved settings equal. The native check
then detected the actual older model and entered downloading; clicking Cancel
restored the controls immediately. Settings/deployment hashes and mtimes plus
input-service PIDs were unchanged. The existing model was not replaced. Full
real download/activation and a GUI app self-update remain separate acceptance.

The feature commit 0c3f156 passed CI 40522851955 on macOS 14/15/26 ARM.
v0.6.2-preview.1 publishes a clean local build of this same source commit:
DMG SHA-256 6d13b4d5c79e9c8fc5a0fbdc97c4e643cf91fa6cc32b633fa6a0a7d8a34d1e0b.
DMG/source/data boundaries, signing structure and portable/server digests were
checked before publishing the draft. Local download of the CI artifact stalled
and was terminated, so this package is explicitly the clean local build, not a
CI binary. Both installed programs are the previously verified 0.6.2 development
build; the final replacement with the published build was stopped when the Mac
locked. A manual unlock is required before that optional UI-driven replacement.

## Long collapsed candidates — 0.6.1

The user reported a long first candidate ending in an ellipsis and supplied an Apple
Pinyin reference that reduced the visible row to three choices. The old 180pt cell
cap and proportional whole-row shrink were removed. Collapsed rows now pack complete
natural-width cells into the native reference width; the configured page size is
an upper bound. Later rows and number shortcuts follow actual visible absolute
indices. Expanded layout, dictionaries, models and ranking are unchanged.

All regression and DMG checks passed; candidate checks increased from 24 to 29,
covering full long text, fewer choices, arrow separation, visible numbering and
expand/collapse page mapping. The same reference phrase rendered fully with three
choices in an actual AppKit static capture. User then repeated the original input after native 0.6.1 installation and explicitly
confirmed the complete first phrase and reduced visible count. This accepts that
scenario, not every application. Unavailable number shortcuts are consumed before
Rime can select a hidden candidate.
User additionally narrowed support to Apple Silicon only; Intel CI/distribution
was removed. Previous 0.6.0 CI 40505797749 passed, but does not cover this fix.

## Maintenance, provenance and compatibility — 0.6.0

The full scripts/test.sh regression and mounted DMG DistributionTests passed locally.
The new 26-check maintenance suite verifies application replacement, checksum backup,
injected installed-validation failure, actual archive restore, downgrade refusal,
release/CPU/origin filtering, default-off update networking, profile-link refusal,
whole-program uninstall staging/undo, partial move rollback and unchanged private bytes.
The existing learning and candidate suites pass; destructive operations remain isolated.

An isolated 5,000-cycle engine/candidate-layout loop completed without empty candidates:
mean 4.62ms, p95 11.14ms; warm/final RSS 372304/393744KiB. This is neither host
keystroke latency nor a long-duration or model-enabled stability test. Diagnostic
JSON was exported and checked for absence of absolute home paths; synthetic private
words/pinyin/phrases are excluded by the summary test.

User acceptance added: Safari personal new word commits and remains available after
reapplying; QQ search field nihao + Space commits without exiting. Neither result
covers every control or CRUD action. See docs/COMPATIBILITY.md for expected/actual
and pending multi-screen, sleep, other application and prolonged-use checks.

The build checks 181 fixed runtime/resource files and 16 source notice digests,
and bundles notices plus source commit/clean state/architecture/toolchain provenance.
The official Squirrel PKG differs from the matching Rime SDK in Mach-O UUID and Lua
patch version; SDK plugin revisions are recipe evidence, not byte-equivalence proof.
This remaining source rebuild audit is explicit in docs/DEPENDENCIES.md.
The 0.6.1 bfc4379 CI 40507767209 passed on macOS 14/15/26 Apple Silicon.
Native installation preserved every setting and loaded the existing model. The
maintenance page, default-preserve uninstall confirmation (cancelled), update
check and native private diagnostic export were checked. Synthetic data was
also recycled using NSWorkspace and restored byte-for-byte from its real Trash
receipt. Real installed-program uninstall was not exercised. A final recovery
ordering fix releases the profile lock before reselecting the restored input
source; build, 26 maintenance and 32 learning-lock checks passed. The tagged
release workflow will rerun full checks on all three supported systems. This machine still has zero valid signing identities.

## Published artifact and tagged workflow

v0.6.1-preview.1 points to fffae68ec5b6c99d864ef4033865f8603d2b39c2.
The tagged release workflow 40509068950 passed all macOS 14/15/26 Apple Silicon
jobs and published the arm64 DMG, portable hash file and source archive. The
initial macOS 14 attempt passed functional tests but could not detach its test
image (busy status 16); rerunning the failed job passed. A later main-only test
cleanup improvement retries that transient status without force-detaching.

DMG SHA-256: 5c4c1ca2d3b74ee34b33b91eb3bc78fd4555c1f52324564a010fa897adc43ae6,
16,633,842 bytes. Server digest matches the verified CI artifact installed locally.
The native installer and production normal-app replacement transaction preserve
all settings, verify deployment/model loading and a previous-program ZIP hash.
Both installed bundles have clean tagged BuildInfo; their payload bytes match.
The final normal application was opened successfully. The published source hash,
GPL plus 16 notices and private-data exclusion were verified. The app downloader
also fetched/verified the public 0.6.1 DMG and nested signatures without installing
another copy. The unauthenticated GitHub API hit shared-egress rate limits after
an initial native update check; authenticated developer metadata was used solely
to test downloading, with no token embedded in the app.

## Rime learning, persistence and recovery — 0.5.0

Learning uses the existing Rime user dictionaries: qingtype_main for base pinyin
and Xiaohe, and rime_ice for Ice. Legacy profiles default to enabled; switching
off excludes learned candidates and stops new learning while preserving history.
The native management page provides backup, export, merge restore, safe reset
and explicit privacy clear. Backups contain native Rime snapshots, names and
SHA-256 digests in a versioned .qinglearning container, saved with mode 0600.

Offline workers stop the service, acquire an exclusive data lock, and only open
private cloned databases. Normal service instances hold a shared lock. Snapshot
restore is validated/merged in a workspace before replacing databases. Partial
move or installation failures restore originals; unverified recovery blocks the
service and retains a path ledger. Reset preserves a safety backup and includes
local-sync-only history; privacy clear includes local snapshots and learning
backups. Configuration, fixed/imported dictionaries, phrases and models are not
learning targets. External custom sync paths stop reset/clear rather than being
modified. A rapid off/on regression exposed second-granularity Rime schema
freshness; deployment now invalidates only the active generated schema.

287 local checks passed: the prior 193, 32 learning validation/boundary/rollback/
lock checks, and 62 actual-engine learning checks with Ice. The suite verifies
repeated low-weight selection changes ranking, a completely new process retains
it, CSV import/deletion and deployment preserve it, Xiaohe shares base learning,
disabled learning adds no entries, learned copies survive fixed-row deletion,
portable restore recovers ranking and retains newer history, sync-only history
is recoverable, and both base/Ice survive reset/recovery. The same 62 checks also
passed with the local reference Wanxiang model; plugin output confirms loading.
All destructive/reset/recovery tests use temporary synthetic data, never the
user's active databases. Two additional partial-replacement checks were run as
the final 32-check safety suite after the full regression pass.

The rebuilt DMG passed mounting, signing-structure and offline-engine checks.
The native installer installed/enabled 0.5.0 and verified deployment/model load;
normal app, nested payload and installed service match. JSON comparison confirms
all preexisting settings unchanged, with only default learningEnabled added.
The installed welcome page reads 0.5.0 and the learning page was inspected in AX
and a screenshot. The real backup button created one backup of both existing
databases; digest, 0600 file and 0700 folder permissions passed readback. The
privacy-clear confirmation was opened and cancelled, with databases, backup and
preferences preserved. Destructive actions were not tested on real user data.
Source e618c79 passed [CI 40475012326](https://github.com/0D00-0721-0/qingtype/actions/runs/40475012326),
including the complete 287-check suite and mounted-DMG inspection. The user then
performed the Safari same-pinyin/repeated-lower-candidate test, saved/applied
settings and tested again, explicitly confirming that ranking advanced and
remained after reapplication. This accepts learning and deployment persistence
in that real application scenario; other apps remain in the compatibility matrix.
See docs/LEARNING.md and ignored build/phase2-*.log for reproducible evidence.

## Expanded long-candidate layout — 0.4.2

The user's longer-input comparison exposed a gap in the earlier ni acceptance:
six equal-width expanded cells truncated whole phrases, while the native panel
lets long candidates span columns. Expanded width also followed the collapsed
page's total width. The six-column grid now assigns spans from measured text
width, wraps in engine order, and uses a bounded independent width (397 pt at
16 pt font). Number keys address only the candidates actually in the first row;
vertical navigation follows the next visual row. The single window, background,
candidate contents/order, page-size preference and absence of a footer remain.

193 local checks pass, including 24 candidate checks. Six new cases exercise
complete long header/body text, three long phrases in the first row, ordered
body wrapping, actual first-row numbering and visual-row navigation. The AppKit
long-phrase preview is 794 x 282 px. Rebuilt DMG mounting and offline-engine
checks pass. Native installation verifies 0.4.2, deployment/model load and all
existing settings unchanged; both installed app payloads match the built binary.
The user confirmed complete long text, normal width and wrapping in the real
faxinmoxinglema scenario. Commit 47ed1f6 passed CI 40470411896. Evidence is
in ignored build/expanded-spans-*.log and expanded-spans-preview.png.

## Native candidate geometry — 0.4.1

The user's two Retina (2x) screenshots show QingType's 32 px candidate glyphs
against Apple Pinyin's 28 px glyphs. Default font size is now 16 pt instead of
18, with a 29 pt capsule instead of 32. Placement shifts the panel 16 pt left
of the marked-text origin and leaves a 6 pt vertical gap; the intended alignment
is the first candidate text, with the panel edge extending left. Horizontal
padding and the separate chevron/divider were calibrated to the reference.
Candidate count, ranking, dictionaries, models and single-window expansion are
unchanged; the reference has nine candidates while the user's profile has seven.

187 internal checks passed, including 18 candidate placement/interaction checks.
The 7-candidate AppKit preview is 630 x 58 px with 28 px glyphs. The rebuilt DMG
passed read-only mounting, signing-structure, minimum-OS, library/data-boundary
and offline-engine checks. These checks do not prove real-host caret alignment.

The native installation service installed 0.4.1 and verified deployment/model
load while preserving all settings. The user profile's font was then changed
through the appearance page and saved successfully. A structured comparison
confirms fontSize 18 -> 16 is the only settings change, with pageSize still 7;
deployment reports success=true and modelVerified=true. Both installed app
versions read back as 0.4.1. The user then followed the same-field, manual-ni
comparison and confirmed that position and size are both close to native. The
user also confirmed same-window expansion and successful mouse-selected commit
to the original input field. This accepts those interactions in that scenario;
other applications, personal-dictionary workflows and schema switching remain
separate acceptance items. The existing 0.4.0 GitHub preview assets are unchanged.

Evidence: build/native-geometry-{build,tests,package,distribution,install}.log and
build/native-geometry-row.png (ignored local files).

The first geometry CI (40466635055) passed the engine checks but detected a
fractional-metric overlap between the last expanded column and the chevron.
Grid columns now use whole-point boundaries; the same 18 interaction checks and
rebuilt distribution checks pass locally. Corrected source aca38e6 passed
[CI 40467256898](https://github.com/0D00-0721-0/qingtype/actions/runs/40467256898),
including the clean build, complete test suite and mounted-DMG checks.

## Installable preview and optional components — 0.4.0

The normal QingType app now opens a native welcome page, installs/enables the
bundled input service, and offers independent opt-in Rime Ice and Wanxiang
installation. First launch does not download either. Model selection follows the
saved simplified/traditional schema. Transfers have progress/cancellation and
official SHA-256/size checks; activation still uses configuration recovery and
verified grammar loading. The existing candidate window is retained.

The default build extracts a hash-pinned Squirrel 1.1.2 archive without relying
on a locally installed Squirrel. Legacy optional .gram files are stripped. Both
executables target macOS 14.0, verified in Mach-O headers. The normal app has its
own bundle ID and packages the input service, libraries and base resources.

186 local checks passed: the prior 160, 20 setup/catalog/install rollback/native
cache checks, and six offline factory engine checks. Package inspection verifies
absence of optional models, Ice and personal data, default resources, portable
DMG checksum, actual minimum OS and library paths. The read-only DMG is mounted,
its nested signing structure verified, and its payload passes the factory engine
test. This does not prove Developer ID/Gatekeeper distribution acceptance.

All four component combinations were tested: neither (factory), Ice only, model
only (8 factory/model checks), and Ice plus model (17 Ice engine checks). The model
was downloaded by the native official downloader, SHA-256 checked and executed
by the real engine; its load is visible in plugin output. Transfer cancellation
was also tested. Optional-download tests use temporary/reference data, not new
models activated in the user's existing profile.

A harness using the same native InstallationService upgraded the local input
service to 0.4.0, verified source enablement, deployment and existing model load,
and confirmed all settings values were preserved. This is a backend invocation,
not a successful graphical click-through. New window inspection remains blocked
by a locked Mac; actual keyboard acceptance is deferred as requested.

Local evidence: build/setup-tests.log, distribution-tests.log,
native-install-040.log, factory-wanxiang-test.log, setup-ice-wanxiang-test.log,
wanxiang-download.log and wanxiang-download-cancel.log. The new CI runs bootstrap,
the full suite and DMG packaging/inspection; its result must be checked at the
pushed source revision. No valid local signing identity exists (0 identities),
so Developer ID/notarization branches are prepared but unexecuted. The source at
93bb9b7 passed CI 40377756642 and was published as v0.4.0-preview.1 with the tested
DMG and SHA-256 file. GitHub's uploaded asset digest matches the local DMG digest.
This is a public preview, not clean-Mac GUI/install/uninstall or Apple notarization acceptance.

## Rime Ice integration — 0.3.1 (2026-10-27)

The user confirmed the complete Rime Ice scheme, with QingType's native candidate
window and settings as the priority. Its AppKit/SwiftUI presentation remains in
use; the package's client configuration and themes are excluded.

The official Release downloader validates full.zip size and GitHub's SHA-256
digest, checks ZIP paths/types/bounds, then installs the three schema dependencies,
Chinese/English dictionaries, Lua (including lunar.db), OpenCC and symbol resources.
Package defaults are namespaced rather than replacing existing defaults, phrases,
Xiaohe files or user custom patches. A manifest, upstream license, owned-file
conflict checks, resource backups and activation rollback are included.

160 internal checks passed: the prior 116, one numeric dictionary-name import
regression, 27 package/isolation/rollback/archive checks and 16 real-engine checks.
The latter use the complete official package in a temporary directory: nihao,
configured page size, personal selection and exact commit, English, Lua date and
lunar data, quick phrases, restart, fixed-row deletion and stable learning identity.
The fixed personal-source checks disable learning; Phase 2 behavior remains pending.

A separate 17-check run used the existing local simplified Wanxiang model. The
plugin output confirms its grammar language, .gram load and double-array image,
in addition to candidate functionality. No model or user words are committed.

0.3.1 is installed locally. A command-line harness calling the same native download
and DeploymentService functions successfully installed the official package and
verified the active, unchanged scheme plus actual model load. All 59 installed
resource hashes match. Every pre-existing settings value is unchanged; the old
JSON gained the expected empty personalWords field and rimeIce metadata. The
current selected schema remains Luna simplified; Rime Ice can be selected in the
input settings and applied. Source Rime data is not a writable target.

The new graphical controls compile, but live window inspection was blocked by a
locked Mac. This is not recorded as a successful UI click-through. Actual typing
and candidate-window acceptance is deferred at the user's request. Local evidence
is in ignored build/rime-ice-tests.log, rime-ice-model-test.log,
rime-ice-install-result.json and the deployment logs. CI additionally fetches a
fixed upstream Rime Ice commit; its result must be checked against the pushed head.


## Phase 0 / Phase 1 — 0.3.0 (2026-10-27)

The user's roadmap is in ROADMAP.md; repository guidance and current handoff are
AGENTS.md / PROGRESS.md. BASELINE.md records the starting 0.2.2 toolchain,
verification scope, installation/recovery behavior and remaining release gaps.
`python3 scripts/capture-baseline.py` generates the actual runtime/toolchain and
binary-digest report in ignored build/baseline.json without word-entry contents.

The personal dictionary now has native settings UI for CRUD, weight, search and
sorting. CSV/TSV/TXT import first previews row results, then applies an explicit
conflict policy. Exports and complete inspection reports use native save dialogs.
The new settings field migrates from earlier JSON and generates an owned Rime
personal table, used by the existing full-pinyin and Xiaohe schemas.

The apply lifecycle stops the input service before saving. It snapshots only
managed configuration, deploys, and restores/recompiles the previous configuration
if deployment fails. External edits stop rollback instead of being overwritten;
failed recovery keeps the service stopped and reports the backup location.
Explicit schema compilation is required: an old usable compiled table must not
mask a failed dictionary build.

116 internal checks passed: the original 61 plus 35 personal data/import/export/
transaction checks and 20 actual engine integration checks. The latter exercise
new word selection and exact commit, changed spelling and weights, CSV round-trip,
Xiaohe, restart, deletion, explicit compile failure and recovery. Their fixed-source
CRUD fixture disables the user dictionary so an intentionally learned copy cannot
masquerade as a fixed row. This does not validate Phase 2 learning behavior.

The native page and editor were inspected through accessibility and a screenshot;
empty input produced a validation message and cancelling left the saved data
unchanged. Version 0.3.0 was installed and read back in the About UI; settings.json
was byte-identical before/after installation. The user deferred real-keyboard
acceptance, so user-application entry creation and input remain unverified. Do not mark Phase 1 fully accepted from internal tests alone.

## 0.2.2 Safari input-source selection

User reported that selecting QingType in Safari had no effect. The Safari
keyboard-source cache already contained QingType, so the earlier QQ diagnosis
alone did not explain this failure. Launch logs also recorded two QingType app
copies competing for the same endpoint.

The generated InputMethodConnectionName now uses the full bundle identifier plus
_Connection, matching the connection naming convention documented by the
[vChewing developer's IMK notes](https://github.com/ShikiSuen/ShikiSuen/blob/main/TechNotes/macOS_Input_Method_Development_Guidelines_2026/macOS_Input_Method_Development_Guidelines_2026-ENU.md).
The service refuses a second instance and checks IMKServer creation. The weak
client binding is refreshed on each key event and activation, and lifecycle logs
contain application identifiers rather than typed text. Bundle checks now guard
the connection convention and matching input-method/settings versions.

Build, signature verification and the existing 61 internal checks passed.
After installing 0.2.2, a fresh TIS selection returned OSStatus 0 and selected=true.
That alone did not prove Safari acceptance: the user initially still could not
switch in the already-running Safari process. The user then completely restarted
Safari and explicitly confirmed that switching worked. This confirms recovery in
that session; other browser/application combinations remain separate validation.

## 0.2.1 regression repair

QQ produced two matching crash reports inside the system source-switching HUD:
`TISCopyInputSourceRefForInputSourceID` returned NULL, then the framework called
`CFRelease` on it. The shared keyboard table contained QingType; QQ's private
keyboard table predated installation and did not. This is consistent with the
sandbox input-source cache issue independently documented in
[Qingjian issue 346](https://github.com/qingjian-team/qingjian/issues/346).
No private framework hooks or private TIS calls are shipped in QingType.

The installer now waits for the input service to exit, backs up only the two
named IntlDataCache keyboard tables, refreshes registration even for enabled
modes, and rechecks enabled state from fresh processes. Cache backups and full
local crash reports are excluded from Git. Local installation backed up 183 cache tables with no skips; QingType 0.2.1
registered successfully, remained enabled, and settings.json was byte-identical
before/after installation. Real QQ input remains user validation;
this document does not claim that a successful engine test proves QQ is fixed.

The old IMKCandidates + floating arrow + separate grid implementation below is
superseded. One AppKit panel now owns all candidate controls. Seventeen new UI checks cover
caret placement in a negative-origin display, screen-edge flipping, separate
arrow hit regions, same-window expansion, selection/scroll persistence, Escape,
and absolute-index numeric and Space selection. The cache helper tests preserve
unrelated files, backup bytes, symlinks, existing backups and root boundaries.

## Passed

- InputMethodKit app and SwiftUI settings app compile, install and pass local
  ad hoc signature verification. Yams is pinned through Package.resolved.
- Nine settings safety checks: Unicode persistence, invalid and duplicate phrase
  rejection, no partial invalid save, manual configuration protection, recovery
  backup, corrupt JSON handling and a dedicated user directory.
- Thirteen content/migration checks: recursive import_tables, owned file copies,
  flattened import list, disabling dictionaries, intact original files,
  circular/missing/traversal dependency rejection, truncated model rejection,
  preservation of old preferences, and three model-log verification checks.
- Nineteen Rime checks in an isolated temporary directory: full pinyin candidates,
  paging, Escape, Backspace, commit selection and exact text, custom phrases,
  Xiaohe candidates, and imported dictionary entries available in both input modes.
- Candidate row, arrow and grid now share one nonactivating AppKit panel; the
  inherited Squirrel candidate panel remains a selectable fallback.
- User confirmed with a real keyboard: selecting QingType, typing `nihao`, seeing
  candidates, and pressing Space inserts `你好`. The test field was also read back
  as `你好` through accessibility.
- TISCopyCurrentKeyboardInputSource reported QingType.Hans after switching via
  the system input-source shortcut. The previous command-line selection failure
  is no longer considered a blocker for using the input source.
- Imported the user's existing cs408 dictionary into QingType: 641 entries.
- Imported a copy of the existing Simplified Chinese Wanxiang model:
  398,497,836 bytes; SHA-256
  `9eedac1d836f3fdafb61b162035c8937253aedc106be40b2b957d9ab64e9ed89`.
- Applied settings from the installed 0.2 settings app. Deployment returned
  `success=true` and `modelVerified=true`. The UI visibly reports that dictionaries
  were compiled and the language model was loaded by the engine.
- Model evidence includes the selected grammar name, opening the imported .gram,
  and a successful gram_db double-array image load. Both regular Rime log files
  and plugin stderr are checked. Spelling-prism success cannot stand in for a
  grammar-model success. Plugin output is saved with each deployment.

## Current limits

The AppKit candidate renderer is not assumed to be pixel-identical to
Apple's built-in Chinese input method. Its detailed interactions, expanded
candidates, cross-application caret tracking, multiple displays, dark mode and
long sessions still need systematic comparison.

Automated UI key events did not reliably trigger composition in either Apple
pinyin or QingType. Real-keyboard confirmation is therefore the input acceptance
criterion; the automated engine tests alone do not prove UI compatibility.

No measured improvement in sentence accuracy is claimed from model loading.
The default base dictionary is Luna Pinyin; the complete Wanxiang schema/package
is separate from importing a .gram model. Current imports accept Rime dictionary
data and dependencies, not arbitrary schema/Lua packages or .scel dictionaries.

Standalone `--preview-system` is only a developer experiment without an active
input session. Offscreen NSView cache captures of that system window are not a
reliable representation of its on-screen appearance. The product directs users
to the real input test field instead of displaying a simulated native preview.

## Evidence and rerun

```sh
./scripts/build-dev.sh
./scripts/test.sh
./scripts/install-dev.sh
```

Use the installed settings app's Save and Apply action for exclusive deployment.
The direct --deploy-user-data command refuses to run while the input method is
active, protecting the user's database lock.

Evidence: build.log, build/test-results.log, build/install-results.log,
build/verified-deployment.json, and the deployment-logs directory under the
QingType user directory. Developer ID signing, notarization, public updates,
independent runtime builds and a broader compatibility matrix remain future work.

## Earlier IMKCandidates experiment (superseded in 0.2.1)

The first supplied screenshot is QingType (Rime candidates such as 妳好/逆号);
second is Apple's pinyin. The user explicitly limited this change to appearance.
Vocabulary, model, sorting and input preferences were preserved byte-for-byte
through installation, verified against the pre-update settings SHA-256.

Changes: selection keys now explicitly use an ASCII-capable keyboard layout,
with NSNumber key codes applied after the candidate data. The native panel gets
up to 64 candidates beginning at the current engine page, instead of only one
page, allowing its public paging controls to know more data is available.
Native selection/highlight callbacks map back to absolute Rime indices.

Five added engine checks passed: data extends beyond the first row; reading it
does not change first-page order or page state; later-page highlighting works;
numeric selection on that page commits; the committed candidate has the expected
absolute index. The suite now passes 9 safety + 13 content + 19 engine checks,
plus bundle identity and signature checks.

Actual numbering and paging-control appearance are awaiting real-keyboard visual
confirmation. Apple's private expanded-candidate UI is not assumed to be exposed
by the public IMKCandidates paging component.

## Expand/collapse and background revision

The user confirmed numbering and the right-side paging entry appeared after the
first appearance patch, then clarified that the desired arrow must expand the
window into a grid. The user explicitly excluded the bottom toolbar and asked
for the official reference's background color. Dictionary/ranking changes remain
out of scope.

Implemented a nonactivating AppKit grid with up to six columns, a fixed first row
of small candidate numbers, aligned word origins in all rows, subtle horizontal
separators and rounded selection highlights. The background is an adaptive light
sRGB #F2F2F2 / dark charcoal surface, avoiding the old popover material's darker
vibrancy tint. No bottom toolbar or footer remains. A top-right chevron and Escape
collapse the window. Arrow keys and first-row number keys are routed to the
stored absolute candidate indices. Selection and composition retain the text
client's focus.

The expand button follows the native candidate frame, and its level is matched
above the native window. Expanded placement follows whether the collapsed window
was above or below the caret and flips when screen space requires it.

Build and the existing suite passed after these changes. A live AppKit preview
was inspected through accessibility and a screenshot. Clicking the second-row
first candidate produced global index 6 in the preview callback. The collapse
callback also completed. The rendered preview is build/expanded-candidate-preview.png.

The user explicitly took responsibility for further real-input validation;
expanded interaction in the installed IME remains for the user to check.
