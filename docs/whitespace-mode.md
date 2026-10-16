# whitespace-modeとの併用と幅の調査

2026-10-16、jaspace.el 1.2.1（`c0c745d`）とEmacs 31.1添付の
`whitespace-mode` を調べた。実行環境はGNU Emacs 31.1 (Windows)である。
表示対象を分けても支障の出る実装があり、完全な併用は確認できなかった。
この文書は問題と検証範囲の記録であり、以下の問題は未修正である。
その後、開発版1.3.0にU+0020の明示機能を追加した。検証を踏まえて整理した
論理幅とピクセル幅の保証範囲は [拡張方針](future-directions.md) を参照。
以下の1.2.1の測定結果は、現在の機能の網羅的な保証を示すものではない。

## 判定基準と検証方法

保守版で目指す「幅を維持する」は、幅APIの値だけでなく、可視化の前後で
他の文字の表示位置や本文・変更状態・undoに影響せず、read-onlyでも安心して
確認できることとする。これは今回ユーザーと確認した要件であり、原著者が
同じ範囲を保証していたと断定するものではない。

今回測定したのは `char-width`、`string-width`、`current-column`、display table、
タブoverlay、face、本文、変更状態、undoである。`current-column` は表示上の
表現を使った列計算であり、GUIの実ピクセル位置の測定ではない。
Font Lockとwhitespaceの実際の切替経路を通すため、`noninteractive` を一時的に
nilにし、空白で始まらない名前のバッファを使った。初期化ファイルは読み込んでいない。
`whitespace-action` はnilとし、自動整形による意図的な本文変更は対象にしなかった。

期待する挙動をassertする一時ERT 10件のうち、4件が成功、6件が失敗した。
失敗6件は下記の4種類に整理できる。既存の通常検証47件が通ることと、
追加条件で問題を検出したことは区別する。一時的な調査コードは保存しない。

## whitespace自身の表示幅の扱い

whitespaceの置換表示も、元の幅を維持する保証を持つものとしては扱えない。
[既定のtab-markのソース](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/lisp/whitespace.el#L837)
には、残り1桁の位置にあるタブが、マーカーの後ろのタブによって次のタブ位置まで
広がるという警告がある。マッピングの選択も表示可能かどうかを調べる処理であり、
元と同じ幅かどうかの検査ではない。

jaspaceを読み込まず、`tab-width` を4、`whitespace-style` を `'(tab-mark)` とし、
既定のマッピングで `"abc\tZ\n"` を確認した。`Z` の位置での `current-column` は、
有効化前4、有効化後8、無効化後4だった。測定時は行頭で列を計算し直してから
対象位置へ移動し、display table変更前の列のキャッシュを再利用しないようにした。

したがって、whitespaceとの併用全体を幅不変と仮定せず、使用するstyleと
マッピングを限定して評価する必要がある。一方、以下のjaspaceの置換消失や
古い幅設定の残存は、このwhitespace単独の幅変化とは別の問題である。

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
別に、置換によってタブ位置まで変わる例である。一時的な比較コードは保存しない。

## 1. whitespaceの無効化でjaspaceの置換表示が消える

全角空白はjaspace、ASCII空白はwhitespaceと、表示対象を分けても発生する。

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
jaspaceを後から有効にしても、whitespaceの保存先には反映されないためである。
[jaspace.el](../jaspace.el) の `jaspace-update` は有効状態とタブ幅を確認するが、
置換tableが外部処理で差し替わったことを確認しない。

jaspaceを先に有効にすると単純な切替では回避できるが、whitespaceが有効な間に
jaspaceをread-only方針で一時停止・復帰させると、その後のwhitespace無効化で
同じ問題を再現した。単なる有効化順序の指定では十分でない。
対応する期待値のテスト2件が失敗した。

## 2. 幅APIがwhitespaceの有効化順と古い状態に依存する

`jaspace--width-advice` は、幅を計算する間、バッファのdisplay table全体を
`jaspace-original-display-table` に置き換える。jaspaceが担当する全角空白・改行
以外のマッピングも、この保存済みtableで評価することになる。

ASCII空白を `[?X ?X]` へ置換するwhitespace設定で確認した。
全角空白のjaspaceマーカーには、2桁幅の `"[]"` を使用した。

| 操作・状態 | ASCII空白の `char-width` | `string-width` の `"a b"` |
| --- | ---: | ---: |
| 両方とも無効 | 1 | 3 |
| whitespace、jaspaceの順で有効化 | 2 | 4 |
| jaspace、whitespaceの順で有効化 | 1 | 3 |
| whitespaceを先に有効化した組で、whitespaceだけ無効化 | 2 | 4 |
| 両方とも無効化 | 1 | 3 |

同じ表示設定でもAPIの結果が順序で変わる。whitespace無効化後も、jaspaceが
有効な間は、保存済みtableにあるwhitespaceの古いマッピングを参照し続ける。
どちらの値を返すべきかという設定方針以前に、順序への依存と無効化後の残存がある。
対応するテスト2件が失敗した。

両モードに全角空白の置換を設定した場合にも注意が必要である。
whitespaceの1桁の `"W"` を先に設定し、jaspaceの2桁の `"[]"` で上書きすると、
表示tableは `"[]"` でも `char-width` は保存済みの `"W"` に由来する1を返した。
後勝ちの表示設定だけでは、幅APIとの整合まで保証されない。

## 3. タブのパディングもwhitespaceの置換対象になる

`jaspace--match-tab` はマーカー文字とASCII空白を連結した文字列を、タブの
overlayの `display` に設定する。この生成した空白にもdisplay tableが適用される。

`tab-width` を4、jaspaceのタブマーカーを `?^`、whitespaceのASCII空白の
置換を `[?X ?X]` とし、本文 `"a\tb\n"` を再着色した。
本文にはASCII空白がないが、生成したパディングがwhitespaceの影響を受ける。

| 条件 | タブoverlayの文字列 | `b` の位置での `current-column` |
| --- | --- | ---: |
| 置換なし | なし | 4 |
| jaspaceのタブマーカーのみ | `"^  "` | 4 |
| 上記のwhitespaceの空白置換も有効 | `"^  "` | 6 |

マーカーの後ろの空白2個がそれぞれ2桁で表示されるため、後続文字がずれる。
この期待値のテスト1件が失敗した。
1桁の `"."` への置換では列4を維持したが、パディングの空白にもその置換が
適用されるため、本文にない空白の印が見える可能性は残る。
「表示する対象が別なら干渉しない」とは扱えない。

## 4. 全角空白の表示幅を固定する仕組みはない

これはwhitespaceとの併用以前にある制約である。
jaspaceは任意の置換文字列をdisplay tableへ設定するが、元の幅への調整をしない。
単独で全角空白の直後の列を調べると、次の値になった。

| 置換文字列 | 全角空白の `char-width` / `string-width` | 直後の `current-column` |
| --- | ---: | ---: |
| `"[]"` | 2 / 2 | 2 |
| `"_"` | 2 / 2 | 1 |
| `"LONG"` | 2 / 2 | 4 |

さらに、既定の `WHITE SQUARE` が1桁となる場合を模擬し、バッファの
`char-width-table` でU+25A1だけを1に設定した。U+3000は2のままである。
この条件では既定の置換文字でも直後の列が1になり、幅APIは2を返した。
この期待値のテスト1件が失敗した。

実際の言語環境やフォントを切り替えた試験ではなく、Emacsの文字幅設定を
制御した検証である。ambiguous widthや実際の字形の幅も含む保証には、
この列計算の問題に加えて、表示環境ごとのGUI検証が必要になる。

## 今回成功した範囲と暫定的な併用

次の4件は成功した。これらは上記の失敗を解消したものではない。

- whitespaceをfaceによる強調だけに限定した組み合わせ。有効化・無効化の
  順序4通り、各3回のread-onlyによる一時停止・復帰で、jaspaceのマッピングと
  タブの列を維持し、最後にoverlayを除去できた。
- ASCII空白を1桁の `"."` に置換した場合の、タブ直後の列の維持。
- タブが残り1桁の位置にある場合、jaspaceの `"^"` のoverlayがwhitespaceの
  tab-markより優先され、タブ直後の列を維持すること。
- read-onlyでの本文・変更状態・undoの保持と、他バッファの幅APIの維持。
  faceだけの場合と1桁のspace-markを加えた場合で、有効化順序も変えた。

現時点で暫定的に勧められるのは、jaspaceで全角空白を置換し、whitespace側は
faceによる強調を担当する構成である。例えば次の表示設定とする。

```elisp
(setq jaspace-alternate-eol-string nil
      jaspace-highlight-tabs nil
      whitespace-style '(face tabs spaces trailing))
```

ここではwhitespaceのspace-mark・tab-mark・newline-markを使わず、display table
の保存・復元を競合させない。jaspaceの全角空白マーカー自体については、
利用環境で元の幅に合う表示になるかを別途確認する必要がある。
この設定例でGUIのピクセル配置まで検証したわけではない。

修正では、外部モードのtable復元への追従、幅補正の対象と基準の限定、
他の表示設定の影響を受けないタブのパディング、全角空白マーカーの幅の扱いを
整理する必要がある。任意文字への対応を広げる前に、この4点を検討する。

この調査を踏まえた将来の対象文字と拡張範囲は、
[機能拡張の方針と実装状況](future-directions.md) に整理した。
上記の暫定的な併用例を、将来の基本機能に必須の構成とするものではない。
