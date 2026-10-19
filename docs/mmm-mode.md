# mmm-mode専用対応の調査と判断

2026-10-14に調査し、JaSpaceの専用mmm-mode対応は削除した。
mmm-mode自体の利用者がいない、あるいはその設計が一切動かないことを理由には
しない。現存する専用処理が不十分で、完全な併用を保守対象にすると表示機能の
範囲を超えるモード別の検証・対応が必要になるためである。

## 保守状況と設計

- [GNU ELPA](https://elpa.gnu.org/packages/mmm-mode.html) の公開版は0.5.11、
  配布日は2024-03-31。調査時の[公式リポジトリの先頭コミット](https://github.com/dgutov/mmm-mode/commit/b1f5c7dbdc405e6e10d9ddd99a43a6b2ad61b176)
  は2024-02-22のリリースコミットだった。
- 2024〜2025年にも不具合報告や修正提案がある。日本語ブログの投稿頻度だけで
  現在の利用者数を推定しない。
- Emacsの通常のモデルは[各バッファに一つのmajor mode](https://www.gnu.org/software/emacs/manual/html_node/elisp/Modes.html)
  である。mmm-modeは領域をoverlayで管理し、ポイントの移動に応じて
  major-mode、syntax table、keymap、選択したローカル変数を保存・復元する。
  font-lockも領域ごとに振り分ける。
  [領域と状態の実装](https://github.com/dgutov/mmm-mode/blob/b1f5c7dbdc405e6e10d9ddd99a43a6b2ad61b176/mmm-region.el)
  を確認した。
- [mmm-vars.el](https://github.com/dgutov/mmm-mode/blob/b1f5c7dbdc405e6e10d9ddd99a43a6b2ad61b176/mmm-vars.el)
  の `mmm-save-local-variables` にはCC Mode、JavaScript、TypeScript、SMIE、
  whitespace等への個別の配慮がある。一方、[FAQ](https://github.com/dgutov/mmm-mode/blob/b1f5c7dbdc405e6e10d9ddd99a43a6b2ad61b176/FAQ)
  も、未対応モードでは追加の変数や状態を保存する必要があり得ると説明する。
  任意のmajor modeとの互換性が保証された仕組みとは判断しない。
- 標準EmacsにはTree-sitterの[複数言語の解析範囲を扱うAPI](https://www.gnu.org/software/emacs/manual/html_node/elisp/Multiple-Languages.html)
  もある。これは一つのmajor mode内で複数言語のparser等を管理する仕組みで、
  既存の任意のmajor modeをそのまま領域ごとに組み合わせる保証ではない。
  Emacs 31.1の標準添付 `mhtml-ts-mode` でもHTML・JavaScript・CSSのために
  この方式が使われる。インストール済みのソースと
  [上流への追加履歴](https://lists.gnu.org/archive/html/emacs-diffs/2025-02/msg00442.html)
  を確認した。
  [issue #142](https://github.com/dgutov/mmm-mode/issues/142) でも保守者がこのAPIを
  案内している。

## 上流の検証範囲

[CI設定](https://github.com/dgutov/mmm-mode/blob/b1f5c7dbdc405e6e10d9ddd99a43a6b2ad61b176/.github/workflows/test.yml)
にはEmacs 25.1〜29.2の複数リリースと、失敗を許容するsnapshotが含まれる。
[テスト](https://github.com/dgutov/mmm-mode/tree/b1f5c7dbdc405e6e10d9ddd99a43a6b2ad61b176/tests)
は11件で、HTML/ERB、JavaScript、テスト用major modeによるsyntax table・
font-lockの確認、版情報を扱う。配慮やテストがないとはいえないが、任意の
モードや外部パッケージを網羅するものではない。

GNU Emacs 31.1 (Windows)で、このコミットの上流ERTを実行した。
無改変では11件中10件が `global-font-lock-mode-cmhh` の未定義で失敗した。
原因はテスト補助コードによる古い内部関数名への依存であり、mmm-mode本体の
機能がすべて壊れている証拠とは扱わない。
[未マージのPR #145](https://github.com/dgutov/mmm-mode/pull/145) と同等の変更を
テスト補助マクロだけに適用すると、11件すべて成功した。mmm-mode本体は
変更していない。

一方、調査時点では次の報告が未解決だった。これらは報告者の環境での結果で、
今回その全てを再現したわけではない。

- [#138](https://github.com/dgutov/mmm-mode/issues/138)：標準の
  `typescript-ts-mode` と組み合わせた際のエラー。
- [#142](https://github.com/dgutov/mmm-mode/issues/142)：Tree-sitterとの併用時の
  再解析と構文強調の性能問題。保守者も実装上の事情を認めている。
- [#143](https://github.com/dgutov/mmm-mode/issues/143)：HTML内JavaScriptの
  インデントと構文強調の問題。
- [#144](https://github.com/dgutov/mmm-mode/issues/144)：Emacs 30.1で
  `c-mode` を埋め込んだ際のredisplayエラー。

## JaSpaceの専用処理の実測

削除前のJaSpaceソースと上記mmm-modeを、初期化ファイルなしのEmacs 31.1で
確認した。テスト用のglobal-font-lock補助処理は前述の修正相当を使用した。
HTML内に `emacs-lisp-mode` または `js-mode` の領域を設け、HTML側と埋め込み側の
両方に全角空白とタブを置いた。専用フックの有無と両モードの有効化順を変えた。
ユーザー側の設定で停止しないよう `jaspace-follow-font-lock` はnilにした。

| 条件 | 確認できた挙動 |
| --- | --- |
| 専用フックなし | 全角空白のdisplay tableによる置換は両領域で有効。faceとタブの代替表示は埋め込み側では付かず、HTML側も有効化順に依存する。 |
| 専用フックあり・タブの代替文字 `?^` | 両方の埋め込みモード、有効化順の両方で `wrong-type-argument characterp nil` が発生。 |
| 専用フックあり・タブ強調nil | 埋め込み側にもfaceが付くが、HTML側は有効化順に依存。HTML＋Emacs Lispでは無効化後の再fontify後にも埋め込み側のJaSpace faceが残ることを別プロセスでも再現。 |

タブのエラーでは、専用処理が `mmm-update-mode-info` にモードの再初期化を
要求し、mmm-modeの一時バッファ内でJaSpaceのmatcherが実行された。
そのバッファには `jaspace--tab-marker` がなく、`char-to-string` にnilが渡った。
専用処理はキーワードの追加だけでは現在のバッファローカルな状態や後始末を
十分に扱えていない。

この調査は二つの組み合わせでのバッチ検証に限定される。全モードとの互換性や
GUI表示を検証したものではない。

## 保守方針

`jaspace-mmm-mode-hook`、`jaspace-synch-mmm-maybe` とmmm-modeの宣言は削除済みである。
専用の互換stubや代替連携APIは追加しない。既存設定にある
`(add-hook 'mmm-mode-hook #'jaspace-mmm-mode-hook)` も取り除く必要がある。

mmm-modeとの完全な併用はサポート対象にしない。通常の全角空白の置換表示が
今回の例で動いたことと、face・タブ・状態切替を含む完全な連携は区別する。
将来具体的な利用要件が生じた場合に、その組み合わせとライフサイクルを再検証する。
