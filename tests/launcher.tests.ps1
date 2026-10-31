$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$launcher = Join-Path $repoRoot 'one_click.ps1'
$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$testDir = Join-Path ([IO.Path]::GetTempPath()) ('vivado_zh_launcher_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testDir | Out-Null
$oldOptions = $env:JAVA_TOOL_OPTIONS
$oldVivado = $env:XILINX_VIVADO

function Assert([bool]$condition, [string]$message) {
    if (-not $condition) { throw $message }
}

try {
    # Import only helper function definitions, not the launcher's executable body.
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($launcher, [ref]$null, [ref]$parseErrors)
    Assert ($parseErrors.Count -eq 0) 'PowerShell 5 parser rejected the launcher.'
    foreach ($name in @('Get-Version','Get-Java')) {
        $definition = $ast.FindAll({param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst]}, $true) | Where-Object Name -eq $name | Select-Object -First 1
        Assert ($null -ne $definition) ("Missing helper: $name")
        . ([scriptblock]::Create($definition.Extent.Text))
    }
    Assert ((Get-Version 'C:\archive\2020.1\2025.2\Vivado') -eq '2025.2') 'Version must come from the nearest path component.'
    Assert ((Get-Version 'C:\Xilinx\Vivado\2019.2') -eq '2019.2') 'Classic Vivado path was not recognized.'
    Assert ((Get-Version 'C:\Apps\Vivado') -eq 'unknown') 'Unknown version should remain unknown.'

    $fakeRoot = Join-Path $testDir '2020.1\archive\2025.2\Vivado'
    $fakeBin = Join-Path $fakeRoot 'bin'
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $fakeBin 'vivado.bat'), "@echo off`r`necho TEST_LAUNCHED`r`necho TEST_OPTIONS=%JAVA_TOOL_OPTIONS%`r`nexit /b 0`r`n", [Text.Encoding]::ASCII)
    foreach ($runtime in @('jre8.0','jre11.0','jre21.0','jdk-21.0')) {
        $bin = Join-Path $fakeRoot ("tps\win64\$runtime\bin")
        New-Item -ItemType Directory -Path $bin -Force | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $bin 'java.exe'), [byte[]]@())
    }
    Assert ((Get-Java $fakeRoot) -match '[\\/]jdk-21\.0[\\/]bin[\\/]java\.exe$') 'Select the newest Java major, preferring JDK to JRE for equal versions.'

    # Use a relocated directory containing Chinese characters and spaces.
    $patchCopy = Join-Path $testDir '汉化 patch copy'
    New-Item -ItemType Directory -Path $patchCopy | Out-Null
    foreach ($file in @('one_click.ps1','vivado-zh-agent.jar','translations.tsv')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination $patchCopy
    }
    $copyScript = Join-Path $patchCopy 'one_click.ps1'
    $env:JAVA_TOOL_OPTIONS = '-Dlauncher.test.preserved=true'
    $env:XILINX_VIVADO = $fakeRoot

    function Invoke-Launcher([string[]]$arguments, [string]$label) {
        $stdout=Join-Path $testDir ($label + '.out')
        $stderr=Join-Path $testDir ($label + '.err')
        $quoted=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$copyScript+'"'))
        foreach ($arg in $arguments) { $quoted += ('"'+$arg+'"') }
        $proc=Start-Process -FilePath $ps -ArgumentList $quoted -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        return [PSCustomObject]@{ ExitCode=$proc.ExitCode; Text=([IO.File]::ReadAllText($stdout) + [IO.File]::ReadAllText($stderr)) }
    }

    $ok = Invoke-Launcher @('-StartNew','-VivadoRoot',$fakeRoot) 'valid'
    Assert ($ok.ExitCode -eq 0) 'Valid explicit install should launch.'
    Assert ($ok.Text -match 'TEST_LAUNCHED') 'Fake Vivado did not run.'
    Assert ($ok.Text -match '-Dvivado\.zh\.version=2025\.2') 'Launcher supplied the wrong Vivado version.'
    Assert ($ok.Text -match '-Dlauncher\.test\.preserved=true') 'Existing Java options were not preserved.'

    $bad = Invoke-Launcher @('-StartNew','-VivadoRoot',(Join-Path $testDir 'missing')) 'invalid'
    Assert ($bad.ExitCode -ne 0) 'Invalid explicit install must fail even if XILINX_VIVADO is valid.'
    Assert ($bad.Text -notmatch 'TEST_LAUNCHED') 'Invalid explicit install fell back to another install.'

    $bad = Invoke-Launcher @('-StartNew','-ProcessId','123') 'conflicting'
    Assert ($bad.ExitCode -ne 0) 'Conflicting process and new-window options must fail.'
    Assert ($bad.Text -notmatch 'TEST_LAUNCHED') 'Conflicting options unexpectedly launched Vivado.'
    Write-Host 'PASS: launcher version detection, Java ordering, paths, options and fail-safe behavior'
} finally {
    $env:JAVA_TOOL_OPTIONS = $oldOptions
    $env:XILINX_VIVADO = $oldVivado
    $resolved = [IO.Path]::GetFullPath($testDir)
    $allowed = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $allowed.EndsWith([IO.Path]::DirectorySeparatorChar)) { $allowed += [IO.Path]::DirectorySeparatorChar }
    if ($resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -match '^vivado_zh_launcher_[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    } else { throw 'Refusing to remove an unexpected test path.' }
}
