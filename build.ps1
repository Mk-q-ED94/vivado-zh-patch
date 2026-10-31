param([string]$JdkHome = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $JdkHome) { $JdkHome=$env:JAVA_HOME }
if ($JdkHome) {
    $javac=Join-Path $JdkHome 'bin\javac.exe'
    $jar=Join-Path $JdkHome 'bin\jar.exe'
    $java=Join-Path $JdkHome 'bin\java.exe'
} else {
    $javac=(Get-Command javac.exe -ErrorAction Stop).Source
    $jar=(Get-Command jar.exe -ErrorAction Stop).Source
    $java=(Get-Command java.exe -ErrorAction Stop).Source
}
foreach ($tool in @($javac,$jar,$java)) { if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "JDK tool not found: $tool" } }
$build=Join-Path $root ('.build\' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $build | Out-Null
$sources=@('VivadoChineseAgentV2.java','VivadoAttach.java','TranslationSelfTest.java') | ForEach-Object { Join-Path (Join-Path $root 'src') $_ }
& $javac --release 8 -Xlint:-options -encoding UTF-8 -d $build $sources
if ($LASTEXITCODE -ne 0) { throw 'Compilation failed. A JDK 9 or newer is required for --release.' }
$newJar=Join-Path $build 'vivado-zh-agent.jar'
& $jar cfm $newJar (Join-Path $root 'manifest.mf') -C $build .
if ($LASTEXITCODE -ne 0) { throw 'JAR creation failed.' }
$target=Join-Path $root 'vivado-zh-agent.jar'
Copy-Item -LiteralPath $newJar -Destination $target -Force
& $java '-Djava.awt.headless=true' ("-javaagent:$target") -cp $target TranslationSelfTest
if ($LASTEXITCODE -ne 0) { throw 'Agent self-test failed.' }
Write-Host 'Build and basic self-test completed.'
