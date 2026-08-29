#Requires -Version 5.1
<#
================================================================================
 Setup-ED3.ps1  —  英雄伝説III「白き魔女」Windows版 セットアップ
================================================================================

 構成:
   cnc-ddraw (ddraw.dll を置くだけ) + 互換性レイヤーは HIGHDPIAWARE のみ
   + ludusavi wrap によるセーブ同期 + Playnite から起動

 常駐プロセスなし。管理者権限なし。互換モードなし。ランチャーなし。

 このスクリプトが「なぜそうしているか」は docs/ にある。ここには書かない。
   docs/analysis.md     ED3_WIN.EXE を解析して確認した事実
   docs/setup.md        必要な作業・設定 / セーブ同期 / 症状別の確認手順
   docs/conventions.md  スクリプトを触るときの規約

 設計上の原則（docs/conventions.md）:
   1. ゲーム本体のファイルには一切触れない
   2. 動いている設定を黙って上書きしない
   3. 書き換える前に *.bak を1つ作る（既にあれば上書きしない）
   4. -WhatIfOnly で本当に何もしない

 使い方:
   .\Setup-ED3.ps1 -VerifyOnly    現状が意図どおりか確認するだけ（変更しない）
   .\Setup-ED3.ps1 -WhatIfOnly    やろうとしている事だけ表示（変更しない）
   .\Setup-ED3.ps1                実行

 ⚠️ ED3_CFG.INI の除外設定は絶対パスで書く必要があり、端末ごとに値が違う。
    もう一方の端末でも必ずこのスクリプトを実行すること。
================================================================================
#>

[CmdletBinding()]
param(
    # ゲームのインストール先
    [string] $GameDir = 'C:\FALCOM\ED3_XP',

    # 実行ファイル名
    [string] $ExeName = 'ED3_WIN.EXE',

    # ludusavi / Playnite 上のゲーム名。両者で完全に一致させること
    [string] $GameName = '英雄伝説III 白き魔女',

    # セーブデータの位置（<winAppData> は ludusavi が %APPDATA% に展開する）
    [string] $SaveRelPath = 'FALCOM/ED3_XP/SAVEDATA',

    # 同期から除外する設定ファイル（速度設定 FRAME を端末ごとに変えるため）
    [string] $ExcludeFile = 'ED3_CFG.INI',

    # 初期状態でどちらのプロファイルを ddraw.ini にするか
    [ValidateSet('fullscreen','window')]
    [string] $Mode = 'window',

    # 表示アスペクト比。ED3 は 640x480 なので 4:3。
    # 空文字にすると aspect_ratio を書かず maintas 任せになる。
    [string] $AspectRatio = '4:3',

    # ウィンドウプロファイルのサイズ（4:3 を維持すること）
    [int] $WindowWidth  = 1440,
    [int] $WindowHeight = 1080,

    # ウィンドウプロファイルの枠とリサイズ可否
    [bool] $WindowBorder    = $true,
    [bool] $WindowResizable = $true,

    # 画面の作業領域に収まらないときにウィンドウサイズを自動で縮めない
    [switch] $NoAutoFit,

    # cnc-ddraw のレンダラ。空 = auto (direct3d9/opengl を試して gdi に落ちる)
    [ValidateSet('','auto','opengl','openglcore','gdi','direct3d9','direct3d9on12')]
    [string] $Renderer = '',

    # 互換性レイヤー。ED3 は DPI だけでよい（ED4 と違い 16BITCOLOR は不要）。
    [string] $CompatLayer = '~ HIGHDPIAWARE',

    # 既に互換性レイヤーが設定されていれば、それを正として書き換えない
    [switch] $KeepCompat,

    # cnc-ddraw を既存フォルダから流用する場合に指定する。
    # 空（既定）なら GitHub の最新 Release から取得する。
    [string] $CncSourceDir = '',

    # ダウンロードの代わりに手元の zip を使う
    [string] $ZipPath = '',

    # ダウンロードを一切行わない
    [switch] $SkipDownload,

    # 既存の ddraw.ini / プロファイルを上書きしない
    [switch] $KeepExistingProfiles,

    # 何も変更せず、現状が意図どおりかだけ確認する
    [switch] $VerifyOnly,

    # 何も変更せず、やろうとしている事だけ表示する
    [switch] $WhatIfOnly
)

$ErrorActionPreference = 'Stop'
$script:Warnings = New-Object System.Collections.Generic.List[string]

$GameId      = 'ed3'
$NativeRes   = '640x480 = 4:3'
$NoChange    = $WhatIfOnly -or $VerifyOnly
$TemplateDir = Join-Path $PSScriptRoot 'ddraw'

# ------------------------------------------------------------------ 表示ヘルパ

function Write-Head($t) {
    Write-Host ''
    Write-Host ('=' * 74) -ForegroundColor DarkCyan
    Write-Host " $t" -ForegroundColor Cyan
    Write-Host ('=' * 74) -ForegroundColor DarkCyan
}
function Write-Ok   ($t) { Write-Host "  [OK]   $t" -ForegroundColor Green }
function Write-Info ($t) { Write-Host "  [--]   $t" -ForegroundColor Gray }
function Write-Act  ($t) { Write-Host "  [変更] $t" -ForegroundColor Yellow }
function Write-Warn2($t) { Write-Host "  [警告] $t" -ForegroundColor Magenta; $script:Warnings.Add($t) | Out-Null }
function Write-Die  ($t) { Write-Host "  [中断] $t" -ForegroundColor Red; exit 1 }

function Test-Change {
    param([string] $Message)
    if ($NoChange) {
        if ($WhatIfOnly) { Write-Host "  (確認のみ) $Message" -ForegroundColor DarkGray }
        return $false
    }
    Write-Act $Message
    return $true
}

function Backup-Once([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $bak = "$Path.bak"
    if (Test-Path -LiteralPath $bak) {
        Write-Info "バックアップ済み: $bak"
        return
    }
    if (Test-Change "バックアップを作成: $bak") {
        Copy-Item -LiteralPath $Path -Destination $bak
    }
}

function Expand-Template([string] $Text, [hashtable] $Map) {
    foreach ($k in $Map.Keys) {
        $Text = $Text.Replace($k, [string]$Map[$k])
    }
    return $Text
}

function Write-Utf8NoBom([string] $Path, [string] $Text) {
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

function Write-Ansi([string] $Path, [string] $Text) {
    # cnc-ddraw / cmd は ini・バッチを ANSI(CP932) として読む。
    # リポジトリ上のテンプレートは UTF-8。生成物だけ CP932 にする。
    $crlf = $Text -replace "(?<!`r)`n", "`r`n"
    [System.IO.File]::WriteAllText($Path, $crlf, [System.Text.Encoding]::GetEncoding(932))
}

function Get-Indent([string] $Line) {
    return ($Line.Length - $Line.TrimStart().Length)
}

function Find-TopLevel {
    # $Pattern に一致する最初の行番号。無ければ -1
    param([string[]] $Lines, [string] $Pattern)
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $Pattern) { return $i }
    }
    return -1
}

function Find-LineUnder {
    # $StartIndex の行の「配下」（より深いインデントが続く範囲）だけを対象に $Pattern を探す。
    # config.yaml には backup: と restore: に同名のキー（toggledPaths など）があるので、
    # ブロックを限定しないと取り違えて別のセクションを壊す。
    param([string[]] $Lines, [int] $StartIndex, [string] $Pattern)
    if ($StartIndex -lt 0) { return -1 }
    $pIndent = Get-Indent $Lines[$StartIndex]
    for ($i = $StartIndex + 1; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^\s*$') { continue }
        if ((Get-Indent $Lines[$i]) -le $pIndent) { return -1 }
        if ($Lines[$i] -match $Pattern) { return $i }
    }
    return -1
}

function Add-LinesAfter {
    # $Index の直後に $Insert を差し込んだ新しい配列を返す
    param([string[]] $Lines, [int] $Index, [string[]] $Insert)
    $new = @()
    if ($Index -ge 0) { $new += $Lines[0..$Index] }
    $new += $Insert
    if ($Index + 1 -lt $Lines.Count) { $new += $Lines[($Index + 1)..($Lines.Count - 1)] }
    return ,$new
}

$ExePath = Join-Path $GameDir $ExeName

if ($VerifyOnly) {
    Write-Host ''
    Write-Host '  *** -VerifyOnly: 現状を確認するだけです。何も変更しません ***' -ForegroundColor Black -BackgroundColor Cyan
}
elseif ($WhatIfOnly) {
    Write-Host ''
    Write-Host '  *** -WhatIfOnly: ファイル・レジストリ・クリップボードには一切触れません ***' -ForegroundColor Black -BackgroundColor Yellow
}

# ============================================================== 0. 前提の確認

Write-Head '0. 前提の確認'

if (-not (Test-Path -LiteralPath $ExePath)) {
    Write-Die "$ExePath が見つかりません。-GameDir / -ExeName を確認してください。"
}
Write-Ok "ゲーム本体: $ExePath"

# .NET の WriteAllText は PowerShell のカレントではなくプロセスのカレントを見る。
# 相対パスの -GameDir だと ini だけ別フォルダに出てしまうので、ここで絶対パスにする。
$GameDir = (Resolve-Path -LiteralPath $GameDir).ProviderPath
$ExePath = Join-Path $GameDir $ExeName

Write-Info "描画解像度は $NativeRes 前提。表示比率は $AspectRatio で固定する。"

try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    $scr = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    Write-Info ("主モニタ: {0}x{1}" -f $scr.Width, $scr.Height)
} catch { }

# ddraw プロファイルのテンプレート
foreach ($t in @('window.ini.tmpl','fullscreen.ini.tmpl')) {
    if (-not (Test-Path -LiteralPath (Join-Path $TemplateDir $t))) {
        Write-Die "$TemplateDir\$t がありません。games/$GameId フォルダごとコピーしてください。"
    }
}
Write-Ok "ddraw テンプレート: $TemplateDir"

# ludusavi
$ludusavi = $null
$cmd = Get-Command 'ludusavi.exe' -ErrorAction SilentlyContinue
if ($cmd) { $ludusavi = $cmd.Source }
if (-not $ludusavi) {
    foreach ($p in @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\ludusavi.exe",
        "$env:ProgramFiles\Ludusavi\ludusavi.exe"
    )) {
        if (Test-Path -LiteralPath $p) { $ludusavi = $p; break }
    }
}
if ($ludusavi) { Write-Ok "ludusavi: $ludusavi" }
else           { Write-Warn2 'ludusavi.exe が PATH 上に見つかりません。Playnite の設定で絶対パスが必要になります。' }

$ludCfg = Join-Path $env:APPDATA 'ludusavi\config.yaml'
if (Test-Path -LiteralPath $ludCfg) { Write-Ok "ludusavi 設定: $ludCfg" }
else { Write-Die "$ludCfg がありません。ludusavi を一度起動して設定を作ってください。" }

# Playnite
if (Test-Path -LiteralPath (Join-Path $env:APPDATA 'Playnite\config.json')) { Write-Ok 'Playnite: 検出' }
else { Write-Warn2 'Playnite が見つかりません。手順5の登録は手動で行ってください。' }

# rclone（クラウド同期に必要）
# ludusavi は未設定でも apps.rclone: ブロックを書き出すので、"rclone" という
# 文字列の有無では判定できない。apps.rclone.path の中身を見る。
$cfgLines   = (Get-Content -LiteralPath $ludCfg -Raw -Encoding UTF8) -split "`r?`n"
$rcloneIdx  = Find-LineUnder $cfgLines (Find-TopLevel $cfgLines '^apps:\s*$') '^\s+rclone:\s*$'
$rclonePath = ''
$rpIdx      = Find-LineUnder $cfgLines $rcloneIdx '^\s+path:\s*'
if ($rpIdx -ge 0) { $rclonePath = (($cfgLines[$rpIdx] -split ':', 2)[1]).Trim().Trim('"', "'") }
if ($rclonePath) {
    Write-Ok "rclone: $rclonePath"
} else {
    Write-Warn2 'ludusavi に rclone が設定されていません（apps.rclone.path が空）。クラウド同期は動きません。'
}

# ディスプレイスケーリングの注意喚起
try {
    $dpi = (Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop\WindowMetrics' -Name AppliedDPI -ErrorAction SilentlyContinue).AppliedDPI
    if ($dpi -and $dpi -ne 96) {
        $pct = [math]::Round($dpi / 96 * 100)
        Write-Info "ディスプレイスケーリングが $pct% です。HIGHDPIAWARE の登録が必須になります（このスクリプトで設定します）。"
    }
} catch { }

# ============================================== 1. cnc-ddraw の入手と配置

Write-Head '1. cnc-ddraw の配置'

# ddraw.dll があれば「配置済み」とみなす。Shaders の有無で再取得すると、
# 動いている ddraw.dll を上書きしてしまう。
$hasDll     = Test-Path -LiteralPath (Join-Path $GameDir 'ddraw.dll')
$hasShaders = Test-Path -LiteralPath (Join-Path $GameDir 'Shaders')

if ($hasDll) {
    $dll = Get-Item -LiteralPath (Join-Path $GameDir 'ddraw.dll')
    Write-Ok ("ddraw.dll 配置済み ({0:N0} バイト / {1:yyyy-MM-dd})" -f $dll.Length, $dll.LastWriteTime)
    if (-not $hasShaders) { Write-Info 'Shaders\ がありません。拡大シェーダを使わないなら問題ありません。' }
}
elseif ($VerifyOnly) {
    Write-Warn2 'ddraw.dll / Shaders が配置されていません。'
}
else {
    $src = $null

    # (a) 既存フォルダから流用する（-CncSourceDir を明示したときだけ）
    if ($CncSourceDir -and (Test-Path -LiteralPath ($CncSourceDir.TrimEnd('\','/') + '\ddraw.dll'))) {
        $src = $CncSourceDir
        Write-Info "流用元: $CncSourceDir"
    }
    # (b) 手元の zip を展開
    elseif ($ZipPath -and (Test-Path -LiteralPath $ZipPath)) {
        $tmp = Join-Path $env:TEMP ('cncddraw_' + [guid]::NewGuid().ToString('N'))
        if (Test-Change "zip を展開: $ZipPath") {
            New-Item -ItemType Directory -Path $tmp -Force | Out-Null
            Expand-Archive -LiteralPath $ZipPath -DestinationPath $tmp -Force
            $src = $tmp
        }
    }
    # (c) GitHub から取得
    elseif (-not $SkipDownload) {
        if (Test-Change 'cnc-ddraw の最新版を GitHub から取得') {
            try {
                $sp = [Net.ServicePointManager]::SecurityProtocol
                [Net.ServicePointManager]::SecurityProtocol = $sp -bor [Net.SecurityProtocolType]::Tls12
                $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/FunkyFr3sh/cnc-ddraw/releases/latest' -UseBasicParsing
                $asset = $rel.assets | Where-Object { $_.name -like 'cnc-ddraw*.zip' } | Select-Object -First 1
                if (-not $asset) { throw 'zip アセットが見つかりません' }
                $zip = Join-Path $env:TEMP $asset.name
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
                $tmp = Join-Path $env:TEMP ('cncddraw_' + [guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $tmp -Force | Out-Null
                Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
                $src = $tmp
                Write-Ok ("取得: " + $rel.tag_name)
            }
            catch {
                Write-Warn2 ("ダウンロードに失敗しました: " + $_.Exception.Message)
                Write-Info '手動で https://github.com/FunkyFr3sh/cnc-ddraw/releases から zip を落とし、'
                Write-Info '-ZipPath "C:\path\to\cnc-ddraw.zip" を付けて実行し直してください。'
            }
        }
    }
    else {
        Write-Warn2 '-SkipDownload 指定。cnc-ddraw の配置をスキップします。'
    }

    if ($src) {
        # コピーに失敗しても以降の手順（プロファイル / レジストリ / ludusavi）は続ける。
        # ここで止まると中途半端な状態で終わってしまう。
        try {
            foreach ($n in @('ddraw.dll', 'ddraw.reference.ini', 'cnc-ddraw config.exe')) {
                $s = Join-Path $src $n
                if (Test-Path -LiteralPath $s) {
                    $d = Join-Path $GameDir $n
                    if (Test-Change "コピー: $n") {
                        if (Test-Path -LiteralPath $d) {
                            $old = Get-Item -LiteralPath $d
                            if ($old.IsReadOnly) { $old.IsReadOnly = $false }
                        }
                        Copy-Item -LiteralPath $s -Destination $d -Force
                    }
                }
            }
            $sh = Join-Path $src 'Shaders'
            if (Test-Path -LiteralPath $sh) {
                if (Test-Change 'コピー: Shaders\') {
                    Copy-Item -LiteralPath $sh -Destination $GameDir -Recurse -Force
                }
            }
        }
        catch {
            Write-Warn2 ("cnc-ddraw の配置に失敗しました: " + $_.Exception.Message)
            Write-Info  'ゲームが起動中だとファイルを置き換えられません。終了してから再実行してください。'
        }
    }
    elseif (-not $NoChange) {
        Write-Warn2 'cnc-ddraw を配置できませんでした。ゲームは低解像度フルスクリーンのままです。'
    }
}

# ================================================== 2. ddraw プロファイルの配置

Write-Head '2. ddraw プロファイルの配置'

if ($AspectRatio) {
    $aspectLine = "aspect_ratio=$AspectRatio"
} else {
    $aspectLine = "; aspect_ratio=  (未指定。maintas 任せ)"
}
if ($Renderer) {
    $rendererLine = "renderer=$Renderer"
} else {
    $rendererLine = "; renderer=auto  (既定のまま)"
}

if ($WindowWidth * 3 -ne $WindowHeight * 4) {
    Write-Warn2 ("ウィンドウサイズ {0}x{1} が 4:3 ではありません。ウィンドウ内に黒帯が入ります。" -f $WindowWidth, $WindowHeight)
}

# ウィンドウが画面の作業領域に収まらないと、cnc-ddraw が縮めた結果
# 「ウィンドウのはずなのに全画面に見える」状態になる。収まる最大の
# 4:3 サイズへ自動で落とす。-NoAutoFit で無効化。
if (-not $NoAutoFit) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $overhead = 0
        if ($WindowBorder) {
            $overhead = [System.Windows.Forms.SystemInformation]::CaptionHeight +
                        ([System.Windows.Forms.SystemInformation]::FrameBorderSize.Height * 2) + 8
        }
        $maxH = $wa.Height - $overhead
        if ($WindowHeight -gt $maxH -or $WindowWidth -gt $wa.Width) {
            $fitH = [Math]::Min($maxH, [Math]::Floor($wa.Width * 3 / 4))
            $fitH = [int]([Math]::Floor($fitH / 3) * 3)
            $fitW = [int]($fitH * 4 / 3)
            Write-Info ("{0}x{1} は作業領域 {2}x{3}（枠 {4}px 込み）に収まりません。" -f $WindowWidth, $WindowHeight, $wa.Width, $wa.Height, $overhead)
            Write-Info ("ウィンドウサイズを {0}x{1} に縮めます（-NoAutoFit で無効化）。" -f $fitW, $fitH)
            $WindowWidth  = $fitW
            $WindowHeight = $fitH
        }
    } catch { }
}

$common = @{
    '@@TITLE@@'        = $GameName
    '@@GAMEID@@'       = $GameId.ToUpper()
    '@@EXENAME@@'      = $ExeName
    '@@NATIVERES@@'    = $NativeRes
    '@@ASPECTLINE@@'   = $aspectLine
    '@@RENDERERLINE@@' = $rendererLine
}
$profiles = @{
    'ddraw.window.ini' = @{
        'Template' = 'window.ini.tmpl'
        'Map' = @{
            '@@BORDER@@'    = ([string]$WindowBorder).ToLower()
            '@@RESIZABLE@@' = ([string]$WindowResizable).ToLower()
            '@@WIDTH@@'     = "$WindowWidth"
            '@@HEIGHT@@'    = "$WindowHeight"
        }
    }
    'ddraw.fullscreen.ini' = @{
        'Template' = 'fullscreen.ini.tmpl'
        'Map' = @{}
    }
}

foreach ($name in @($profiles.Keys)) {
    $dest = Join-Path $GameDir $name
    if ($KeepExistingProfiles -and (Test-Path -LiteralPath $dest)) {
        Write-Info "-KeepExistingProfiles 指定。既存のまま: $name"
        continue
    }
    $map = @{}
    foreach ($k in $common.Keys) { $map[$k] = $common[$k] }
    foreach ($k in $profiles[$name].Map.Keys) { $map[$k] = $profiles[$name].Map[$k] }

    $tmplPath = Join-Path $TemplateDir $profiles[$name].Template
    $text = Expand-Template (Get-Content -LiteralPath $tmplPath -Raw -Encoding UTF8) $map

    Backup-Once $dest
    if (Test-Change "書き込み: $name") {
        Write-Ansi $dest $text
    }
}

# ddraw.ini は -Mode のプロファイルの複製。savesettings=0 なので
# 手で編集する前提のファイルではない。毎回作り直す。
$iniPath = Join-Path $GameDir 'ddraw.ini'
$srcIni  = Join-Path $GameDir ("ddraw.$Mode.ini")
if ($KeepExistingProfiles -and (Test-Path -LiteralPath $iniPath)) {
    Write-Info '-KeepExistingProfiles 指定。ddraw.ini は触りません。'
}
elseif (Test-Path -LiteralPath $srcIni) {
    Backup-Once $iniPath
    if (Test-Change "ddraw.ini を $Mode プロファイルで更新") {
        Copy-Item -LiteralPath $srcIni -Destination $iniPath -Force
    }
}
elseif (-not $NoChange) {
    Write-Warn2 "$srcIni がありません。ddraw.ini を更新できませんでした。"
}

# 切り替え用 cmd
$cmds = @{
    'Use_Window.cmd'     = "@echo off`r`ncopy /y `"%~dp0ddraw.window.ini`" `"%~dp0ddraw.ini`" >nul`r`necho ウィンドウ表示 ($WindowWidth" + "x$WindowHeight) に切り替えました。`r`n"
    'Use_Fullscreen.cmd' = "@echo off`r`ncopy /y `"%~dp0ddraw.fullscreen.ini`" `"%~dp0ddraw.ini`" >nul`r`necho フルスクリーン表示 ($AspectRatio レターボックス) に切り替えました。`r`n"
}
foreach ($n in @($cmds.Keys)) {
    if (Test-Change "書き込み: $n") {
        Write-Ansi (Join-Path $GameDir $n) $cmds[$n]
    }
}

# ==================================================== 3. 互換性レイヤー

Write-Head '3. 互換性レイヤー'

$layersHKCU = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$layersHKLM = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$layerValue = $CompatLayer

# HKLM に古いエントリがあると HKCU より優先される
if (Test-Path -LiteralPath $layersHKLM) {
    $lm = Get-ItemProperty -LiteralPath $layersHKLM -ErrorAction SilentlyContinue
    if ($lm -and $lm.PSObject.Properties.Name -contains $ExePath) {
        Write-Warn2 ("HKLM 側にエントリがあります: " + $lm.$ExePath)
        Write-Info  '  HKLM は HKCU より優先されます。挙動がおかしい場合は管理者権限で削除してください:'
        Write-Info  ('  reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "' + $ExePath + '" /f')
    }
}

$cur = $null
if (Test-Path -LiteralPath $layersHKCU) {
    $p = Get-ItemProperty -LiteralPath $layersHKCU -ErrorAction SilentlyContinue
    if ($p -and $p.PSObject.Properties.Name -contains $ExePath) { $cur = $p.$ExePath }
}

if ($cur -eq $layerValue) {
    Write-Ok "互換性レイヤー: 既に `"$layerValue`""
}
elseif (($KeepCompat -or $VerifyOnly) -and $cur) {
    if ($VerifyOnly) { Write-Info "現在の互換性レイヤー: `"$cur`"" }
    else             { Write-Info "-KeepCompat 指定。現在の値をそのまま使います: `"$cur`"" }
    $layerValue = $cur
}
else {
    if ($cur) { Write-Info "現在の値: `"$cur`"" }
    if (Test-Change "互換性レイヤーを `"$layerValue`" に設定") {
        if (-not (Test-Path -LiteralPath $layersHKCU)) { New-Item -Path $layersHKCU -Force | Out-Null }
        New-ItemProperty -LiteralPath $layersHKCU -Name $ExePath -Value $layerValue -PropertyType String -Force | Out-Null
    }
}

if ($layerValue -match 'WINXPSP3') {
    Write-Warn2 'WINXPSP3 が入っています。これが UAC 昇格を誘発し、ludusavi wrap が os error 740 で失敗します。'
}
if ($layerValue -notmatch 'HIGHDPIAWARE') {
    Write-Warn2 'HIGHDPIAWARE が入っていません。スケーリングが 100% 以外だと表示比率がずれます。'
}
Write-Info 'cnc-ddraw が入っていれば互換モードは不要です。DPI だけ当てます。'

# ==================================================== 4. ludusavi

Write-Head '4. ludusavi の設定'

$yaml     = Get-Content -LiteralPath $ludCfg -Raw -Encoding UTF8
$ludLines = $yaml -split "`r?`n"
$dirty    = $false

# --- 4a. カスタムゲーム -------------------------------------------------------

$entry = @(
    "  - name: $GameName"
    '    integration: override'
    '    files:'
    "      - `"<winAppData>/$SaveRelPath`""
    '    registry: []'
    '    installDir: []'
    '    winePrefix: []'
)

# 登録済みかどうかは customGames: の配下にある "- name:" 行だけを見る。
# 全文の部分一致だと、前方一致する別名（"... 完全版" など）を誤検出し、
# ludusavi が引用符付きで書き戻したときには逆に毎回重複エントリを足してしまう。
$cgIdx      = Find-TopLevel $ludLines '^customGames:\s*(\[\]\s*)?$'
$nameRe     = '^\s*-\s+name:\s*"?' + [regex]::Escape($GameName) + '"?\s*$'
$registered = ($cgIdx -ge 0) -and ((Find-LineUnder $ludLines $cgIdx $nameRe) -ge 0)

if ($registered) {
    Write-Ok "カスタムゲーム `"$GameName`" は登録済み"
}
elseif ($VerifyOnly) {
    Write-Warn2 "カスタムゲーム `"$GameName`" が ludusavi に登録されていません。"
}
elseif ($cgIdx -ge 0) {
    if (Test-Change "customGames に `"$GameName`" を追加") {
        if ($ludLines[$cgIdx] -match '\[\]') { $ludLines[$cgIdx] = 'customGames:' }
        $ludLines = Add-LinesAfter -Lines $ludLines -Index $cgIdx -Insert $entry
        $dirty = $true
    }
}
else {
    if (Test-Change "customGames セクションを作って `"$GameName`" を追加") {
        # 末尾の空行を落としてから追記し、最後に改行を1つだけ残す
        $tail = @($ludLines)
        while ($tail.Count -gt 0 -and $tail[$tail.Count - 1] -match '^\s*$') {
            $tail = @($tail[0..($tail.Count - 2)])
        }
        $ludLines = @($tail) + @('customGames:') + $entry + @('')
        $dirty = $true
    }
}

# --- 4b. ED3_CFG.INI を同期から除外 -------------------------------------------
#
# ED3_CFG.INI はセーブデータと同じフォルダにあるが、速度設定 (FRAME) を
# 端末ごとに変えたいので同期対象から外す。
# toggledPaths だけは <winAppData> が使えず絶対パスで書く必要があるため、
# 実行時のユーザー名から生成する（＝端末ごとに値が違う）。
# ⚠️ もう一方の端末でも必ずこのスクリプトを実行すること。

$excludeAbs  = (Join-Path $env:APPDATA (($SaveRelPath -replace '/', '\') + '\' + $ExcludeFile))
$excludeYaml = $excludeAbs -replace '\\', '/'

# backup: 配下の toggledPaths だけを対象にする。restore: 配下にも同名のキーがあり、
# まとめて触ると restore 側を空マップから null に変えて config.yaml を壊す。
$backupIdx = Find-TopLevel $ludLines '^backup:\s*$'
$tpIdx     = Find-LineUnder $ludLines $backupIdx '^\s+toggledPaths:\s*(\{\}\s*)?$'
$excluded  = ($tpIdx -ge 0) -and ((Find-LineUnder $ludLines $tpIdx ([regex]::Escape($excludeYaml))) -ge 0)

if ($excluded) {
    Write-Ok "$ExcludeFile は既に同期対象外"
}
elseif ($VerifyOnly) {
    Write-Warn2 "$ExcludeFile が同期対象から除外されていません（速度設定が端末間で上書きされます）。"
}
elseif ($tpIdx -lt 0) {
    Write-Warn2 'config.yaml の backup: 配下に toggledPaths が見つからず、除外設定を追加できませんでした。'
    Write-Info  'ludusavi の GUI（バックアップ画面のファイル一覧）でチェックを外してください。'
}
else {
    $ind      = Get-Indent $ludLines[$tpIdx]
    $gameLine = (' ' * ($ind + 2)) + "${GameName}:"
    $pathLine = (' ' * ($ind + 4)) + "`"$excludeYaml`": false"

    if (Test-Change "$ExcludeFile を同期対象から除外") {
        if ($ludLines[$tpIdx] -match '\{\}') {
            # {} を開く。触るのは backup: 配下のこの1行だけ
            $ludLines[$tpIdx] = (' ' * $ind) + 'toggledPaths:'
            $ludLines = Add-LinesAfter -Lines $ludLines -Index $tpIdx -Insert @($gameLine, $pathLine)
        }
        else {
            $gIdx = Find-LineUnder $ludLines $tpIdx ('^' + [regex]::Escape($gameLine) + '\s*$')
            if ($gIdx -ge 0) {
                $ludLines = Add-LinesAfter -Lines $ludLines -Index $gIdx -Insert @($pathLine)
            } else {
                $ludLines = Add-LinesAfter -Lines $ludLines -Index $tpIdx -Insert @($gameLine, $pathLine)
            }
        }
        $dirty = $true
    }
}

# --- 4c. 書き込み -------------------------------------------------------------
# $dirty は Test-Change が $true を返したときにしか立たないので、
# -WhatIfOnly / -VerifyOnly でここに入ることはない。

if ($dirty) {
    Backup-Once $ludCfg
    Write-Utf8NoBom $ludCfg (($ludLines -join "`n"))
    Write-Ok 'config.yaml を更新しました。'
}
elseif (-not $NoChange) {
    Write-Info 'config.yaml の変更はありません。'
}

Write-Info "セーブ先: %APPDATA%\$($SaveRelPath -replace '/','\')"

# 実際に検出できるか確認
# -VerifyOnly / -WhatIfOnly では実行しない。ludusavi の起動はマニフェスト更新の
# ネットワークアクセスと %APPDATA%\ludusavi への書き込みを伴うため。
if ($ludusavi -and -not $NoChange) {
    Write-Host ''
    Write-Info 'ludusavi でスキャンして検出できるか確認します...'
    $prevEnc = $null
    $prevEap = $ErrorActionPreference
    try {
        # PowerShell 5.1 はネイティブコマンドの出力をコンソールのコードページ (日本語環境では
        # CP932) で解釈する。--api の JSON は UTF-8 なので、揃えないとゲーム名が化けて必ず不一致になる。
        $prevEnc = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        # ネイティブコマンドの stderr で終了させない
        $ErrorActionPreference = 'Continue'
        $out = & $ludusavi backup --preview --api $GameName 2>&1 | Out-String
        if ($out -notmatch [regex]::Escape($GameName)) {
            Write-Warn2 'ludusavi がこのゲームを検出できませんでした。セーブデータが未作成かもしれません。'
            Write-Info  '一度ゲームを起動してセーブしてから、もう一度試してください。'
        } else {
            Write-Ok 'ludusavi が検出しました。'
        }
    } catch {
        Write-Warn2 ("ludusavi の実行に失敗: " + $_.Exception.Message)
    } finally {
        $ErrorActionPreference = $prevEap
        if ($prevEnc) { [Console]::OutputEncoding = $prevEnc }
    }
}

# ==================================================== 5. Playnite

Write-Head '5. Playnite への登録（手動）'

$ludExe = if ($ludusavi) { $ludusavi } else { 'ludusavi' }
$playniteArgs = "wrap --name `"$GameName`" --gui --cloud-sync --ask-downgrade --force-restore --force-backup -- `"$ExePath`""

Write-Host ''
Write-Host '  Playnite → ゲームを追加 → 手動で追加 → 「操作」タブ → プレイアクション' -ForegroundColor White
Write-Host ''
Write-Host ('    名前          : ' + $GameName)    -ForegroundColor White
Write-Host  '    種類          : ファイル'          -ForegroundColor White
Write-Host ('    パス          : ' + $ludExe)       -ForegroundColor White
Write-Host ('    引数          : ' + $playniteArgs) -ForegroundColor Yellow
Write-Host ('    作業フォルダー: ' + $GameDir)      -ForegroundColor White
Write-Host ''
Write-Host '    --force（無印）は絶対に付けないこと。クラウド競合の確認まで消えます。' -ForegroundColor Magenta

if (Test-Change '引数をクリップボードにコピー') {
    try { Set-Clipboard -Value $playniteArgs; Write-Ok 'クリップボードにコピーしました。' }
    catch { Write-Info '(クリップボードにコピーできませんでした)' }
}

# ==================================================== 6. 検証

Write-Head '6. 検証'

if ($WhatIfOnly) {
    Write-Info '-WhatIfOnly なので検証はスキップします。'
}
elseif (Test-Path -LiteralPath $iniPath) {
    $ini = Get-Content -LiteralPath $iniPath -Encoding Default

    function Get-IniValue([string[]] $Lines, [string] $Key) {
        $hit = $Lines | Where-Object { $_ -match ('^\s*' + [regex]::Escape($Key) + '\s*=') } | Select-Object -Last 1
        if ($hit) { return ($hit -split '=', 2)[1].Trim() }
        return $null
    }

    $expect = @(
        @{ Key = 'maintas';      Want = 'true' },
        @{ Key = 'nonexclusive'; Want = 'true' },
        @{ Key = 'savesettings'; Want = '0'    }
    )
    if ($AspectRatio) { $expect += @{ Key = 'aspect_ratio'; Want = $AspectRatio } }

    $bad = 0
    foreach ($e in $expect) {
        $got = Get-IniValue $ini $e.Key
        if ($got -eq $e.Want) { Write-Ok ("ddraw.ini: {0} = {1}" -f $e.Key, $got) }
        else { Write-Warn2 ("ddraw.ini: {0} が {1} ではなく `"{2}`" です" -f $e.Key, $e.Want, $got); $bad++ }
    }
    if ($bad -eq 0) { Write-Ok "ddraw.ini は $AspectRatio 固定で反映されています。" }

    if (-not (Test-Path -LiteralPath (Join-Path $GameDir 'ddraw.dll'))) {
        Write-Warn2 'ddraw.dll が ddraw.ini と同じフォルダにありません。設定は読まれません。'
    }

    $chk = $null
    if (Test-Path -LiteralPath $layersHKCU) {
        $p2 = Get-ItemProperty -LiteralPath $layersHKCU -ErrorAction SilentlyContinue
        if ($p2 -and $p2.PSObject.Properties.Name -contains $ExePath) { $chk = $p2.$ExePath }
    }
    if ($chk -match 'HIGHDPIAWARE' -and $chk -notmatch 'WINXPSP3') { Write-Ok "互換性レイヤー: `"$chk`"" }
    else { Write-Warn2 "互換性レイヤーが `"$chk`" です。期待値は `"$CompatLayer`"（WINXPSP3 は不可）。" }
}
else {
    Write-Warn2 'ddraw.ini がありません。手順2が失敗しています。'
}

# ==================================================== まとめ

Write-Head 'まとめ'

if ($VerifyOnly) {
    Write-Host '  -VerifyOnly でした。何も変更していません。' -ForegroundColor Cyan
}
elseif ($WhatIfOnly) {
    Write-Host '  -WhatIfOnly でした。何も変更していません。' -ForegroundColor Yellow
    Write-Host '  問題なければ -WhatIfOnly を外して実行してください。' -ForegroundColor Yellow
}

if ($script:Warnings.Count -gt 0) {
    Write-Host ''
    Write-Host '  未解決の警告:' -ForegroundColor Magenta
    foreach ($w in $script:Warnings) { Write-Host "    - $w" -ForegroundColor Magenta }
}

Write-Host @"

  次にやること
  ------------
  1. $ExeName を直接起動して、$AspectRatio で映ることを確認する
  2. ゲーム内「環境設定 → 画面描画」で速度を調整する
       FRAME=8 (初期値) → 1.0 倍
       FRAME=4          → 2.0 倍   ← 実用的
       FRAME=2          → 4.0 倍   (アニメーションはカクつく)
     この値は $ExcludeFile に保存され、同期対象外にしてあるので
     端末ごとに違う値にできます。
  3. Playnite に上記のプレイアクションで登録し、Playnite から起動する

  表示の切り替え
  --------------
    Use_Window.cmd      → $WindowWidth x $WindowHeight のウィンドウ
    Use_Fullscreen.cmd  → フルスクリーン（$AspectRatio レターボックス）

  うまく動かないとき
  ------------------
    docs/setup.md に症状別の切り分け手順がある。
    起動直後に砂時計で固まるのは DirectSound のデバイス列挙待ち。
    高速スタートアップと未使用の音声出力を無効化すると出にくくなる。

  元に戻すには
  ------------
    - $GameDir から ddraw.dll を削除
    - reg delete "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "$ExePath" /f
    - *.bak を元のファイル名に戻す

"@ -ForegroundColor Gray
