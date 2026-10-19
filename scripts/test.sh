#!/bin/sh
set -eu

emacs=${1:-emacs}
CDPATH= cd -P "$(dirname "$0")/.."

"$emacs" --batch -Q --eval '(progn (princ emacs-version) (terpri))'

"$emacs" --batch -Q -L . -l jaspace.el -l test/jaspace-tests.el \
    -f ert-run-tests-batch-and-exit

"$emacs" --batch -Q --eval '(setq byte-compile-error-on-warn t)' \
    -f batch-byte-compile jaspace.el

"$emacs" --batch -Q -L . -l jaspace.elc -l test/jaspace-tests.el \
    -f ert-run-tests-batch-and-exit

"$emacs" --batch -Q -L . -l test/package-smoke.el
