# 他言語・組版用の空白文字の追加候補

2026-10-16、開発版1.3.0（`ba9d9a6`）を基準に調べた。
追加の目的は、意図して挿入された文字の存在・種類・個数の確認である。
利用者数の証明は条件にせず、用途と [拡張方針](future-directions.md) に基づいて評価した。
以下は未実装の候補と試作の記録であり、採用範囲・公開設定は未確定である。

## 候補と設定案

| 文字 | 確認用途 | 優先度 |
| --- | --- | --- |
| U+202F NARROW NO-BREAK SPACE | フランス語の句読点や数字の桁区切りで、SPACE・NBSPと区別する。 | 優先する。 |
| U+2800 BRAILLE PATTERN BLANK | Unicode点字データの空白セルの位置・個数を確認する。 | 優先する。 |
| U+2002 EN SPACE／U+2003 EM SPACE | 空白の種類と、単一文字か複数文字かを識別する。 | 組版用の候補とする。 |
| U+2007 FIGURE SPACE | 数字を並べたデータの空白セルを確認する。 | 組版用の候補とする。 |
| U+2009 THIN SPACE | 狭い空白の存在や、SPACE・NNBSPとの違いを確認する。 | 組版用の候補とする。 |

全て既定では無効にし、必要な文字だけを選ぶ。設定は文字と代替文字列の対応表に
まとめる案を第一候補とする。対象はこの6文字に限定し、既存の公開設定は維持する。
対応表の公開名、代替文字列の制約、推奨マーカーは未決定である。

方式はU+3000と同じdisplay tableを候補とする。試験で双方向表示の順序を維持できた。
折り返し・列計算・生成された表示文字列への作用には制約があるが、
[U+3000の現行方式を許容する判断](future-directions.md#表示の受動性と許容する制約)
を追加候補にも適用し、文字特性の完全な再現を前提にしない。

## 用途の根拠

### フランス語と組版用空白

[Unicode 17.0の空白文字の説明](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-6/)
は、U+202Fをフランス語の句読点周辺の狭い改行禁止スペースとして説明する。
[CLDR 34の変更記録](https://cldr.unicode.org/downloads/cldr-34) にも、フランス語の
数字の桁区切りなどをU+202Fへ変更したことが記録されている。
`"12\u202F345"` や `"«\u202Fbonjour\u202F»"` で空白の種類を確認する用途がある。

UnicodeはEN SPACE・EM SPACEを組版用の幅を持つ空白、FIGURE SPACEを数字と同じ幅の空白、
THIN SPACEを狭い空白として説明する。言語専用というより組版上の用途である。
[InDesign CS6の公式マニュアル](https://helpx.adobe.com/pdf/cs6/indesign_reference.pdf)
にも各種空白の挿入と記号表示があり、編集時に空白を識別する先例がある。
ただし、製品が説明する物理的な幅を、そのままEmacsの仕様とは扱わない。

### 点字の空白セル

[Unicodeの点字パターン表](https://www.unicode.org/charts/PDF/U2800.pdf) によると、
U+2800は多くのフォントで幅のある空白として描かれるが、空白文字としては動作しない。
Unicode上の分類は空白区切り文字ではなく記号（So）である。

[PEF 1.0公開草案](https://braillespecs.github.io/pef/pef-specification.html)
は各行をUnicode点字パターンの文字列で表し、U+2800を含む例も示している。
[Liblouisのunicode.dis](https://github.com/liblouis/liblouis/blob/master/tables/unicode.dis)
にも、点のないパターンをU+2800へ対応付ける定義がある。
[北米点字委員会の書式規定](https://www.brailleauthority.org/formats/2016manual-web/section01.html)
には一定数の空白セルを置く例があり、その位置・個数を画面上で確認する価値がある。

ただし、空白セルが必ずU+2800で符号化されるわけではない。
[unicode-without-blank.dis](https://github.com/liblouis/liblouis/blob/master/tables/unicode-without-blank.dis)
のようにU+0020を使う構成は既存の半角空白表示で扱える。
今回の評価は視覚的な編集補助であり、点字の書式判定や点字機器での検証ではない。

### アラビア語・ヘブライ語など

[Unicodeの中東の文字体系の説明](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-9/)
にある通常の単語間空白は、既存のU+0020表示で扱える。
今回の調査では、これらの言語専用の、U+3000に相当する幅付き空白を
追加する根拠は得られなかった。

一方、[結合・書字方向の制御文字](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-23/)
は見えなくても必要な場合があり、今回の対象にしない。

| 文字 | 必要となる役割 |
| --- | --- |
| U+200C ZWNJ／U+200D ZWJ | 接続字形や合字の制御。ペルシア語のZWNJも幅付き空白とは区別する。 |
| U+061C ALM／U+200E LRM／U+200F RLMなど | 周囲の文字の双方向表示の制御。 |
| U+034F CGJ | 結合文字の並べ替えなどの制御。ヘブライ語の記号にも用途がある。 |

U+202Fにはモンゴル語で接尾辞を区切る旧来の用途もあるが、
[Unicode 17.0の説明](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-13/)
ではUnicode 16.0以降その役割はU+180Eへ移っている。
古いモンゴル語データでの字形形成は未検証であり、対応済みとは扱わない。

## 標準機能との分担

[Emacs 28の変更記録](https://www.gnu.org/software/emacs/news/NEWS.28.html)
と [表示仕様](https://www.gnu.org/software/emacs/manual/html_node/emacs/Text-Display.html)
によると、`nobreak-char-display` はUnicodeの水平空白文字も強調する。
候補の組版用空白5文字は同じ `nobreak-space` faceで表示できるが、
種類ごとのマーカーはなく、連続した文字の境界も分かりにくい。
U+2800は水平空白文字ではないため、この強調の対象にならない。

標準の強調で十分なら追加機能は不要であり、NBSPを標準に任せる方針も維持する。
マーカーが有効な間は、対象文字に対する標準の強調や `escape` のバックスラッシュ表示を
覆う。標準変数は変更せず、解除時にはその時点の標準設定へ戻す。

## 試験条件

GNU Emacs 31.1 (Windows)、初期化ファイルなしで、一時的な試作を比較した。
製品本体は変更していない。統合試作は既存のtable登録・所有権記録・復元・幅APIのadviceと
Font Lockの状態管理を利用し、候補の設定は検査中だけ有効にした。

検証用の対応はU+202F→`:`、U+2002→`+`、U+2003→`=`、U+2007→`#`、
U+2009→`.`、U+2800→`o`。製品の推奨マーカーを決めたものではない。
以下には不変性を期待して失敗した試験と、反例の再現を期待した試験を含む。

## 双方向表示と字形形成

### overlayとdisplay tableの比較

[Emacs Lispマニュアル](https://www.gnu.org/software/emacs/manual/html_node/elisp/Bidirectional-Display.html)
によると、文字列のdisplay propertyやoverlayで覆った本文は元の方向特性が無視され、
U+FFFCに相当する単位として扱われる。幅が同じでも、周囲の表示順が変わり得る。

追加6文字と比較用のU+0020・U+00A0・U+3000について、次の6文字列の `%c` を置き換え、
段落方向を自動・LTR・RTLの3通りにした。`nobreak-char-display` はnil、
`truncate-lines` はt、フォントはCourier New 13とした。

```elisp
"אב 12%c345 גד\n"
"اب 12%c345 جد\n"
"اب ١٢%c٣٤٥ جد\n"
"abc אבג%c\n"
"אב%cגד ab\n"
"سَلَام%cلا (abc 12)\n"
```

各文字18条件で、overlayの文字列 `"."`、display tableの `[?.]`、
faceのみの `shadow` を比較した。

| 文字 | bidi-class | overlayで表示順が変わった条件 | display table・faceのみ |
| --- | --- | --- | --- |
| U+202F・U+00A0 | CS | 各9/18 | 変化なし |
| U+2800 | L | 11/18 | 変化なし |
| U+2002・U+2003・U+2007・U+2009 | WS | 各0/18 | 変化なし |
| U+0020・U+3000 | WS | 各0/18 | 変化なし |

例えば `"אב 12\u202F345 גד"` の数字部分は元は画面上でも `12`、空白、`345` の順だが、
overlayでは `345`、`.`、`12` の順になった。論理列は変わらなかった。
display tableでは表示順と解決済みbidiレベルを維持した。
統合試作でも6候補×上記18条件の計108条件で順序・bidiレベル・論理列が一致した。
このため、U+0020のoverlay方式を追加文字全体へ一般化しない。

表示順は `posn-at-x-y` による画面からの逆引きで確認し、代表例では
`bidi-resolved-levels` とも照合した。`posn-at-point` の座標のソートだけでは
誤った差が出たため、判定には使わなかった。

### 既存の半角空白と接続・結合記号

製品のU+0020表示は、faceのみと `?.` で `"abc אבג \n"` の順序を維持した。
U+202Fの反例を既存の半角空白機能の不具合とは扱わない。

字形形成は、製品の半角空白表示と、各候補へ区切りを替えた統合試作の18条件で比較した。

- アラビア語の母音記号とLAM–ALEF：`"سَلَام لا (abc 12)"`。
- ヘブライ語の結合記号：`"שָׁלוֹם עוֹלָם (abc 12)"`。
- ペルシア語のZWNJと拡張アラビア・インド数字：`"می\u200Cروم خانه (abc ۱۲)"`。

自動compositionが発生し、`find-composition` の範囲、字形コード・メトリクスは
一致した。キャッシュ識別番号は除外した。

## 状態管理と標準設定の切替

| 検査 | 結果 |
| --- | --- |
| 英語・日本語×タブ幅1・2・4・8×U+0020の無効・face・マーカー×タブの無効・face・マーカー | U+3000は `[]`、改行は `$\n` とした計72条件で、全位置の論理列と幅APIを維持。読み取り専用でも本文・変更状態・undoを維持した。 |
| 既存・共有table、他機能による追加・変更 | 元のtableを破壊せず、自分の登録だけを解除した。 |
| 通常の複製・indirect buffer、narrowing、別バッファの終了 | 他方のマッピングを維持し、narrowing外も後始末できた。 |
| Font Lock・read-onlyによる停止と復帰、編集・再着色、major mode変更 | 候補のマッピングも設定に従って除去・復帰した。 |
| U+202Fの元の論理幅を2へ変更 | 幅APIは2でも、1桁マーカーでは後続文字の論理列が1桁ずれた。 |
| whitespaceを先に有効化し、試作を有効化してからwhitespaceを解除 | 候補のマッピングも消えた。[既知の併用問題](whitespace-mode.md) を引き継ぐ。 |

最初の単独比較では、6文字×overlay・tableの2方式×
`nobreak-char-ascii-display` nil・t×`nobreak-char-display` の初期値nil・t・`escape`×
表示中の切替5回（t→nil→`escape`→t→nil）の計360条件を調べた。
統合試作のtable方式でも180条件を比較し、解除後はその時点の標準設定による
未加工バッファと同じピクセル寸法へ戻った。標準変数や本文・変更状態・undoは変えなかった。
単独比較の初期tableはnilであり、既存tableの保全は統合試作で別に調べた。

`glyphless-display-mode` も先・後の両順序で切り替え、
モード状態やglyphless用tableを巻き戻さないことを確認した。
候補を無効にした統合試作では、既存の61件もソース実行で成功した。

## 幅が同じでも折り返しは変わる

Courier New・Consolas・Arial×6文字×LTR・RTL×`word-wrap` nil・tの72条件で、
画面行先頭が30条件（各フォント16/24、2/24、12/24）変わった。
この比較には元の字形とマーカーのピクセル寸法の差も含む。

ConsolasではU+2800を除く5文字について、短い行 `"a%cb\n"` の置換前後が
21×15pxで一致した。この条件で5文字×LTR・RTL×折り返し4設定×window幅11通りの
440条件を比較すると、32条件で画面行先頭が変わった。
全て `word-wrap-whitespace-mode` 使用時で、EN・EM・FIGURE・THIN SPACEが各8条件だった。
U+202Fの88条件と、通常の継続・通常のword wrap・categoryによるword wrapには差がなかった。

本文は `"ab%cdef gh "` または `"אב%cגד הו "` を6回繰り返して改行を加え、
本文領域は288〜208pxとした。LTR・256pxの具体例：

```elisp
(concat (apply #'concat (make-list 6 "ab\u2002def gh ")) "\n")
```

画面行先頭は元の `(1 34 62)` からU+2002→`[?+]` で `(1 31 62)` へ変わった。
末尾改行後の位置を含む。全体の256×30pxは変わらなかった。
元のU+2002への置換では差がなく、診断用にbuffer専用category tableで `+` に
カテゴリー `|` を与えても元へ戻った。

[xdisp.c](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/src/xdisp.c#L557)
のカテゴリー判定は描画中の文字を優先する。
[word-wrap-mode.el](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/lisp/textmodes/word-wrap-mode.el#L28)
はEN SPACEなどへ `|` を加えるが、NNBSPは既定では加えない。
元の非ASCII空白の改行候補が置換で失われると説明できる。
カテゴリーをマーカーへコピーすると、本文中の同じ記号の働きも変えるため採用しない。

同じ仕組みは既存のU+3000にも作用する。列計算・編集結果への影響と
whitespace-modeとの同条件比較は [全角空白の調査](ideographic-space-display.md) を参照。

## 生成された表示文字列への作用

本文の `A` を他機能のoverlayで `"a\u202Fb"` に表示し、その後に `B` がある条件でも、
試作のU+202F→`:` が作用した。display property自体は変えないが、行幅は38pxから32pxへ
変わり、解除すると戻った。通常のbuffer display tableは本文だけに作用する方式ではない。
追加候補もU+3000と同じ適用範囲を前提にする。
タブのパディングが変わらなかったのは、対象にU+0020がないためである。

## 残る検討・検証

公開設定とマーカーの選定では、元の論理幅と列計算の関係、標準表示との優先関係、
既存マッピングの扱いを整理する。試験で全候補が論理幅1だったことを、
任意の文字幅設定への保証にはしない。

確認範囲はWindows版Emacs 31.1と記載したフォント・本文・設定に限る。
他OS・Emacs版、実端末、任意のフォント・双方向制御文字・禁則処理全体は未検証である。
Emacs 28より前は標準の強調対象も異なるため、27.1での確認は別途必要になる。
