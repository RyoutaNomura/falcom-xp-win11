# 実行ファイルの解析結果

実行ファイルを直接解析して確認した仕様。
**推測ではなく、PE ヘッダ・インポートテーブル・リソース・逆アセンブルから読んだ事実。**

ここで確定した事実が、[setup.md](setup.md) の設定すべての根拠になる。

---

## 1.1 共通事項

| | `ED3_WIN.EXE` | `ED4_XP.EXE` |
|---|---|---|
| サイズ | 389,120 バイト | 933,888 バイト |
| ビルド日時 | 2007-03-05 | 2007-03-05 |
| リンカ | MSVC 6.0 | MSVC 6.0 |
| バージョン | Ver 1.14 | 1.0.1.0 |
| サブシステム | GUI (2) | GUI (2) |
| ASLR (`DYNAMICBASE`) | **false** | **false** |
| DEP (`NXCOMPAT`) | **false** | **false** |
| 埋め込みマニフェスト | **なし** | **なし** |
| ファイル名のインストーラ検出語 | なし | なし |
| `QueryPerformanceCounter` の import | **なし** | **なし** |

この表から確定すること:

| 事実 | 帰結 |
|---|---|
| `NXCOMPAT` = false | **DEP は最初から適用されていない。** DEP の除外登録は効果を持たない |
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

**`%APPDATA%\FALCOM\ED3_XP\SAVEDATA\ED3_CFG.INI`（114 バイト）**

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
FPS には上限（実測 40 前後）があるため:

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
ED4_ENV.EXE      61,440     ← 環境設定ツール（別プロセス、2002 年ビルド）
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

> 逆アセンブルから確定できるのはここまで。`0`〜`3` が体感速度にどう効くかは実測で決める。
> 間引くほど描画負荷が下がるので、重い環境では `2` (x4) が最も速い。

### セーブデータの保存先

`falcom.inf` の定義:

```
MKDIR  %UserPath%ED4_XP
MKDIR  %UserPath%ED4_XP\SaveData
```

→ **`%APPDATA%\FALCOM\ED4_XP\SaveData`**（1ファイル 14,460 バイト、ファイル名はセーブ枠番号）

ED3 は `SAVEDATA`、ED4 は `SaveData`。**綴りが違う。**

---

## 1.4 解析に使った方法

特別なツールは使っていない。Python で PE ヘッダを直接パースし、逆アセンブルは capstone。

```python
# セクションテーブルから RVA → ファイルオフセットを解決し、
# データディレクトリ [1] = インポート、[2] = リソースを辿る
e_lfanew = struct.unpack_from('<I', data, 0x3C)[0]
# ... IMAGE_NT_HEADERS → IMAGE_OPTIONAL_HEADER → DataDirectory
```

- `DllCharacteristics` の `0x0040` = ASLR、`0x0100` = DEP
- リソースタイプ `24` = マニフェスト、`16` = バージョン情報、`5` = ダイアログ
- ダイアログリソースの文字列は UTF-16LE。日本語が入るので ASCII 抽出では拾えない
- レジストリのルートキーは `push 0x80000001` のような即値で読める（`HKEY_CURRENT_USER`）
