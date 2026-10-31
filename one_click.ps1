param([switch]$StartNew, [string]$VivadoRoot = '', [int]$ProcessId = 0)
$ErrorActionPreference = 'Stop'
$patchDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$agentJar = Join-Path $patchDir 'vivado-zh-agent.jar'
$wordFile = Join-Path $patchDir 'translations.tsv'
if (-not (Test-Path -LiteralPath $agentJar -PathType Leaf) -or -not (Test-Path -LiteralPath $wordFile -PathType Leaf)) {
    Write-Host '补丁文件不完整：需要 vivado-zh-agent.jar 和 translations.tsv。' -ForegroundColor Red
    exit 1
}

function Get-Version([string]$p) {
    if ($p -match '(?<!\d)(20\d\d\.\d{1,2})(?!\d)') { return $Matches[1] }
    return 'unknown'
}
function Get-VivadoRoot([string]$exe) {
    $p = Split-Path -Parent $exe
    1..3 | ForEach-Object { $p = Split-Path -Parent $p }
    return $p
}
function Get-Java([string]$root) {
    $bases = @((Join-Path $root 'tps\win64'), (Join-Path (Split-Path -Parent $root) 'tps\win64'))
    foreach ($base in $bases) {
        if (Test-Path -LiteralPath $base -PathType Container) {
            $dirs = @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(jre|jdk)' } | Sort-Object Name -Descending)
            foreach ($dir in $dirs) {
                $java = Join-Path $dir.FullName 'bin\java.exe'
                if (Test-Path -LiteralPath $java -PathType Leaf) { return $java }
            }
        }
    }
    $java = Get-Command java.exe -ErrorAction SilentlyContinue
    if ($java) { return $java.Source }
    return $null
}
function Find-Install {
    $found = New-Object 'System.Collections.Generic.List[string]'
    foreach ($candidate in @($VivadoRoot,$env:XILINX_VIVADO,$env:VIVADO_HOME)) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'bin\vivado.bat') -PathType Leaf)) { $found.Add($candidate) }
    }
    if ($found.Count -gt 0) { return $found[0] }
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem)) {
        $root = $drive.Root
        foreach ($vendor in @('AMDDesignTools','Xilinx')) {
            $base = Join-Path $root $vendor
            if (-not (Test-Path -LiteralPath $base -PathType Container)) { continue }
            foreach ($dir in @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue)) {
                foreach ($p in @((Join-Path $dir.FullName 'Vivado'),$dir.FullName)) {
                    if (Test-Path -LiteralPath (Join-Path $p 'bin\vivado.bat') -PathType Leaf) { $found.Add($p) }
                }
            }
            $old = Join-Path $base 'Vivado'
            if (Test-Path -LiteralPath $old -PathType Container) {
                foreach ($dir in @(Get-ChildItem -LiteralPath $old -Directory -ErrorAction SilentlyContinue)) {
                    if (Test-Path -LiteralPath (Join-Path $dir.FullName 'bin\vivado.bat') -PathType Leaf) { $found.Add($dir.FullName) }
                }
            }
        }
    }
    $inPath=Get-Command vivado.bat -ErrorAction SilentlyContinue
    if ($inPath) { $found.Add((Split-Path -Parent (Split-Path -Parent $inPath.Source))) }
    $sorted = @($found | Sort-Object -Unique | Sort-Object { $v=Get-Version $_; if ($v -eq 'unknown') { [version]'0.0' } else { [version]$v } } -Descending)
    if ($sorted.Count -gt 0) { return $sorted[0] }
    return $null
}

$running = @()
if (-not $StartNew) {
    foreach ($p in @(Get-Process -Name vivado -ErrorAction SilentlyContinue)) {
        try {
            if ($p.MainWindowHandle -ne 0 -and $p.Path -match '[\\/]bin[\\/]unwrapped[\\/][^\\/]+[\\/]vivado\.exe$' -and (Test-Path -LiteralPath (Join-Path (Get-VivadoRoot $p.Path) 'bin\vivado.bat') -PathType Leaf)) {
                $running += [PSCustomObject]@{ Id=$p.Id; Path=$p.Path; Title=$p.MainWindowTitle; Root=(Get-VivadoRoot $p.Path) }
            }
        } catch { }
    }
}
$selected = $null
if ($ProcessId -gt 0) {
    $candidates = @($running | Where-Object { $_.Id -eq $ProcessId })
    if ($candidates.Count -ne 1) { Write-Host '指定的 PID 不是可见的 Vivado 主窗口。'; exit 1 }
    $selected = $candidates[0]
}
elseif ($running.Count -eq 1) { $selected=$running[0] }
elseif ($running.Count -gt 1) {
    Write-Host '发现多个 Vivado 窗口，请输入需要汉化的编号：'
    for ($i=0; $i -lt $running.Count; $i++) { Write-Host ("{0}. PID {1}  {2}" -f ($i+1),$running[$i].Id,$running[$i].Title) }
    $choice=Read-Host '编号（输入 0 则启动新窗口）'
    $n=0
    if (-not [int]::TryParse($choice,[ref]$n) -or $n -lt 0 -or $n -gt $running.Count) { Write-Host '编号无效。'; exit 1 }
    if ($n -gt 0) { $selected=$running[$n-1] }
}
$root = if ($selected) { $selected.Root } else { Find-Install }
if (-not $root -or -not (Test-Path -LiteralPath (Join-Path $root 'bin\vivado.bat') -PathType Leaf)) {
    Write-Host '未找到 Vivado。可通过参数 -VivadoRoot 指定包含 bin\vivado.bat 的目录。' -ForegroundColor Red
    exit 1
}
$version = Get-Version $root
Write-Host ("已找到 Vivado {0}: {1}" -f $version,$root)
if ($version -ne '2025.2') { Write-Host '此版本使用通用界面兼容模式；流程导航专用适配只在 2025.2 中启用，其他版本尚未完整验证。' -ForegroundColor Yellow }

if ($selected) {
    $java=Get-Java $root
    $legacy=$false
    if ($java) {
        $jcmd=Join-Path (Split-Path -Parent $java) 'jcmd.exe'
        if (Test-Path -LiteralPath $jcmd -PathType Leaf) {
            try { $jvmInfo = (& $jcmd $selected.Id VM.command_line 2>&1 | Out-String) } catch { $jvmInfo = '' }
            if ($jvmInfo -match 'Vivado2025_zh[/\\]vivado-zh-agent\.jar') { $legacy=$true }
        }
    }
    if ($legacy) {
        Write-Host '检测到旧版补丁：为避免重复注入，将保留原窗口并启动新的增强版窗口。' -ForegroundColor Yellow
    } elseif ($java) {
        $cp=$agentJar
        $toolsJar=Join-Path (Split-Path -Parent (Split-Path -Parent $java)) 'lib\tools.jar'
        if (Test-Path -LiteralPath $toolsJar -PathType Leaf) { $cp += ';' + $toolsJar }
        Write-Host ("正在向 Vivado 窗口 PID {0} 注入..." -f $selected.Id)
        $attachExit=1
        try { & $java -cp $cp VivadoAttach ("$($selected.Id)") $agentJar $version 2>&1 | ForEach-Object { Write-Host $_ }; $attachExit=$LASTEXITCODE } catch { Write-Host ("附加诊断：" + $_.Exception.Message) }
        if ($attachExit -eq 0) {
            Write-Host '注入成功；重新启动原版 Vivado 可以恢复英文界面。' -ForegroundColor Green
            exit 0
        }
        Write-Host '当前进程无法安全注入，将保留原窗口并启动新的增强版窗口。' -ForegroundColor Yellow
    } else { Write-Host '未找到可用 Java 附加工具，将启动新的增强版窗口。' -ForegroundColor Yellow }
}

if ($env:JAVA_TOOL_OPTIONS -match 'vivado-zh-agent\.jar') {
    Write-Host '当前环境已包含其他汉化 agent；为避免重复加载，请先在此命令行移除该环境选项再启动。' -ForegroundColor Red
    exit 1
}
$prior=$env:JAVA_TOOL_OPTIONS
$jarOption='-javaagent:"' + $agentJar + '"'
$env:JAVA_TOOL_OPTIONS=($prior + ' ' + $jarOption + ' -Dvivado.zh.version=' + $version).Trim()
$work=Join-Path $env:LOCALAPPDATA 'VivadoZhPatch\work'
New-Item -ItemType Directory -Force -Path $work | Out-Null
Push-Location $work
try {
    Write-Host '正在启动汉化版 Vivado；启动后请保留此窗口，直到退出 Vivado。'
    & (Join-Path $root 'bin\vivado.bat') -mode gui
    exit $LASTEXITCODE
} finally { Pop-Location; $env:JAVA_TOOL_OPTIONS=$prior }
