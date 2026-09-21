# 実行ファイルの解析結果

実行ファイルを直接解析して確認した仕様。
**推測ではなく、PE ヘッダ・インポートテーブル・リソース・逆アセンブルから読んだ事実。**

ここで確定した事実が、[setup.md](setup.md) の設定すべての根拠になる。

---

## 1.1 共通事項

| | `ED3_WIN.EXE` | `ED4_XP.EXE` | `ED5_XP.EXE` |
|---|---|---|---|
| サイズ | 389,120 バイト | 933,888 バイト | 815,104 バイト |
| ビルド日時 | 2007-03-05 | 2007-03-05 | 2007-03-05 |
| リンカ | MSVC 6.0 | MSVC 6.0 | MSVC 6.0 |
| バージョン | Ver 1.14 | 1.0.1.0 | 1.0.1.2 |
| サブシステム | GUI (2) | GUI (2) | GUI (2) |
| DEP (`NXCOMPAT`) | **false** | **false** | **false** |
| 埋め込みマニフェスト | **なし** | **なし** | **なし** |
| ファイル名のインストーラ検出語 | なし | なし | なし |
| `QueryPerformanceCounter` の import | **なし** | **なし** | **なし** |

この表から確定すること:

| 事実 | 帰結 |
|---|---|
| `NXCOMPAT` = false | **DEP は適用されない。** DEP 関連の設定は動作に影響しない |
| マニフェストが無く、ファイル名にも `setup` / `install` を含まない | **昇格要求は実行ファイル由来ではない。** Windows のインストーラ検出でもない。昇格が起きるなら原因は互換性レイヤー側 |
| `QueryPerformanceCounter` を import していない | **`QueryPerformanceCounter` / `QueryPerformanceFrequency` の戻り値を細工する時間伸縮ツールは原理的に効かない。** タイミングは `timeGetTime` / `timeSetEvent` 系（`WINMM.dll`） |

---

## 1.2 `ED3_WIN.EXE`

### インポート（抜粋）

```
DDRAW.dll     DirectDrawCreate                    ← DirectDraw 1 のみ。7 の API は使わない
DSOUND.dll    DirectSoundCreate
DINPUT.dll    DirectInputCreateA
WINMM.dll     timeSetEvent, timeKillEvent,
              timeBeginPeriod, timeEndPeriod, timeGetTime
```

**`ED3_WIN.EXE` 自身が `DDRAW.dll` を import している。**

### 設定・セーブの保存先

`fsetup.dll` を動的ロードして `GetUserPath` を呼ぶ。埋め込まれているベース文字列:

```
Application Data\FALCOM\
```

同梱の `FALCOM.INF` の定義:

```
%UserPath%ED3_XP\SAVEDATA
```

→ 実体は **`%APPDATA%\FALCOM\ED3_XP\SAVEDATA`**

### 設定ファイル `ED3_CFG.INI`

**`%APPDATA%\FALCOM\ED3_XP\SAVEDATA\ED3_CFG.INI`**

```ini
[新・英雄伝説 III 「白き魔女」]
BGM=WAVE
SE=ON
Joystick=ON
Video=ON
DSound=ON
BGM VOL=9  SE VOL=9
FRAME=8
```

**設定ファイルがセーブデータと同じフォルダにある。**
→ セーブ同期の際に除外指定が必要になる（[setup.md](setup.md)）。

### `FRAME` = 進行速度

ゲーム内「環境設定 → 画面描画」の値。**移動1歩あたりの補間コマ数。**
FPS には上限があるため:

```
体感速度  ∝  FPS ÷ FRAME
```

| `FRAME` | 相対速度 |
|---|---|
| 8（初期値） | 1.0 |
| 4 | 2.0 |
| 2 | 4.0 |

小さくするほど速くなり、アニメーションはカクつく。

---

## 1.3 `ED4_XP.EXE`

**ED3 とは構成が根本的に違う。** 実行ファイル名だけ変えた流用はできない。

### フォルダ構成

```
ED4_XP.EXE      933,888     ← 本体
ED4_ENV.EXE      61,440     ← 環境設定ツール（別プロセス）
ED4_XP.GDF      327,680
falcom.inf        3,412
DLLDV/                      ← 描画・入力・音声のドライバ DLL
LIB/                        ← データ (*.DAT) とムービー (*.AVI)
MIDI/
WAVEDV/                     ← BGM (*.WAV + *.POS)
```

### インポート

```
WINMM.dll     timeGetTime
KERNEL32.dll  CreateDirectoryA, SetCurrentDirectoryA, LoadLibraryA, ...
USER32.dll
GDI32.dll
ADVAPI32.dll  RegCreateKeyExA, RegSetValueExA, RegQueryValueExA, RegCloseKey
SHELL32.dll   SHGetSpecialFolderLocation, SHGetPathFromIDListA, SHGetMalloc
ole32.dll
```

**DirectDraw / DirectSound / DirectInput を一切 import していない。**

### `DLLDV\` — 実行時にロードされるドライバ

`LoadLibraryA` で動的に読む。exe 内に埋め込まれている名前:

| DLL | 役割 | 色深度 | `DDRAW.dll` を import |
|---|---|---|---|
| `DLLDV\Full555` / `Full565` | 排他フルスクリーン描画 | 16bit (RGB555 / RGB565) | **する** |
| `DLLDV\Win555` / `Win565` | ウィンドウ描画 | 16bit (RGB555 / RGB565) | **する** |
| `DLLDV\DXSDev` | サウンド (DSOUND) | — | — |
| `DLLDV\DXIDev` | 入力 (DINPUT) | — | — |
| `DLLDV\DXWDev` | WAVE 再生 (WINMM) | — | — |
| `DLLDV\MIDIDev` | MIDI | — | — |
| `DLLDV\NBGMDev` | BGM 無し | — | — |

確定すること:

| 事実 | 帰結 |
|---|---|
| `DDRAW.dll` を呼ぶのは `DLLDV\` 配下の DLL | だが **DLL 検索順序は「プロセスの exe があるフォルダ」が最優先**。呼び出し元 DLL の場所は関係ない → **差し替え用の `ddraw.dll` はゲーム直下に置く**（`DLLDV\` の中ではない） |
| 描画ドライバは 16bit サーフェスしか扱わない | **Windows 8 以降のデスクトップは 32bit 固定。** 16bit を見せる仕組みが要る |

### 描画解像度

`ED4_XP.EXE` 内に `push 480; push 640` の並びが複数存在。
→ **640x480 (4:3) 固定**（ED3 も同じ）。

### 設定の保存先は**レジストリ**

**`HKEY_CURRENT_USER\SOFTWARE\FALCOM\ED4_XP`**（`push 0x80000001` = HKCU を確認）

| 値名 | 型 | 意味 |
|---|---|---|
| **`ScreenMode`** | DWORD | **`0`=ウィンドウ / `1`=フルスクリーン** |
| **`PixelFormat`** | DWORD | 下記 |
| **`FrameRate`** | DWORD | 下記。既定 `3` |
| `BGM` | DWORD | BGM デバイス (WAVE / MIDI / なし) |
| `BGMVolume` / `SEVolume` | DWORD | 音量 |
| `MessageWait` | DWORD | メッセージウェイト |
| `SaveNumber` | DWORD | 最後に使ったセーブ番号 |
| `EnableMovie` | DWORD | ムービー再生 |
| `EnablePad` / `EnableDirectInput` | DWORD | ジョイパッド / DirectInput |
| `EnableDirect3D` / `IgnoreDirect3D` | DWORD | Direct3D |
| `OnVideo` | DWORD | サーフェイス（ビデオ / システム） |
| `HardwareAcceleration` | DWORD | 2D アクセラレーション |

`ED4_ENV.EXE` のダイアログリソース（UTF-16LE）から抽出した選択肢:

| 設定 | 選択肢 |
|---|---|
| スクリーンモード | `ﾌﾙｽｸﾘｰﾝ` / `ｳｲﾝﾄﾞｳ` |
| サーフェイス | `ﾋﾞﾃﾞｵ` / `ｼｽﾃﾑ` |
| Direct3D | `ON` / `OFF` |
| フレームレート | `x1,x2,x4,Fix` |
| BGM デバイス | `WAVE,MIDI,なし` |

**設定がレジストリにあり、セーブフォルダに入っていない。**
→ ED3 と違い、セーブ同期の除外指定は不要（[setup.md](setup.md)）。

#### `ScreenMode` の分岐（`0x00491670`）

```
ScreenMode == 0  →  Win555 を試す → 失敗したら Win565
ScreenMode != 0  →  PixelFormat に従って Full555 / Full565
```

#### `PixelFormat` の分岐（同じ関数）

```
bit1 (値 2) が立っている  →  明示指定。bit0 が 0 なら 555、1 なら 565
bit1 が 0                 →  自動探索。Full555 を試し、駄目なら Full565
```

`PixelFormat=3` で「565 を明示指定」。既定は `0` = 自動探索。

#### `FrameRate` の分岐（`0x004a17ae` 付近）

読み込み時の既定値は `3`。内部の描画間引き係数への変換:

| `FrameRate` | 間引き係数 | 制御フラグ |
|---|---|---|
| `0` | 1 | ON |
| `1` | 2 | ON |
| `2` | 4 | ON |
| `3`（既定）以上 | 1 | **OFF** |

`3` だけ制御フラグが下りる。**フレームレート制限を外す設定**と読める。

> 逆アセンブルから確定できるのはここまで。`0`〜`3` が体感速度にどう効くかは実際に試して決める。

### セーブデータの保存先

`falcom.inf` の定義:

```
MKDIR  %UserPath%ED4_XP
MKDIR  %UserPath%ED4_XP\SaveData
```

→ **`%APPDATA%\FALCOM\ED4_XP\SaveData`**（ファイル名はセーブ枠番号）

ED3 は `SAVEDATA`、ED4 は `SaveData`。**綴りが違う。**

---

## 1.4 `ED5_XP.EXE`

**ED3 型（exe 自身が `DDRAW.dll` を import）と ED4 型（設定はレジストリ）の混在。**
ED3 / ED4 のどちらのスクリプトをそのまま流用してもいけない。

### フォルダ構成

```
ED5_XP.EXE      815,104     ← 本体
ED5_CFG.EXE      57,344     ← 環境設定ツール（別プロセス。ビルドは 2003-02-05、"CONFIG" 1.00）
ED5_XP.GDF      327,680
FALCOM.INF        3,661
ED5_DT00..10.DAT            ← データ
ED5_DT07/08/10.M, .W        ← BGM のループ情報 (MIDI 用 / WAVE 用)
MIDI_GM/                    ← BGM (*.MID)
WAVEDVD/                    ← BGM (*.WAV)
```

**`DLLDV\` が無い。** ED4 のような描画ドライバ DLL の仕組みを持たない。

### インポート（抜粋）

```
DDRAW.dll     DirectDrawCreate              ← exe 自身が import（ED3 と同じ）
DSOUND.dll    DirectSoundCreate
DINPUT.dll    DirectInputCreateA
WINMM.dll     timeSetEvent, timeGetTime, midiStream*, joyGetPosEx,
              auxGetVolume, auxSetVolume, mciSendCommandA, mmio*
MSACM32.dll   acmStreamOpen, acmStreamConvert, ...
AVIFIL32.dll  AVIFileOpenA, AVIStreamGetFrame, ...
ADVAPI32.dll  RegCreateKeyExA, RegSetValueExA, RegQueryValueExA, RegCloseKey
SHELL32.dll   SHGetSpecialFolderLocation, SHGetPathFromIDListA, SHGetMalloc
GDI32.dll     CreatePalette, SelectPalette, GetSystemPaletteEntries,
              CreateDIBSection, BitBlt, ...
```

確定すること:

| 事実 | 帰結 |
|---|---|
| `DDRAW.dll` を呼ぶのは **exe 自身** | 差し替え用の `ddraw.dll` はゲーム直下でそのまま効く。ED4 のような `DLLDV\` の考慮は要らない |
| `CreatePalette` / `SelectPalette` / `GetSystemPaletteEntries` を使う | **パレット（8bit）前提の描画。** 下の `SetDisplayMode` と一致する |

### 画面モード — 640x480 / **8bit (256色)** の排他フルスクリーン固定

`DirectDrawCreate` のあと `QueryInterface` で `IID_IDirectDraw2`
（`b3a6f3e0-2b43-11cf-a2de-00aa00b93356`）を取り、`0x0042a3d0` の初期化関数で:

```
SetCooperativeLevel(hwnd, 0x11)       ; DDSCL_EXCLUSIVE | DDSCL_FULLSCREEN
SetDisplayMode(640, 480, 8, 60, 0)    ; 失敗したら
SetDisplayMode(640, 480, 8,  0, 0)    ; リフレッシュレート指定なしで再試行
```

オープニング用の別経路（ウィンドウクラス名 `"Open"`、`0x0046dd` 付近）だけは 16bit を先に試す:

```
SetDisplayMode(640, 480, 16, 0, 0)    ; 失敗したら
SetDisplayMode(640, 480,  8, 0, 0)
```

どちらも失敗すると `"DirectDraw Init FAILED"` のメッセージボックスが出る。

| 事実 | 帰結 |
|---|---|
| 本編が要求する色深度は **8bit** | **Windows 8 以降のデスクトップは 32bit 固定で、8bit の画面モードは存在しない。** cnc-ddraw が事実上の必須条件 |
| 16bit を要求するのはオープニングの経路だけ | **`16BITCOLOR` は ED5 には当てない。** 16bit 前提なのは ED4 の描画ドライバの話（[1.3](#13-ed4_xpexe)） |
| 排他フルスクリーン (`DDSCL_EXCLUSIVE`) を取りにいく | `nonexclusive=true` が要る（[setup.md 2.1](setup.md#21-アスペクト比--maintas--aspect_ratio--nonexclusive)） |
| 解像度は 640x480 | **4:3 固定**（ED3 / ED4 と同じ） |

`DDSCL_NORMAL`（ウィンドウ）側の分岐もコード上は存在するが、それを選ぶフラグ
（`0x004becf9`）は WinMain で `1` に初期化されたあと、`0` を書く箇所がどこにも無い。
`ED5_CFG.EXE` のダイアログにもスクリーンモードの項目が無い。
→ **ゲーム側にウィンドウモードは無い。** 表示のウィンドウ化は cnc-ddraw 側で作る。

### 設定の保存先は**レジストリ**

**`HKEY_CURRENT_USER\SOFTWARE\FALCOM\ED5_XP`**

`ED5_CFG.EXE` の設定テーブル（`0x00409110` 以降）から読んだ値名・選択肢・既定値:

| 値名 | 型 | ダイアログ上の項目 | 値 | 既定 |
|---|---|---|---|---|
| `DirectSound` | DWORD | DirectSound | `1`=ON / `0`=OFF | `1` |
| `SE` | DWORD | 効果音 | `1`=ON / `0`=OFF | `1` |
| `Joystick` | DWORD | ｼﾞｮｲｽﾃｨｯｸ | `1`=ON / `0`=OFF | `1` |
| `DirectInput` | DWORD | DirectInput | `1`=ON / `0`=OFF | `1` |
| **`Flip`** | DWORD | 描画速度固定 | `1`=自動 / `0`=同期 | `1` |
| **`Surface`** | DWORD | VRAM | `1`=ビデオ / `0`=メイン | `1` |
| `BgmVolume` / `SEVolume` | DWORD | BGM / 効果音ﾎﾞﾘｭｰﾑ | 上限 `9` | `9` |
| **`Frame`** | DWORD | 描画精度 | `0`=標準 / `1`=少し粗い / `2`=粗い | `0` |
| `BGM` | DWORD | BGM | `0`=なし / `1`=WAVE / `2`=MIDI | `1` |

ON/OFF の対応は推測ではない。テーブルの各エントリは
`{値名, 第1コントロールID, 第2コントロールID, 既定値}` の 16 バイトで、
`0x00401561` のループが

```
SendDlgItemMessage(id1, BM_SETCHECK, value)
SendDlgItemMessage(id2, BM_SETCHECK, (value == 0))
```

を呼ぶ。**非 0 ならダイアログ上の第1選択肢が選ばれる。**

**`ScreenMode` も `EnableDirect3D` も無い。** ED4 で必要だった設定が ED5 には存在しない
（画面モードは exe 側で固定、Direct3D を使う経路が無い）。

> `Frame`（描画精度）が ED3 の `FRAME` に当たる速度・品質の調整だが、
> `0`〜`2` が体感速度にどう効くかは実際に試して決める。

### セーブデータの保存先

埋め込み文字列 `\Application Data\FALCOM\` と `ED5_XP\ED5SD000.DAT`、
および `FALCOM.INF` の `MKDIR %UserPath%ED5_XP`。

→ **`%APPDATA%\FALCOM\ED5_XP`**（フォルダ**直下**に `ED5SD000.DAT` 形式で置かれる）

| | セーブの位置 |
|---|---|
| ED3 | `%APPDATA%\FALCOM\ED3_XP\SAVEDATA` |
| ED4 | `%APPDATA%\FALCOM\ED4_XP\SaveData` |
| **ED5** | **`%APPDATA%\FALCOM\ED5_XP`（サブフォルダ無し）** |

**設定がレジストリにあるので、ED3 のような同期の除外指定は不要**（[setup.md](setup.md)）。
スクリーンショットは `BMP\ED5_%02d-%02d-%02d-%02d-%02d.BMP` で、
**ゲームフォルダ側**なので同期の対象外。
