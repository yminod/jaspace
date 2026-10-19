# U+3000の置換表示と折り返し・論理列

2026-10-16、開発版1.3.0（`ba9d9a6`）、GNU Emacs 31.1 (Windows)で調べた。
[他言語の空白候補の試作](international-spaces.md) で見つかったdisplay tableの制約が、
既存のU+3000にも当てはまるかを確認した。製品本体は変更していない。

## 結論

U+3000でも既定の `□` への置換により、カテゴリーに基づく画面の折り返しが変わる。
追加候補に固有の問題ではなく、whitespace-modeでも同じ設定で再現した。
現行方式は制約を含めて許容する。[方針](future-directions.md#表示の受動性と許容する制約)
に従い、次の三つを区別して案内する。

- **カテゴリーによる折り返し**：幅が同じでも、元とマーカーのカテゴリーが違うと
  改行候補が変わる。既定の `□` では `word-wrap` と `word-wrap-by-category` が
  ともに有効な条件で再現した。
- **論理列**：display tableのベクトルの要素数を使う列計算では、全角字形一つの
  マーカーも1桁になる。マーカーの `char-width` を2へ変えても解消しない。
- **ピクセル配置**：フォントによる差は上の二つとは別に起こり得る。
  今回は幅・高さをそろえた条件でも反例を確認した。

## 検証条件

字形の寸法、画面行先頭、カテゴリー、`fill-region`、幅APIと論理列を比較した。

GUIは `-Q`、LTR、`nobreak-char-display` nilとし、他のマーカーの影響を
避けるため、タブ・改行・U+0020の明示は無効にした。
各条件で解除後の画面行先頭と論理列が元へ戻ることも確認した。

ConsolasとＭＳ ゴシック、faceの `:height 120` で字形の寸法を比較した。
ＭＳ ゴシックでは `"口a\u3000b口\n"` が、U+3000を `□`・`++`・`[]`・`口` に
置換しても64×16pxを維持した。このフォントで次の比較を行った。

- マーカー6種類：nil（faceのみ）、元のU+3000、既定の `□`、`++`、`[]`、`口`。
- 表示設定6種類：行の切り詰め、通常の継続、通常のword wrap、カテゴリーによる
  word wrap、禁則処理を読み込んだカテゴリーによるword wrap、
  `word-wrap-whitespace-mode` の既定設定。
- 本文2種類：`"ab\u3000def gh 口 "` と `"漢字\u3000かな。abc "` をそれぞれ6回繰り返し、
  改行を加えた。windowの本文領域は320〜240pxの11通り。

この792条件に、U+25A1の `char-width-table` の値を2にした `□` の132条件を加え、
計924条件を比較した。画面行先頭はGUIの `vertical-motion` で取得した。
106条件で行先頭が変わり、これらでも全体と先頭部分のピクセル寸法は一致した。

## カテゴリーによる折り返し

Emacs 31.1の初期状態で、U+3000はカテゴリー `|` を持ち、`□` は持たない。
`口` は `|` を持つ。これはUnicodeのWhite_Spaceなどの属性ではなく、
Emacsのcategory tableにおける分類である。
[characters.el](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/lisp/international/characters.el#L142)
ではU+3000を含む範囲に `|` を付けている。

標準の `word-wrap-by-category` は、このカテゴリーを折り返しに使用する。
[標準マニュアル](https://www.gnu.org/software/emacs/manual/html_node/emacs/Visual-Line-Mode.html)
にあるとおり、Customizeからの設定では `kinsoku.el` も読み込まれる。

各欄は22条件（本文2種類×window幅11通り）中、画面行先頭が変わった条件数である。
U+25A1の幅設定を変更しない通常の比較を示す。

| マーカー | 切り詰め | 通常の継続 | 通常のword wrap | category | category＋kinsoku | whitespace拡張 |
| --- | --- | --- | --- | --- | --- | --- |
| nil（faceのみ） | 0 | 0 | 0 | 0 | 0 | 0 |
| 元のU+3000 | 0 | 0 | 0 | 0 | 0 | 0 |
| `□` | 0 | 0 | 0 | 7 | 9 | 9 |
| `++`・`[]` | 各0 | 各2 | 各0 | 各8 | 各9 | 各9 |
| `口` | 0 | 0 | 0 | 0 | 0 | 0 |

`□` の文字幅設定を2へ変えても、この行の結果は同じだった。
複数字形の `++`・`[]` では通常の継続にも差があり、カテゴリーの不一致だけで
全てのマーカーの影響範囲を説明することはできない。

具体例はＭＳ ゴシック、本文領域304px、通常の `word-wrap-by-category` である。

```elisp
(concat (apply #'concat (make-list 6 "ab\u3000def gh 口 ")) "\n")
```

元の画面行先頭は `(1 32 64 74)`、`□` への置換後は `(1 32 61 74)` となった。
末尾改行後の位置を含む。全体は304×48pxのままだった。
buffer専用のcategory tableで、診断のため `□` に `|` を付けると元の行先頭へ戻った。
`++` でもこの例の行先頭が同じように変わり、そちらでは論理列も元と一致していた。
従って、カテゴリーによる折り返しの変化を、後述の論理列の問題だけでは説明できない。

原因は、[xdisp.cのカテゴリー判定](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/src/xdisp.c#L557)
が描画中の文字を優先することと整合する。U+3000は元から `|` を持つため、
EN SPACEなどと違い、`word-wrap-whitespace-mode` を別に有効にしなくても起こる。
カテゴリーをマーカーへ付ける方法は、本文に実在する同じ記号の働きも変えるため、
修正には採用しない。

## 論理列はマーカーの文字幅だけでは決まらない

[indent.c](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/src/indent.c#L281)
の列計算には、display tableのベクトルを `ASIZE`、すなわち要素数で数える処理がある。
次はJaSpaceを読み込まないEmacsでも `(2 3)` を返した。元の末尾列は4である。

```elisp
(require 'disp-table)
(with-temp-buffer
  (insert "a\u3000b")
  (setq buffer-display-table (make-display-table))
  (aset buffer-display-table #x3000 [#x3000])
  (list (char-width #x3000) (current-column)))
```

元と同じ字形へ差し替えても、幅APIが示す2桁と、列計算がこの文字に割り当てる1桁が食い違う。
JaSpaceの幅APIのadviceだけが作り出した差ではない。

製品でも `"a\u3000b"` の末尾列を調べ、次の結果になった。

| 設定 | 置換ベクトルの要素数 | 末尾の `current-column` |
| --- | --- | --- |
| nil（faceのみ） | table登録なし | 4 |
| 元のU+3000・`□`・`口` | 1 | 3 |
| `++`・`[]` | 2 | 4 |

U+25A1の幅を2へ変えても、1要素のベクトルの列計算は1のままだった。
元とマーカーの `char-width` が等しいことだけでは、論理列を維持できない。

## 編集コマンドへの影響

同じ2種類の本文、`text-mode`、`fill-column` 30、禁則処理のカテゴリーを使い、
JaSpaceの有効・無効で `fill-region` の結果を比較した。
マーカー6種類×本文2種類×U+25A1の幅設定2種類の24比較中、12比較で結果が変わった。

- 元のU+3000・`□`・`口` の各1要素の置換では、いずれも改行を挿入する位置が変わった。
- nil（faceのみ）、`++`・`[]` では、この比較の結果は一致した。

有効化・解除だけで本文・変更状態・undoが変わる問題ではなく、その後の編集結果への
影響である。他の編集・移動コマンド全体は未検証である。

## whitespace-modeとの同条件比較

whitespace-modeの既定のマッピングにU+3000は含まれず、既定設定のままでは
`"a\u3000b"` の論理列も変わらなかった。この点と、U+3000の明示を設定した場合を区別した。
比較ではwhitespace-modeを単独で使用し、JaSpaceとの同時有効化は行っていない。
折り返しを設定する `word-wrap-whitespace-mode` は、表示モードの `whitespace-mode` とは
別の機能である。

```elisp
(setq whitespace-style '(space-mark)
      whitespace-display-mappings '((space-mark #x3000 [#x25a1])))
```

ＭＳ ゴシック、`:height 120`、前記と同じ本文2種類・window幅11通りで、
nil（faceのみ）・元のU+3000・`□`・`++` を、通常のword wrap・category・
category＋kinsoku・`word-wrap-whitespace-mode` の4設定で比較した。
faceのみのwhitespace設定では、`whitespace-style` を `(face spaces)`、
`whitespace-space-regexp` を `"\\(\u3000+\\)"` とした。

- 計352比較で、両モードの画面行先頭は全て一致した。
  51比較で両方とも元の行先頭と異なった。内訳は上表の `□` と `++` の
  category・category＋kinsoku・whitespace拡張の各欄と同じだった。
- 1要素の置換では、whitespace-modeでも末尾列が4から3へ変わった。
  `□` の幅を2にしても同じだった。既定の `□` の幅が1の場合、
  `char-width` はwhitespaceで1、JaSpaceで2を返す違いがあるが、末尾列は両方3だった。
- `fill-region` はマーカー6種類×本文2種類の12比較で、両モードの結果が全て一致した。
  うち6比較では両方とも無効時の結果と異なり、1要素の置換で再現した。
- 読み取り専用での表示・解除は、本文・変更状態・undoを維持した。

書字方向については別に、whitespaceの既定のNBSPマーカーと、設定を追加した
U+202F・U+3000・U+2800を、段落方向3通りと数字を含むヘブライ語・アラビア語の
3例で比較した。計36条件で、画面からの本文位置の逆引きによる文字順を維持した。
任意の双方向制御文字やマーカーを網羅する保証ではない。

[whitespace.elのマッピング登録](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/lisp/whitespace.el#L2533)
もdisplay tableへベクトルを直接登録する。調べた実装には、元の文字の幅や
カテゴリーを維持する補正は見当たらず、今回の比較でもそれらの差を再現した。

## macOSでの追加確認

2026-10-20、macOS 27.0.1（arm64）、GNU Emacs 31.1のGUIでも、
現行版1.3.0の全角空白の置換でピクセル配置が変わる例を確認した。
Menlo 18で `a　b　c` の全角空白を `[]` に置換すると、Emacsの座標で
`b` の横位置は128→132px、`c` は157→165pxとなり、後続行は4px上へ移動した。
論理列12・15、本文、バッファの未変更状態は維持した。

これはピクセル配置の追加観察であり、上記のカテゴリー・`fill-region`・
whitespace-modeとの比較条件全体をmacOSで追試した結果ではない。
別途成功した自動GUIテスト4件と実行条件は
[検証記録](../test/README.md#macosposix) を参照。

## 制約の扱い

faceだけの強調では、今回の画面行先頭と `fill-region` の差を再現しなかった。
ただし、faceのフォント属性による配置の変化まで保証するものではない。
読み込み後に代替文字列をnilへ変える場合のface設定の注意は
[READMEの制約](../README.md#既知の制約と要改善事項) も参照。

既定値は維持し、追加文字にも同じ判断基準を適用する。
他OS・Emacs版、任意のフォント・本文・window設定まで結果を一般化しない。
