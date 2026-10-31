$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ps = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$testDir = Join-Path ([IO.Path]::GetTempPath()) ('vivado_zh_build_' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $testDir 'src') -Force | Out-Null
try {
    foreach ($name in @('build.ps1','manifest.mf','translations.tsv','vivado-zh-agent.jar')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $name) -Destination $testDir
    }
    foreach ($name in @('VivadoChineseAgentV2.java','VivadoAttach.java')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot ('src\' + $name)) -Destination (Join-Path $testDir 'src')
    }
    # This intentionally compiles, then fails the runtime self-test.
    [IO.File]::WriteAllText((Join-Path $testDir 'src\TranslationSelfTest.java'), 'public class TranslationSelfTest { public static void main(String[] a) { throw new AssertionError("intentional failure"); } }', [Text.Encoding]::ASCII)
    $target = Join-Path $testDir 'vivado-zh-agent.jar'
    $before = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    $stdout = Join-Path $testDir 'stdout.txt'
    $stderr = Join-Path $testDir 'stderr.txt'
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"' + (Join-Path $testDir 'build.ps1') + '"'))
    $proc = Start-Process -FilePath $ps -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if ($proc.ExitCode -eq 0) { throw 'A failing self-test must make the build fail.' }
    $after = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($before -ne $after) { throw 'A failing self-test replaced the existing JAR.' }
    Write-Host 'PASS: failed build self-test preserves the previous JAR'
} finally {
    $resolved = [IO.Path]::GetFullPath($testDir)
    $allowed = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $allowed.EndsWith([IO.Path]::DirectorySeparatorChar)) { $allowed += [IO.Path]::DirectorySeparatorChar }
    if ($resolved.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -match '^vivado_zh_build_[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
    } else { throw 'Refusing to remove an unexpected test path.' }
}
