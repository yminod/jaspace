# 検証

## 実行方法

Emacsを用意し、リポジトリのルートで実行する。初期化ファイルは読み込まない。
macOSなどのPOSIX環境では `/bin/sh` 用のスクリプトを使える。

```sh
./scripts/test.sh
```

EmacsがPATHにない場合は、最初の引数に実行ファイルのパスを指定する。

```sh
./scripts/test.sh /Applications/Emacs.app/Contents/MacOS/Emacs
```

PowerShell 7以降（`pwsh`）を使う場合：

```powershell
pwsh -File ./scripts/test.ps1
```

ソースのERT、警告をエラー扱いにしたバイトコンパイル、コンパイル済みコードのERT、
パッケージメタデータと読み込み・アンロードを検証する。
EmacsがPATHにない場合は `-Emacs '/path/to/emacs'` を付ける。

ソースのERTだけを実行する場合：

```powershell
emacs --batch -Q -L . -l jaspace.el -l test/jaspace-tests.el -f ert-run-tests-batch-and-exit
```

GUI描画は別のスクリプトで確認する。

```powershell
pwsh -File ./scripts/test-gui.ps1 -Emacs '/path/to/emacs'
```

PATHにある場合は `-Emacs` を省略できる。GUIはテスト後に終了する。
起動前にLispの括弧を確認し、タイムアウト・異常終了・完了記録のない終了は失敗とする。

## 現行開発版の確認結果

2026-10-16、GNU Emacs 31.1 (Windows)、開発版1.3.0（`ba9d9a6`）で、
ERT 61件がソース・バイトコードの両方で成功した。
バイトコンパイルとパッケージ検証も成功した。
2026-10-20にはmacOSのEmacs 31.1でも同じ検証とGUIの4件が成功した。
環境固有の実行条件と目視比較の結果は [macOS（POSIX）](#macosposix) を参照。

| 検証対象 | 確認した範囲 |
| --- | --- |
| 表示と幅 | 全角空白・改行・タブ・U+0020、幅API、論理列、タブ幅変更と編集後の更新。 |
| 状態遷移 | ユーザーフックでの有効化、Font Lock・read-onlyによる停止と復帰、コマンドループでの直接変更の反映、明示的な無効化。 |
| 設定の保全と後始末 | 既存・共有display table、他機能の変更、narrowing、複製・indirect buffer、major mode変更、バッファ終了、アンロード。 |
| 本文への影響 | 本文・変更状態・undoの保持、読み取り専用バッファでの利用。 |
| パッケージの影響 | 読み込みによる既存バッファへの影響がないこと、アンロード後のoverlay・フック・adviceの除去、共有idle timerの登録が変わらないこと。 |

U+0020の追加分は14件で、既定で無効、face・マーカーの選択、再有効化での設定変更、
不正なマーカーの拒否、他のdisplay・composition・invisibleや既存マッピングの尊重を
確認した。タブ幅1・2・4・8、U+3000は `[]`、改行は `$\n`、タブは `^` として、
全位置の論理列も比較した。
この成功は、任意のU+3000マーカーや他モードとの併用まで保証するものではない。

Font Lockとwhitespaceの切替は、batch時の抑制を避けて実際のモード関数を通している。
ただし、この検証はGUI描画を含まない。indirect bufferの色付けの独立や、
他方での編集に伴うタブ幅の即時更新は対応範囲外である。

### GUI描画

WindowsのGUI（Courier New、fontパラメータのサイズ13）で4件が成功した。
ドット・ハイフンによるU+0020の明示について、文字の座標、サイズ変更、
他のマーカーを含む折り返しとバッファ全体のピクセル寸法を確認した。
display tableとoverlayの組合せでは `posn-at-point` の値だけで判断せず、
`posn-at-x-y` による逆引きも使った。

Arialと `#` のマーカーでは、行幅が99pxから126pxへ変わっても論理列と幅APIは
維持された。Arialがない環境ではこの1件をskipする。
任意のフォント・faceでのピクセル配置の維持は保証しない。

対応範囲はEmacs 27.1以降だが、確認済みのEmacsバージョンはWindows・macOSとも31.1である。
他の対応バージョン・OS、実端末、任意のフォント割り当ては未検証である。

### macOS（POSIX）

2026-10-20、macOS 27.0.1（arm64）、GNU Emacs 31.1（build 2、NS版）、
開発版1.3.0（`33bd281` に `scripts/test.sh` を追加）で確認した。
ソース・バイトコードのERT各61件、警告をエラー扱いにしたバイトコンパイル、
パッケージメタデータと読み込み・アンロードの検証がすべて成功した。

通常の実行では、幅APIへのadviceの登録に伴うEmacsのネイティブコンパイルで、
コンパイラが `-mmacosx-version-min=18.0` を拒否した。
この環境では次の指定で成功した。ネイティブコンパイルは無効化していない。
スクリプト自体には環境固有の設定を加えていない。

```sh
MACOSX_DEPLOYMENT_TARGET=14.0 ./scripts/test.sh
```

同日、GUIの4件もすべて成功した（skipなし）。既定フォントはMenlo 12。
Arialと `#` のマーカーでは、ピクセル寸法が `(84 . 14)` から `(120 . 14)` に
変わる一方、論理列と幅APIは維持された。
`JASPACE_GUI_TESTS_COMPLETE` とプロセスの終了コード0を確認した。

追加の目視比較は、通常起動したEmacsに本forkのソースを読み込み、Menlo 18で行った。
同じ本文を通常表示と全マーカー有効の表示で上下に並べ、本文の一致と未変更状態も確認した。
ASCII行・タブ行で測定した文字座標は一致し、100個の半角空白を含む行でも
折り返し後の `end` の横位置と論理列は一致した。
一方、`a　b　c` の全角空白を `[]` に置換した行では、Emacsの座標で
`b` が横128→132px、`c` が157→165pxとなった（論理列12・15は維持）。
この行の高さも変わり、後続行の縦位置は4px上がった。
全角空白の置換でピクセル配置が変わり得る既知の制約は
[U+3000の表示](../docs/ideographic-space-display.md) を参照。
この目視比較は、前述の `-Q` による自動GUIテストとは別に実施した。

このセッションのサンドボックス内のシェルからはGUIを起動できなかったため、
Computer Useで接続したEmacsから、`make-process` で別のEmacsを起動した。
子プロセスに `MACOSX_DEPLOYMENT_TARGET=14.0` と `JASPACE_GUI_REPORT` を渡し、
リポジトリを作業ディレクトリとして、次の引数で実行した。
既存のEmacsの初期化ファイルや読み込み済みパッケージは子プロセスに引き継がない。

```text
-Q -L . -L test -l jaspace.el -l test/jaspace-gui-tests.el --eval '(jaspace-gui-run-tests)'
```

これは `scripts/test-gui.ps1` と同じGUIテストの実行引数である。
同スクリプトの起動経路自体が成功したことを示す結果ではない。
サンドボックス内のシェルからは、JaSpaceを読み込まない最小GUI起動でも
AppKit初期化中の `_RegisterApplication` でabortした。
Computer Useによる画面取得・キーボード操作は成功しており、
シェル経由の起動制限とGUIテストの成否は区別する。

## 研究用の一時試験

通常のテストとは別に実行した試作・比較であり、上記の件数には含めない。
反例の再現を期待する検査もあるため、テストの成功と不具合の不存在は区別する。
一時テストや関連アセットは保存せず、次の文書に条件・結果・限界を残した。

| 調査 | 内容 |
| --- | --- |
| [timer](../docs/timer.md) | 導入前後と廃止後の更新経路、旧Emacsのソース、ドラッグ操作のメモに対応するハンドラとコマンドループの比較。 |
| [mmm-mode](../docs/mmm-mode.md) | 上流のテストと専用連携の挙動、削除の判断。 |
| [whitespace-mode](../docs/whitespace-mode.md) | table復元・幅API・タブのパディングの干渉、単独使用時の論理幅・ピクセル幅、既定のU+0020ドット表示による折り返しの変化。 |
| [U+3000の表示](../docs/ideographic-space-display.md) | カテゴリーによる折り返し、列計算、`fill-region`、同設定のwhitespace-modeとの比較。 |
| [非置換表示の実現性](../docs/passive-display-feasibility.md) | face・静的合成・自動合成など7方式の比較、タブ・改行・カテゴリー・合成キャッシュの反例と実装規模。 |
| [追加文字](../docs/international-spaces.md) | 候補6文字の用途、標準設定との関係、双方向表示・字形形成・状態管理・折り返しの試作。 |

## 過去の検証

| 時点・対象 | 結果 |
| --- | --- |
| 2026-10-14、原版1.1 | `make-local-hook` が廃止済みのため有効化に失敗。その呼出しだけをテスト内で無処理にすると15件が成功した。観察用の置換であり、製品の互換処理には採用していない。テストは `da1ba12` に残る。 |
| 2026-10-14、保守版1.2.1 | ERT 43件がソース・バイトコードの両方で成功。うち5件はdisplay tableの複製時の後始末に対する回帰テスト。 |
| 2026-10-16、timer廃止の再検証 | コマンドループ、別バッファからの変更、複数の停止条件に対する4件を追加し、計47件が成功。 |
| 2026-10-16、U+0020の追加 | 14件を追加し、現行の計61件となった。 |
