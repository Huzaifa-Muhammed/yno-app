# Build and deploy the YNO super-admin panel to Firebase Hosting.
#
#   powershell -File tool\deploy_admin.ps1
#
# The panel IS the web build: `main.dart` runs `AdminApp` instead of `YnoApp`
# under `kIsWeb`, so `flutter build web` produces it and nothing else. It lands
# on the app project's default Hosting site — the same project as the data, so
# the panel talks to Firestore with no cross-project setup:
#
#     https://yno-app-e96f5.web.app
#
# Prerequisites, both one-off:
#   * `firebase login` as an account with access to yno-app-e96f5. The panel's
#     data project is NOT the website's (nellab.org is yalla-nellab-12650) —
#     being logged in for the website is not being logged in for this.
#   * The super-admin account must already exist in Firebase console ->
#     Authentication -> Users. Nothing in this repo creates it, deliberately:
#     see lib/admin/admin_config.dart.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host '==> Building the admin panel (flutter build web --release)' -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

Write-Host '==> Deploying to Firebase Hosting (yno-app-e96f5)' -ForegroundColor Cyan
firebase deploy --only hosting --project yno-app-e96f5
if ($LASTEXITCODE -ne 0) { throw 'firebase deploy failed' }

Write-Host ''
Write-Host 'Live at https://yno-app-e96f5.web.app' -ForegroundColor Green
Write-Host 'Verify with the bundle, not the status code: a Flutter SPA rewrite' -ForegroundColor DarkGray
Write-Host 'returns 200 for every path whether or not the deploy landed.' -ForegroundColor DarkGray
