# falcom-xp-win11

日本ファルコムの Windows 版タイトル（2007年 DL 版）を **Windows 11** で動かすための、
実行ファイルの解析結果と、そこから導かれる設定、それを反映したセットアップスクリプト。

| タイトル | 実行ファイル | スクリプト |
|---|---|---|
| 英雄伝説III「白き魔女」 | `ED3_WIN.EXE` | [`games/ed3/`](games/ed3/) |
| 英雄伝説IV「朱紅い雫」 | `ED4_XP.EXE` | [`games/ed4/`](games/ed4/) |

**常駐プロセスなし。管理者権限なし。互換モードなし。ランチャーなし。**
DLL インジェクションもしないので、ゲーム本体のファイルには一切触れない。
やめるときは `ddraw.dll` を消すだけで戻る。

---

## 使い方

```powershell
# 1. 現状を確認するだけ（何も変更しない）
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -VerifyOnly

# 2. やろうとしている事を確認する（何も変更しない）
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -WhatIfOnly

# 3. 実行
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

`setup.ps1` が導入済みのタイトルを検出して、対象を選ばせる。
表示モードやレンダラを指定したいときは `games\<id>\Setup-*.ps1` を直接実行する
（パラメータ一覧は各ゲームの README）。

管理者権限は不要。既存のファイルを書き換える前に必ず `*.bak` を1つ作る（既にあれば上書きしない）。

> **`-VerifyOnly` を常用する。** 何も変更せず、現状と期待値の差分だけを出す。
> スクリプトが動いている設定を上書きすると起動しなくなることがあるので、まず現状を見てから流す。

### 前提

- ゲームがインストール済み（既定は `C:\FALCOM\ED3_XP` / `C:\FALCOM\ED4_XP`）
- [ludusavi](https://github.com/mtkennerly/ludusavi) と [rclone](https://rclone.org/) が導入済みで、
  rclone のリモートが設定済み（セーブ同期を使う場合）
- [Playnite](https://playnite.link/) が導入済み（使う場合）

セーブ同期と Playnite を使わないなら、警告が出るだけで表示まわりの設定は通る。

### 1タイトルだけ持ち出す

`games\<id>\` フォルダを丸ごとコピーすれば単体で動く。
スクリプトは同じフォルダの `ddraw\*.ini.tmpl` しか参照しない。

---

## このスクリプトが解決すること

- **ED4 が Windows 11 で起動するようになる**（ED4）
  16bit カラーのサーフェスしか扱わない描画ドライバに合わせて、互換性レイヤーを設定する。
- **640×480 のフルスクリーン固定から解放される**（ED3 / ED4）
  cnc-ddraw を導入し、4:3 を保ったウィンドウ表示とフルスクリーン表示を切り替えられるようにする。
- **セーブデータを端末間で共有できる**（ED3 / ED4）
  ludusavi に登録し、Playnite から起動するだけで復元とバックアップが回るようにする。

設定した値とその根拠は [docs/setup.md](docs/setup.md)、
その元になった実行ファイルの解析結果は [docs/analysis.md](docs/analysis.md)。

---

## ドキュメント

**「解析して分かった事実」→「そこから必要になる設定」→「それを実行するスクリプト」**の順。

| | 内容 |
|---|---|
| [docs/analysis.md](docs/analysis.md) | **実行ファイルの解析結果（事実）。** PE ヘッダ・インポート・リソース・逆アセンブルから読んだ仕様 |
| [docs/setup.md](docs/setup.md) | **必要な作業・設定。** 各項目に analysis のどの事実が根拠かを付けてある。セーブ同期と症状別の確認手順もここ |
| [docs/conventions.md](docs/conventions.md) | スクリプトを触るときの規約（文字コード・設計原則・公開前チェック） |
| [games/ed3/README.md](games/ed3/README.md) / [games/ed4/README.md](games/ed4/README.md) | 各スクリプトのパラメータ一覧 |

**事実は `docs/` にだけ書く。** この README と各 README はリンクに徹する。

- 動かない → [docs/setup.md の「症状別の確認手順」](docs/setup.md#6-症状別の確認手順)
- なぜこの設定なのか → [docs/setup.md](docs/setup.md) → 根拠のリンク先（analysis）
- スクリプトをいじりたい → [docs/conventions.md](docs/conventions.md)

---

## ライセンス

スクリプトとドキュメントは MIT ライセンス（[LICENSE](LICENSE)）。

このリポジトリは**ゲーム本体のファイルを一切含まない。** cnc-ddraw も同梱しておらず、
スクリプトが実行時に [公式の Releases](https://github.com/FunkyFr3sh/cnc-ddraw/releases) から取得する
（GPL、作者 FunkyFr3sh）。
