# Fabrique les captures de la fiche Play Store sur l'émulateur Android déjà démarré.
# Usage : powershell -File play_store/captures/lancer_captures.ps1 [emulator-5554]
# Le test dépose les images dans /sdcard/Pictures/lc_captures (elles survivent à la désinstallation de l'appli).
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$racine = Split-Path (Split-Path $PSScriptRoot)
Set-Location $racine
$appareil = if ($args.Count -gt 0) { $args[0] } else { "emulator-5554" }
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
# Google Play : le grand côté ne doit pas dépasser 2 fois le petit (1080x2160 = 2:1).
& $adb -s $appareil shell wm size 1080x2160
& $adb -s $appareil shell rm -rf /sdcard/Pictures/lc_captures
firebase emulators:exec --only "auth,firestore" --project le-comptoir-60ba8 "flutter test integration_test/captures.dart -d $appareil --timeout 15m"
$code = $LASTEXITCODE
& $adb -s $appareil shell wm size reset
& $adb -s $appareil pull /sdcard/Pictures/lc_captures/. $PSScriptRoot
exit $code
