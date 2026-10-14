# 検証

PowerShellから、初期化ファイルを読み込まずに実行する。

```powershell
./scripts/test.ps1 -Emacs 'C:\Users\cap06\emacs\bin\emacs.exe'
```

このスクリプトはソースのERT、警告をエラー扱いにしたコンパイル、
コンパイル済みコードのERT、パッケージメタデータとアンロードの検証を行う。
EmacsがPATHにある場合は `-Emacs` を省略できる。

ソースのERTだけを実行するには次を使う。

```powershell
& C:\Users\cap06\emacs\bin\emacs.exe --batch -Q -L . -l jaspace.el -l test/jaspace-tests.el -f ert-run-tests-batch-and-exit
```

`-l jaspace.el` はソースを明示的に読み込み、古い `.elc` の混入を防ぐ。

## 原版の確認結果

2026-10-14、GNU Emacs 31.1 (Windows) で upstream 1.1 を確認した。

- そのまま読み込むと `lexical-binding` の不足が警告される。
- 有効化は、廃止済みの `make-local-hook` の呼び出しで停止する。
- テスト内でその呼び出しだけを無処理に置き換えると、15件の挙動テストが通る。
- 全角空白・改行・タブの表示、空文字とnilの扱い、コマンド・フック、
  major mode変更、read-only、font-lock追従、変更状態とundoの保持を記録した。

この置き換えは原版の観察用であり、製品コードの互換処理には採用しない。
現代化後のテストにはこの置き換えを含めていない。原版のテストは
`da1ba12` コミットから確認できる。

## 保守版の確認結果

2026-10-14、GNU Emacs 31.1 (Windows) で43件のERTがソース・バイトコードの
両方で成功した。バイトコンパイルの警告はなく、パッケージのメタデータと
アンロードの検証も成功した。

追加したテストは共有・標準display table、他機能のマッピングの保持、
複数バッファ、バッファ終了、narrowing、read-only、タブの編集と幅の変更、
実際のfont-lock切替、他のfont-lock設定の保持、文字幅、空行の移動、
`whitespace-mode`との併用を対象とする。有効化をユーザーに委ねる変更に合わせ、
未有効化のバッファへの影響、ユーザーのフックによる有効化、一時停止中の
明示的な無効化とmajor mode変更も確認する。パッケージの読み込みで既存
バッファやグローバル更新用フックを変更しないこと、有効・一時停止中の
バッファの両方でアンロード時に後始末できることも検証する。

v1.2.1のdisplay tableの後始末の修正に対し、5件の回帰テストを追加した。
通常の複製とindirect bufferでの双方の無効化、複製側の終了・major mode変更、
保持されたtableと他機能の編集の維持、`whitespace-mode` と併用した複製側の
後始末を確認する。併用テストでは有効化・無効化の順序を変え、元のバッファの
表示と復元用tableが影響を受けないことを確認する。indirect bufferの
Font Lockによる色付けの独立や、別バッファで編集した後のタブ幅の即時更新は
今回の対応範囲に含めない。

font-lockとwhitespaceはbatch時の有効化を抑制するため、実動作の切替テストでは
`noninteractive` を一時的にnilにし、非表示扱いにならないバッファ名を使う。
GUI描画の見た目の確認とは区別する。

対応範囲はEmacs 27.1以降とし、当面は最新版31.1の検証を基準にする。
ローカルで確認済みなのは31.1のみで、全対応バージョンでの厳密なテストは
後回しにする。既知のAPI変更がない範囲では互換性を見込む。
mmm-modeとの限定的な併用調査と専用処理を削除した理由は
[docs/mmm-mode.md](../docs/mmm-mode.md) に記録した。
GUIでの見た目の確認は今後の検証項目である。
