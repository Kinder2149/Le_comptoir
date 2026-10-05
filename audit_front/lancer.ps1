# Audit visuel : copie locale de Firebase + émulateur Android déjà démarré.
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
$env:CAPTURES = if ($args.Count -gt 0) { $args[0] } else { "audit_front/avant" }
Set-Location (Split-Path $PSScriptRoot)
firebase emulators:exec --only "auth,firestore" --project le-comptoir-60ba8 "flutter drive --driver=audit_front/pilote/integration_test.dart --target=audit_front/audit_visuel_test.dart -d emulator-5554"
exit $LASTEXITCODE
