# Setup-ED3.ps1 — 英雄伝説III「白き魔女」

| | |
|---|---|
| 実行ファイル | `ED3_WIN.EXE` |
| 既定のインストール先 | `C:\FALCOM\ED3_XP` |
| 設定ファイル | `%APPDATA%\FALCOM\ED3_XP\SAVEDATA\ED3_CFG.INI` |
| セーブデータ | `%APPDATA%\FALCOM\ED3_XP\SAVEDATA` |

何をどう設定するかは [../../docs/setup.md](../../docs/setup.md)、その根拠は
[../../docs/analysis.md](../../docs/analysis.md)。困ったときは
[症状別の確認手順](../../docs/setup.md#6-症状別の確認手順)。

```powershell
# 現状が意図どおりか確認するだけ（何も変更しない）
powershell -ExecutionPolicy Bypass -File .\Setup-ED3.ps1 -VerifyOnly

# やろうとしている事だけ表示（何も変更しない）
powershell -ExecutionPolicy Bypass -File .\Setup-ED3.ps1 -WhatIfOnly

# 実行
powershell -ExecutionPolicy Bypass -File .\Setup-ED3.ps1
```

このフォルダを丸ごとコピーすれば単体で動く（`ddraw\*.ini.tmpl` を参照するため
`.ps1` 1つだけでは動かない）。

## パラメータ

| パラメータ | 既定 | 意味 |
|---|---|---|
| `-GameDir` / `-ExeName` | `C:\FALCOM\ED3_XP` / `ED3_WIN.EXE` | インストール先 |
| `-GameName` | `英雄伝説III 白き魔女` | ludusavi / Playnite 上の名前。**両者で1文字も違わないこと** |
| `-SaveRelPath` | `FALCOM/ED3_XP/SAVEDATA` | セーブデータの位置（`<winAppData>` 起点） |
| `-ExcludeFile` | `ED3_CFG.INI` | セーブ同期から除外する設定ファイル |
| `-Mode` | `window` | 初期状態でどちらのプロファイルを `ddraw.ini` にするか |
| `-AspectRatio` | `4:3` | 空にすると `aspect_ratio` を書かない |
| `-WindowWidth` / `-WindowHeight` | 1440 / 1080 | 作業領域に収まらなければ自動で縮小 |
| `-NoAutoFit` | off | その自動縮小を無効化 |
| `-WindowBorder` / `-WindowResizable` | `$true` | ウィンドウの枠とリサイズ可否 |
| `-Renderer` | 空 (auto) | `gdi` / `opengl` / `direct3d9` など |
| `-CompatLayer` | `~ HIGHDPIAWARE` | 互換性レイヤー。**`WINXPSP3` は入れない** |
| `-KeepCompat` | off | 既存の互換性レイヤーを正として書き換えない |
| `-KeepExistingProfiles` | off | 既存の ini を上書きしない |
| `-CncSourceDir` | （なし） | 既に cnc-ddraw があるフォルダから流用する（既定は GitHub から取得） |
| `-ZipPath` / `-SkipDownload` | — | 手元の zip を使う / ダウンロードしない |
| `-VerifyOnly` | off | **何も変更せず、現状が意図どおりかだけ確認する** |
| `-WhatIfOnly` | off | 何も変更せず、やろうとしている事だけ表示 |

## 処理の順序

前提確認 → cnc-ddraw 配置 → ddraw プロファイル生成 → 互換性レイヤー →
ludusavi（`customGames` 追加 + `ED3_CFG.INI` を `toggledPaths` で除外）→
Playnite の登録内容表示 → 検証。

ゲーム内の設定（`ED3_CFG.INI`）には触らない。

> ⚠️ `toggledPaths` は**絶対パスで書く必要があり、端末ごとに値が違う**。
> **もう一方の端末でも必ずこのスクリプトを実行すること**
> （[docs/setup.md 5.3](../../docs/setup.md#53-ludusavi-の設定)）。
