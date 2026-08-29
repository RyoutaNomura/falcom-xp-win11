# Setup-ED4.ps1 — 英雄伝説IV「朱紅い雫」

| | |
|---|---|
| 実行ファイル | `ED4_XP.EXE`（環境設定は `ED4_ENV.EXE`） |
| 既定のインストール先 | `C:\FALCOM\ED4_XP` |
| 設定の保存先 | レジストリ `HKCU\SOFTWARE\FALCOM\ED4_XP` |
| セーブデータ | `%APPDATA%\FALCOM\ED4_XP\SaveData` |

何をどう設定するかは [../../docs/setup.md](../../docs/setup.md)、その根拠は
[../../docs/analysis.md](../../docs/analysis.md)。困ったときは
[症状別の確認手順](../../docs/setup.md#8-症状別の確認手順)。

```powershell
# 現状が意図どおりか確認するだけ（何も変更しない）
powershell -ExecutionPolicy Bypass -File .\Setup-ED4.ps1 -VerifyOnly

# やろうとしている事だけ表示（何も変更しない）
powershell -ExecutionPolicy Bypass -File .\Setup-ED4.ps1 -WhatIfOnly

# 実行
powershell -ExecutionPolicy Bypass -File .\Setup-ED4.ps1
```

このフォルダを丸ごとコピーすれば単体で動く（`ddraw\*.ini.tmpl` を参照するため
`.ps1` 1つだけでは動かない）。

## パラメータ

| パラメータ | 既定 | 意味 |
|---|---|---|
| `-GameDir` / `-ExeName` | `C:\FALCOM\ED4_XP` / `ED4_XP.EXE` | インストール先 |
| `-GameName` | `英雄伝説IV 朱紅い雫` | ludusavi / Playnite 上の名前。**両者で1文字も違わないこと** |
| `-SaveRelPath` | `FALCOM/ED4_XP/SaveData` | セーブデータの位置（`<winAppData>` 起点） |
| `-Mode` | `fullscreen` | 初期状態でどちらのプロファイルを `ddraw.ini` にするか |
| `-AspectRatio` | `4:3` | 空にすると `aspect_ratio` を書かない |
| `-WindowWidth` / `-WindowHeight` | 1440 / 1080 | 作業領域に収まらなければ自動で縮小 |
| `-NoAutoFit` | off | その自動縮小を無効化 |
| `-WindowBorder` / `-WindowResizable` | `$true` | ウィンドウの枠とリサイズ可否 |
| `-Renderer` | 空 (auto) | `gdi` / `opengl` / `direct3d9` など |
| `-CompatLayer` | `~ 16BITCOLOR HIGHDPIAWARE` | 互換性レイヤー |
| `-KeepCompat` | off | 既存の互換性レイヤーを正として書き換えない |
| `-GameScreenMode` | **`keep`** | `window` / `fullscreen` を明示したときだけ書き換える |
| `-KeepExistingProfiles` | off | 既存の ini を上書きしない |
| `-SkipGameSettings` | off | レジストリのゲーム設定を触らない |
| `-CncSourceDir` | （なし） | 既に cnc-ddraw があるフォルダから流用する（既定は GitHub から取得） |
| `-ZipPath` / `-SkipDownload` | — | 手元の zip を使う / ダウンロードしない |
| `-VerifyOnly` | off | **何も変更せず、現状が意図どおりかだけ確認する** |
| `-WhatIfOnly` | off | 何も変更せず、やろうとしている事だけ表示 |

## 処理の順序

前提確認 → cnc-ddraw 配置 → ddraw プロファイル生成 → レジストリ（互換性レイヤー /
`EnableDirect3D`）→ ludusavi → Playnite の登録内容表示 → 検証。

> **`ScreenMode` は既定では書き換えない。** ED4 は `0`（ウィンドウ）でないと起動しないが、
> 動いている値をスクリプトが勝手に上書きしないことを優先している
> （[docs/setup.md 4.1](../../docs/setup.md#41-ed4--レジストリ-hkcusoftwarefalcomed4_xp)）。
> 明示するときだけ `-GameScreenMode window`。
