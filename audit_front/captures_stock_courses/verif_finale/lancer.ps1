# Captures de vérification finale (B1 à B5, C1) sur l'émulateur Android déjà démarré.
# Usage : powershell -File audit_front/captures_stock_courses/verif_finale/lancer.ps1 [emulator-5554]
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$racine = Split-Path (Split-Path (Split-Path $PSScriptRoot))
Set-Location $racine
$appareil = if ($args.Count -gt 0) { $args[0] } else { "emulator-5554" }
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb -s $appareil shell wm size 1080x2160
& $adb -s $appareil shell rm -rf /sdcard/Pictures/lc_verif
firebase emulators:exec --only "auth,firestore" --project le-comptoir-60ba8 "flutter test integration_test/captures_verification.dart -d $appareil --timeout 15m"
$code = $LASTEXITCODE
& $adb -s $appareil shell wm size reset
& $adb -s $appareil pull /sdcard/Pictures/lc_verif/. $PSScriptRoot
exit $code
