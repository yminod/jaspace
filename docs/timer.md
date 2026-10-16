# idle timer廃止の調査と判断

2026-10-16に、原版1.1と保守版1.2.1の更新経路を調査・再検証した。
idle timerを廃止し、有効化したバッファ内のフックで状態を更新する方針を維持する。
timer自体が現在のEmacsで動かないための変更ではない。自動有効化をユーザーの
設定に委ねる現在の設計では、状態の変化に応じて更新し、表示の再計算を
Font Lockに任せることで、パッケージ固有の待機処理を持たずに済むためである。

## timer導入前後の履歴と理由

[保存版の一覧](../PROVENANCE.md) にあるソースを比較した。

| 保存版 | 更新経路と当時の記載 |
| --- | --- |
| 0.1.0.9（2002-09-23）、1.0.0.3（2003-05-19）、1.0.0.5（2003-06-08） | グローバルな `post-command-hook` に `jaspace-post-command-hook` を追加し、コマンド後に状態を確認する。Windowsでシェルからファイルをドラッグして開くと、クリックやキー入力までjaspaceが有効にならない旨の既知問題を記載している。 |
| 1.0.0.7（2004-04-22） | 上記のフックを削除し、共有idle timerへ変更。ドラッグ時の既知問題の記載もなくなった。 |
| 1.1（2005-02-26） | idle timerを継続し、状態追従に加えてタブマーカーの幅の変化も検出する。 |

確認できる導入時期は1.0.0.5より後、1.0.0.7までの間である。
間の版や変更理由を明記した作者の記録は確認できておらず、1.0.0.7を厳密な
初導入版とは断定しない。保存済みの作者の配布ページにもtimerの採用理由はない。

差分からは、**ユーザーの次の操作を待たず、idle時にも自動有効化と状態追従を
行えるようにするため**と推定する。これは後述の比較テストで確認した効果であり、
作者自身が明記した理由とは区別する。既知問題の削除はこの解釈と整合する。
後述のソース分析と合成イベントのテストでも、メモに対応する動作を確認した。
ただし、当時のWindowsのドラッグ操作そのものを再現した証拠ではない。
また、1.0.0.7のタブ設定はfaceの強調だけなので、後年のタブ代替表示の幅更新が
timer採用の最初の理由だったとは考えない。

## 原著者のドラッグ操作のメモを説明する経路

Emacs 21.2のWindows向けソースを調べると、**表示先とカレントバッファが
異なる状態でコマンド後のフックを実行する経路**で、メモの症状を説明できる。

1. [w32term.c](https://github.com/emacs-mirror/emacs/blob/244c288bd138a0a433ca83e1654917fa8a1fb2b9/src/w32term.c#L8777)
   はWindowsの `WM_DROPFILES` をdropイベントに変換する。
   [w32-win.el](https://github.com/emacs-mirror/emacs/blob/244c288bd138a0a433ca83e1654917fa8a1fb2b9/lisp/term/w32-win.el#L154)
   は通常のキー割り当てで `w32-drag-n-drop` を呼ぶ。
2. `w32-drag-n-drop` は `save-excursion` の内側で `find-file` を実行する。
   ファイルBを表示するが、関数から戻るとカレントバッファは呼び出し元Aへ戻る。
   `save-excursion` はウィンドウに表示するバッファまでAへ戻すものではない。
3. [keyboard.cのコマンド実行後](https://github.com/emacs-mirror/emacs/blob/244c288bd138a0a433ca83e1654917fa8a1fb2b9/src/keyboard.c#L1644)
   は、そのまま `post-command-hook` を実行する。
   jaspace 1.0.0.5のフックはAで `jaspace-update` を呼ぶため、Bを有効化しない。
4. カレントバッファを選択中ウィンドウのBへ合わせる処理は、
   [次のループの先頭](https://github.com/emacs-mirror/emacs/blob/244c288bd138a0a433ca83e1654917fa8a1fb2b9/src/keyboard.c#L1366)
   にある。その後のクリックやキー入力がBで実行されれば、コマンド後の
   jaspaceの更新もBで行われ、有効になる。

この経路では、dropが特別なイベントなのでフックが省略されるわけではない。
フックの実行先が違うことが問題になる。Emacs 21.3の
[同じハンドラ](https://github.com/emacs-mirror/emacs/blob/8f1b13b5a300d5fd803661b6bca2f576f88e5247/lisp/term/w32-win.el#L154)
にも同じ `save-excursion` がある。

原著者は `font-lock-support-mode` との関係を疑っていたが、今回確認した経路の
説明にはFont Lockの遅延や不具合を仮定する必要がない。Emacs 21.2の
[font-lock.el](https://github.com/emacs-mirror/emacs/blob/244c288bd138a0a433ca83e1654917fa8a1fb2b9/lisp/font-lock.el#L1015)
と [easy-mmode.el](https://github.com/emacs-mirror/emacs/blob/244c288bd138a0a433ca83e1654917fa8a1fb2b9/lisp/emacs-lisp/easy-mmode.el#L269)
は、ファイル訪問後またはコマンド後に対象バッファのFont Lockを有効化する。
コマンド後の登録順もFont Lock側が先頭、jaspace側が末尾なので、順序の逆転が
常に起きていたとはいえない。後述の動作検証では、BのFont Lockが既に有効でも
jaspaceだけが無効のままになることを確認した。

### Emacs 31.1にも残る動作と現行jaspaceの対応

Emacs 31.1でも、
[w32-drag-n-drop](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/lisp/term/w32-win.el#L133)
は `save-excursion` の内側でファイルを開く。URL処理等を経由するようになったが、
表示先を残しながらカレントバッファを戻す構造は同じである。
[コマンド後のフック](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/src/keyboard.c#L1545)
より先に表示先へ同期する変更もなく、同期は引き続き
[ループの先頭](https://github.com/emacs-mirror/emacs/blob/a360712c9d272d950d8d8255ef74570f7e90b7d9/src/keyboard.c#L1360)
で行う。フックを呼ぶ `safe_run_hooks_maybe_narrowed` もカレントバッファを
表示先へ切り替える関数ではない。timer導入前のjaspaceでは、症状は現在でも残る。

timer方式では、同期後のBをidle時のコールバックで更新できる。
現行jaspaceでは、ユーザーのmajor modeフックでBの初期化中に有効化し、
Font Lockの状態はBの `font-lock-mode-hook` で追従する。
Emacs側の動作が消えたのでtimerが不要になったのではなく、Bで直接処理する
有効化・更新経路を設けたことで、Aのコマンド後のフックへの依存をなくしている。

## 原版の仕組み

基準は `upstream/1.1` タグのソースである。

- 読み込みの末尾で `jaspace-set-idle-timer` を呼び、共有の
  `jaspace-idle-timer` を一つ登録する。
- 登録内容は `(run-with-idle-timer jaspace-idle-delay t 'jaspace-update)`。
  遅延の初期値は、定義済みなら `idle-update-delay`、そうでなければ1秒である。
- コールバックはバッファ引数を持たず、`jaspace-update` は実行時の
  カレントバッファだけを扱う。全バッファを巡回する仕組みではない。
- `jaspace-modes` とバッファごとの選択状態から有効・無効を判定し、
  Font Lock、read-only、`tab-width` の変化に追従する。
  必要な再着色では `font-lock-fontify-buffer` を呼ぶ。
- 更新の末尾や明示的なon/offでもtimerの遅延を再設定する。
  全バッファで無効にしても、通常のon/offではtimerをキャンセルしない。

繰り返し指定tは、同じ待機中に一定間隔で発火し続ける意味ではなく、
Emacsが再びidleになるたびに指定秒数の経過後に一度実行する指定である。
Emacs 31.1の `timer.el` と
[Idle Timers](https://www.gnu.org/software/emacs/manual/html_node/elisp/Idle-Timers.html) で確認した。

## 保守版への変更経緯

timerと自動有効化の廃止は関連するが、別の変更として行われた。

| コミット | 変更 |
| --- | --- |
| `2910061` | idle timerによる更新を廃止。フックによる状態更新と `font-lock-flush` による着色済み状態の無効化へ移行。この時点では自動有効化とグローバルな更新フックを維持した。 |
| `cd032a7` | 効果のなくなった `jaspace-idle-delay`、`jaspace-idle-timer`、`jaspace-set-idle-timer` を削除。同一セッションの旧timerをキャンセルする再読み込み用の互換処理も削除した。 |
| `36a5672` | `jaspace-modes` による自動有効化を廃止。有効化をユーザーに委ね、更新・終了用フックをバッファローカルにした。 |

timerが不要になった直接の理由は、`2910061` で更新が必要な契機にフックを
設けたことである。major modeの初期化・ファイル訪問後の自動有効化、
Font Lock切替、read-only切替を直接検出し、直接の変数変更はコマンド後に確認する。
自動有効化の廃止だけを理由としたものではなく、それを残していた段階でも
後述のテストでtimerを使わない更新を確認した。

その後の `36a5672` では、ユーザーのmajor modeフック等で有効化するため、
まだ操作していないバッファを共有timerが見つけて有効化する責務自体もなくなった。
状態追従の必要性が消えたのではなく、その起動契機と管理範囲を変更したのである。

現行版は `require` だけでは有効化も更新フックの追加も行わない。
共有timerを持たないため、遅延の設定や最後のバッファを閉じた後のtimer管理も
不要になった。一方、コマンドごとの状態確認は増える。性能の優劣を測定した
変更ではなく、必要な更新契機と後始末を明確にする設計上の判断である。

## 現行版の更新契機

実装は [jaspace.el](../jaspace.el) の `jaspace--set-buffer-hooks`、
`jaspace-update`、`jaspace--font-lock-changed` を中心とする。

| 契機 | 処理と反映時点 |
| --- | --- |
| `jaspace-mode-on` | 有効化の希望を記録し、ローカルフックと表示設定を追加する。明示的な有効化ではまず表示を有効にし、停止条件はその後の更新で判定する。 |
| `font-lock-mode-hook` | Font Lock停止時のタブoverlayを除去し、追従設定に従って一時停止・復帰する。追従しない設定でも停止時のタブoverlayは除去する。 |
| `read-only-mode-hook` | `read-only-mode` コマンドによる変更を、その呼び出し中に反映する。 |
| ローカルな `post-command-hook` | そのバッファのコマンド後に、停止条件とタブ幅の変化を確認する。変化がなければ再有効化や再着色の要求は行わない。 |
| `after-change-functions` | 編集行の古いタブoverlayを除去する。Font Lockによる再着色時に新しい位置と幅で作り直す。 |
| 無効化・major mode変更・バッファ終了 | 表示設定、タブoverlay、ローカルフックを後始末する。アンロード時は有効・一時停止中の全バッファを後始末する。 |

`jaspace--requested` は有効化の希望、`jaspace-mode` は実際の有効状態を表す。
一時停止中も更新・終了用フックを保持し、停止条件がなくなると復帰する。
Font Lock追従とread-onlyの両方を設定した場合は、両条件が許すまで復帰しない。
明示的な無効化では希望とフックも消すため、その後の更新で勝手に復帰しない。

[post-command-hook](https://www.gnu.org/software/emacs/manual/html_node/elisp/Command-Overview.html)
はコマンドループが実行する。Lispから関数を直接呼ぶだけでは、コマンド後の
更新まで実行したことにはならない。

## 反映タイミングと制約

`setq` や `setq-local` で `font-lock-mode`、`buffer-read-only`、`tab-width`、
追従設定を変更しても、それだけではjaspaceの更新フックは走らない。
そのバッファで次のコマンドが終わるまで状態やタブ幅が残る場合がある。
別バッファのコマンド後の更新では反映されず、idleの経過を契機とする更新も
提供しない。外部処理から変更して直ちに反映したい場合は、対象バッファで
`jaspace-update` を呼ぶ。

この呼び出しは状態とoverlayを更新し、必要な再着色を要求する。
`font-lock-flush` はその場で全バッファを再着色する関数ではなく、実際の
色付けとタブoverlayの再生成はFont Lockが行う。
表示用文字列やタブマーカーの設定を取り直すには、従来どおり再有効化が必要である。

旧版から同じEmacsセッション内で読み直す際のtimer引き継ぎは扱わない。
旧版が登録したtimerを現行版が自動回収する保証はないため、移行時はEmacsを
再起動する。廃止した公開設定は [READMEの移行案内](../README.md#原典と旧版からの移行) を参照。

## 検証結果

GNU Emacs 31.1 (Windows)、初期化ファイルなしで確認した。

### 原版1.1のtimer

原版の観察には、文字コードと改行のみ正規化した `a71b2b6` のソースを
別プロセスで読み込んだ。廃止済みの `make-local-hook` だけを無処理に置き換えた。
一時的なERT 3件で、timerの共有登録とon/off後の存続、コールバックが現在の
バッファだけを更新すること、read-onlyの直接変更がコールバックで反映される
ことを確認した。登録されたtimerを `timer-event-handler` へ渡す検証であり、
実時間のidle待ちやGUIでの発火を測定したものではない。

### 導入前後と廃止直後の比較

導入前後と廃止の経緯についても、保存済みの1.0.0.5・1.0.0.7、`2910061`、
現行版を別々のEmacsプロセスで比較した。一時的なERTを各版に3件ずつ実行し、
計12件すべて成功した。観察した差は次のとおりである。

| 条件 | 1.0.0.5 | 1.0.0.7 | `2910061` | 現行版 |
| --- | --- | --- | --- | --- |
| global Font Lockの下で、コマンドを介さず `emacs-lisp-mode` を初期化 | 次のコマンド後のフックで有効化 | timerコールバックで有効化 | major mode・Font Lockのフックで有効化 | ユーザーの `prog-mode-hook` で有効化 |
| 一度更新した後、Font LockをLispから有効化 | 次のコマンド後のフックまで無効 | timerコールバックまで無効 | Font Lockのフックで有効化 | 有効化希望を記録したバッファで、Font Lockのフックにより復帰 |
| 有効なバッファで `read-only-mode` を切替 | 次のコマンド後のフックで停止・復帰 | timerコールバックで停止・復帰 | read-onlyのフックで停止・復帰 | read-onlyのフックで停止・復帰 |

Font Lockは実際のモード関数で切り替え、全角空白のjaspace faceも確認した。
現行版の初期化テストではユーザーフックを設定した。
1.0.0.5が期待する標準display tableをテスト側で用意し、全版で同じ条件にした。

ここでの「次のコマンド後」はそのフックを明示実行し、「timerコールバック」は
登録済みtimerを `timer-event-handler` に渡して確認した。idle待ちの実時間や
Emacs 21.x本体、OSからのドラッグ操作は試していない。この検証が示すのは、
追加操作がない場合に更新する経路の差と、現在のフックによる代替が成立する範囲である。

### ドラッグ操作のメモに対応する経路の再現

ドラッグ操作のメモに関する追加調査では、Emacs 31.1 (Windows)上で
21.2から取り出した `w32-drag-n-drop` の定義と、31.1添付の実際のハンドラを比較した。
jaspaceは1.0.0.5、1.0.0.7、現行版の3種類を別プロセスで読み込み、
各組み合わせでdropと通常のファイル訪問の2件、計12件の一時ERTが成功した。

dropでは、単一の選択ウィンドウを宛先に合成イベントを作り、
`execute-kbd-macro` で実際のコマンドループとハンドラを通した。
`post-command-hook` の観測結果は次のとおりだった。両ハンドラで同じ結果になった。

| jaspace | カレントバッファ | 表示バッファ | 表示バッファのFont Lock | 表示バッファのjaspace |
| --- | --- | --- | --- | --- |
| 1.0.0.5 | 呼び出し元A | ファイルB | 有効 | 無効。続く通常コマンド後に有効になる。 |
| 1.0.0.7 | 呼び出し元A | ファイルB | 有効 | 無効。Bでtimerコールバックを実行すると有効になる。 |
| 現行版＋ユーザーの `prog-mode-hook` | 呼び出し元A | ファイルB | 有効 | 既に有効。追加のコマンドやtimerコールバックは不要。 |

対照として `save-excursion` を伴わず `find-file` を実行するコマンドも通した。
1.0.0.5は同じコマンド後にBで有効化し、timer方式の1.0.0.7はコールバック後、
現行版はユーザーフックで有効化した。dropに限って更新先がずれる説明と整合する。

テストでは `raise-frame` だけを無処理にし、初期化ファイルは使用していない。
旧ハンドラは定義だけを取り出して実行し、旧版のフレーム初期化は読み込んでいない。
実際のWindowsシェルからの投入、フレーム間の移動、Emacs 21.xバイナリでの実行、
実時間のidle発火は検証していない。ソース上の経路の説明と、31.1での
ハンドラ・コマンドループの再現を、当時の環境全体の再現とは区別する。

### 現行版の継続的な検証

この調査時に [test/jaspace-tests.el](../test/jaspace-tests.el) へ4件を追加した。
実際のコマンドループでの直接変更、別バッファからの変更の反映時点、
Font Lockとread-onlyを組み合わせた停止・復帰を確認する。
[test/package-smoke.el](../test/package-smoke.el) では読み込み、有効化、
一時停止、アンロードの前後で共有idle timerの登録が変化しないことも確認した。
当時の計47件はソース・バイトコードの両方で成功し、コンパイルも成功した。
現在の件数と再実行方法は [test/README.md](../test/README.md) を参照。

GUI描画、idleとの体感上の差、性能の定量比較、他のEmacs版での実行は含まない。
