# whitespace-modeとの併用と幅の調査

2026-10-16、jaspace.el 1.2.1（`c0c745d`）とEmacs 31.1添付の
`whitespace-mode` を調べた。実行環境はGNU Emacs 31.1 (Windows)である。
表示対象を分けても支障の出る実装があり、完全な併用は確認できなかった。
以下の測定値は1.2.1の記録であり、併用の干渉問題は未修正である。
開発版1.3.0ではU+0020をJaSpace単独で明示できるようにした。
現在の [拡張方針](future-directions.md) は併用を前提とせず、U+3000の現行方式は
既知の制約を含めて許容する。同設定のwhitespaceにも列計算・折り返しの制約があることは
[追試](ideographic-space-display.md#whitespace-modeとの同条件比較) で確認した。

## 判定基準と検証方法

当初は、表示前後で幅API・列位置・本文・状態を維持することを期待して検査した。
この期待に対する失敗と、現在の方針で許容する制約は区別する。

今回測定したのは `char-width`、`string-width`、`current-column`、display table、
タブoverlay、face、本文、変更状態、undoである。`current-column` は表示上の
表現を使った列計算であり、GUIの実ピクセル位置の測定ではない。
Font Lockとwhitespaceの実際の切替経路を通すため、`noninteractive` を一時的に
nilにし、空白で始まらない名前のバッファを使った。初期化ファイルは読み込んでいない。
`whitespace-action` はnilとし、自動整形による意図的な本文変更は対象にしなかった。

期待する挙動をassertする一時ERT 10件のうち、4件が成功、6件が失敗した。
失敗6件は下記の4種類に整理できる。通常検証の成功だけでは併用を保証できない。

## whitespace自身の表示幅の扱い

whitespaceの置換表示も、元の幅を維持する保証を持つものとしては扱えない。
[既定のtab-markのソース](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/lisp/whitespace.el#L837)
には、残り1桁の位置にあるタブが、マーカーの後ろのタブによって次のタブ位置まで
広がるという警告がある。マッピングの選択も表示可能かどうかを調べる処理であり、
元と同じ幅かどうかの検査ではない。

JaSpaceを読み込まず、`tab-width` を4、`whitespace-style` を `'(tab-mark)` とし、
既定のマッピングで `"abc\tZ\n"` を確認した。`Z` の位置での `current-column` は、
有効化前4、有効化後8、無効化後4だった。列のキャッシュは再計算して測定した。

以下のJaSpaceの置換消失や古い幅設定の残存は、この単独の幅変化とは別の問題である。

### フォントによるピクセル幅の違い

同日、GUIでwhitespace単独の空白マーカーも確認した。本文は
`"a b c d e f g h i j\n"`、`whitespace-style` は `'(space-mark)` とし、
既定のU+0020マーカーを使った。`face-remap-add-relative` でdefault faceの
familyを切り替え、`window-text-pixel-size` で行の幅を測った。

| フォント | 無効時 | 有効時 |
| --- | ---: | ---: |
| Courier New | 152px | 152px |
| Arial | 99px | 99px |
| Times New Roman | 85px | 94px |
| Segoe UI | 97px | 88px |
| Meiryo | 102px | 111px |

この条件ではどのフォントでも空白の `char-width` は1のままだった。
`'(face spaces)` に限定した場合は、5種類とも行のピクセル幅は変わらなかった。
同じ1桁でも、元の空白とマーカーのフォント上の幅は一致するとは限らない。
faceにフォントやサイズ等を指定した別条件までは検証していない。

タブの上記の例もGUIで40pxから72pxへの変化を確認した。これはフォント差とは
別に、置換によってタブ位置まで変わる例である。

## 1. whitespaceの無効化でJaSpaceの置換表示が消える

全角空白はJaSpace、ASCII空白はwhitespaceと、表示対象を分けても発生する。

```elisp
(setq-local whitespace-style '(space-mark)
            whitespace-display-mappings '((space-mark ?\s [?.])))
(whitespace-mode 1)
(jaspace-mode-on)
(whitespace-mode -1)
```

この後も `jaspace-mode` はtだが、`buffer-display-table` の全角空白の置換が消える。
コマンド後の更新でも復旧しない。faceは別管理なので、全角空白の強調が残る
場合でも置換表示が維持されたことにはならない。

[whitespace.el](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/lisp/whitespace.el)
の `whitespace-display-char-on` は有効化前のtableを保存し、
`whitespace-display-char-off` はそれをバッファへ戻す。
JaSpaceを後から有効にしても、whitespaceの保存先には反映されないためである。
[jaspace.el](../jaspace.el) の `jaspace-update` は有効状態とタブ幅を確認するが、
置換tableが外部処理で差し替わったことを確認しない。

JaSpaceを先に有効にすると単純な切替では回避できるが、whitespaceが有効な間に
JaSpaceをread-only方針で一時停止・復帰させると、その後のwhitespace無効化で
同じ問題を再現した。単なる有効化順序の指定では十分でない。

## 2. 幅APIがwhitespaceの有効化順と古い状態に依存する

`jaspace--width-advice` は、幅を計算する間、バッファのdisplay table全体を
`jaspace-original-display-table` に置き換える。JaSpaceが担当する全角空白・改行
以外のマッピングも、この保存済みtableで評価することになる。

ASCII空白を `[?X ?X]` へ置換するwhitespace設定で確認した。
全角空白のJaSpaceマーカーには、2桁幅の `"[]"` を使用した。

| 操作・状態 | ASCII空白の `char-width` | `string-width` の `"a b"` |
| --- | ---: | ---: |
| 両方とも無効 | 1 | 3 |
| whitespace、JaSpaceの順で有効化 | 2 | 4 |
| JaSpace、whitespaceの順で有効化 | 1 | 3 |
| whitespaceを先に有効化した組で、whitespaceだけ無効化 | 2 | 4 |
| 両方とも無効化 | 1 | 3 |

同じ表示設定でもAPIの結果が順序で変わる。whitespace無効化後も、JaSpaceが
有効な間は、保存済みtableにあるwhitespaceの古いマッピングを参照し続ける。
どちらの値を返すべきかという設定方針以前に、順序への依存と無効化後の残存がある。

両モードに全角空白の置換を設定した場合にも注意が必要である。
whitespaceの1桁の `"W"` を先に設定し、JaSpaceの2桁の `"[]"` で上書きすると、
表示tableは `"[]"` でも `char-width` は保存済みの `"W"` に由来する1を返した。
後勝ちの表示設定だけでは、幅APIとの整合まで保証されない。

## 3. タブのパディングもwhitespaceの置換対象になる

`jaspace--match-tab` はマーカー文字とASCII空白を連結した文字列を、タブの
overlayの `display` に設定する。この生成した空白にもdisplay tableが適用される。

`tab-width` を4、JaSpaceのタブマーカーを `?^`、whitespaceのASCII空白の
置換を `[?X ?X]` とし、本文 `"a\tb\n"` を再着色した。
本文にはASCII空白がないが、生成したパディングがwhitespaceの影響を受ける。

| 条件 | タブoverlayの文字列 | `b` の位置での `current-column` |
| --- | --- | ---: |
| 置換なし | なし | 4 |
| JaSpaceのタブマーカーのみ | `"^  "` | 4 |
| 上記のwhitespaceの空白置換も有効 | `"^  "` | 6 |

マーカーの後ろの空白2個がそれぞれ2桁で表示されるため、後続文字がずれる。
1桁の `"."` への置換では列4を維持したが、パディングの空白にもその置換が
適用されるため、本文にない空白の印が見える可能性は残る。
「表示する対象が別なら干渉しない」とは扱えない。

## 4. 全角空白の表示幅を固定する仕組みはない

これはwhitespaceとの併用以前にある制約である。
JaSpaceは任意の置換文字列をdisplay tableへ設定するが、元の幅への調整をしない。
単独で全角空白の直後の列を調べると、次の値になった。

| 置換文字列 | 全角空白の `char-width` / `string-width` | 直後の `current-column` |
| --- | ---: | ---: |
| `"[]"` | 2 / 2 | 2 |
| `"_"` | 2 / 2 | 1 |
| `"LONG"` | 2 / 2 | 4 |

既定の `WHITE SQUARE` の幅を1に設定した条件でも列は1になった。
ただし、後の [ソース分析とGUI追試](ideographic-space-display.md) では、
列計算が置換ベクトルの要素数を使うため、マーカーの幅を2にしても解消しないと分かった。
カテゴリーによる折り返しや編集結果への影響も同文書にまとめた。

## 今回成功した範囲と暫定的な併用

成功した4件の範囲は次のとおりである。

- whitespaceをfaceによる強調だけに限定した組み合わせ。有効化・無効化の
  順序4通り、各3回のread-onlyによる一時停止・復帰で、JaSpaceのマッピングと
  タブの列を維持し、最後にoverlayを除去できた。
- ASCII空白を1桁の `"."` に置換した場合の、タブ直後の列の維持。
- タブが残り1桁の位置にある場合、JaSpaceの `"^"` のoverlayがwhitespaceの
  tab-markより優先され、タブ直後の列を維持すること。
- read-onlyでの本文・変更状態・undoの保持と、他バッファの幅APIの維持。
  faceだけの場合と1桁のspace-markを加えた場合で、有効化順序も変えた。

現時点で暫定的に勧められるのは、JaSpaceで全角空白を置換し、whitespace側は
faceによる強調を担当する構成である。例えば次の表示設定とする。

```elisp
(setq jaspace-alternate-eol-string nil
      jaspace-highlight-tabs nil
      whitespace-style '(face tabs spaces trailing))
```

ここではwhitespaceのspace-mark・tab-mark・newline-markを使わず、display table
の保存・復元を競合させない。全角空白マーカー自体の列計算・折り返しの制約は残る。
この併用例でGUIのピクセル配置まで検証したわけではない。

## 標準側の注意書きと過去の報告

2026-10-16、現行設計を維持する判断に際し、標準側での案内も確認した。

[whitespace.elのマッピング定義](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/lisp/whitespace.el#L839)
には、タブの残り幅がちょうど1桁だと、まずマーカーを表示し、その後のタブが
次のタブ位置まで進んでしまうという警告コメントがある。問題になる場合は
該当マッピングをコメントアウトするよう案内している。
ただし、この警告は設定値を定義するソース内にあり、
`whitespace-display-mappings` 自体のdocstringには含まれない。

また、2011年の [bug#10119](https://lists.gnu.org/archive/html/bug-gnu-emacs/2011-11/msg00840.html)
には、改行マーカーがwindow右端に来ると `C-e` が次の行末へ移動するという報告がある。
可視化が移動に影響する問題の過去の報告であり、現在も同じ不具合が残ることや、
今回のU+3000の列計算と同一原因であることを示すものではない。

確認した [利用者向けマニュアル](https://www.gnu.org/software/emacs/manual/html_node/emacs/Useless-Whitespace.html)、
Emacs 31.1同梱のパッケージ冒頭説明、`whitespace-display-mappings` のdocstring、
NEWS類の関連語検索では、置換により `fill-region` の結果が変わり得るという
直接の注意書きは見当たらなかった。公開履歴・報告を網羅した調査ではなく、
過去に一切注意喚起がなかったとは断定しない。

今回のU+3000の反例は、whitespace側にも同じ置換を追加した条件である。
既定のマッピングにはU+3000がないため、既定設定でも同じ編集結果の変化が起こると
一般化しない。一方、既定のU+0020マーカーにも以下の配置上の影響がある。

## 既定のU+0020のドット表示も配置を変え得る

2026-10-16、GNU Emacs 31.1 (Windows)、初期化ファイルなしで追試した。
既定の `whitespace-style` は `space-mark` を含み、
既定の `whitespace-display-mappings` はU+0020をU+00B7 MIDDLE DOT `·`、
それが表示できない場合はU+002E FULL STOP `.` に置き換える。
U+3000の置換が既定にないことは、既定マーカーの影響がないことを意味しない。

影響を分離するため、マッピングは既定のまま `whitespace-style` だけを
`(space-mark)` とした場合と、styleも全て既定の場合を比較した。
JaSpaceは読み込まず、文字列overlayも使用していない。

### 論理列と整形

U+0020も選択されたマーカーも `char-width` が1の環境で、
`"a b  c\tZ\n"` の全位置の列は両設定とも元と一致した。
`char-width` のU+0020は1、`string-width` の `"a b"` は3のままだった。

`"abc def ghij klm nopq rst uvw xyz "`・`"漢字 かな。abc "`・
`"אב 12 345 גד "` を各6回繰り返して改行を付け、`text-mode`、`fill-column` 30で
`fill-region` を比較した。2設定×3本文の6比較全てで結果は一致した。
通常のU+0020→1文字のマーカーは、U+3000→1文字で論理列が2から1へ変わる例とは
条件が異なる。この試験では同じ整形結果の変化は再現していない。

### ピクセル幅と画面の折り返し

faceの `:height 120` で、短い行 `"a b c d e f\n"` を比較した。
次は `space-mark` だけを有効にした結果で、改行マーカーの追加幅を含まない。

| フォント | 空白／ドットの字形の幅 | 行のピクセル幅（無効→有効） |
| --- | --- | --- |
| Consolas | 9／9px | 99→99px |
| Arial | 4／5px | 69→74px |
| Times New Roman | 4／5px | 64→69px |
| ＭＳ ゴシック | 8／8px | 88→88px |

同じ4フォント、上記3本文、通常の継続・word wrap・category wrapの3設定、
本文幅3通り（42桁のframeに右margin 6・4・2桁）を組み合わせた。
`nobreak-char-display` はnil、マッピングとfaceの装飾は標準値のままとした。
各style 108条件、計216条件で、全位置の論理列は維持されたが、
画面行先頭は各styleで34条件変わった。内訳はArialが15/27、
Times New Romanが19/27、Consolas・ＭＳ ゴシックは各0/27だった。

具体例はArial、本文領域288px、通常の継続である。

```elisp
(concat (apply #'concat (make-list 6 "abc def ghij klm nopq rst uvw xyz ")) "\n")
```

`space-mark` だけでも画面行先頭が `(1 41 83 122 163 202 206)` から
`(1 40 79 119 157 197 206)` へ変わった。末尾改行後の位置を含む。
全体の288×108pxは同じだったため、全体の寸法一致だけでは不変と判断できない。

論理幅が1桁同士でも、置換後の実際の字形の幅まで同じにはならない。
既定のドット表示でも画面行の境界が変わり得ることを確認した結果であり、
任意のフォント・文字幅設定・編集や移動コマンド全体を検証したものではない。
