# Sámara Conditions

A private family iPhone app for the Holt stay in Sámara, Guanacaste, from 5 Dec 2026 to 1 Jun 2027, and the free morning job that feeds it.

The phone downloads one file, `conditions.json`, and draws it. Heat, windows, shore energy, and the calm line are computed in the morning job. Tides for the stay are bundled from NOAA, so the curve does not depend on the server.

Open-Meteo weather and waves are CC BY 4.0. Tide predictions are NOAA CO-OPS station 9684403, public domain. See `NOTICE` and the Sources sheet in the app.

How to build, test, and shoot the screens: `docs/BUILD.md`. What each screen does: `docs/ISSUES.md`. The locked design is `docs/source/design-spec-v1.md`.
