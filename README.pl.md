# dts-to-eac3

[English](README.md) | **Polski**

Konwertuje ścieżkę audio **DTS / DTS-HD Master Audio** z filmu do **E-AC3 (Dolby Digital Plus)**.

Wiele telewizorów nie dekoduje DTS, więc film odtwarzany z pendrive'a, dysku albo przez DLNA
nie ma dźwięku. E-AC3 obsługuje praktycznie każdy współczesny telewizor. Skrypt przygotowuje
nową ścieżkę E-AC3, którą potem dodajesz do filmu (remux), bez ponownego kodowania obrazu.

- Dekoduje pełny DTS-HD MA (razem z warstwą bezstratną), a nie tylko rdzeń DTS.
- Zachowuje oryginalną ścieżkę bez zmian, więc nic nie tracisz.
- Obsługa przeciągnij-i-upuść, także kilku filmów naraz.
- Sam instaluje brakujące narzędzia (ffmpeg, MKVToolNix) przez `winget`.
- Działa na czystym Windowsie: nie wymaga PowerShell 7 ani zmiany polityki wykonywania skryptów.
- Komunikaty w konsoli po polsku albo po angielsku ([patrz Język](#język)).

## Jak to działa

1. **Analiza:** `ffprobe` odczytuje ścieżki audio i wybiera pierwszą ścieżkę DTS.
2. **Wyciągnięcie:** `mkvextract` (dla MKV) albo `ffmpeg` (dla innych kontenerów) zapisuje ścieżkę bez zmian do `.dts`.
3. **Konwersja:** `ffmpeg` dekoduje DTS-HD MA i koduje go do E-AC3 5.1, 48 kHz.
4. **Weryfikacja:** skrypt porównuje czas trwania wyniku ze źródłem.

## Wymagania

- Windows 10 (1809 lub nowszy) albo Windows 11
- `winget`: [Instalator aplikacji](https://apps.microsoft.com/detail/9NBLGGH4NWNX) z Microsoft Store, domyślnie jest w Windows 11
- Wolne miejsce na dysku: około 5–7 GB na film (oryginalna ścieżka `.dts` plus nowa `.eac3`),
  a do remuxu dodatkowo tyle, ile zajmuje sam film

## Szybki start

1. Pobierz ZIP z najnowszego wydania w zakładce
   [**Releases**](https://github.com/Dziukens/dts-to-eac3/releases/latest) i rozpakuj go
   (albo użyj `git clone`).
   > Przed rozpakowaniem kliknij ZIP prawym przyciskiem → **Właściwości** → zaznacz **Odblokuj**.
   > Inaczej Windows będzie ostrzegał przy każdym uruchomieniu skryptu.
2. *(Opcjonalnie)* Uruchom **`setup.cmd`**, żeby od razu zainstalować ffmpeg i MKVToolNix.
   Ten krok można pominąć, bo `convert.cmd` sam doinstaluje brakujące narzędzia przy pierwszym uruchomieniu.
   Instalator MKVToolNix może poprosić o uprawnienia administratora.
3. **Przeciągnij plik z filmem na `convert.cmd`** (można kilka naraz).
   Możesz też uruchomić go dwuklikiem i wkleić ścieżkę do filmu.

Przykład: dla filmu trwającego 2 h 53 min wyciągnięcie i konwersja zajęły około 2,5 minuty.

### Wynik

Pliki trafiają do folderu `eac3_out\` obok filmu:

| Plik | Zawartość |
|---|---|
| `film.<index>.<język>.dts` | oryginalna ścieżka, bez zmian |
| `film.<index>.<język>.eac3` | nowa ścieżka E-AC3 5.1, 48 kHz (domyślnie 1024 kb/s) |

`<index>` to numer ścieżki w filmie, a `<język>` to jej kod języka (np. `eng`, `pol`; `und` gdy nieokreślony).

Jeśli skrypt wypisze ostrzeżenie o **przesunięciu ścieżki** (w ms), zapamiętaj tę wartość,
bo będzie potrzebna przy remuxie.

## Zaawansowane użycie (PowerShell)

```powershell
# lista ścieżek audio w pliku
.\Convert-DtsToEac3.ps1 "D:\Filmy\film.mkv" -ListTracks

# kilka plików naraz
.\Convert-DtsToEac3.ps1 "D:\Filmy\a.mkv" "D:\Filmy\b.mkv"

# konkretna ścieżka (Index z listy), inny bitrate i folder wyjściowy
.\Convert-DtsToEac3.ps1 "D:\Filmy\film.mkv" -TrackIndex 2 -Bitrate 1536k -OutDir "D:\Filmy\out"
```

Te same opcje działają też z `convert.cmd`, np. `convert.cmd "D:\Filmy\film.mkv" -Bitrate 1536k`.

| Parametr | Domyślnie | Opis |
|---|---|---|
| `-InputFile` | pyta o ścieżkę | jeden lub kilka plików z filmami (MKV, M2TS, MP4…); nazwę parametru można pominąć |
| `-TrackIndex` | pierwsza ścieżka DTS | indeks ścieżki z `-ListTracks`; może to być też ścieżka w innym formacie (np. TrueHD, FLAC) |
| `-Bitrate` | `1024k` | `640k` (jakość streamingowa), `1024k` (bardzo dobra), `1536k` (jak DD+ na Blu-ray) |
| `-OutDir` | `eac3_out\` obok filmu | folder wyjściowy |
| `-ListTracks` | | tylko wypisuje ścieżki audio |
| `-SkipExtract` | | koduje bezpośrednio z filmu, bez zapisywania `.dts` (oszczędza miejsce) |
| `-Language` | `auto` | język komunikatów: `pl`, `en` albo `auto` |

## Język

Komunikaty w konsoli są dostępne po **polsku** i po **angielsku**. Język jest wybierany w tej kolejności:

1. Parametr `-Language pl` / `-Language en`, np. `convert.cmd film.mkv -Language en`
   albo `setup.cmd -Language en`.
2. Zmienna środowiskowa `DTS_TO_EAC3_LANG`. Żeby ustawić ją na stałe (potem otwórz nowe okno):
   ```bat
   setx DTS_TO_EAC3_LANG en
   ```
3. Język interfejsu Windows: polski → `pl`, każdy inny → `en`.

Nowy język dodasz, dopisując sekcję w [`Messages.ps1`](Messages.ps1). Brakujące teksty są brane z wersji angielskiej.

## Remux

Przykład: E-AC3 jako pierwsza (domyślna) ścieżka audio, oryginalny DTS-HD MA jako druga.
Obraz i wszystkie napisy zostają.

```powershell
& "C:\Program Files\MKVToolNix\mkvmerge.exe" -o "D:\Filmy\film.eac3.mkv" `
  --default-track-flag 1:no "D:\Filmy\film.mkv" `
  --language 0:eng --track-name "0:E-AC3 5.1" --default-track-flag 0:yes "D:\Filmy\eac3_out\film.1.eng.eac3" `
  --track-order "0:0,1:0,0:1"
```

Opcje stojące przed plikiem dotyczą tego pliku. `0:`, `1:` to numery ścieżek wewnątrz pliku,
a w `--track-order` zapis `1:0` oznacza „drugi plik, ścieżka 0”.

- `1` w `--default-track-flag 1:no` to numer ścieżki DTS w filmie (Index z `-ListTracks`). Dopasuj go do swojego pliku.
- `--language 0:eng` ustaw na język ścieżki (ten sam, co w nazwie pliku `.eac3`).
- Ścieżki pominięte w `--track-order` (np. napisy) trafiają na koniec w oryginalnej kolejności.
- Żeby usunąć oryginalny DTS (plik mniejszy o kilka GB), dodaj `-A` przed plikiem filmu i pomiń `--track-order`.
- Jeśli skrypt ostrzegł o przesunięciu ścieżki, dodaj `--sync 0:<ms>` przed plikiem `.eac3`.
- Wygodniej graficznie: **MKVToolNix GUI** (menu Start).

## Ograniczenia

- Enkoder E-AC3 w ffmpeg obsługuje maks. **5.1**. Źródło 7.1 jest miksowane do 5.1
  (tylne kanały wchodzą do bocznych z -3 dB, przód bez zmian).
- E-AC3 obsługuje maks. 48 kHz, więc źródło 96 kHz jest resamplowane do 48 kHz.
- Kodowanie jest stratne. Oryginalny `.dts` zostaje, więc możesz powtórzyć konwersję z innym bitrate.
- Tylko Windows.

## Rozwiązywanie problemów

| Problem | Rozwiązanie |
|---|---|
| „System Windows ochronił ten komputer” albo ostrzeżenie przy uruchamianiu `.cmd` | ZIP nie został odblokowany przed rozpakowaniem. Kliknij **Więcej informacji → Uruchom mimo to** albo odblokuj ZIP i rozpakuj go ponownie. |
| `Nie znaleziono winget` | Zainstaluj [Instalator aplikacji](https://apps.microsoft.com/detail/9NBLGGH4NWNX) albo zainstaluj ręcznie [ffmpeg](https://www.gyan.dev/ffmpeg/builds/) (folder `bin` dodaj do PATH) i [MKVToolNix](https://mkvtoolnix.download/downloads.html#windows). |
| PowerShell blokuje `.ps1` przy uruchamianiu bezpośrednio | `powershell -ExecutionPolicy Bypass -File .\Convert-DtsToEac3.ps1 -InputFile "..."` |
| `Brak ścieżki DTS` | Plik nie ma ścieżki DTS. Sprawdź `-ListTracks` i wskaż ścieżkę przez `-TrackIndex`. |
| `ffmpeg` nie działa w terminalu zaraz po instalacji | Otwórz nowy terminal (odświeżenie PATH). Sam skrypt znajduje ffmpeg również bez tego. |

## Dla deweloperów

| Plik | Rola |
|---|---|
| `convert.cmd`, `setup.cmd` | launchery: uruchamiają skrypty `.ps1` z `-ExecutionPolicy Bypass` |
| `Convert-DtsToEac3.ps1` | główny skrypt (Windows PowerShell 5.1+ i PowerShell 7) |
| `Setup.ps1` | instalacja ffmpeg i MKVToolNix przez winget |
| `Messages.ps1` | komunikaty konsoli dla każdego języka i wybór języka |
| `CHANGELOG.md` | historia zmian, z niej powstaje opis wydania |
| `build-release.ps1` | buduje paczkę do wydania |

Pliki `.ps1` muszą być zapisane w UTF-8 **z BOM** (inaczej PowerShell 5.1 psuje polskie znaki),
a `.cmd` w czystym ASCII. Wszystkie teksty dla użytkownika trzymaj w `Messages.ps1`, a nie w plikach `.cmd`. Końce linii CRLF pilnuje `.gitattributes`.

**Nowe wydanie:**

1. Dopisz sekcję `## vX.Y.Z` do `CHANGELOG.md` i zacommituj zmiany.
2. `.\build-release.ps1 -Version X.Y.Z` tworzy `dist\dts-to-eac3-vX.Y.Z.zip` i `dist\release-notes-vX.Y.Z.md`.
3. `git tag vX.Y.Z` oraz `git push origin vX.Y.Z`.
4. Na GitHubie: **Releases → Draft a new release**, wybierz tag, wklej opis i dołącz ZIP.