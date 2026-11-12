# Spike lessons for the Sámara conditions iPhone app
Written Nov 12, 2026 (PT). Sources: Spike transcript (agent 6a9ba50b-…, Nov 9–11 build 9/10 threads), the ios-app-validation-loop skill, `/workspace/spike-speed-audit-2026-11-09/report.md`, and `/workspace/spike-cursor-workflow-review-2026-11-11/report.md`.

## Why these rules exist (evidence, short)
- Build 9 took 10 h 11 min: 22 SHAs, 14 Mac runs and 5 Pepper rounds, and still wasn't uploaded. Mac verification was 55% of the critical path. UI failures stalled at 12–16 for six runs because fixes were guessed blind (Nov 9 audit).
- Build 10 took about 7 h from feedback to TestFlight. The late blockers were a visual check made too late, coding ahead of a product decision (the stopped-screen copy), and a media behavior that no screenshot could prove (Nov 11 review).
- A GIF showing a bug the executor's own report had already named went to Sean anyway ("Uh this is completely wrong haha").
- One gate run was lost because the coder and the gate shared a simulator and its camera permission was denied.

## The 10 rules
1. **Research and Sean's pick come first.** Do the domain research, get Sean's explicit answers (conditions list and backend option), send rough sketches, and only then do polished design. Never polish an invented need.
2. **One written entry per change, before any code.** In `docs/ISSUES.md`, write the intended behavior, the screen states it covers (loading, fresh, stale, offline, error, empty), one measurable acceptance check, and any open decision. Batch Sean's open decisions into one message, and never code ahead on a guessed answer.
3. **Lock the scope for each build.** New items go to the next build, not into the one in flight.
4. **Screens get checked early.** After a screen change, the coder captures the affected states with the in-repo screenshot helper (status bar fixed at 9:41) and checks them against a measurable target. Pepper reviews the real PNGs *before* the full gate, with at most one more round.
5. **Two test tiers.** In-between commits get the build, `swift test` (logic in a SwiftPM package) and only the affected or last-failed UI tests (`-only-testing`). The full UI suite, the screenshot pack and Pepper's pass run on release candidates only. Then TestFlight, then the phone-only checklist. Don't start a new gate while one runs; queue the newest SHA.
6. **Evidence before a third guess.** If the same test or gate fails on two SHAs in a row, the next commit is diagnostics only: an accessibility-tree dump, a screenshot at the failure point, the failing query and logs. The root-cause fix comes after that.
7. **Knowledge lives in the repo.** `docs/BUILD.md` (exact build and test commands), `docs/ISSUES.md`, `scripts/screenshots.sh` with its presets, and the test fixtures, including a frozen `fixtures/conditions-sample.json` so UI tests never hit the network. Tag every shipped build (`v0.1-b1`, …), and every report names the full SHA.
8. **Isolate the environment.** Use a separate repo, separate named simulators for coder and gate, and a separate derived-data/build folder from Spike's. Set location and notification permissions deliberately with `simctl privacy`/`simctl location` before launch. Never reuse Spike's simulator.
9. **Prove the data behavior directly.** For a conditions app, the "media bug" equivalent is time and data. Use fixture tests for stale data (the age label shows, never a silent blank), offline launch (last cache and its timestamp), tide extremes against the NOAA table, and timezone (America/Costa_Rica, UTC−6, no DST). A screenshot can't prove these.
10. **Never show Sean something unchecked.** Open every PNG yourself first. Call it a "simulator preview" until the phone smoke test passes. Send the full report as a real message with the SHA, what was tested and what wasn't, and Pepper's notes.

## Mac worker facts
- The coder runs as a Cursor cloud agent on Sean's Mac worker: CloudAgent environment `{"type":"machine","name":"SeanMac-SpikeReplay"}`.
- The worker is **shared with Spike**. Before launching, check the workers list and coordinate with Spike, and never run during an active Spike gate.
- The worker **does not survive a reboot**. Restart it with `~/cursor-worker/finish-setup.sh`.
- Mac-offline rule (from the skill): probe with ListMachines plus `hostname; date` on the `kind: desktop` id, and re-probe at about 1, 3, 7 and 15 min before telling Sean anything. A cloud agent's "no Mac worker" means its own pool, not Sean's Mac.
- Spike's simulator is named `SpikeWorker-iPhone17Pro`, and Spike's repo is `seanholt111/SpikeReplay`. **Don't touch either.**
- Proposed for this app (nothing created yet): repo `seanholt111/SamaraConditions`, simulators `Samara-Coder-iPhone` and `Samara-Gate-iPhone`, and build folder `~/cursor-builds/samara-conditions/DerivedData`. Use absolute `/Users/<name>/…` paths, not `~`, in gate scripts.
