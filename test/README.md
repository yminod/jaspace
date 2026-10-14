# 検証

PowerShellから、初期化ファイルを読み込まずに実行する。

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
現代化後の検証では置き換えを外して同じ挙動を確認する。
