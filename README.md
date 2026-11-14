# dts-to-eac3

Konwertuje ścieżkę audio **DTS / DTS-HD Master Audio** z filmu do **E-AC3 (Dolby Digital Plus)**,
który obsługuje większość telewizorów. Oryginalna ścieżka jest wyciągana bez zmian, a nowa
trafia do osobnego pliku `.eac3`, gotowego do remuxu.

- Dekoduje pełny DTS-HD MA (razem z warstwą bezstratną), a nie tylko rdzeń DTS.
- Sam instaluje brakujące narzędzia (ffmpeg, MKVToolNix) przez `winget`.
- Działa na czystym Windowsie: nie wymaga PowerShell 7 ani zmiany polityki wykonywania skryptów.

## Wymagania

- Windows 10 (1809+) lub Windows 11
- `winget` (Instalator aplikacji z Microsoft Store, domyślnie jest w Windows 11)

## Szybki start

1. Pobierz ZIP z najnowszego wydania w zakładce
   [**Releases**](https://github.com/Dziukens/dts-to-eac3/releases/latest) i rozpakuj go
   (albo użyj `git clone`).
   > Jeśli pobierasz ZIP: przed rozpakowaniem kliknij go prawym przyciskiem → **Właściwości** →
   > zaznacz **Odblokuj**. Inaczej Windows będzie pytał o zgodę przy każdym uruchomieniu.
2. Uruchom **`setup.cmd`** (jednorazowo). Instaluje ffmpeg i MKVToolNix, a te już zainstalowane pomija.
   Instalacja MKVToolNix może poprosić o uprawnienia administratora.
3. **Przeciągnij plik z filmem na `convert.cmd`** (można kilka naraz).
   Możesz też uruchomić go dwuklikiem i wkleić ścieżkę.

Wynik trafia do folderu `eac3_out\` obok filmu:

| Plik | Zawartość |
|---|---|
| `film.<index>.<język>.dts` | oryginalna ścieżka, bez zmian |
| `film.<index>.<język>.eac3` | nowa ścieżka E-AC3 5.1, 48 kHz, 1024 kb/s |

Krok 2 można pominąć, bo `convert.cmd` przy pierwszym uruchomieniu sam doinstaluje brakujące narzędzia.

## Zaawansowane użycie (PowerShell)

```powershell
# lista ścieżek audio w pliku
.\Convert-DtsToEac3.ps1 -InputFile "D:\Filmy\film.mkv" -ListTracks

# konkretna ścieżka (Index z listy), inny bitrate i folder wyjściowy
.\Convert-DtsToEac3.ps1 -InputFile "D:\Filmy\film.mkv" -TrackIndex 2 -Bitrate 1536k -OutDir "D:\Filmy\out"
```

| Parametr | Domyślnie | Opis |
|---|---|---|
| `-InputFile` | (wymagany) | plik z filmem (MKV, M2TS, MP4…) |
| `-TrackIndex` | pierwsza ścieżka DTS | indeks strumienia z `-ListTracks` |
| `-Bitrate` | `1024k` | `640k` (jakość streamingowa), `1024k`, `1536k` (jak DD+ na Blu-ray) |
| `-OutDir` | `eac3_out\` obok filmu | folder wyjściowy |
| `-ListTracks` | | tylko wypisuje ścieżki audio |
| `-SkipExtract` | | koduje bezpośrednio z filmu, bez zapisywania `.dts` |

Jeśli PowerShell blokuje uruchomienie skryptu, użyj:
`powershell -ExecutionPolicy Bypass -File .\Convert-DtsToEac3.ps1 -InputFile "..."`

## Remux

Przykład: E-AC3 jako pierwsza (domyślna) ścieżka audio, oryginalny DTS-HD MA jako druga.
Obraz i wszystkie napisy zostają.

```powershell
& "C:\Program Files\MKVToolNix\mkvmerge.exe" -o "D:\Filmy\film.eac3.mkv" `
  --default-track-flag 1:no "D:\Filmy\film.mkv" `
  --language 0:eng --track-name "0:E-AC3 5.1" --default-track-flag 0:yes "D:\Filmy\eac3_out\film.1.eng.eac3" `
  --track-order "0:0,1:0,0:1"
```

- `1` w `--default-track-flag 1:no` to ID ścieżki DTS w filmie (Index z `-ListTracks`). Trzeba ją dopasować do swojego pliku.
- Ścieżki pominięte w `--track-order` (np. napisy) trafiają na koniec w oryginalnej kolejności.
- Żeby usunąć oryginalny DTS (mniejszy plik), dodaj `-A` przed plikiem filmu i pomiń `--track-order`.
- Jeśli skrypt ostrzegł o **przesunięciu ścieżki**, dodaj `--sync 0:<ms>` przed plikiem `.eac3`.
- Wygodniej graficznie: **MKVToolNix GUI** (menu Start).

## Ograniczenia

- Enkoder E-AC3 w ffmpeg obsługuje maks. **5.1**. Źródło 7.1 jest miksowane do 5.1
  (tylne kanały wchodzą do bocznych z -3 dB, przód bez zmian).
- E-AC3 obsługuje maks. 48 kHz, więc źródło 96 kHz jest resamplowane do 48 kHz.
- Kodowanie jest stratne. Oryginalny `.dts` zostaje, więc możesz powtórzyć konwersję z innym bitrate.

## Pliki

| Plik | Rola |
|---|---|
| `convert.cmd` | launcher: przeciągnij film / dwuklik |
| `setup.cmd` | launcher instalacji narzędzi |
| `Convert-DtsToEac3.ps1` | główny skrypt (PowerShell 5.1+) |
| `Setup.ps1` | instalacja ffmpeg i MKVToolNix przez winget |
| `CHANGELOG.md` | historia zmian, z niej powstaje opis wydania |
| `build-release.ps1` | buduje paczkę do wydania: `.\build-release.ps1 -Version 1.0.0` → `dist\` |
