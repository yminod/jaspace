param(
    [string]$Emacs = 'emacs'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$report = [System.IO.Path]::GetTempFileName()
$previousReport = $env:JASPACE_GUI_REPORT
Push-Location -LiteralPath $projectRoot
try {
    & $Emacs --batch -Q --eval '(dolist (file (quote ("jaspace.el" "test/jaspace-tests.el" "test/jaspace-gui-tests.el"))) (with-temp-buffer (insert-file-contents file) (check-parens)))'
    if ($LASTEXITCODE -ne 0) { throw 'GUI test syntax check failed.' }
    $env:JASPACE_GUI_REPORT = $report
    $launch = @{
        FilePath = $Emacs
        WorkingDirectory = $projectRoot
        ArgumentList = @('-Q', '-L', '.', '-L', 'test', '-l', 'jaspace.el',
                         '-l', 'test/jaspace-gui-tests.el',
                         '--eval', '(jaspace-gui-run-tests)')
        PassThru = $true
    }
    if ($IsWindows) { $launch.WindowStyle = 'Hidden' }
    $process = Start-Process @launch
    if (-not $process.WaitForExit(30000)) {
        $process.Kill()
        throw 'GUI tests timed out.'
    }
    $result = Get-Content -LiteralPath $report -Raw
    Write-Output $result
    if ($result -notmatch 'JASPACE_GUI_TESTS_COMPLETE') {
        throw 'Emacs exited without completing GUI tests.'
    }
    if ($process.ExitCode -ne 0) { throw 'GUI layout tests failed.' }
}
finally {
    Pop-Location
    $env:JASPACE_GUI_REPORT = $previousReport
    Remove-Item -LiteralPath $report
}
