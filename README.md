# jaspace.el

`jaspace.el` は、日本語の全角空白を可視化し、設定により改行やタブも表示する
Emacsのminor modeである。このリポジトリでは、原版の使い勝手を尊重しながら、
現在のEmacsで保守しやすい実装へ段階的に更新する。

保守の基準には upstream の最終版1.1を使用する。原典の取得元、既知の旧版、
ライセンス、ハッシュなどは [PROVENANCE.md](PROVENANCE.md) を参照。

## 目的

- 現在のEmacsで警告なく読み込み、安定して利用できるようにする。
- 全角空白、改行、タブの表示に関する従来の挙動をテストで明確にする。
- 公開されてきたコマンドやカスタマイズ変数との互換性をできる限り維持する。
- 古いEmacs向けの回避処理や廃止APIへの依存を整理する。
- 通常のEmacsパッケージとして導入・更新できる構成にする。

## 作業方針

1. upstream の原典は無改変のコミットとタグで保存する。
2. 現在の挙動をテストで記録してから内部設計を変更する。
3. 文字コード変換、整形、メタデータ追加、機能変更を別々のコミットにする。
4. 既存の公開インターフェースと、内部実装上の偶然の挙動を区別する。
5. 廃止APIは機械的に置換せず、現行Emacsでも回避処理が必要か検証する。
6. 原版との互換性修正と、新しい対象文字などの機能拡張を分けて進める。
7. 原著者によるコードと、このリポジトリで加えた変更を履歴上で区別する。

最終版1.1は保守開始時の基準であって、その内部設計を維持するという意味では
ない。旧版は、挙動の変遷や後の版で処理が追加された理由を調べる資料として
利用する。

## 進め方

1. 主要な挙動と有効化・無効化時の後始末をERTテストで固定する。
2. ソースをUTF-8へ変換し、パッケージメタデータを整える。
3. minor mode、font-lock、display tableの管理を現行APIに合わせる。
4. 旧adviceと定期idle timerが現在も必要か検証し、可能なら除去する。
5. 複数バッファ、read-only、major mode変更、`whitespace-mode`との併用を
   確認する。
6. 対応するEmacsの範囲を決め、複数バージョンでテストする。

## 現在の状態

無改変の upstream 1.1 は `upstream/1.1` タグで保存済みである。
保守版1.2.0は GNU Emacs 27.1以降を対象とし、UTF-8、lexical binding、
パッケージメタデータ、現行APIによる表示と後始末に移行した。
XEmacsやEmacs 20/21向けの分岐・廃止APIの代替処理は削除し、保守対象にしない。

進め方の1〜5は実装とEmacs 31.1 (Windows)での検証まで完了した。
38件のERTをソース・バイトコンパイル済みコードの両方で確認し、警告を
エラー扱いにしたコンパイルと、パッケージのアンロードも通っている。
6については対応範囲を27.1以降とし、当面は最新版31.1の検証を基準に進める。
既知のAPI変更がない範囲では互換性を見込むが、全対応バージョンでの厳密な
テストは後回しにする。31.1以外を検証済みとはしていない。

## 導入と設定

このディレクトリを `load-path` に追加して読み込む。Emacsの
`M-x package-install-file` で `jaspace.el` を指定して導入することもできる。

```elisp
(add-to-list 'load-path "C:/Users/cap06/src/jaspace")
(require 'jaspace)
```

有効化するバッファはユーザーが選ぶ。手動の切替には `M-x jaspace-mode`、
強制的な有効化・無効化には `M-x jaspace-mode-on` / `M-x jaspace-mode-off`
を使う。プログラミング用のバッファで有効にしたい場合は、初期化ファイルで
フックを設定する。

```elisp
(add-hook 'prog-mode-hook (lambda () (jaspace-mode 1)))
```

`require` だけでは、既存・新規のバッファで自動的に有効にならない。

```elisp
;; 設定は読み込み前、またはモードを再度有効化する前に指定する。
(setq jaspace-alternate-jaspace-string "\N{WHITE SQUARE}"
      jaspace-alternate-eol-string "\N{LEFT-POINTING DOUBLE ANGLE QUOTATION MARK}\n"
      jaspace-highlight-tabs ?^)
```

例ではUnicodeの文字名を使う `\N{...}` 表記で文字を明示している。
文字を直接入力しても同じ値になり、代替表示には任意の文字列を指定できる。

全角空白の代替文字列をnilまたは空文字にすると、文字の置換を行わずfaceで
強調する。改行の代替文字列は必ず改行文字で終える。

## 互換性と変更点

- 表示に関するコマンド名、カスタマイズ変数、face名を維持した。
  Lispからの引数なしの `jaspace-mode` は従来どおりトグルする。
  `jaspace-mode-hook` は有効化時だけ、
  `jaspace-mode-off-hook` は無効化時だけ、状態が変わったときに実行する。
- `jaspace-modes` と対象major modeによる自動有効化を削除した。
  有効化する場所はユーザーのフックやコマンドで指定する。
- display tableをバッファごとに複製し、他バッファや共有tableを変更しない。
  後から他の機能が変更したマッピングは無効化時にも維持する。
- タブの代替表示には専用overlayを使う。無効化・major mode変更・バッファの
  終了時に削除し、他の機能のdisplayプロパティは消さない。
- idle timerを廃止し、有効化したバッファ内のfont-lock、read-onlyのフックと
  `post-command-hook` で更新する。`setq` による状態変更はそのバッファでの
  次のコマンド後に反映する。即時反映には `jaspace-update` を呼ぶ。
  不要になった `jaspace-idle-delay`、`jaspace-idle-timer`、
  `jaspace-set-idle-timer` と、同一セッションでの旧版からの再読み込みに備える
  互換処理も削除した。
- `jaspace-follow-font-lock` と `jaspace-disable-on-read-only-buffers` による
  一時停止・復帰はユーザーが有効化したバッファだけに適用する。
  明示的に無効化した場合やmajor modeを変更した場合は、更新用フックも外す。
- Emacs 31.1でも代替表示が文字幅のAPIに影響するため、`char-width` と
  `string-width` の補正は `advice-add` で残した。有効なバッファがなくなれば
  adviceを取り外す。`vertical-motion` の旧補正は空行の移動を検証して除去した。
- `whitespace-mode` との有効化・無効化の順序を検証した。同じ文字のdisplay
  tableマッピングには、後から有効にしたモードの設定が適用される。
- mmm-mode専用の `jaspace-mmm-mode-hook` と `jaspace-synch-mmm-maybe` を削除した。
  専用処理にはタブ表示のエラーや後始末の不具合があり、保守版ではmmm-mode
  との完全な併用をサポート対象にしない。調査結果は
  [docs/mmm-mode.md](docs/mmm-mode.md) を参照。

## 検証

```powershell
./scripts/test.ps1 -Emacs 'C:\Users\cap06\emacs\bin\emacs.exe'
```

原版の確認結果と個別の実行方法は [test/README.md](test/README.md) を参照。
