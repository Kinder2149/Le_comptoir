# Lance un seul parcours Android : un_parcours.ps1 <nom_du_fichier_sans_.dart>
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Set-Location (Split-Path $PSScriptRoot)
firebase emulators:exec --only "auth,firestore" --project le-comptoir-60ba8 "flutter test integration_test/$($args[0]).dart -d emulator-5554 --timeout 15m" 2>&1 | Out-File -Encoding utf8 "audit_front/$($args[0]).txt"
