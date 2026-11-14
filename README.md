# dts-to-eac3

**English** | [Polski](README.pl.md)

Converts a movie's **DTS / DTS-HD Master Audio** track to **E-AC3 (Dolby Digital Plus)**.

Many TVs can't decode DTS, so a movie played from a USB drive, a hard disk or over DLNA has no sound.
Virtually every modern TV supports E-AC3. This tool creates a new E-AC3 track that you then add
to the movie (remux), without re-encoding the video.

- Decodes full DTS-HD MA (including the lossless layer), not just the DTS core.
- Keeps the original track untouched, so nothing is lost.
- Drag and drop, including several movies at once.
- Installs missing tools (ffmpeg, MKVToolNix) automatically via `winget`.
- Works on a clean Windows install: no PowerShell 7 and no execution policy changes needed.

> The tool's console messages are in Polish.

## How it works

1. **Analysis:** `ffprobe` reads the audio tracks and picks the first DTS track.
2. **Extraction:** `mkvextract` (for MKV) or `ffmpeg` (for other containers) saves the track unchanged to `.dts`.
3. **Conversion:** `ffmpeg` decodes the DTS-HD MA and encodes it to E-AC3 5.1, 48 kHz.
4. **Verification:** the script compares the output's duration with the source.

## Requirements

- Windows 10 (1809 or later) or Windows 11
- `winget`: [App Installer](https://apps.microsoft.com/detail/9NBLGGH4NWNX) from the Microsoft Store, included in Windows 11 by default
- Free disk space: about 5–7 GB per movie (the original `.dts` track plus the new `.eac3`),
  plus the size of the movie itself for the remux

## Quick start

1. Download the ZIP from the latest release on the
   [**Releases**](https://github.com/Dziukens/dts-to-eac3/releases/latest) page and extract it
   (or use `git clone`).
   > Before extracting, right-click the ZIP → **Properties** → check **Unblock**.
   > Otherwise Windows will show a warning every time you run a script.
2. *(Optional)* Run **`setup.cmd`** to install ffmpeg and MKVToolNix up front.
   You can skip this step: `convert.cmd` installs any missing tools on its first run.
   The MKVToolNix installer may ask for administrator rights.
3. **Drag a movie file onto `convert.cmd`** (several at once work too).
   You can also double-click it and paste the path to the movie.

Example: for a 2 h 53 min movie, extraction and conversion took about 2.5 minutes.

### Output

Files are written to an `eac3_out\` folder next to the movie:

| File | Contents |
|---|---|
| `movie.<index>.<lang>.dts` | the original track, unchanged |
| `movie.<index>.<lang>.eac3` | the new E-AC3 5.1, 48 kHz track (1024 kb/s by default) |

`<index>` is the track number in the movie and `<lang>` is its language code (e.g. `eng`, `pol`; `und` if not set).

If the script prints a warning about a **track delay** (in ms), note the value: you'll need it for the remux.

## Advanced usage (PowerShell)

```powershell
# list the audio tracks in a file
.\Convert-DtsToEac3.ps1 -InputFile "D:\Movies\movie.mkv" -ListTracks

# a specific track (Index from the list), a different bitrate and output folder
.\Convert-DtsToEac3.ps1 -InputFile "D:\Movies\movie.mkv" -TrackIndex 2 -Bitrate 1536k -OutDir "D:\Movies\out"
```

| Parameter | Default | Description |
|---|---|---|
| `-InputFile` | (required) | the movie file (MKV, M2TS, MP4…) |
| `-TrackIndex` | first DTS track | track index from `-ListTracks`; can also be a track in another format (e.g. TrueHD, FLAC) |
| `-Bitrate` | `1024k` | `640k` (streaming quality), `1024k` (very good), `1536k` (like DD+ on Blu-ray) |
| `-OutDir` | `eac3_out\` next to the movie | output folder |
| `-ListTracks` | | only lists the audio tracks |
| `-SkipExtract` | | encodes straight from the movie without saving the `.dts` (saves disk space) |

## Remux

Example: E-AC3 as the first (default) audio track, the original DTS-HD MA as the second.
The video and all subtitles are kept.

```powershell
& "C:\Program Files\MKVToolNix\mkvmerge.exe" -o "D:\Movies\movie.eac3.mkv" `
  --default-track-flag 1:no "D:\Movies\movie.mkv" `
  --language 0:eng --track-name "0:E-AC3 5.1" --default-track-flag 0:yes "D:\Movies\eac3_out\movie.1.eng.eac3" `
  --track-order "0:0,1:0,0:1"
```

Options placed before a file apply to that file. `0:`, `1:` are track numbers inside the file,
and in `--track-order`, `1:0` means "second file, track 0".

- The `1` in `--default-track-flag 1:no` is the DTS track's number in the movie (Index from `-ListTracks`). Adjust it to your file.
- Set `--language 0:eng` to the track's language (the same code as in the `.eac3` file name).
- Tracks not listed in `--track-order` (e.g. subtitles) go at the end in their original order.
- To drop the original DTS (a file several GB smaller), add `-A` before the movie file and leave out `--track-order`.
- If the script warned about a track delay, add `--sync 0:<ms>` before the `.eac3` file.
- Prefer a GUI? Use **MKVToolNix GUI** (Start menu).

## Limitations

- ffmpeg's E-AC3 encoder supports up to **5.1**. A 7.1 source is downmixed to 5.1
  (the back channels are mixed into the side channels at -3 dB; the front is unchanged).
- E-AC3 supports up to 48 kHz, so a 96 kHz source is resampled to 48 kHz.
- The encoding is lossy. The original `.dts` is kept, so you can redo the conversion at a different bitrate.
- Windows only.

## Troubleshooting

| Problem | Solution |
|---|---|
| "Windows protected your PC" or a security warning when running a `.cmd` | The ZIP wasn't unblocked before extracting. Click **More info → Run anyway**, or unblock the ZIP and extract it again. |
| `Nie znaleziono winget` (winget not found) | Install [App Installer](https://apps.microsoft.com/detail/9NBLGGH4NWNX), or install [ffmpeg](https://www.gyan.dev/ffmpeg/builds/) (add its `bin` folder to PATH) and [MKVToolNix](https://mkvtoolnix.download/downloads.html#windows) manually. |
| PowerShell blocks the `.ps1` when run directly | `powershell -ExecutionPolicy Bypass -File .\Convert-DtsToEac3.ps1 -InputFile "..."` |
| `Brak ścieżki DTS` (no DTS track) | The file has no DTS track. Check `-ListTracks` and pick a track with `-TrackIndex`. |
| `ffmpeg` doesn't work in a terminal right after installation | Open a new terminal to refresh PATH. The script itself finds ffmpeg either way. |

## For developers

| File | Role |
|---|---|
| `convert.cmd`, `setup.cmd` | launchers: run the `.ps1` scripts with `-ExecutionPolicy Bypass` |
| `Convert-DtsToEac3.ps1` | main script (Windows PowerShell 5.1+ and PowerShell 7) |
| `Setup.ps1` | installs ffmpeg and MKVToolNix via winget |
| `CHANGELOG.md` | change history, used for the release notes |
| `build-release.ps1` | builds the release package |

`.ps1` files must be saved as UTF-8 **with BOM** (otherwise PowerShell 5.1 garbles Polish characters),
and `.cmd` files as plain ASCII. `.gitattributes` enforces CRLF line endings.

**New release:**

1. Add a `## vX.Y.Z` section to `CHANGELOG.md` and commit.
2. `.\build-release.ps1 -Version X.Y.Z` creates `dist\dts-to-eac3-vX.Y.Z.zip` and `dist\release-notes-vX.Y.Z.md`.
3. `git tag vX.Y.Z` and `git push origin vX.Y.Z`.
4. On GitHub: **Releases → Draft a new release**, pick the tag, paste the notes and attach the ZIP.

## License

[MIT](LICENSE)
