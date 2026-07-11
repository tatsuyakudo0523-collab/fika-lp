# フィーカLP 本番デプロイスクリプト
# 使い方: powershell -File deploy.ps1
# Gitで管理されているファイルを Xserverビジネス (fika-ladies-clinic.com/public_html) へFTPSアップロードする。
# 認証情報は %USERPROFILE%\.fika-deploy.env (FTP_HOST / FTP_USER / FTP_PASS) から読む。

$ErrorActionPreference = 'Stop'
$envFile = Join-Path $env:USERPROFILE '.fika-deploy.env'
if (-not (Test-Path $envFile)) { throw ".fika-deploy.env が見つかりません: $envFile" }

$conf = @{}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') { $conf[$Matches[1].Trim()] = $Matches[2].Trim() }
}
foreach ($k in 'FTP_HOST','FTP_USER','FTP_PASS') {
    if (-not $conf[$k]) { throw ".fika-deploy.env に $k がありません" }
}

$repo = $PSScriptRoot
Set-Location $repo

# デプロイ対象 = Git管理下のファイル(スクリプト類は除外)
$files = git ls-files | Where-Object { $_ -notmatch '^(deploy\.ps1|\.gitignore|README)' }

$failed = @()
foreach ($f in $files) {
    $remote = $f -replace '\\', '/'
    $url = "ftp://$($conf.FTP_HOST)/$remote"
    Write-Host "upload: $remote" -NoNewline
    curl.exe -sS --ssl-reqd --ftp-create-dirs -T $f --user "$($conf.FTP_USER):$($conf.FTP_PASS)" $url
    if ($LASTEXITCODE -eq 0) { Write-Host "  OK" } else { Write-Host "  FAILED"; $failed += $remote }
}

if ($failed.Count) {
    Write-Host "`n失敗: $($failed.Count)件 → $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "`n全 $($files.Count) ファイルのデプロイ完了" -ForegroundColor Green
