# jaspace.el

`jaspace.el` は、日本語のいわゆる全角空白（U+3000 IDEOGRAPHIC SPACE）を可視化し、
設定によりいわゆる半角空白（U+0020 SPACE）・改行・タブも
表示するEmacsのminor modeである。現行開発版は1.3.0で、GNU Emacs 27.1以降を対象とする。

`whitespace-mode` にも表示上の置換機能があるが、jaspaceは表示文字を
差し替えても `char-width` / `string-width` が返す元の文字幅を維持する。
タブは1桁幅のマーカーを元のタブ幅に収め、後続の文字の位置を変えない。
ピクセル単位の幅や配置は、フォントやfaceによって変わり得るので、論理的な文字幅・
列位置の維持と区別し、任意の表示環境でのピクセル配置の不変性は保証しない。

## 導入

`M-x package-install-file` で `jaspace.el` を指定してインストールできる。
リポジトリから直接読み込む場合は、配置先を `load-path` に追加する。
例のパスは実際の配置先に合わせて変更する。

```elisp
(add-to-list 'load-path "/path/to/jaspace")
(require 'jaspace)
```

## 有効化

有効化するバッファはユーザーが選ぶ。`require` だけでは自動的に有効にならない。
手動の切替には `M-x jaspace-mode` でのトグル、明示的な有効化・無効化の指定には
`M-x jaspace-mode-on` / `M-x jaspace-mode-off` を使う。
初期化ファイルでフックを設定してもよい。
たとえばプログラミング用のバッファで有効にしたい場合は次の通り。

```elisp
(add-hook 'prog-mode-hook (lambda () (jaspace-mode 1)))
```

Lispからの引数なしの `jaspace-mode` もトグル動作となるので、有効化には
`(jaspace-mode 1)` を使う。`jaspace-mode-hook` は有効化時だけ、
`jaspace-mode-off-hook` は無効化時だけ、実際に状態が変わったときに実行する。
major modeを変更するとjaspaceは無効になる。新しいモードに有効化用のフックを
設定していれば、そこで再度有効になる。

## 表示の設定

既定では全角空白を `WHITE SQUARE` で表示する。改行とタブのマーカーは
無効である。表示を変更する例は次のとおり。

```elisp
(setq jaspace-alternate-jaspace-string "\N{WHITE SQUARE}"
      jaspace-alternate-eol-string "\N{LEFT-POINTING DOUBLE ANGLE QUOTATION MARK}\n"
      jaspace-highlight-tabs ?^)
```

例ではUnicodeの文字名を使う `\N{...}` 表記で文字を明示している。
文字を直接入力しても同じ値になり、全角空白や改行の代替表示には任意の
文字列を指定できる。

| 変数 | 設定内容 |
| --- | --- |
| `jaspace-alternate-jaspace-string` | 全角空白の代替文字列。nilまたは空文字はfaceだけで強調する。 |
| `jaspace-alternate-eol-string` | 改行の代替文字列。必ず改行文字で終える。nilまたは空文字はマーカーを無効にする。 |
| `jaspace-highlight-tabs` | nilはタブの強調を無効にし、tはfaceだけで強調する。文字を指定するとマーカーも表示する。 |
| `jaspace-highlight-spaces` | U+0020 SPACEの表示。既定のnilは無効、tはfaceだけで強調し、文字を指定すると1桁幅のマーカーも表示する。 |
| `jaspace-mode-string` | モードラインの表示。既定値は `" JaSp"`。 |

代替文字列・タブ・半角空白の設定は、読み込み前または有効化前に指定する。
有効化中に変更した場合は、一度無効化してから再有効化する。

faceだけで全角空白を可視化するには、`jaspace-highlight-jaspace-face` の
背景色を設定する。`M-x customize-face` でこのfaceを指定して変更できる。
読み込み後に表示方法を変更してもfaceの既定値は切り替わらない。
タブのマーカーには、例の `?^` のように表示幅が1桁の文字を使う。

### 半角空白の明示

半角空白（U+0020）は既定では明示しない。whitespace-modeの `space-mark` に
似た表示をjaspace単独で使いたい場合は、例えばドットを指定する。

```elisp
(setq jaspace-highlight-spaces ?.)
```

全角空白・タブ・改行も併せて明示するには、次のように設定する。
whitespace-modeの有効化は不要である。

```elisp
(setq jaspace-highlight-spaces ?.
      jaspace-highlight-tabs ?^
      jaspace-alternate-jaspace-string "[]"
      jaspace-alternate-eol-string "$\n")
```

本文中の半角空白にだけマーカーを付け、タブの表示用に生成した余白には付けない。
`jaspace-highlight-space-face` で色を変更できる。背景色を付けるだけでよければ、
`jaspace-highlight-spaces` をtにする。NBSP（U+00A0）の表示は変更せず、
標準の `nobreak-char-display` とユーザーの設定に任せる。

マーカーには表示幅1桁の可視文字を使う。例えば `?\N{MIDDLE DOT}` も指定できるが、
文字幅設定で2桁になる場合は使えない。無効な値では有効化前にエラーを通知する。
1桁であっても、可変幅フォントや代替フォントでは元の空白とピクセル幅が異なり得る。
他の機能がdisplay・composition・invisibleを指定した空白や、display tableで
既に置換している空白には、jaspaceのマーカーを重ねない。

その他の設定は `M-x customize-group RET jaspace` から変更できる。

## 状態の更新と併用

`jaspace-follow-font-lock` は既定でtであり、有効化したバッファでは
Font Lockが無効な間jaspaceを一時停止し、有効になると復帰する。
`jaspace-disable-on-read-only-buffers` をtにすると、読み取り専用の間も
一時停止する。この設定の既定値はnilである。

Font Lockや読み取り専用状態の変更はフックで反映する。これらの状態や
`tab-width` を直接 `setq` で変更した場合は、そのバッファでの次のコマンド後に
反映する。即時反映には `jaspace-update` を呼ぶ。
明示的に無効化したバッファでは、自動的に復帰しない。
idle timerを廃止した理由、旧版との更新タイミングの違いと検証結果は
[docs/timer.md](docs/timer.md) に記録した。

無効化・major mode変更・バッファの終了時は、jaspaceの表示設定とタブ・半角空白の
overlayを後始末する。他の機能が後から変更したマッピングやdisplayプロパティは
維持する。後始末は共有tableを直接書き換えず、変更したコピーを各バッファへ
設定するため、複製したバッファの無効化・終了で他方の置換表示を消さない。

`whitespace-mode` と併用する場合、当面はwhitespace側をfaceによる強調に
限定する。space-mark・tab-mark・newline-markによる置換を併用すると、
表示対象を分けても、whitespaceの無効化でjaspaceの置換表示が消える場合がある。
幅APIやタブのパディングにも影響がある。再現条件と検証範囲は
[docs/whitespace-mode.md](docs/whitespace-mode.md) に記録した。

## 既知の制約と要改善事項

1. **indirect bufferの色付け・タブ更新は完全には独立しない。**
   indirect bufferは、元のバッファと本文を共有しながら、表示範囲やpoint、
   ローカル変数などを別に持てるバッファである。Font Lockが付けるfaceは
   本文の属性として共有されるため、色付けは各バッファで独立しない。
   また、一方で編集すると他方のタブマーカーのパディングが更新されず、
   再着色まで古い幅が残る場合がある。完全な分離は、具体的な利用上の
   必要が確認されるまで保留する。
2. **faceの既定値が読み込み時の設定に依存する。**
   `jaspace-highlight-jaspace-face` と `jaspace-highlight-tab-face` は、
   読み込み時のカスタマイズ変数の値から既定値を決める。例えば、読み込み後に
   全角空白の代替文字列をnilや空文字にして再有効化しても、faceは前景色だけの
   ままとなる。faceだけで可視化する場合は、背景色を明示的に設定する。
   表示方法を変更したときのfaceの扱いを、ユーザーのface設定を尊重しながら
   見直す余地がある。
3. **タブのマーカーを表示幅1桁として扱う。**
   指定された文字の実際の幅は考慮していないため、全角など幅の異なる文字では
   後続文字の表示位置がずれる。表示幅1桁を前提とする仕様と設定値の検証を
   整理する。任意幅の文字への対応は、必要性が確認されるまで保留する。
4. **全角空白の置換文字列を元の表示幅へ自動調整しない。**
   `char-width` / `string-width` の補正と、実際の表示幅の維持は別である。
   元と幅の異なる文字列を指定すると、後続文字の位置が変わる。
   既定の `WHITE SQUARE` も、文字幅設定によっては元の全角空白と幅が異なる。
   [whitespaceとの併用調査](docs/whitespace-mode.md) にこの制約の検証も含めた。

mmm-modeとの完全な併用はサポート対象にしない。専用対応を削除した理由と
検証結果は [docs/mmm-mode.md](docs/mmm-mode.md) を参照。
XEmacsおよびEmacs 27.1未満はサポート対象にしない。

## 今後の拡張方針

日常的に必要な空白文字を、論理的な幅・列位置と読みやすさを保ったまま識別できる
ことを目指す。強化対象、半角空白の実装状況、標準機能との分担と表示環境の扱いは
[機能拡張の方針と実装状況](docs/future-directions.md) に整理した。

## 検証

GNU Emacs 31.1 (Windows)で、61件のERTがソース・バイトコードの両方で成功している。
警告をエラー扱いにしたバイトコンパイル、パッケージのメタデータと
読み込み・アンロードの検証も通っている。

テスト用の実行スクリプトはPowerShell 7以降（`pwsh`）を前提とする。
EmacsがPATHにある場合は、リポジトリのルートで次を実行する。

```powershell
pwsh -File ./scripts/test.ps1
```

PATHにない場合は `-Emacs` に実行ファイルのパスを指定する。通常の自動テストは
GUI描画を含まない。別途 `scripts/test-gui.ps1` の4件で、等幅フォントでの
座標・折り返し・文字サイズ変更と、可変幅フォントで論理列とピクセル幅が異なる
条件を確認した。フォントごとの網羅的な保証ではない。
確認済みのバージョンは31.1のみで、全対応バージョンの
厳密なテストは後回しにしている。既知のAPI変更がない範囲では互換性を見込む。
検証範囲と個別の実行方法は [test/README.md](test/README.md) を参照。

## 原典と旧版からの移行

原著者はSatomi I.、ライセンスはGNU GPL version 2 or laterである。
保守の基準とした原版1.1は、無改変の `upstream/1.1` タグで保存している。
原典の取得元、既知の旧版、ハッシュなどは [PROVENANCE.md](PROVENANCE.md) を参照。
保守版の変更履歴はコミット履歴とリリースタグから確認できる。

原版1.1の設定を移行する場合は、次の変更に注意する。

- `jaspace-modes` による自動有効化は廃止した。有効化する場所をフックで指定する。
- 更新用のidle timerは廃止した。`jaspace-idle-delay`、`jaspace-idle-timer`、
  `jaspace-set-idle-timer` は提供しない。
- mmm-mode専用の `jaspace-mmm-mode-hook` と `jaspace-synch-mmm-maybe` は提供しない。

表示に関する公開コマンド名、カスタマイズ変数、face名は維持している。
