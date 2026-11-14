# Zmiany

## v1.0.0

Pierwsze wydanie.

- Konwersja ścieżki **DTS / DTS-HD Master Audio** do **E-AC3 (Dolby Digital Plus) 5.1, 48 kHz**.
- Oryginalna ścieżka jest wyciągana bez strat do `.dts` (mkvextract dla MKV, ffmpeg dla innych kontenerów).
- Automatyczny downmix 7.1 → 5.1 i resampling 96 kHz → 48 kHz.
- Wykrywanie przesunięcia ścieżki względem obrazu, z gotową wartością `--sync` do remuxu.
- `convert.cmd`: przeciągnij jeden lub kilka filmów albo uruchom dwuklikiem i wklej ścieżkę.
- `setup.cmd`: instalacja ffmpeg i MKVToolNix przez winget. Brakujące narzędzia doinstalowują się też same przy pierwszej konwersji.
- Działa w Windows PowerShell 5.1 (czysty Windows 10/11), bez zmiany polityki wykonywania skryptów.

**Instalacja:** pobierz `dts-to-eac3-v1.0.0.zip`, przed rozpakowaniem odblokuj go
(prawy przycisk → Właściwości → Odblokuj), rozpakuj i przeciągnij film na `convert.cmd`.
