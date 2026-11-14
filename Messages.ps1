<#
    Komunikaty konsoli w wielu językach / Console messages in multiple languages.
    Dołączany (dot-source) przez Convert-DtsToEac3.ps1 i Setup.ps1.

    Kolejność wyboru języka / Language selection order:
      1. parametr -Language en|pl
      2. zmienna środowiskowa DTS_TO_EAC3_LANG (en|pl)
      3. język interfejsu Windows (polski -> pl, każdy inny -> en)

    Nowy język: dodaj klucz do $Messages i do $SupportedLanguages (brakujące teksty spadają do en).
#>

$SupportedLanguages = @{ en = 'en-US'; pl = 'pl-PL' }

$Messages = @{
    en = @{
        WarnPrefix       = 'WARNING: '
        ErrorPrefix      = 'ERROR: '
        # Convert-DtsToEac3.ps1
        MissingTools     = 'ffmpeg or MKVToolNix is missing - running the installer (Setup.ps1)...'
        StillMissing     = 'Still missing: {0}. Install them manually (see README.md).'
        Prompt           = 'Drag a movie file into this window (or paste its path) and press Enter.'
        PromptLabel      = 'File'
        FileNotFound     = 'File not found: {0}'
        ProbeFailed      = 'ffprobe cannot read the file: {0}'
        NoAudio          = 'The file has no audio tracks.'
        AudioTracksIn    = 'Audio tracks in: {0}'
        ColCodec         = 'Codec'
        ColProfile       = 'Profile'
        ColChannels      = 'Channels'
        ColLayout        = 'Layout'
        ColLanguage      = 'Language'
        ColTitle         = 'Title'
        TrackNotFound    = 'Stream {0} does not exist or is not an audio track.'
        NoDts            = 'No DTS track found. Pick a track with -TrackIndex.'
        Selected         = 'Selected stream {0}: {1}, {2} ch ({3}), {4} Hz, language: {5}'
        Delay            = 'The track is offset by {0} ms relative to the video. When remuxing, use: mkvmerge --sync 0:{0}'
        Extracting       = '[1/2] Extracting the track -> {0}'
        ExtractFailed    = 'Track extraction failed (exit code {0}).'
        NotDts           = '[1/2] The track is not DTS - encoding directly from the source.'
        Downmix          = 'The source has {0} channels ({1}). The ffmpeg E-AC3 encoder supports up to 5.1, downmixing to 5.1.'
        Converting       = '[2/2] Converting to E-AC3 ({0}) -> {1}'
        ConvertFailed    = 'Conversion failed (exit code {0}).'
        Done             = 'Done: {0}, {1} ch ({2}), {3} Hz, {4:N0} kb/s, duration {5:N1} s (source {6:N1} s)'
        DurationMismatch = 'The output duration differs from the source by more than 1 s - check the file before remuxing.'
        OutputFile       = 'E-AC3 file: {0}'
        SummaryOk        = 'Finished: {0} file(s) converted.'
        SummaryFailed    = 'Finished with errors: {0} of {1} file(s) failed.'
        # Setup.ps1
        AlreadyInstalled = '{0}: already installed'
        NoWinget         = @'
winget was not found. Install "App Installer" from the Microsoft Store and run setup again,
or install the tools manually:
  ffmpeg:     https://www.gyan.dev/ffmpeg/builds/   (add the bin folder to PATH)
  MKVToolNix: https://mkvtoolnix.download/downloads.html#windows
'@
        NoWingetShort    = 'winget not found.'
        Installing       = 'Installing {0}...'
        InstallFailed    = 'Installing {0} failed (winget exit code: {1}).'
        SetupDone        = 'Done. The tools are installed.'
    }
    pl = @{
        WarnPrefix       = 'OSTRZEŻENIE: '
        ErrorPrefix      = 'BŁĄD: '
        # Convert-DtsToEac3.ps1
        MissingTools     = 'Brakuje ffmpeg lub MKVToolNix - uruchamiam instalację (Setup.ps1)...'
        StillMissing     = 'Nadal brakuje: {0}. Zainstaluj je ręcznie (patrz README.md).'
        Prompt           = 'Przeciągnij plik z filmem do tego okna (albo wklej ścieżkę) i naciśnij Enter.'
        PromptLabel      = 'Plik'
        FileNotFound     = 'Plik nie istnieje: {0}'
        ProbeFailed      = 'ffprobe nie może odczytać pliku: {0}'
        NoAudio          = 'Plik nie zawiera żadnych ścieżek audio.'
        AudioTracksIn    = 'Ścieżki audio w: {0}'
        ColCodec         = 'Kodek'
        ColProfile       = 'Profil'
        ColChannels      = 'Kanały'
        ColLayout        = 'Układ'
        ColLanguage      = 'Język'
        ColTitle         = 'Tytuł'
        TrackNotFound    = 'Strumień {0} nie istnieje lub nie jest ścieżką audio.'
        NoDts            = 'Brak ścieżki DTS. Wskaż ścieżkę ręcznie przez -TrackIndex.'
        Selected         = 'Wybrano strumień {0}: {1}, {2} kan. ({3}), {4} Hz, język: {5}'
        Delay            = 'Ścieżka ma przesunięcie {0} ms względem obrazu. Przy remuxie użyj: mkvmerge --sync 0:{0}'
        Extracting       = '[1/2] Wyciąganie ścieżki -> {0}'
        ExtractFailed    = 'Wyciąganie ścieżki nie powiodło się (kod {0}).'
        NotDts           = '[1/2] Ścieżka nie jest DTS - koduję bezpośrednio ze źródła.'
        Downmix          = 'Źródło ma {0} kanałów ({1}). Enkoder E-AC3 w ffmpeg obsługuje maks. 5.1, robię downmix do 5.1.'
        Converting       = '[2/2] Konwersja do E-AC3 ({0}) -> {1}'
        ConvertFailed    = 'Konwersja nie powiodła się (kod {0}).'
        Done             = 'Gotowe: {0}, {1} kan. ({2}), {3} Hz, {4:N0} kb/s, czas {5:N1} s (źródło {6:N1} s)'
        DurationMismatch = 'Czas trwania wyniku różni się od źródła o ponad 1 s - sprawdź plik przed remuxem.'
        OutputFile       = 'Plik E-AC3: {0}'
        SummaryOk        = 'Zakończono: przekonwertowano plików: {0}.'
        SummaryFailed    = 'Zakończono z błędami: nie powiodło się {0} z {1} plików.'
        # Setup.ps1
        AlreadyInstalled = '{0}: już zainstalowany'
        NoWinget         = @'
Nie znaleziono winget. Zainstaluj "Instalator aplikacji" (App Installer) ze sklepu Microsoft Store
i uruchom setup ponownie, albo zainstaluj narzędzia ręcznie:
  ffmpeg:     https://www.gyan.dev/ffmpeg/builds/   (dodaj folder bin do PATH)
  MKVToolNix: https://mkvtoolnix.download/downloads.html#windows
'@
        NoWingetShort    = 'Brak winget.'
        Installing       = 'Instaluję {0}...'
        InstallFailed    = 'Instalacja {0} nie powiodła się (kod winget: {1}).'
        SetupDone        = 'Gotowe. Narzędzia są zainstalowane.'
    }
}

function Resolve-Language([string]$Requested) {
    if ($Requested -and $Requested -ne 'auto') { return $Requested.ToLower() }
    $envLang = "$env:DTS_TO_EAC3_LANG".Trim().ToLower()
    if ($SupportedLanguages.ContainsKey($envLang)) { return $envLang }
    $ui = (Get-UICulture).TwoLetterISOLanguageName
    if ($SupportedLanguages.ContainsKey($ui)) { return $ui }
    return 'en'
}

function Set-Language([string]$Lang) {
    $script:Lang        = $Lang
    $script:LangCulture = [Globalization.CultureInfo]::GetCultureInfo($SupportedLanguages[$Lang])
}

# T 'Klucz' arg0 arg1 ... -> przetłumaczony i sformatowany tekst / translated, formatted text
function T {
    param(
        [Parameter(Mandatory, Position = 0)][string]$Key,
        [Parameter(ValueFromRemainingArguments)][object[]]$FormatArgs
    )
    $text = $Messages[$script:Lang][$Key]
    if (-not $text) { $text = $Messages['en'][$Key] }
    if (-not $text) { return $Key }
    if ($FormatArgs) { return [string]::Format($script:LangCulture, $text, $FormatArgs) }
    return $text
}

function Write-Warn([string]$Text) { Write-Host ((T 'WarnPrefix') + $Text) -ForegroundColor Yellow }
