# Setup-ED5.ps1 — 英雄伝説V「海の檻歌」

| | |
|---|---|
| 実行ファイル | `ED5_XP.EXE`（環境設定は `ED5_CFG.EXE`） |
| 既定のインストール先 | `C:\FALCOM\ED5_XP` |
| 設定の保存先 | レジストリ `HKCU\SOFTWARE\FALCOM\ED5_XP` |
| セーブデータ | `%APPDATA%\FALCOM\ED5_XP`（**直下**。`SaveData` のようなサブフォルダは無い） |

何をどう設定するかは [../../docs/setup.md](../../docs/setup.md)、その根拠は
[../../docs/analysis.md](../../docs/analysis.md)。困ったときは
[症状別の確認手順](../../docs/setup.md#6-症状別の確認手順)。

```powershell
# 現状が意図どおりか確認するだけ（何も変更しない）
powershell -ExecutionPolicy Bypass -File .\Setup-ED5.ps1 -VerifyOnly

# やろうとしている事だけ表示（何も変更しない）
powershell -ExecutionPolicy Bypass -File .\Setup-ED5.ps1 -WhatIfOnly

# 実行
powershell -ExecutionPolicy Bypass -File .\Setup-ED5.ps1
```

このフォルダを丸ごとコピーすれば単体で動く（`ddraw\*.ini.tmpl` を参照するため
`.ps1` 1つだけでは動かない）。

## パラメータ

| パラメータ | 既定 | 意味 |
|---|---|---|
| `-GameDir` / `-ExeName` | `C:\FALCOM\ED5_XP` / `ED5_XP.EXE` | インストール先 |
| `-GameName` | `英雄伝説V 海の檻歌` | ludusavi / Playnite 上の名前。**両者で1文字も違わないこと** |
| `-SaveRelPath` | `FALCOM/ED5_XP` | セーブデータの位置（`<winAppData>` 起点） |
| `-Mode` | `fullscreen` | 初期状態でどちらのプロファイルを `ddraw.ini` にするか |
| `-AspectRatio` | `4:3` | 空にすると `aspect_ratio` を書かない |
| `-WindowWidth` / `-WindowHeight` | 1440 / 1080 | 作業領域に収まらなければ自動で縮小 |
| `-NoAutoFit` | off | その自動縮小を無効化 |
| `-WindowBorder` / `-WindowResizable` | `$true` | ウィンドウの枠とリサイズ可否 |
| `-Renderer` | 空 (auto) | `gdi` / `opengl` / `direct3d9` など |
| `-CompatLayer` | `~ HIGHDPIAWARE` | 互換性レイヤー。**`16BITCOLOR` は付けない**（ED4 専用） |
| `-KeepCompat` | off | 既存の互換性レイヤーを正として書き換えない |
| `-GameSurface` | **`keep`** | `video` / `main` を明示したときだけ `Surface` を書き換える |
| `-KeepExistingProfiles` | off | 既存の ini を上書きしない |
| `-SkipGameSettings` | off | レジストリのゲーム設定を触らない |
| `-CncSourceDir` | （なし） | 既に cnc-ddraw があるフォルダから流用する（既定は GitHub から取得） |
| `-ZipPath` / `-SkipDownload` | — | 手元の zip を使う / ダウンロードしない |
| `-VerifyOnly` | off | **何も変更せず、現状が意図どおりかだけ確認する** |
| `-WhatIfOnly` | off | 何も変更せず、やろうとしている事だけ表示 |

## 処理の順序

前提確認 → cnc-ddraw 配置 → ddraw プロファイル生成 → レジストリ（互換性レイヤー /
`Surface`）→ ludusavi → Playnite の登録内容表示 → 検証。

## ED3 / ED4 との違い

| | ED3 | ED4 | **ED5** |
|---|---|---|---|
| `DDRAW.dll` を import するもの | exe 自身 | `DLLDV\` の DLL | **exe 自身** |
| 色深度 | — | 16bit | **8bit (256色)** |
| `16BITCOLOR` | 不要 | **必須** | **不要** |
| ゲーム側の画面モード設定 | 無し | `ScreenMode`（0 でないと起動しない） | **無し（排他フルスクリーン固定）** |
| 設定の保存先 | `ED3_CFG.INI`（セーブと同じ場所） | レジストリ | **レジストリ** |
| 同期からの除外 | **必要**（`ED3_CFG.INI`） | 不要 | **不要** |

> **ゲーム側に画面モードの設定は無い。** `ED5_CFG.EXE` にもフルスクリーン／ウィンドウの
> 選択肢が無く、`ED5_XP.EXE` は常に排他フルスクリーンを取りにいく
> （[docs/analysis.md 1.4](../../docs/analysis.md#14-ed5_xpexe)）。
> ウィンドウ表示は cnc-ddraw 側（`nonexclusive=true`）で作る。

> **`16BITCOLOR` を当てないこと。** ED5 が要求するのは 8bit で、16bit 前提なのは
> ED4 の描画ドライバの話。ED4 のスクリプトからコピーしてくると入ってしまう。
