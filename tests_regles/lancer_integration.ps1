# Lance les tests d'intégration sur l'émulateur Android (déjà démarré),
# contre les émulateurs Firebase locaux.
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Set-Location (Split-Path $PSScriptRoot)
$appareil = if ($args.Count -gt 0) { $args[0] } else { "emulator-5554" }
firebase emulators:exec --only "auth,firestore" --project le-comptoir-60ba8 "flutter test integration_test -d $appareil --timeout 15m"
exit $LASTEXITCODE
