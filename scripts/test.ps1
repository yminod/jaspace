param(
    [string]$Emacs = 'emacs'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & $Emacs --batch -Q --eval '(progn (princ emacs-version) (terpri))'
    if ($LASTEXITCODE -ne 0) { throw 'Emacs version check failed.' }

    & $Emacs --batch -Q -L . -l jaspace.el -l test/jaspace-tests.el -f ert-run-tests-batch-and-exit
    if ($LASTEXITCODE -ne 0) { throw 'Source ERT tests failed.' }

    & $Emacs --batch -Q --eval '(setq byte-compile-error-on-warn t)' -f batch-byte-compile jaspace.el
    if ($LASTEXITCODE -ne 0) { throw 'Byte compilation failed.' }

    & $Emacs --batch -Q -L . -l jaspace.elc -l test/jaspace-tests.el -f ert-run-tests-batch-and-exit
    if ($LASTEXITCODE -ne 0) { throw 'Compiled ERT tests failed.' }

    & $Emacs --batch -Q -L . -l test/package-smoke.el
    if ($LASTEXITCODE -ne 0) { throw 'Package smoke test failed.' }
}
finally {
    Pop-Location
}
