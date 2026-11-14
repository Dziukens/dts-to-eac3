# Changelog

## v1.1.0

- Console messages in **English** and **Polish**. Choose with `-Language en|pl`
  (also via `convert.cmd` / `setup.cmd`), the `DTS_TO_EAC3_LANG` environment variable,
  or automatically from the Windows display language.
- `Convert-DtsToEac3.ps1` accepts several files at once and asks for a path when run without one.
  A failed file no longer stops the rest, and a summary is printed at the end.
- MKVToolNix output follows the chosen language.
- Docs: English README (Polish version in `README.pl.md`).

## v1.0.0

First release.

- Converts a **DTS / DTS-HD Master Audio** track to **E-AC3 (Dolby Digital Plus) 5.1, 48 kHz**.
- Extracts the original track losslessly to `.dts` (mkvextract for MKV, ffmpeg for other containers).
- Automatic 7.1 → 5.1 downmix and 96 kHz → 48 kHz resampling.
- Detects a track delay relative to the video and prints the `--sync` value to use for the remux.
- `convert.cmd`: drag one or more movies onto it, or double-click it and paste a path.
- `setup.cmd`: installs ffmpeg and MKVToolNix via winget. Missing tools are also installed automatically on the first conversion.
- Runs on Windows PowerShell 5.1 (a clean Windows 10/11 install) without changing the script execution policy.

**Installation:** download `dts-to-eac3-v1.0.0.zip`, unblock it before extracting
(right-click → Properties → Unblock), extract it and drag a movie onto `convert.cmd`.
