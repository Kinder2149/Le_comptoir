# Lance les tests de règles Firestore sur les émulateurs locaux.
# Les émulateurs exigent Java 21 : on utilise celui d'Android Studio.
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
Set-Location (Split-Path $PSScriptRoot)
firebase emulators:exec --only "auth,firestore" --project le-comptoir-60ba8 "node --test tests_regles/regles.test.mjs tests_regles/evenements.test.mjs tests_regles/caisses.test.mjs tests_regles/annulations.test.mjs tests_regles/clotures.test.mjs tests_regles/membres.test.mjs tests_regles/suivi.test.mjs tests_regles/images.test.mjs tests_regles/suppression.test.mjs tests_regles/gymnases.test.mjs tests_regles/gestionnaires.test.mjs tests_regles/types_produit.test.mjs tests_regles/stock_role.test.mjs tests_regles/courses.test.mjs tests_regles/restes.test.mjs tests_regles/preparation.test.mjs tests_regles/stock_depart.test.mjs tests_regles/previsions.test.mjs tests_regles/references.test.mjs tests_regles/apports.test.mjs tests_regles/familles_rayons.test.mjs"
exit $LASTEXITCODE
