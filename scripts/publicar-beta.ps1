# Publica uma versao BETA do app para testadores (sem Google Play Console).
#
#   powershell -ExecutionPolicy Bypass -File scripts\publicar-beta.ps1
#
# O que faz:
#   1. le a versao do app/pubspec.yaml (ex.: 0.2.0+2);
#   2. compila o APK de release ASSINADO com a sua chave de upload (app/android/key.properties);
#   3. calcula o SHA-256 do arquivo (para conferencia);
#   4. cria (ou atualiza) um "Release" no GitHub e anexa o APK;
#   5. imprime o LINK DE DOWNLOAD que voce envia aos testadores.
#
# Requisitos: Flutter, GitHub CLI (`gh auth login` feito) e a chave de upload em
# app/android/key.properties (a mesma de sempre: sem ela os celulares nao aceitam ATUALIZAR).
param(
  [string]$Repo = "Washington-Freitas/DesperrengueApp_TAI3",
  [string]$Notas = "",
  [switch]$SkipBuild   # reaproveita o APK ja compilado (nao recompila)
)
# "Continue": o flutter/gh escrevem avisos em stderr; os erros reais sao checados por $LASTEXITCODE.
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$app = Join-Path $root "app"

if (-not (Test-Path (Join-Path $app "android\key.properties"))) {
  throw "Faltou app/android/key.properties (chave de upload). Veja docs/PLAY_STORE.md, secao 1."
}

$ver = (Select-String -Path (Join-Path $app "pubspec.yaml") -Pattern "^version:\s*(\S+)").Matches[0].Groups[1].Value
$name = $ver.Split("+")[0]
$tag = "beta-v$name"
Write-Host "Versao: $ver  ->  release $tag" -ForegroundColor Cyan

if (-not $SkipBuild) {
  Push-Location $app
  flutter build apk --release
  if ($LASTEXITCODE -ne 0) { Pop-Location; throw "O build falhou." }
  Pop-Location
}

$src = Join-Path $app "build\app\outputs\flutter-apk\app-release.apk"
$apk = Join-Path $app "build\app\outputs\flutter-apk\desperrengue-$name.apk"
Copy-Item $src $apk -Force
$sha = (Get-FileHash $apk -Algorithm SHA256).Hash.ToLower()
$mb = [math]::Round((Get-Item $apk).Length / 1MB, 1)
Write-Host "APK: $apk ($mb MB)" -ForegroundColor Cyan
Write-Host "SHA-256: $sha"

$body = @"
## Desperrengue beta $name

Instalador para **testadores** (Android). Nao e a versao final.

**Como instalar:** abra este link no celular, toque no arquivo ``desperrengue-$name.apk``, baixe e instale.
Se o Android pedir, permita "Instalar apps desta fonte". Guia completo: docs/TESTE_COM_AMIGOS.md

SHA-256: ``$sha``

$Notas
"@

# Texto das notas em arquivo (aspas dentro de argumentos quebram no PowerShell 5.1).
$notesFile = Join-Path $env:TEMP "desperrengue-notas.md"
[IO.File]::WriteAllText($notesFile, $body, (New-Object Text.UTF8Encoding $false))
gh release view $tag --repo $Repo *> $null
if ($LASTEXITCODE -eq 0) {
  gh release upload $tag $apk --clobber --repo $Repo
  gh release edit $tag --notes-file $notesFile --repo $Repo
} else {
  gh release create $tag $apk --repo $Repo --prerelease --title "Desperrengue beta $name" --notes-file $notesFile
}
if ($LASTEXITCODE -ne 0) { throw "Falha ao publicar no GitHub." }

Write-Host ""
Write-Host "PRONTO! Envie este link aos testadores:" -ForegroundColor Green
Write-Host "https://github.com/$Repo/releases/tag/$tag" -ForegroundColor Green
Write-Host "Download direto do APK:" 
Write-Host "https://github.com/$Repo/releases/download/$tag/desperrengue-$name.apk"
