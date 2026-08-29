#Requires -Version 5.1
<#
================================================================================
 setup.ps1  —  falcom-xp-win11 の入口
================================================================================

 導入済みのタイトルを検出して、そのセットアップスクリプトを呼ぶ。
 実体は games\<id>\Setup-*.ps1 にあり、そちらを直接叩いてもよい。

 使い方:
   .\setup.ps1                       検出して一覧を出し、対象を選ばせる
   .\setup.ps1 -Game ed4 -VerifyOnly 現状が意図どおりか確認するだけ
   .\setup.ps1 -Game ed4 -WhatIfOnly やろうとしている事だけ表示
   .\setup.ps1 -Game all             検出できた全タイトルを実行
   .\setup.ps1 -Game ed4 -GameDir 'D:\Games\ED4_XP'

 個別のパラメータ（-Mode / -Renderer / -GameScreenMode など）は
 games\<id>\Setup-*.ps1 を直接実行してください。一覧は各ゲームの
 README.md にあります。

 管理者権限は不要です。
================================================================================
#>

[CmdletBinding()]
param(
    # 対象。省略すると対話で選ぶ
    [ValidateSet('', 'ed3', 'ed4', 'all')]
    [string] $Game = '',

    # インストール先の上書き（単一タイトルを指定したときだけ有効）
    [string] $GameDir = '',

    # 何も変更せず、現状が意図どおりかだけ確認する
    [switch] $VerifyOnly,

    # 何も変更せず、やろうとしている事だけ表示する
    [switch] $WhatIfOnly
)

$ErrorActionPreference = 'Stop'

# タイトル定義。新しいタイトルを足すときはここと games\<id>\ を追加する。
$Catalog = @(
    [pscustomobject]@{
        Id       = 'ed3'
        Title    = '英雄伝説III 白き魔女'
        Script   = 'games\ed3\Setup-ED3.ps1'
        ExeName  = 'ED3_WIN.EXE'
        Defaults = @('C:\FALCOM\ED3_XP')
    }
    [pscustomobject]@{
        Id       = 'ed4'
        Title    = '英雄伝説IV 朱紅い雫'
        Script   = 'games\ed4\Setup-ED4.ps1'
        ExeName  = 'ED4_XP.EXE'
        Defaults = @('C:\FALCOM\ED4_XP')
    }
)

function Find-GameDir {
    # 存在しないドライブを指すと Join-Path が例外を投げるので、
    # 探索は文字列連結で行い、全体を try で包む。
    param([pscustomobject] $Entry)
    try {
        foreach ($d in $Entry.Defaults) {
            if (Test-Path -LiteralPath ($d.TrimEnd('\') + '\' + $Entry.ExeName)) { return $d }
        }
        # よくある置き場所も見る
        $roots = @('C:\FALCOM', 'D:\FALCOM')
        if ($env:ProgramFiles)          { $roots += "$env:ProgramFiles\FALCOM" }
        if (${env:ProgramFiles(x86)})   { $roots += "${env:ProgramFiles(x86)}\FALCOM" }
        foreach ($root in $roots) {
            if (-not (Test-Path -LiteralPath $root)) { continue }
            $hit = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                   Where-Object { Test-Path -LiteralPath ($_.FullName.TrimEnd('\') + '\' + $Entry.ExeName) } |
                   Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
    } catch { }
    return $null
}

Write-Host ''
Write-Host ('=' * 74) -ForegroundColor DarkCyan
Write-Host ' falcom-xp-win11  —  導入済みタイトルの検出' -ForegroundColor Cyan
Write-Host ('=' * 74) -ForegroundColor DarkCyan
Write-Host ''

$found = @()
foreach ($e in $Catalog) {
    $dir = if ($GameDir -and $Game -eq $e.Id) { $GameDir } else { Find-GameDir $e }
    $e | Add-Member -NotePropertyName 'Dir' -NotePropertyValue $dir -Force
    if ($dir) {
        Write-Host ("  [検出] {0,-4} {1,-22} {2}" -f $e.Id, $e.Title, $dir) -ForegroundColor Green
        $found += $e
    } else {
        Write-Host ("  [ --] {0,-4} {1,-22} 見つかりません" -f $e.Id, $e.Title) -ForegroundColor DarkGray
    }
}

if ($found.Count -eq 0) {
    Write-Host ''
    Write-Host '  導入済みのタイトルが見つかりませんでした。' -ForegroundColor Red
    Write-Host '  -Game <id> -GameDir "<インストール先>" で明示的に指定してください。' -ForegroundColor Red
    Write-Host ''
    exit 1
}

# 対象の決定
if ($Game -eq 'all') {
    $targets = $found
}
elseif ($Game) {
    $targets = @($found | Where-Object { $_.Id -eq $Game })
    if ($targets.Count -eq 0) {
        Write-Host ''
        Write-Host "  $Game が見つかりませんでした。-GameDir で明示してください。" -ForegroundColor Red
        exit 1
    }
}
elseif ($found.Count -eq 1) {
    $targets = $found
}
else {
    Write-Host ''
    for ($i = 0; $i -lt $found.Count; $i++) {
        Write-Host ("    {0}) {1}  ({2})" -f ($i + 1), $found[$i].Title, $found[$i].Id)
    }
    Write-Host ("    a) 全部")
    Write-Host ''
    $ans = Read-Host '  対象を選んでください'
    if ($ans -eq 'a') {
        $targets = $found
    } else {
        $n = 0
        if (-not [int]::TryParse($ans, [ref]$n) -or $n -lt 1 -or $n -gt $found.Count) {
            Write-Host '  取り消しました。' -ForegroundColor Yellow
            exit 0
        }
        $targets = @($found[$n - 1])
    }
}

# 実行
$failed = @()
foreach ($t in $targets) {
    $script = Join-Path $PSScriptRoot $t.Script
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Host ''
        Write-Host "  $script がありません。リポジトリを丸ごと取得してください。" -ForegroundColor Red
        exit 1
    }

    $splat = @{ GameDir = $t.Dir }
    if ($VerifyOnly) { $splat['VerifyOnly'] = $true }
    if ($WhatIfOnly) { $splat['WhatIfOnly'] = $true }

    Write-Host ''
    Write-Host ('#' * 74) -ForegroundColor DarkGray
    Write-Host ("#  {0}  ({1})" -f $t.Title, $t.Script) -ForegroundColor White
    Write-Host ('#' * 74) -ForegroundColor DarkGray

    # 子スクリプトの Write-Die は子を終わらせるだけなので、終了コードを見る
    $global:LASTEXITCODE = 0
    & $script @splat
    if ($LASTEXITCODE -ne 0) { $failed += $t.Title }
}

if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host ('  中断されました: ' + ($failed -join ', ')) -ForegroundColor Red
    Write-Host '  上のログの [中断] / [警告] を確認してください。' -ForegroundColor Red
    Write-Host ''
    exit 1
}

Write-Host ''
Write-Host '  完了しました。個別の調整は games\<id>\README.md を参照してください。' -ForegroundColor Cyan
Write-Host ''
