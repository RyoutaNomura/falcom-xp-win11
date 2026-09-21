# セットアップ — 必要な作業・設定

[analysis.md](analysis.md) の解析結果から導かれる、実際にやること。各項目に**根拠**を付けてある。

| | |
|---|---|
| [スクリプトが設定する内容](#スクリプトが設定する内容) | 何をどこに書き込むかの一覧。まずここ |
| [1. cnc-ddraw を置く](#1-cnc-ddraw-を置く) | [2. `ddraw.ini` の値の理由](#2-ddrawini-の値の理由) |
| [3. 互換性レイヤー](#3-互換性レイヤー) | [4. ゲーム側の設定](#4-ゲーム側の設定) |
| [5. セーブデータ同期](#5-セーブデータ同期) | [6. 症状別の確認手順](#6-症状別の確認手順) |
| [7. スクリプトが扱わないこと](#7-スクリプトが扱わないこと) | [8. 元に戻す](#8-元に戻す) |
| [9. 参考](#9-参考) | |

---

## スクリプトが設定する内容

### ゲームフォルダに置くもの

| ファイル | 内容 |
|---|---|
| `ddraw.dll` / `Shaders\` / `ddraw.reference.ini` / `cnc-ddraw config.exe` | cnc-ddraw 一式。GitHub の最新 Release から取得する（既にあれば何もしない） |
| `ddraw.window.ini` / `ddraw.fullscreen.ini` | 表示プロファイル2種（値は下表） |
| `ddraw.ini` | `-Mode` で指定した側のコピー。cnc-ddraw が実際に読むファイル |
| `Use_Window.cmd` / `Use_Fullscreen.cmd` | プロファイルを `ddraw.ini` にコピーするだけのバッチ |

### `ddraw.ini` に書く値

**既定値から変える必要があるキーだけを書く。** それ以外は cnc-ddraw の既定のまま。
明示する値が少ないほど、cnc-ddraw が更新されたときの追従が楽になる。

| キー | cnc-ddraw の既定 | window | fullscreen |
|---|---|---|---|
| `windowed` | `false` | `true` | `true` |
| `fullscreen` | `false` | `false` | **`true`** |
| `border` | `true` | `true` | **`false`** |
| `resizable` | `true` | `true` | `false` |
| `width` × `height` | 0 × 0 | **作業領域に収まる最大の 4:3** | 0 × 0 |
| `posX` / `posY` | — | `-32000`（画面中央） | `-32000` |
| `maintas` | `false` | **`true`** | **`true`** |
| `aspect_ratio` | （なし） | **`4:3`** | **`4:3`** |
| `nonexclusive` | `true` | `true` | `true` |
| `boxing` | `false` | `false` | `false` |
| `adjmouse` | **`true`** | **`false`** | **`false`** |
| `devmode` | `false` | `false` | `false` |
| `noactivateapp` | `false` | **`true`** | **`true`** |
| `savesettings` | **`1`** | **`0`** | **`0`** |

### レジストリ

| キー / 値 | 設定値 | 対象 |
|---|---|---|
| `HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers` の `"<exe のフルパス>"` | `~ HIGHDPIAWARE` | ED3 |
| 同上 | `~ 16BITCOLOR HIGHDPIAWARE` | ED4 |
| `HKCU\SOFTWARE\FALCOM\ED4_XP` の `EnableDirect3D` | `0` | ED4 |
| `HKCU\SOFTWARE\FALCOM\ED4_XP` の `ScreenMode` | **書き換えない**（`-GameScreenMode` で明示したときだけ） | ED4 |
| `HKCU\SOFTWARE\FALCOM\ED5_XP` の `Surface` | **書き換えない**（`-GameSurface` で明示したときだけ） | ED5 |

### ludusavi の `config.yaml`

| 追加する内容 | 対象 |
|---|---|
| `customGames` にエントリ1件（セーブフォルダを `<winAppData>` 相対で指定） | 全タイトル |
| `backup.toggledPaths` に `ED3_CFG.INI` の除外を1行 | ED3 |

`config.yaml` が無ければこの項目は警告を出して飛ばす。表示まわりの設定は最後まで行われる。

### 触らないもの

- **ゲーム本体のファイル**（`*.EXE` / `*.DAT` / `DLLDV\` など）
- **ED3 のゲーム内設定**（`ED3_CFG.INI`）
- **ED4 の音量 / `FrameRate` / メッセージウェイト**、および既定では `ScreenMode`
- **ED5 の音量 / `Frame` / `BGM` / `Flip`**、および既定では `Surface`
- **Playnite の設定** — 登録に使う引数を表示してクリップボードにコピーするだけ。登録は手動

既存のファイルを書き換える前に `*.bak` を1つ作る（既にあれば上書きしない）。
`-WhatIfOnly` / `-VerifyOnly` を付けると、ファイル・レジストリ・ネットワーク・
クリップボードのいずれにも触れない。

---

## 1. cnc-ddraw を置く

`ddraw.dll` をゲームフォルダに置くだけで、640x480 の DirectDraw 描画を
ウィンドウ表示 + アップスケーリングに差し替えられる。

配布元: <https://github.com/FunkyFr3sh/cnc-ddraw>（GPL、作者 FunkyFr3sh）

**置き場所は ED3 / ED4 / ED5 とも「ゲーム直下」。** `DLLDV\` の中ではない。

> **根拠**: ED4 で `DDRAW.dll` を呼ぶのは `DLLDV\Full565.dll` などだが、DLL 検索順序は
> 「プロセスの exe があるフォルダ」が最優先で、呼び出し元 DLL の場所は関係ない
> （[analysis 1.3](analysis.md#13-ed4_xpexe)）。
> ED3 / ED5 は exe 自身が `DDRAW.dll` を import するので、そもそも迷う余地がない
> （[analysis 1.4](analysis.md#14-ed5_xpexe)）。

> **ED5 では cnc-ddraw が事実上の必須条件。** ED5 が要求する 8bit (256色) の画面モードは
> Windows 8 以降のデスクトップに存在しない（[analysis 1.4](analysis.md#画面モード--640x480--8bit-256色-の排他フルスクリーン固定)）。

> `cnc-ddraw config.exe` は使わないほうが無難。保存すると `ddraw.ini` を書き換えるので、
> スクリプトが生成するプロファイルとの二重管理になる。

---

## 2. `ddraw.ini` の値の理由

値そのものは[上の表](#ddrawini-に書く値)。ここでは既定から変えている理由を書く。

### 2.1 アスペクト比 — `maintas` + `aspect_ratio` + `nonexclusive`

描画は 640x480 = 4:3（[analysis 1.3](analysis.md#描画解像度)）。
**画面が横に伸びる経路は2つあり、どちらも塞ぐ必要がある。**

| 経路 | 対策 |
|---|---|
| **DPI スケーリングが 100% 以外**のとき | 互換性レイヤーの `HIGHDPIAWARE`（[3](#3-互換性レイヤー)） |
| **ゲームが排他フルスクリーンで画面モードを 640x480 に切り替える**と、拡大するのは cnc-ddraw ではなく **GPU / パネル側**になり、`maintas` も `aspect_ratio` も一切効かない | `nonexclusive=true` |

`maintas` はアスペクト比の維持を有効にするだけで、比率そのものは指定しない。
`maintas` だけでは維持されないことがあるため、`aspect_ratio=4:3` で比率を明示する。

```ini
maintas=true
aspect_ratio=4:3
nonexclusive=true
```

### 2.2 ウィンドウサイズ — 作業領域に収まること

**cnc-ddraw は、画面の作業領域に収まらないウィンドウを画面サイズまで縮める。**
枠と表題バーを含めて収まらないサイズを指定すると、画面いっぱいの窓になり、
フルスクリーンと見分けがつかなくなる。

既定の `1440x1080` は 1080p では枠込みで収まらない。
スクリプトは実行時に作業領域と枠の高さを測り、収まる最大の 4:3 サイズに調整する
（`-NoAutoFit` で無効化）。

### 2.3 マウス

このシリーズはキーボード / ジョイパッド操作なので、cnc-ddraw にカーソルを触らせない。
`adjmouse` は既定が `true` なので、明示的に切らないと有効になる。

それでもカーソルを掴まれる場合、cnc-ddraw 側に `lock_mouse_top_left` と
`hook_peekmessage` がある（どちらも既定 `false`。スクリプトは書き出さない）。

### 2.4 `noactivateapp=true`

古い DirectSound アプリは非アクティブ化のメッセージでサウンドバッファを解放し、
アクティブ化のメッセージで作り直す作りになっていることが多い。ウィンドウモードで動かすと
このやり取りが本来の想定と食い違い、解放だけされて再作成されない状態に落ちる。

`WM_ACTIVATEAPP` / `WM_NCACTIVATE` をゲームから隠せば、その分岐に入らない。
リファレンス ini の記述は "Hide WM_ACTIVATEAPP and WM_NCACTIVATE messages to prevent problems on alt+tab"。

### 2.5 `savesettings=0`

既定の `1` だと、ゲーム終了時に cnc-ddraw が `ddraw.ini` を書き戻す。
プロファイルを設定の正本にするため `0` にする。

### 2.6 拡大品質（任意）

`shader=` にシェーダのパスを指定する。既定は `Shaders\interpolation\catmull-rom-bilinear.glsl`。
スクリプトは指定していない（既定のまま）。

| 用途 | パス |
|---|---|
| くっきり（にじみなし） | `Shaders\nearest-neighbor.glsl` |
| ドット絵向け | `Shaders\xbr\xbr-lv2-noblend.glsl` |
| ドット絵向け（高品質） | `Shaders\xbrz\xbrz-freescale-multipass.glsl` |
| ブラウン管風 | `Shaders\crt\crt-lottes-fast-no-warp-bilinear.glsl` |
| シャープネス補正 | `Shaders\sharpen\rca-sharpen.glsl` |

拡大率が整数にならない環境（1080p では 2.25 倍）では `nearest-neighbor` だとドットが不揃いに見える。
`boxing=true` で整数倍に固定するか（1080p なら 1280x960）、シェーダで補間する。

---

## 3. 互換性レイヤー

| レイヤー | 判定 | 根拠 |
|---|---|---|
| `HIGHDPIAWARE` | ✅ **全タイトルに必要** | スケーリングが 100% 以外のとき、DPI 非対応アプリから見た画面比率がずれる。スケーリングをアプリ側に任せて防ぐ |
| **`16BITCOLOR`** | ✅ **ED4 に必須 / ED3・ED5 には当てない** | ED4 の描画ドライバは 16bit (RGB565 / RGB555) サーフェスしか扱わない（[analysis 1.3](analysis.md#dlldv--実行時にロードされるドライバ)）。Windows 8 以降のデスクトップは 32bit 固定なので、簡易カラーモード「16 ビット (65536) カラー」を当てないと**起動しない**。ED3 / ED5 は自身が `DDRAW.dll` を import しており不要。**ED5 が要求するのはそもそも 8bit** で、16bit のシムは的外れ（[analysis 1.4](analysis.md#14-ed5_xpexe)） |
| **`WINXPSP3`** | ❌ **入れない** | 下記 |
| `RUNASINVOKER` | ❌ 不要 | `WINXPSP3` が誘発する昇格を打ち消せない |
| `DWM8And16BitMitigation` / `640X480` | ❌ 不要 | — |

### 3.1 `WINXPSP3` を入れてはいけない理由

**`WINXPSP3` は UAC 昇格を誘発する。** そして `ludusavi wrap` はゲームを `CreateProcess` で
起動するが、`CreateProcess` は昇格できない。結果、Playnite 経由の起動が次のエラーで失敗する。

```
Game failed to launch.
エラー： 要求された操作には管理者特権が必要です。 (os error 740)
```

実行ファイル自身はマニフェストを持たず、ファイル名もインストーラ検出に引っかからない
（[analysis 1.1](analysis.md#11-共通事項)）ので、昇格の原因はここにしかない。
**cnc-ddraw を導入すれば互換モード自体が不要。**

### 3.2 期待どおりにならないとき

> **HKLM も確認すること。** HKLM のエントリは HKCU より優先される。
> 古い形式（`~` 始まりでない）のエントリが残っていることがある。削除には管理者権限が要る。

> `__COMPAT_LAYER` 環境変数を渡すランチャーを噛ませている場合、この環境変数は
> レジストリの値を**上書き**する。**必要なレイヤーを全部列挙し直すこと**（追加ではない）。

---

## 4. ゲーム側の設定

### 4.1 ED4 — レジストリ `HKCU\SOFTWARE\FALCOM\ED4_XP`

| 値 | 設定値 | 根拠 |
|---|---|---|
| **`ScreenMode`** | **`0`（ウィンドウ）** | 下記 |
| **`EnableDirect3D`** | **`0`（OFF）** | cnc-ddraw は DirectDraw のみを実装していて Direct3D を持たない。ON だと cnc-ddraw を経由しない描画になる |

`ED4_ENV.EXE`（環境設定）からも同じ値を設定できる。値の一覧は
[analysis 1.3](analysis.md#設定の保存先はレジストリ)。

#### `ScreenMode` は `0`（ウィンドウ）

cnc-ddraw の一般的な案内は「ゲーム側をフルスクリーンにする」だが、
**ED4 は `ScreenMode=1` では起動しない。**

**根拠**（[analysis の `ScreenMode` の分岐](analysis.md#screenmode-の分岐0x00491670)）:

| 値 | 読み込まれる DLL | 挙動 |
|---|---|---|
| `1` | `Full555` / `Full565` | 排他モード取得 + 画面モードを 640x480x16 に変更 + ページフリップ。`16BITCOLOR` シムと cnc-ddraw のエミュレーションが二重にかかると通らない |
| **`0`** | `Win555` / `Win565` | **単純なウィンドウ blit。cnc-ddraw が素直に受けられる** |

**`ScreenMode=0` でも cnc-ddraw は効く。** 描画するのは `Win565.dll` だが、
それが読む `DDRAW.dll` は結局 cnc-ddraw なので、拡大・アスペクト比・フルスクリーン表示は
すべて `ddraw.ini` 側で制御できる。

> **ゲーム側の画面モードと、見た目のウィンドウ／フルスクリーンは別のレイヤーの話。**

スクリプトは既定 (`-GameScreenMode keep`) では `ScreenMode` を**書き換えない**
（[conventions 2.2](conventions.md#22-動いている設定を黙って上書きしない)）。
明示したいときだけ `-GameScreenMode window`。

### 4.2 ED3 — `ED3_CFG.INI`

スクリプトは触らない。ゲーム内「環境設定」から設定する。

### 4.3 ED5 — レジストリ `HKCU\SOFTWARE\FALCOM\ED5_XP`

**既定では何も書き込まない。** ED4 で必要だった設定が ED5 には存在しないため。

| 値 | 設定値 | 根拠 |
|---|---|---|
| `ScreenMode` | **存在しない** | 画面モードは exe 側で排他フルスクリーン固定。`ED5_CFG.EXE` にも項目が無い |
| `EnableDirect3D` | **存在しない** | Direct3D を使う経路が無い |
| **`Surface`** | **書き換えない**（`-GameSurface` で明示したときだけ） | 描画が崩れるときに `main`（メインメモリ）を試すための逃げ道 |

値の一覧は [analysis 1.4](analysis.md#設定の保存先はレジストリ-1)。
設定は `ED5_CFG.EXE`（環境設定）から変更する。

> **ゲーム側にウィンドウモードは無い。** ED4 の `ScreenMode` に当たる設定が無く、
> `ED5_XP.EXE` は常に `DDSCL_EXCLUSIVE | DDSCL_FULLSCREEN` を取りにいく
> （[analysis 1.4](analysis.md#画面モード--640x480--8bit-256色-の排他フルスクリーン固定)）。
> **ウィンドウ表示は cnc-ddraw 側（`nonexclusive=true` + `windowed=true`）だけで作る。**

---

## 5. セーブデータ同期

複数の端末でセーブを共有する構成。**使わないなら5章はまるごと不要。**

```
Playnite から起動
  → ludusavi wrap がクラウドとの差分を確認（ズレていれば3択で確認）
  → 復元 → ゲーム実行 → バックアップ → アップロード
```

手動でのダウンロード操作は不要。**Playnite 拡張も自前スクリプトも要らない。**

必要なもの: [ludusavi](https://github.com/mtkennerly/ludusavi) /
[rclone](https://rclone.org/)（リモート設定済み） / [Playnite](https://playnite.link/)

### 5.1 Playnite のプレイアクション

ゲームの編集 → 「操作」タブ → プレイアクション。

| 項目 | 値 |
|---|---|
| 種類 | ファイル |
| パス | `ludusavi`（PATH にある場合。無ければ `ludusavi.exe` のフルパス） |
| 作業フォルダー | ゲームのインストール先 |

```
wrap --name "英雄伝説III 白き魔女" --gui --cloud-sync --ask-downgrade --force-restore --force-backup -- "C:\FALCOM\ED3_XP\ED3_WIN.EXE"
wrap --name "英雄伝説IV 朱紅い雫"   --gui --cloud-sync --ask-downgrade --force-restore --force-backup -- "C:\FALCOM\ED4_XP\ED4_XP.EXE"
wrap --name "英雄伝説V 海の檻歌"    --gui --cloud-sync --ask-downgrade --force-restore --force-backup -- "C:\FALCOM\ED5_XP\ED5_XP.EXE"
```

| オプション | 効果 |
|---|---|
| `--name` | ludusavi 側のカスタムゲーム名と一致させる。**1文字も違わないこと** |
| `--gui` | 確認・通知を GUI で表示（コンソールではなくダイアログ） |
| `--cloud-sync` | バックアップ完了時にクラウドへアップロード |
| **`--ask-downgrade`** | **バックアップがライブより古いときだけ**確認する |
| **`--force-restore`** | 毎回出る定型確認「復元しますか？」を抑制 |
| **`--force-backup`** | 毎回出る定型確認「バックアップしますか？」を抑制 |

> ⚠️ **`--force`（無印）は絶対に付けない。** クラウド競合の確認まで消え、黙って進む。

`wrap` はゲームが終了するまで生き続けるので、Playnite のプレイ時間計測は既定の追跡モードのまま動く。
記録されない場合のみ、追跡モードを「フォルダー」にしてインストール先を指定する。

スクリプトがこの引数を組み立ててクリップボードにコピーする（登録自体は手動）。

### 5.2 確認ダイアログの2系統

**「毎回出る定型確認」と「危ないときだけ出る確認」がある。**

| 確認 | 出る条件 | 抑制方法 |
|---|---|---|
| 「復元しますか？」 | **無条件・毎回** | `--force-restore` |
| 「バックアップしますか？」 | **無条件・毎回** | `--force-backup` |
| **クラウド競合の3択** | **差分があるときだけ** | `--force`（無印）でのみ消える |
| **ダウングレード警告** | **バックアップがライブより古いときだけ** | 抑制不可 |

前2つは差分の有無を見ていない定型確認なので抑制してよい。
**上のコマンドは、意味のある後ろ2つだけを残している。**

`--force-restore` を付けてもクラウド競合の確認は残る（判定に `--force`（無印）を使っているため）。
安全側に倒した設計になっている。

クラウド競合の3択:

- **「ダウンロード」** — その場でクラウドから引き落としてから復元に進む
- **「無視」** — 何も同期せずゲームが起動する。**押し間違えても被害は出ない**
- **「アップロード」** — ⚠️ もう一方の端末の新しいバックアップをクラウドから消す

#### 端末をまたぐと必ず競合になる — これは仕様

**根拠**: ludusavi は復元の前に、**Upload 方向**でクラウド同期をプレビュー実行する。
**差分が1つでもあれば競合扱いになる。** そして端末Bのローカルバックアップフォルダは、
端末Aが使っている間ずっと更新されない。つまり切り替えた直後は常にクラウドより遅れているので、
**端末を切り替えるたびに必ず競合ダイアログが出る**（[ludusavi Discussion #436](https://github.com/mtkennerly/ludusavi/discussions/436)）。

対処は [5.6](#56-運用上の注意)。

恒久的に消したいなら、`backup.path` / `restore.path` をクラウドのローカル同期フォルダに
直接向けて `cloud.synchronize: false` にする方法もある（このスクリプトは対応しない）。
競合ダイアログと待ち時間は消えるが、同期の完了を自分で待つ必要がある。

### 5.3 ludusavi の設定

`%APPDATA%\ludusavi\config.yaml`

```yaml
customGames:
  - name: 英雄伝説III 白き魔女
    integration: override
    files:
      - "<winAppData>/FALCOM/ED3_XP/SAVEDATA"
    registry: []
    installDir: []
    winePrefix: []

  - name: 英雄伝説IV 朱紅い雫
    integration: override
    files:
      - "<winAppData>/FALCOM/ED4_XP/SaveData"
    registry: []
    installDir: []
    winePrefix: []

  - name: 英雄伝説V 海の檻歌
    integration: override
    files:
      - "<winAppData>/FALCOM/ED5_XP"
    registry: []
    installDir: []
    winePrefix: []

# ED3 のみ。速度設定 FRAME を端末ごとに変えるための除外
backup:
  toggledPaths:
    英雄伝説III 白き魔女:
      "C:/Users/<ユーザー名>/AppData/Roaming/FALCOM/ED3_XP/SAVEDATA/ED3_CFG.INI": false
```

- `<winAppData>` は `%APPDATA%` に展開されるプレースホルダ。**絶対パスを書かないこと。**
  ユーザー名やドライブ構成が違う端末でも、この設定がそのまま通る
- **セーブフォルダ名は ED3 が `SAVEDATA`、ED4 が `SaveData`**（[analysis 1.3](analysis.md#セーブデータの保存先)）。
  **ED5 はサブフォルダを作らず `ED5_XP` の直下に置く**（[analysis 1.4](analysis.md#セーブデータの保存先-1)）
- `registry: []` なので**ゲーム設定は同期されない。** ED4 / ED5 の画面設定や音量が
  端末ごとに独立するのはこのため（意図的）
- **ED3 の除外が要る理由**: `ED3_CFG.INI` は速度設定を含み、**セーブデータと同じフォルダにある**
  （[analysis 1.2](analysis.md#設定ファイル-ed3_cfgini)）

> ⚠️ `toggledPaths` は**絶対パスで書く必要がある**（ここだけ `<winAppData>` が使えない）。
> つまり端末ごとに値が違う。`Setup-ED3.ps1` は実行時のユーザー名から生成する。
> **もう一方の端末でも必ずスクリプトを実行すること。**

#### 同期速度の調整（任意）

`wrap` の起動時／終了時の待ち時間は、**転送量ではなくクラウド API の往復回数**で決まる
（セーブは 15KB 程度）。往復を減らす設定:

```yaml
apps:
  rclone:
    path: "<rclone.exe のフルパス>"
    arguments: "--ignore-checksum --transfers=2 --checkers=4"   # --fast-list は付けない

backup:
  format:
    chosen: zip          # simple → zip
  retention:
    full: 1
    differential: 3
```

| 変更 | 理由 |
|---|---|
| **`--fast-list` を付けない** | ディレクトリ全体を一括列挙するオプション。ファイル数が万単位のとき有効で、**数ファイルでは余計な列挙が1回増えるだけの損** |
| **`zip` 形式にする** | `simple` だと世代ごとに深い階層ができる。zip なら**1世代 = 1ファイル**で列挙対象が激減 |
| **世代を減らす** | 最大 12 世代 → 4 世代 |

> `zip` に変えると既存の `simple` 形式のバックアップとは別扱いになり、初回に再アップロードが発生する。

ゲーム単位の絞り込みは**すでに効いている。** `wrap --name` を指定すると、ludusavi が rclone に
そのゲームだけを対象にする `--include` を渡す。

### 5.4 Playnite 拡張（Ludusavi for Playnite）は使わない

`wrap` が復元・バックアップ・クラウド同期をすべて担うため、役割が完全に重複する。
併用すると二重に走り、実行順も保証されない。

**残す場合は、自動化を必ず全部切ること**（`DoRestoreOnGameStarting` /
`DoBackupOnGameStopped` / `DoBackupDuringPlay` をすべて `false`）。

### 5.5 もう一方の端末への展開

1. ludusavi と rclone を導入
2. `config.yaml` のカスタムゲーム・クラウド設定を同じ内容にする（`<winAppData>` のおかげでパスは無修正）
3. rclone のリモートを同じフォルダに向ける
4. Playnite のプレイアクションを [5.1](#51-playnite-のプレイアクション) の `wrap` コマンドにする
5. **ED3 の場合、`toggledPaths` の絶対パスをその端末のユーザー名に直す**（スクリプトを実行すればよい）

初回だけ手動でダウンロードしてから起動すると確実。以降は `wrap` が差分を検出する。

### 5.6 運用上の注意

- **必ず Playnite から起動する。** exe を直接叩くと `wrap` を経由せず、同期されない
- **両端末で同時にプレイしない**
- 端末を切り替えた直後の競合ダイアログでは、**必ず「ダウンロード」**を選ぶ
- 迷ったら「無視」を選べば何も起きない

---

## 6. 症状別の確認手順

> **まず `-VerifyOnly` を実行する。** 何も変更せず、現状と期待値の差分だけを出す。
>
> ```powershell
> powershell -ExecutionPolicy Bypass -File .\setup.ps1 -VerifyOnly
> ```

| 症状 | 上から順に確認する | 詳細 |
|---|---|---|
| **ED5 が起動しない / 一瞬で落ちる** | ① `ddraw.dll` がゲーム直下にあるか（**無いと 8bit モードが取れない**） ② 互換性レイヤーが `~ HIGHDPIAWARE` か（**`16BITCOLOR` は入れない**） ③ `ED5_CFG.EXE` で VRAM=**メイン**（`-GameSurface main`）を試す ④ `-Renderer gdi` を試す ⑤ BGM を「なし」にして音まわりを切り分ける | [1](#1-cnc-ddraw-を置く) / [4.3](#43-ed5--レジストリ-hkcusoftwarefalcomed5_xp) |
| **ED5 で「DirectDraw Init FAILED」が出る** | `ddraw.dll` が読まれていない。ゲーム直下にあるか、別フォルダの `ddraw.ini` を見ていないか | [1](#1-cnc-ddraw-を置く) |
| **ED4 が起動しない** | ① 互換性レイヤーが `~ 16BITCOLOR HIGHDPIAWARE` か ② `ED4_ENV.EXE` で スクリーンモード=**ウィンドウ**、Direct3D=OFF ③ `ddraw.dll` をリネームして素で起動するか ④ サーフェイス=システム、2D/3D アクセラレーション OFF ⑤ ムービー再生 OFF ⑥ `PixelFormat` を明示（`2`=555 / `3`=565 / `0`=自動） | [3](#3-互換性レイヤー) / [4.1](#41-ed4--レジストリ-hkcusoftwarefalcomed4_xp) |
| **起動時に砂時計のまま固まる** | しばらく待つ / 高速スタートアップを無効化 / 未使用の HDMI・DP 音声出力を無効化 | [7.1](#71-起動直後に砂時計のまま固まる) |
| **UAC が出る / `os error 740`** | 互換性レイヤーから `WINXPSP3` を外す。**HKLM 側も見る**（HKCU より優先） | [3.1](#31-winxpsp3-を入れてはいけない理由) |
| **画面が横に伸びる** | ① DPI スケーリングが 100% か ② `HIGHDPIAWARE` が入っているか ③ `ddraw.ini` に `maintas` **と** `aspect_ratio` の両方があるか ④ `nonexclusive=true` があるか ⑤ `cnc-ddraw config.exe` に反映されているか（無ければ ini が読まれていない） ⑥ ED4 は Direct3D が ON に戻っていないか ⑦ GPU 側のスケーリング設定 | [2.1](#21-アスペクト比--maintas--aspect_ratio--nonexclusive) |
| **ウィンドウにしたのにフルスクリーンのまま** | 枠込みで作業領域に収まっていない。`-WindowWidth 1280 -WindowHeight 960` などで小さくする | [2.2](#22-ウィンドウサイズ--作業領域に収まること) |
| **フォーカスを外すと BGM が止まる** | `ddraw.ini` の `noactivateapp=true` | [2.4](#24-noactivateapptrue) |
| **マウスがウィンドウに捕まる** | `ddraw.ini` の `adjmouse` / `devmode` が `false` か。それでも掴まれるならゲーム側（`DINPUT`） | [2.3](#23-マウス) |
| **描画が崩れる / 色がおかしい** | `-Renderer gdi` を試す（auto → opengl → direct3d9 → gdi）。ED4 は `ED4_ENV.EXE` でサーフェイス=システム、アクセラレーション OFF、ムービー OFF | [2](#2-ddrawini-の値の理由) |
| **進行が速すぎる / 遅すぎる** | ED3 は `FRAME`、ED4 は「フレームレート」、ED5 は「描画精度」。外部ツールは要らない | [7.2](#72-進行速度) |
| **端末切り替えのたびに競合ダイアログ** | 仕様。**必ず「ダウンロード」**を選ぶ。迷ったら「無視」 | [5.2](#52-確認ダイアログの2系統) |
| **Playnite からの起動が遅い** | rclone のクラウド API 往復。`--fast-list` を外す / `zip` 形式 / 世代を減らす | [5.3](#同期速度の調整任意) |
| **セーブが復元されない / 古いデータが戻る** | exe を直接起動していないか / 競合ダイアログで「ダウンロード」を選んだか / Playnite 拡張を併用していないか | [5.4](#54-playnite-拡張ludusavi-for-playniteは使わない) |

**最後の手段**: 互換性レイヤーに `WINXPSP3` を足すと起動することがある。
ただし [3.1](#31-winxpsp3-を入れてはいけない理由) のとおり Playnite 経由の起動を諦めることになる。

```
reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" ^
    /v "C:\FALCOM\ED4_XP\ED4_XP.EXE" /t REG_SZ /d "~ WINXPSP3 16BITCOLOR HIGHDPIAWARE" /f
```

---

## 7. スクリプトが扱わないこと

以下は Windows 側 / ゲーム内の設定で、スクリプトは変更しない。手動で調整する。

### 7.1 起動直後に砂時計のまま固まる

Windows を起動した直後に、砂時計カーソルのままウィンドウが出ないことがある。
しばらく待てば起動する。サウンドデバイスの列挙待ちと見られる。

出にくくするには:

- **高速スタートアップを無効化する** — 起動状態が毎回一定になる
- **未使用の HDMI / DisplayPort 音声出力を無効化する** — 列挙対象を減らす

### 7.2 進行速度

ゲーム内の描画設定で変わる。**外部の速度変更ツールは効かない** — 実行ファイルが
`QueryPerformanceCounter` を import していないため（[analysis 1.1](analysis.md#11-共通事項)）。

| | 設定場所 | 実用値 |
|---|---|---|
| **ED3** | ゲーム内「環境設定 → 画面描画」→ `ED3_CFG.INI` の `FRAME` | `8`（初期値）→ **`4`** で 2 倍 |
| **ED4** | `ED4_ENV.EXE` の「フレームレート」→ レジストリの `FrameRate` | `x1` / `x2` / `x4` / `Fix` |
| **ED5** | `ED5_CFG.EXE` の「描画精度」→ レジストリの `Frame` | `標準` / `少し粗い` / `粗い` |

値と内部の間引き係数の対応は [analysis 1.2](analysis.md#frame--進行速度) /
[1.3](analysis.md#framerate-の分岐0x004a17ae-付近) / [1.4](analysis.md#設定の保存先はレジストリ-1)。

端末ごとに違う値にしたい場合:

- **ED3** — `ED3_CFG.INI` がセーブと同じフォルダにあるので、同期から除外する必要がある（[5.3](#53-ludusavi-の設定)）
- **ED4 / ED5** — 設定がレジストリなので**何もしなくてよい**。自動的に端末ごとの値になる

---

## 8. 元に戻す

```powershell
# 1. cnc-ddraw を外す（ゲーム本体には一切変更を加えていない）
Remove-Item "C:\FALCOM\ED4_XP\ddraw.dll"

# 2. 互換性レイヤーを解除
reg delete "HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" /v "C:\FALCOM\ED4_XP\ED4_XP.EXE" /f

# 3. 書き換えたファイルを戻す（スクリプトが *.bak を作っている）
Move-Item "$env:APPDATA\ludusavi\config.yaml.bak" "$env:APPDATA\ludusavi\config.yaml" -Force
```

ED4 は `ED4_ENV.EXE` でスクリーンモード / Direct3D を好みに戻す。

---

## 9. 参考

- [cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw) — 全設定は同梱の `ddraw.reference.ini`
- [起動しないときの報告方法（デバッグログ版の入手先）](https://github.com/FunkyFr3sh/cnc-ddraw/issues/44)
- [Game launch wrapping — ludusavi docs](https://github.com/mtkennerly/ludusavi/blob/master/docs/help/game-launch-wrapping.md)
- [ludusavi CLI reference（`wrap` の全オプション）](https://github.com/mtkennerly/ludusavi/blob/master/docs/cli.md)
- [What is the intended behavior of Cloud Sync? — ludusavi Discussion #436](https://github.com/mtkennerly/ludusavi/discussions/436)
