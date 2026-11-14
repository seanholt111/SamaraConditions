# Build and run

Repo root: the directory that contains `pipeline/` and `ios/`.

## Pipeline, on this Mac

Python 3.9 or newer. A C compiler (`cc`) is required for the Liljegren library.

```bash
python3 -m venv .venv
.venv/bin/pip install -r pipeline/requirements.txt
cd pipeline
PYTHONPATH=src ../.venv/bin/python -m pytest tests -q
PYTHONPATH=src ../.venv/bin/python -m samara fixture --out ../fixtures/conditions.fixture.json
```

A live file, from the repo root, keeping the previous file if this run is bad:

```bash
cd pipeline
PYTHONPATH=src ../.venv/bin/python -m samara live --out ../docs/conditions.json --previous ../docs/conditions.json
```

The fixture week pins the published quartiles (126.1 / 157.0 / 197.0 kJ) and the 28.5 kJ calm line. 11 Nov hours come from `data/this-week-hourly-nov11.csv`. 12–17 Nov hours come from `data/snapshot-forecast.json` and `data/snapshot-marine.json`, an Open-Meteo pull on 12 Nov 2026. The original all-days hourly file was not in the source bundle, and the live model has moved, so Thu–Tue calm windows are this later run.

Tides for 1 Dec 2026–30 Jun 2027 are already in `data/tides-puntarenas-2026-2027.json` (NOAA CO-OPS 9684403, MLLW, lst).

## App

Xcode 27, iOS 17 simulator. Derived data stays out of Spike's build folder.

```bash
xcodebuild \
  -project ios/SamaraConditions.xcodeproj \
  -scheme SamaraConditions \
  -destination 'platform=iOS Simulator,name=Samara-Gate-iPhone' \
  -derivedDataPath /Users/seanholt/cursor-builds/samara-conditions/DerivedData \
  build
```

Logic tests, no simulator:

```bash
cd ios/SamaraCore && swift test
```

One UI test:

```bash
xcodebuild \
  -project ios/SamaraConditions.xcodeproj \
  -scheme SamaraConditions \
  -destination 'platform=iOS Simulator,name=Samara-Gate-iPhone' \
  -derivedDataPath /Users/seanholt/cursor-builds/samara-conditions/DerivedData \
  test -only-testing:SamaraConditionsUITests/StatesUITests/testFresh
```

Screenshots, status bar fixed at 9:41, into `screenshots/<shortsha>/`:

```bash
bash scripts/screenshots.sh
```

The simulator is `Samara-Gate-iPhone`. Do not boot or erase `SpikeWorker-iPhone17Pro`.

Bundle id `com.seanholt.samaraconditions`. Signing is off for the simulator. For TestFlight, set the development team in the target and let Xcode manage signing. Sean handles the Apple sign-in.

The app reads `https://seanholt111.github.io/SamaraConditions/conditions.json`, caches it, and opens the cache when the network fails. Launch arguments `-use-fixture` and `-ui-state` (loading, fresh, stale, stale-tide, offline, error, imn) draw the frozen week instead.

## Morning job

The workflow is `.github/workflows/conditions.yml` (the same text is kept at `docs/github-actions-conditions.yml`). It runs at 10:17 and 11:17 UTC (04:17 and 05:17 in Costa Rica) and on workflow_dispatch. It runs the tests, then writes `docs/conditions.json` with `--previous` pointed at that same file, and commits the file with `heartbeat.txt` so the schedule is not turned off for inactivity. A failed fetch or a failed validation leaves the last good file in place.

GitHub Pages already serves the `docs/` folder from `main`, so that commit is the publish. The job does not upload a Pages artifact or use a `github-pages` environment, and the repository Pages setting stays as it is.
