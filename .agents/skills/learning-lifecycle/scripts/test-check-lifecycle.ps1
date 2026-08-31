[CmdletBinding()]
param(
    [Parameter()]
    [string]$CheckerPath = (Join-Path $PSScriptRoot 'check-lifecycle.ps1')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:CheckerPath = (Resolve-Path -LiteralPath $CheckerPath).Path
$script:PowerShellPath = (Get-Process -Id $PID).Path
$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:Passed = 0
$script:Failed = 0
$script:StageTargets = @{
    'baseline-diagnostic' = 'BD-01'
    'motion-change' = 'MC-01'
    'probability-thermal' = 'PT-01'
    'quantum-foundations' = 'QF-01'
    'quantum-statistics' = 'QS-01'
    'trial-quantum-information' = 'TQI-01'
    'trial-condensed-matter' = 'TCM-01'
    'trial-optics' = 'TO-01'
    'direction-selection' = 'DS-01'
}
$script:StageNames = @{
    'baseline-diagnostic' = '基线诊断'
    'motion-change' = '运动与变化'
    'probability-thermal' = '概率与热统'
    'quantum-foundations' = '量子基础'
    'quantum-statistics' = '量子统计'
    'trial-quantum-information' = '量子信息试学'
    'trial-condensed-matter' = '凝聚态试学'
    'trial-optics' = '光学试学'
    'direction-selection' = '方向选择'
}
$script:StageDependencies = @{
    'baseline-diagnostic' = 'none'
    'motion-change' = 'none'
    'probability-thermal' = 'none'
    'quantum-foundations' = 'none'
    'quantum-statistics' = 'probability-thermal, quantum-foundations'
    'trial-quantum-information' = 'none'
    'trial-condensed-matter' = 'none'
    'trial-optics' = 'none'
    'direction-selection' = 'trial-quantum-information, trial-condensed-matter, trial-optics'
}
$script:StageDates = @{
    'baseline-diagnostic' = '2026-08-01'
    'motion-change' = '2026-08-02'
    'probability-thermal' = '2026-08-03'
    'quantum-foundations' = '2026-08-04'
    'quantum-statistics' = '2026-08-05'
    'trial-quantum-information' = '2026-08-06'
    'trial-condensed-matter' = '2026-08-07'
    'trial-optics' = '2026-08-08'
    'direction-selection' = '2026-08-09'
}

function Write-FixtureFile {
    param(
        [string]$Root,
        [string]$RelativePath,
        [string]$Content
    )

    $path = Join-Path $Root ($RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
    $directory = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }
    [System.IO.File]::WriteAllText($path, ($Content.TrimStart("`r", "`n") + "`n"), $script:Utf8NoBom)
}

function Read-FixtureFile {
    param([string]$Root, [string]$RelativePath)
    return [System.IO.File]::ReadAllText((Join-Path $Root ($RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar))))
}

function Replace-FixtureText {
    param(
        [string]$Root,
        [string]$RelativePath,
        [string]$OldValue,
        [string]$NewValue
    )

    $content = Read-FixtureFile -Root $Root -RelativePath $RelativePath
    if (-not $content.Contains($OldValue)) {
        throw "夹具替换失败，未找到文本：$RelativePath :: $OldValue"
    }
    Write-FixtureFile -Root $Root -RelativePath $RelativePath -Content $content.Replace($OldValue, $NewValue)
}

function Set-StageDependency {
    param([string]$Root, [string]$StageId, [string]$Dependency)

    $index = Read-FixtureFile -Root $Root -RelativePath 'roadmap/index.md'
    $oldRow = '| {0} | 1 | {0}.md | {1} | none |' -f $StageId, $script:StageDependencies[$StageId]
    $newRow = '| {0} | 1 | {0}.md | {1} | none |' -f $StageId, $Dependency
    if (-not $index.Contains($oldRow)) { throw "路线注册表中找不到阶段：$StageId" }
    Write-FixtureFile -Root $Root -RelativePath 'roadmap/index.md' -Content $index.Replace($oldRow, $newRow)

    Replace-FixtureText -Root $Root -RelativePath ("roadmap/$StageId.md") -OldValue ("- depends_on: " + $script:StageDependencies[$StageId]) -NewValue ("- depends_on: " + $Dependency)
}

function New-BaseFixture {
    param([string]$Root)

    [void][System.IO.Directory]::CreateDirectory($Root)
    $rows = [System.Collections.Generic.List[string]]::new()
    foreach ($stageId in $script:StageTargets.Keys) {
        $rows.Add(('| {0} | 1 | {0}.md | {1} | none |' -f $stageId, $script:StageDependencies[$stageId]))
    }
    $index = @"
# 最小路线夹具

| stage_id | contract_version | route_file | depends_on | unlocks |
|---|---:|---|---|---|
$($rows -join "`n")
"@
    Write-FixtureFile -Root $Root -RelativePath 'roadmap/index.md' -Content $index

    foreach ($stageId in $script:StageTargets.Keys) {
        $targetId = $script:StageTargets[$stageId]
        $minimum = if ($stageId -eq 'baseline-diagnostic') { 'sampled' } else { 'independent' }
        $kind = if ($stageId -eq 'baseline-diagnostic') { '诊断' } else { '教学' }
        $route = @"
# $($script:StageNames[$stageId])

## 阶段：$($script:StageNames[$stageId]) {#$stageId}
- stage_id: $stageId
- contract_version: 1
- pace_hint: 约 1 周
- depends_on: $($script:StageDependencies[$stageId])

### 阶段目的

形成阶段能力。

### 教学范围

覆盖目标所需知识与方法。

### 局部活动门槛

仅在依赖活动前检查具体能力。

### 退出目标

| target_id | 类型 | 可观察表现 | 最低证据 | 代表性任务 |
|---|---|---|---|---|
| $targetId | $kind | 给出可核验表现 | $minimum | 完成代表性任务 |

### 阶段成果

形成可复核成果。

### 退出条件与解锁

目标达标并通过退出审计后解锁下游。
"@
        Write-FixtureFile -Root $Root -RelativePath ("roadmap/$stageId.md") -Content $route
    }

    $learningTemplate = @'
---
date: YYYY-MM-DD
stage_id: stage-id
activity: learning
target_ids:
  - TARGET-00
topic: 主题
planned_minutes: 90
status: planned
---

# 学习单

## 本次目标

<!-- 实例化后填写。 -->

## 前置检查

<!-- 实例化后填写。 -->

## 学习内容

<!-- 实例化后填写。 -->

## 练习

<!-- 实例化后填写。 -->

## 用户结果

<!-- 学习者作答。 -->

## AI 批阅

<!-- 批阅后填写。 -->

| target_id | help | evidence_state | evidence | correction_closure | review_debt |
|---|---|---|---|---|---|
| TARGET-00 | 待填写 | 待填写 | 待填写 | 待填写 | 待填写 |

## 下一步

<!-- 批阅后填写。 -->

## 相关项目与资料

<!-- 按需填写。 -->
'@
    Write-FixtureFile -Root $Root -RelativePath 'templates/learning-session.md' -Content $learningTemplate

    $checkpointTemplate = @'
---
stage_id: stage-id
contract_version: 1
completed_on: YYYY-MM-DD
decision: passed
---

# 阶段检查点

## 逐目标证据

| target_id | evidence_level | evidence_files | independence_or_transfer |
|---|---|---|---|
| TARGET-00 | independent | [已批阅学习单](../../sessions/YYYY/MM/YYYY-MM-DD-topic.md) | 实例化后填写 |

## 独立性与迁移说明

<!-- 通过后填写。 -->

## 非阻断问题

<!-- 通过后填写。 -->

## 解锁结果

<!-- 通过后填写。 -->
'@
    Write-FixtureFile -Root $Root -RelativePath 'templates/stage-checkpoint.md' -Content $checkpointTemplate
    Set-CurrentState -Root $Root
}

function Set-CurrentState {
    param(
        [string]$Root,
        [string]$FocusStageId = 'baseline-diagnostic',
        [string]$FocusMode = 'work',
        [string]$FocusState,
        [string]$FocusEvidence = 'none',
        [object[]]$ParallelRows = @(),
        [string]$NextStageId,
        [string]$NextActivity,
        [string]$NextTargetId
    )

    $focusTargetId = $script:StageTargets[$FocusStageId]
    if ([string]::IsNullOrWhiteSpace($FocusState)) {
        $FocusState = if ($FocusStageId -eq 'baseline-diagnostic') { 'unsampled' } else { 'not_started' }
    }
    if ([string]::IsNullOrWhiteSpace($NextStageId)) { $NextStageId = $FocusStageId }
    if ([string]::IsNullOrWhiteSpace($NextActivity)) {
        $NextActivity = if ($NextStageId -eq 'baseline-diagnostic') { 'diagnostic' } else { 'learning' }
    }
    if ([string]::IsNullOrWhiteSpace($NextTargetId)) { $NextTargetId = $script:StageTargets[$NextStageId] }

    $parallelIds = @($ParallelRows | ForEach-Object { $_.StageId } | Sort-Object -Unique)
    $parallelYaml = if ($parallelIds.Count -eq 0) {
        'parallel_stage_ids: []'
    }
    else {
        "parallel_stage_ids:`n" + (($parallelIds | ForEach-Object { "  - $_" }) -join "`n")
    }
    $parallelTableRows = if ($ParallelRows.Count -eq 0) {
        ''
    }
    else {
        ($ParallelRows | ForEach-Object {
                '| {0} | {1} | {2} | {3} | {4} |' -f $_.StageId, $_.TargetId, $_.State, $_.Evidence, $_.Unmet
            }) -join "`n"
    }

    $current = @"
---
updated: 2026-08-31
focus_stage_id: $FocusStageId
focus_mode: $FocusMode
$parallelYaml
---

# 当前执行板

## 当前阶段目标状态

| target_id | state | evidence | unmet |
|---|---|---|---|
| $focusTargetId | $FocusState | $FocusEvidence | 尚有待办 |

## 合法的并行学习线

| stage_id | target_ids | state | evidence | unmet |
|---|---|---|---|---|
$parallelTableRows

## 关键能力复核队列

| target_id | due | task | status |
|---|---|---|---|

## 唯一下一学习任务

- stage_id: $NextStageId
- activity: $NextActivity
- target_ids: $NextTargetId
- task: 完成一项尚未满足的具体任务
"@
    Write-FixtureFile -Root $Root -RelativePath 'state/current.md' -Content $current
}

function Add-Session {
    param(
        [string]$Root,
        [string]$StageId,
        [string]$Status = 'planned',
        [string]$EvidenceState,
        [string]$Date,
        [string]$Slug,
        [string]$UserText,
        [string]$AiText,
        [switch]$OmitEvidenceTable
    )

    $targetId = $script:StageTargets[$StageId]
    if ([string]::IsNullOrWhiteSpace($Date)) { $Date = $script:StageDates[$StageId] }
    if ([string]::IsNullOrWhiteSpace($EvidenceState)) {
        $EvidenceState = if ($StageId -eq 'baseline-diagnostic') { 'sampled' } else { 'independent' }
    }
    if ([string]::IsNullOrEmpty($UserText)) {
        $UserText = if ($Status -in @('submitted', 'reviewed')) { '学习者提交了可核验结果。' } else { '<!-- 学习者作答。 -->' }
    }
    if ([string]::IsNullOrEmpty($AiText)) {
        $AiText = if ($Status -eq 'reviewed') { '已完成逐目标批阅。' } else { '<!-- 批阅后填写。 -->' }
    }
    $evidenceTable = if ($Status -eq 'reviewed' -and -not $OmitEvidenceTable) {
        @"

| target_id | help | evidence_state | evidence | correction_closure | review_debt |
|---|---|---|---|---|---|
| $targetId | none | $EvidenceState | 已记录可核验表现 | 无需订正 | 已记录复核债务 |
"@
    }
    else { '' }
    $activity = if ($StageId -eq 'baseline-diagnostic') { 'diagnostic' } else { 'learning' }
    if ([string]::IsNullOrWhiteSpace($Slug)) { $Slug = $StageId }
    $relative = 'sessions/{0}/{1}/{2}-{3}.md' -f $Date.Substring(0, 4), $Date.Substring(5, 2), $Date, $Slug
    $session = @"
---
date: $Date
stage_id: $StageId
activity: $activity
target_ids:
  - $targetId
topic: $($script:StageNames[$StageId])夹具
planned_minutes: 90
status: $Status
---

# 学习单

## 本次目标

取得目标证据。

## 前置检查

确认题意。

## 学习内容

完成必要学习。

## 练习

完成一项练习。

## 用户结果

$UserText

## AI 批阅

$AiText$evidenceTable

## 下一步

依据证据继续。

## 相关项目与资料

无外部项目。
"@
    Write-FixtureFile -Root $Root -RelativePath $relative -Content $session
    return $relative
}

function Add-Checkpoint {
    param(
        [string]$Root,
        [string]$StageId,
        [string]$SessionRelativePath,
        [string]$EvidenceLevel,
        [string]$Date
    )

    if ([string]::IsNullOrWhiteSpace($Date)) { $Date = $script:StageDates[$StageId] }
    if ([string]::IsNullOrWhiteSpace($EvidenceLevel)) {
        $EvidenceLevel = if ($StageId -eq 'baseline-diagnostic') { 'sampled' } else { 'independent' }
    }
    $targetId = $script:StageTargets[$StageId]
    $evidenceLink = '../../' + $SessionRelativePath
    $checkpoint = @"
---
stage_id: $StageId
contract_version: 1
completed_on: $Date
decision: passed
---

# 阶段检查点

## 逐目标证据

| target_id | evidence_level | evidence_files | independence_or_transfer |
|---|---|---|---|
| $targetId | $EvidenceLevel | [证据]($evidenceLink) | 已记录独立性或起点结论 |

## 独立性与迁移说明

已完成人工退出审计。

## 非阻断问题

无。

## 解锁结果

由路线依赖推导。
"@
    Write-FixtureFile -Root $Root -RelativePath ("checkpoints/stages/$Date-$StageId.md") -Content $checkpoint
}

function Close-Stage {
    param([string]$Root, [string]$StageId)
    $session = Add-Session -Root $Root -StageId $StageId -Status reviewed
    Add-Checkpoint -Root $Root -StageId $StageId -SessionRelativePath $session
}

function Invoke-Checker {
    param([string]$Root)

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $script:PowerShellPath
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @('-NoProfile', '-File', $script:CheckerPath, '-Root', $Root)) {
        [void]$startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $output = ($stdout + $stderr).Trim()
    $codes = @([regex]::Matches($output, 'ERROR \[(?<code>[A-Z0-9_]+)\]') | ForEach-Object { $_.Groups['code'].Value })
    return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $output; Codes = $codes }
}

function Invoke-TestCase {
    param(
        [string]$Name,
        [scriptblock]$Arrange,
        [int]$ExpectedExitCode,
        [string[]]$ExpectedCodes = @()
    )

    $root = Join-Path $script:SuiteRoot ('case-' + [guid]::NewGuid().ToString('N'))
    try {
        New-BaseFixture -Root $root
        if ($null -ne $Arrange) { & $Arrange $root }
        $result = Invoke-Checker -Root $root
        $problems = [System.Collections.Generic.List[string]]::new()
        if ($result.ExitCode -ne $ExpectedExitCode) {
            $problems.Add("退出码应为 $ExpectedExitCode，实际为 $($result.ExitCode)")
        }
        foreach ($code in $ExpectedCodes) {
            if ($code -notin $result.Codes) { $problems.Add("缺少错误码 $code") }
        }
        if ($ExpectedExitCode -eq 0 -and $result.Codes.Count -ne 0) {
            $problems.Add('成功用例不应输出 ERROR 错误码')
        }
        if ($problems.Count -gt 0) {
            $script:Failed++
            Write-Output ("FAIL {0}: {1}" -f $Name, ($problems -join '；'))
            if ($result.Output) { Write-Output $result.Output }
        }
        else {
            $script:Passed++
            Write-Output ("PASS {0}" -f $Name)
        }
    }
    catch {
        $script:Failed++
        Write-Output ("FAIL {0}: 夹具或测试器异常：{1}" -f $Name, $_.Exception.Message)
    }
}

$script:SuiteRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('learning-lifecycle-tests-' + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($script:SuiteRoot)

try {
    Invoke-TestCase -Name '合法最小仓库与模板实例化' -Arrange {} -ExpectedExitCode 0

    Invoke-TestCase -Name '学习单缺少标题' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue '## 练习' -NewValue '### 练习'
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_MISSING_HEADING')

    Invoke-TestCase -Name '学习单重复标题' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue '## 用户结果' -NewValue "## 练习`n`n重复练习。`n`n## 用户结果"
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_DUPLICATE_HEADING')

    Invoke-TestCase -Name '学习单标题乱序' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue '## 前置检查' -NewValue '## 临时标题'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue '## 学习内容' -NewValue '## 前置检查'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue '## 临时标题' -NewValue '## 学习内容'
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_HEADING_ORDER')

    Invoke-TestCase -Name '学习单路径日期不一致' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change' -Date '2026-08-10'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue 'date: 2026-08-10' -NewValue 'date: 2026-08-11'
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_PATH_DATE')

    Invoke-TestCase -Name '学习单非法状态' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue 'status: planned' -NewValue 'status: finished'
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_STATUS')

    Invoke-TestCase -Name '学习单非法活动' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue 'activity: learning' -NewValue 'activity: tutoring'
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_ACTIVITY')

    Invoke-TestCase -Name '学习单未知阶段' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue 'stage_id: motion-change' -NewValue 'stage_id: missing-stage'
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_UNKNOWN_STAGE')

    Invoke-TestCase -Name '学习单未知目标' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue '  - MC-01' -NewValue '  - UNKNOWN-99'
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_UNKNOWN_TARGET')

    Invoke-TestCase -Name '学习单前置区解析失败' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue 'date: 2026-08-02' -NewValue "date: 2026-08-02`n这不是合法字段"
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_YAML_PARSE')

    Invoke-TestCase -Name '路线非法阶段 ID' -Arrange {
        param($root)
        Replace-FixtureText -Root $root -RelativePath 'roadmap/index.md' -OldValue '| motion-change | 1 | motion-change.md | none | none |' -NewValue '| Motion Change | 1 | motion-change.md | none | none |'
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_STAGE_ID')

    Invoke-TestCase -Name '路线非法目标 ID' -Arrange {
        param($root)
        Replace-FixtureText -Root $root -RelativePath 'roadmap/motion-change.md' -OldValue '| MC-01 | 教学 |' -NewValue '| MC01 | 教学 |'
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_TARGET_ID')

    Invoke-TestCase -Name '路线阶段 ID 重复' -Arrange {
        param($root)
        $row = '| motion-change | 1 | motion-change.md | none | none |'
        Replace-FixtureText -Root $root -RelativePath 'roadmap/index.md' -OldValue $row -NewValue ("$row`n$row")
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_DUPLICATE_STAGE')

    Invoke-TestCase -Name '路线目标 ID 重复' -Arrange {
        param($root)
        Replace-FixtureText -Root $root -RelativePath 'roadmap/probability-thermal.md' -OldValue '| PT-01 | 教学 |' -NewValue '| MC-01 | 教学 |'
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_DUPLICATE_TARGET')

    Invoke-TestCase -Name '路线退出目标机器表不能重复' -Arrange {
        param($root)
        $row = '| MC-01 | 教学 | 给出可核验表现 | independent | 完成代表性任务 |'
        $duplicate = "$row`n`n| target_id | 类型 | 可观察表现 | 最低证据 | 代表性任务 |`n|---|---|---|---|---|`n$row"
        Replace-FixtureText -Root $root -RelativePath 'roadmap/motion-change.md' -OldValue $row -NewValue $duplicate
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_TARGET_PARSE_DUPLICATE')

    Invoke-TestCase -Name '阶段正文不得复制 unlocks 元数据' -Arrange {
        param($root)
        Replace-FixtureText -Root $root -RelativePath 'roadmap/motion-change.md' -OldValue '- depends_on: none' -NewValue "- depends_on: none`n- unlocks: probability-thermal"
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_CONTRACT_DUPLICATE_UNLOCKS')

    Invoke-TestCase -Name 'unlocks 导航摘要不能指向自身' -Arrange {
        param($root)
        Replace-FixtureText -Root $root -RelativePath 'roadmap/index.md' -OldValue '| motion-change | 1 | motion-change.md | none | none |' -NewValue '| motion-change | 1 | motion-change.md | none | motion-change |'
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_SELF_UNLOCK')

    Invoke-TestCase -Name '阶段契约版本与注册表不一致' -Arrange {
        param($root)
        Replace-FixtureText -Root $root -RelativePath 'roadmap/motion-change.md' -OldValue '- contract_version: 1' -NewValue '- contract_version: 2'
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_CONTRACT_VERSION_MISMATCH')

    Invoke-TestCase -Name '阶段契约不能缺少教学范围' -Arrange {
        param($root)
        Replace-FixtureText -Root $root -RelativePath 'roadmap/motion-change.md' -OldValue '### 教学范围' -NewValue '### 临时说明'
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_CONTRACT_SECTION')

    Invoke-TestCase -Name '路线注册表畸形数据行失败关闭' -Arrange {
        param($root)
        Replace-FixtureText -Root $root -RelativePath 'roadmap/index.md' -OldValue '| motion-change | 1 | motion-change.md | none | none |' -NewValue '| motion-change | 1 | motion-change.md | none |'
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_REGISTRY_PARSE')

    Invoke-TestCase -Name '未知阶段依赖' -Arrange {
        param($root)
        Set-StageDependency -Root $root -StageId 'motion-change' -Dependency 'missing-stage'
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_UNKNOWN_DEPENDENCY')

    Invoke-TestCase -Name '依赖环' -Arrange {
        param($root)
        Set-StageDependency -Root $root -StageId 'motion-change' -Dependency 'probability-thermal'
        Set-StageDependency -Root $root -StageId 'probability-thermal' -Dependency 'motion-change'
    } -ExpectedExitCode 1 -ExpectedCodes @('ROUTE_CYCLE')

    Invoke-TestCase -Name '合法并行学习线' -Arrange {
        param($root)
        $parallel = [pscustomobject]@{ StageId = 'motion-change'; TargetId = 'MC-01'; State = 'not_started'; Evidence = 'none'; Unmet = '等待教学' }
        Set-CurrentState -Root $root -ParallelRows @($parallel)
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '锁定阶段不能作为并行学习线' -Arrange {
        param($root)
        $parallel = [pscustomobject]@{ StageId = 'quantum-statistics'; TargetId = 'QS-01'; State = 'not_started'; Evidence = 'none'; Unmet = '上游尚未汇合' }
        Set-CurrentState -Root $root -ParallelRows @($parallel)
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_ILLEGAL_PARALLEL')

    Invoke-TestCase -Name '锁定阶段主要目标不能登记独立证据' -Arrange {
        param($root)
        [void](Add-Session -Root $root -StageId 'quantum-statistics' -Status reviewed -EvidenceState 'independent')
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_LOCKED_STAGE_EVIDENCE')

    Invoke-TestCase -Name '多阶段学习单的锁定次要目标不能登记独立证据' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'independent'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue '  - MC-01' -NewValue "  - MC-01`n  - QS-01"
        $row = '| MC-01 | none | independent | 已记录可核验表现 | 无需订正 | 已记录复核债务 |'
        $secondary = '| QS-01 | none | independent | 已记录可核验表现 | 无需订正 | 已记录复核债务 |'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue $row -NewValue "$row`n$secondary"
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_LOCKED_STAGE_EVIDENCE')

    foreach ($lockedActivity in @('assessment', 'project')) {
        Invoke-TestCase -Name "锁定阶段不能用 $lockedActivity 登记 guided 证据" -Arrange {
            param($root)
            $session = Add-Session -Root $root -StageId 'quantum-statistics' -Status reviewed -EvidenceState 'guided'
            Replace-FixtureText -Root $root -RelativePath $session -OldValue 'activity: learning' -NewValue ("activity: " + $lockedActivity)
        } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_LOCKED_STAGE_EVIDENCE')
    }

    Invoke-TestCase -Name '锁定阶段不能倒灌 needs_refresh 正式状态' -Arrange {
        param($root)
        [void](Add-Session -Root $root -StageId 'quantum-statistics' -Status reviewed -EvidenceState 'needs_refresh')
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_LOCKED_STAGE_EVIDENCE')

    Invoke-TestCase -Name '锁定阶段可以保留未来 planned 预览任务' -Arrange {
        param($root)
        [void](Add-Session -Root $root -StageId 'quantum-statistics' -Status planned)
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '当前阶段目标机器表不能重复' -Arrange {
        param($root)
        $row = '| BD-01 | unsampled | none | 尚有待办 |'
        $duplicate = "$row`n`n| target_id | state | evidence | unmet |`n|---|---|---|---|`n$row"
        Replace-FixtureText -Root $root -RelativePath 'state/current.md' -OldValue $row -NewValue $duplicate
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_TARGET_PARSE_DUPLICATE')

    Invoke-TestCase -Name '初始状态证据链接仍须指向合法证据类型' -Arrange {
        param($root)
        Write-FixtureFile -Root $root -RelativePath 'notes.md' -Content "# 普通说明`n"
        $parallel = [pscustomobject]@{ StageId = 'motion-change'; TargetId = 'MC-01'; State = 'not_started'; Evidence = '[普通说明](../notes.md)'; Unmet = '等待教学' }
        Set-CurrentState -Root $root -ParallelRows @($parallel)
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_EVIDENCE_TYPE')

    Invoke-TestCase -Name 'needs_refresh 不能由旧通过检查点支持' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change' -Status reviewed
        Add-Checkpoint -Root $root -StageId 'motion-change' -SessionRelativePath $session
        $checkpointPath = 'checkpoints/stages/{0}-motion-change.md' -f $script:StageDates['motion-change']
        $parallel = [pscustomobject]@{ StageId = 'motion-change'; TargetId = 'MC-01'; State = 'needs_refresh'; Evidence = "[旧检查点](../$checkpointPath)"; Unmet = '需要新的遗忘证据' }
        Set-CurrentState -Root $root -ParallelRows @($parallel)
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_EVIDENCE_STRENGTH')

    Invoke-TestCase -Name '较新 needs_refresh 压过旧 robust 与历史检查点' -Arrange {
        param($root)
        $oldSession = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'robust' -Date '2026-08-02'
        Add-Checkpoint -Root $root -StageId 'motion-change' -SessionRelativePath $oldSession -EvidenceLevel 'independent'
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'needs_refresh' -Date '2026-08-10')
        $parallel = [pscustomobject]@{ StageId = 'motion-change'; TargetId = 'MC-01'; State = 'robust'; Evidence = "[旧证据](../$oldSession)"; Unmet = '错误地忽略了后续遗忘' }
        Set-CurrentState -Root $root -ParallelRows @($parallel)
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_STALE_EVIDENCE')

    Invoke-TestCase -Name '同日 needs_refresh 压过所有同日强证据' -Arrange {
        param($root)
        $strong = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'robust' -Date '2026-08-10' -Slug 'z-strong'
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'needs_refresh' -Date '2026-08-10' -Slug 'a-refresh')
        $parallel = [pscustomobject]@{ StageId = 'motion-change'; TargetId = 'MC-01'; State = 'robust'; Evidence = "[同日强证据](../$strong)"; Unmet = '错误地用文件名推断日内先后' }
        Set-CurrentState -Root $root -ParallelRows @($parallel)
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_STALE_EVIDENCE')

    foreach ($recoveredState in @('independent', 'robust')) {
        Invoke-TestCase -Name "needs_refresh 后可由较新 $recoveredState 恢复" -Arrange {
            param($root)
            [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'robust' -Date '2026-08-02')
            [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'needs_refresh' -Date '2026-08-10')
            $recovery = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState $recoveredState -Date '2026-08-20'
            $parallel = [pscustomobject]@{ StageId = 'motion-change'; TargetId = 'MC-01'; State = $recoveredState; Evidence = "[恢复证据](../$recovery)"; Unmet = '按目标最低证据继续安排' }
            Set-CurrentState -Root $root -ParallelRows @($parallel)
        } -ExpectedExitCode 0
    }

    Invoke-TestCase -Name '已通过阶段出现 needs_refresh 后可局部重开' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        Close-Stage -Root $root -StageId 'motion-change'
        $refresh = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'needs_refresh' -Date '2026-08-10'
        Set-CurrentState -Root $root -FocusStageId 'motion-change' -FocusState 'needs_refresh' -FocusEvidence "[遗忘证据](../$refresh)" -NextActivity 'assessment'
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '重开后只有 guided 时补强债务仍保持开放' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        Close-Stage -Root $root -StageId 'motion-change'
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'needs_refresh' -Date '2026-08-10')
        $guided = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'guided' -Date '2026-08-20'
        Set-CurrentState -Root $root -FocusStageId 'motion-change' -FocusState 'guided' -FocusEvidence "[补强中证据](../$guided)" -NextActivity 'assessment'
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '重开后恢复最低证据即可关闭补强债务' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        Close-Stage -Root $root -StageId 'motion-change'
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'needs_refresh' -Date '2026-08-10')
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'independent' -Date '2026-08-20')
        Set-CurrentState -Root $root -FocusStageId 'probability-thermal'
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '已通过阶段没有 needs_refresh 时仍不能重开' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        Close-Stage -Root $root -StageId 'motion-change'
        Set-CurrentState -Root $root -FocusStageId 'motion-change'
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_COMPLETED_FOCUS', 'NEXT_LOCKED_STAGE')

    Invoke-TestCase -Name 'current.updated 之后的完成阶段 needs_refresh 必须同步' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        Close-Stage -Root $root -StageId 'motion-change'
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'needs_refresh' -Date '2026-08-10')
        Set-CurrentState -Root $root -FocusStageId 'probability-thermal'
        Replace-FixtureText -Root $root -RelativePath 'state/current.md' -OldValue 'updated: 2026-08-31' -NewValue 'updated: 2026-08-05'
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_FUTURE_REVIEWED_EVIDENCE')

    Invoke-TestCase -Name '晚于 current.updated 但不改变当前状态的 reviewed 学习单可保留' -Arrange {
        param($root)
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'independent' -Date '2026-08-20')
        Replace-FixtureText -Root $root -RelativePath 'state/current.md' -OldValue 'updated: 2026-08-31' -NewValue 'updated: 2026-08-15'
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '未来 reviewed 学习单失败关闭' -Arrange {
        param($root)
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'independent' -Date '2099-01-01')
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_FUTURE_REVIEWED_EVIDENCE')

    Invoke-TestCase -Name '未来 planned 学习单允许预先安排' -Arrange {
        param($root)
        [void](Add-Session -Root $root -StageId 'motion-change' -Status planned -Date '2099-01-01')
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '未来 passed checkpoint 失败关闭' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'baseline-diagnostic' -Status reviewed -EvidenceState 'sampled' -Date '2099-01-01'
        Add-Checkpoint -Root $root -StageId 'baseline-diagnostic' -SessionRelativePath $session -Date '2099-01-01'
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_FUTURE_CHECKPOINT')

    Invoke-TestCase -Name 'submitted 用户结果为空' -Arrange {
        param($root)
        [void](Add-Session -Root $root -StageId 'motion-change' -Status submitted -UserText '<!-- 空结果 -->')
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_EMPTY_USER_RESULT')

    Invoke-TestCase -Name 'submitted 用户结果仅含有效 Markdown 数据表' -Arrange {
        param($root)
        $tableResult = "| 项目 | 结果 |`n|---|---|`n| 速度 | 2 m/s |"
        [void](Add-Session -Root $root -StageId 'motion-change' -Status submitted -UserText $tableResult)
    } -ExpectedExitCode 0

    Invoke-TestCase -Name 'reviewed AI 批阅为空' -Arrange {
        param($root)
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -AiText '<!-- 空批阅 -->' -OmitEvidenceTable)
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_EMPTY_AI_REVIEW', 'SESSION_EVIDENCE_TABLE')

    Invoke-TestCase -Name 'reviewed 用户结果为空' -Arrange {
        param($root)
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -UserText '<!-- 空结果 -->')
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_EMPTY_USER_RESULT')

    Invoke-TestCase -Name 'reviewed 用户结果仅含有效 Markdown 数据表' -Arrange {
        param($root)
        $tableResult = "| 项目 | 结果 |`n|---|---|`n| 位移 | 3 m |"
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -UserText $tableResult)
    } -ExpectedExitCode 0

    Invoke-TestCase -Name 'reviewed 逐目标表仍含占位值' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change' -Status reviewed
        Replace-FixtureText -Root $root -RelativePath $session -OldValue '| MC-01 | none | independent |' -NewValue '| MC-01 | 待填写 | independent |'
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_HELP_LEVEL')

    Invoke-TestCase -Name '学习单逐目标证据机器表不能重复' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change' -Status reviewed
        $row = '| MC-01 | none | independent | 已记录可核验表现 | 无需订正 | 已记录复核债务 |'
        $duplicate = "$row`n`n| target_id | help | evidence_state | evidence | correction_closure | review_debt |`n|---|---|---|---|---|---|`n$row"
        Replace-FixtureText -Root $root -RelativePath $session -OldValue $row -NewValue $duplicate
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_EVIDENCE_PARSE_DUPLICATE')

    foreach ($help in @('hint', 'framework', 'solution')) {
        foreach ($state in @('independent', 'robust')) {
            Invoke-TestCase -Name "强帮助与 $state 缺少独立闭环：$help" -Arrange {
                param($root)
                $session = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState $state
                $oldRow = "| MC-01 | none | $state | 已记录可核验表现 | 无需订正 | 已记录复核债务 |"
                $newRow = "| MC-01 | $help | $state | 已记录可核验表现 | open | 已记录复核债务 |"
                Replace-FixtureText -Root $root -RelativePath $session -OldValue $oldRow -NewValue $newRow
            } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_HELP_EVIDENCE_CONFLICT')
        }
    }

    Invoke-TestCase -Name '描述性未闭环不能支持强帮助后的 independent' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'independent'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue '| MC-01 | none | independent | 已记录可核验表现 | 无需订正 | 已记录复核债务 |' -NewValue '| MC-01 | framework | independent | 已记录可核验表现 | 仍需换题无提示验证 | 已记录复核债务 |'
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_HELP_EVIDENCE_CONFLICT')

    Invoke-TestCase -Name '强帮助后明确独立闭环可以升级' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'independent'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue '| MC-01 | none | independent | 已记录可核验表现 | 无需订正 | 已记录复核债务 |' -NewValue '| MC-01 | framework | independent | 已记录可核验表现 | independently_closed: 已换等价任务无提示完成 | 已记录复核债务 |'
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '基线未取样却创建检查点' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'baseline-diagnostic' -Status reviewed -EvidenceState 'unsampled'
        Add-Checkpoint -Root $root -StageId 'baseline-diagnostic' -SessionRelativePath $session -EvidenceLevel 'sampled'
        Set-CurrentState -Root $root -FocusStageId 'motion-change'
    } -ExpectedExitCode 1 -ExpectedCodes @('CHECKPOINT_EVIDENCE_STRENGTH')

    Invoke-TestCase -Name '基线 assessment 可取得无提示 sampled 退出复核样本' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'baseline-diagnostic' -Status reviewed -EvidenceState 'sampled'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue 'activity: diagnostic' -NewValue 'activity: assessment'
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '基线 assessment 有方法提示时不能登记 sampled' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'baseline-diagnostic' -Status reviewed -EvidenceState 'sampled'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue 'activity: diagnostic' -NewValue 'activity: assessment'
        Replace-FixtureText -Root $root -RelativePath $session -OldValue '| BD-01 | none | sampled |' -NewValue '| BD-01 | hint | sampled |'
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_DIAGNOSTIC_SOURCE')

    Invoke-TestCase -Name 'guided 冒充 independent' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'guided'
        Add-Checkpoint -Root $root -StageId 'motion-change' -SessionRelativePath $session -EvidenceLevel 'independent'
    } -ExpectedExitCode 1 -ExpectedCodes @('CHECKPOINT_EVIDENCE_STRENGTH')

    Invoke-TestCase -Name '缺少基线检查点却迁移焦点' -Arrange {
        param($root)
        Set-CurrentState -Root $root -FocusStageId 'motion-change'
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_BASELINE_NOT_CLOSED')

    foreach ($unreviewedStatus in @('planned', 'submitted')) {
        Invoke-TestCase -Name "检查点不能引用 $unreviewedStatus 学习单" -Arrange {
            param($root)
            $session = Add-Session -Root $root -StageId 'motion-change' -Status $unreviewedStatus
            Add-Checkpoint -Root $root -StageId 'motion-change' -SessionRelativePath $session -EvidenceLevel 'independent'
        } -ExpectedExitCode 1 -ExpectedCodes @('CHECKPOINT_UNREVIEWED_EVIDENCE')
    }

    Invoke-TestCase -Name '非基线检查点不能在基线通过前创建' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change' -Status reviewed
        Add-Checkpoint -Root $root -StageId 'motion-change' -SessionRelativePath $session
    } -ExpectedExitCode 1 -ExpectedCodes @('CHECKPOINT_BASELINE_NOT_CLOSED')

    Invoke-TestCase -Name '同日基线检查点不能证明非基线检查点发生在其后' -Arrange {
        param($root)
        $baselineSession = Add-Session -Root $root -StageId 'baseline-diagnostic' -Status reviewed -Date '2026-08-01'
        Add-Checkpoint -Root $root -StageId 'baseline-diagnostic' -SessionRelativePath $baselineSession -Date '2026-08-02'
        $motionSession = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -Date '2026-08-02'
        Add-Checkpoint -Root $root -StageId 'motion-change' -SessionRelativePath $motionSession -Date '2026-08-02'
    } -ExpectedExitCode 1 -ExpectedCodes @('CHECKPOINT_BASELINE_NOT_CLOSED')

    Invoke-TestCase -Name '前一日基线检查点可支持次日非基线检查点' -Arrange {
        param($root)
        $baselineSession = Add-Session -Root $root -StageId 'baseline-diagnostic' -Status reviewed -Date '2026-08-01'
        Add-Checkpoint -Root $root -StageId 'baseline-diagnostic' -SessionRelativePath $baselineSession -Date '2026-08-02'
        $motionSession = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -Date '2026-08-02'
        Add-Checkpoint -Root $root -StageId 'motion-change' -SessionRelativePath $motionSession -Date '2026-08-03'
        Set-CurrentState -Root $root -FocusStageId 'probability-thermal'
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '检查点不能选择性忽略较新的 needs_refresh' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        $strong = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'robust' -Date '2026-08-02'
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'needs_refresh' -Date '2026-08-10')
        Add-Checkpoint -Root $root -StageId 'motion-change' -SessionRelativePath $strong -EvidenceLevel 'independent' -Date '2026-08-20'
    } -ExpectedExitCode 1 -ExpectedCodes @('CHECKPOINT_STALE_EVIDENCE')

    Invoke-TestCase -Name '阶段检查点逐目标证据机器表不能重复' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        $session = Add-Session -Root $root -StageId 'motion-change' -Status reviewed
        Add-Checkpoint -Root $root -StageId 'motion-change' -SessionRelativePath $session
        $path = 'checkpoints/stages/2026-08-02-motion-change.md'
        $row = '| MC-01 | independent | [证据](../../sessions/2026/08/2026-08-02-motion-change.md) | 已记录独立性或起点结论 |'
        $duplicate = "$row`n`n| target_id | evidence_level | evidence_files | independence_or_transfer |`n|---|---|---|---|`n$row"
        Replace-FixtureText -Root $root -RelativePath $path -OldValue $row -NewValue $duplicate
    } -ExpectedExitCode 1 -ExpectedCodes @('CHECKPOINT_EVIDENCE_PARSE_DUPLICATE')

    Invoke-TestCase -Name '检查点契约版本必须匹配当前阶段契约' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'baseline-diagnostic' -Status reviewed
        Add-Checkpoint -Root $root -StageId 'baseline-diagnostic' -SessionRelativePath $session
        Replace-FixtureText -Root $root -RelativePath 'checkpoints/stages/2026-08-01-baseline-diagnostic.md' -OldValue 'contract_version: 1' -NewValue 'contract_version: 2'
    } -ExpectedExitCode 1 -ExpectedCodes @('CHECKPOINT_CONTRACT_VERSION')

    Invoke-TestCase -Name '检查点不能引用完成日期之后的证据' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'motion-change' -Status reviewed -Date '2026-08-10'
        Add-Checkpoint -Root $root -StageId 'motion-change' -SessionRelativePath $session -EvidenceLevel 'independent'
    } -ExpectedExitCode 1 -ExpectedCodes @('CHECKPOINT_EVIDENCE_DATE')

    Invoke-TestCase -Name '下一任务指向锁定阶段' -Arrange {
        param($root)
        Set-CurrentState -Root $root -NextStageId 'quantum-statistics' -NextActivity 'learning' -NextTargetId 'QS-01'
    } -ExpectedExitCode 1 -ExpectedCodes @('NEXT_LOCKED_STAGE', 'NEXT_LOCKED_TARGET')

    Invoke-TestCase -Name '下一任务阶段必须属于焦点或已登记并行线' -Arrange {
        param($root)
        Set-CurrentState -Root $root -NextStageId 'motion-change' -NextActivity 'learning' -NextTargetId 'MC-01'
    } -ExpectedExitCode 1 -ExpectedCodes @('NEXT_STAGE_SCOPE')

    Invoke-TestCase -Name '下一任务指向已满足目标' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'baseline-diagnostic' -Status reviewed -EvidenceState 'sampled'
        $evidence = '[基线证据](../' + $session + ')'
        Set-CurrentState -Root $root -FocusMode 'exit_review' -FocusState 'sampled' -FocusEvidence $evidence
    } -ExpectedExitCode 1 -ExpectedCodes @('NEXT_SATISFIED_TARGET')

    Invoke-TestCase -Name '当前执行板拒绝重复唯一下一任务' -Arrange {
        param($root)
        $path = 'state/current.md'
        $content = Read-FixtureFile -Root $root -RelativePath $path
        Write-FixtureFile -Root $root -RelativePath $path -Content ($content + "`n## 唯一下一学习任务`n`n- stage_id: baseline-diagnostic`n- activity: diagnostic`n- target_ids: BD-01`n- task: 重复任务`n")
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_DUPLICATE_HEADING')

    Invoke-TestCase -Name '退出审计允许 assessment 重检已满足焦点目标' -Arrange {
        param($root)
        $session = Add-Session -Root $root -StageId 'baseline-diagnostic' -Status reviewed -EvidenceState 'sampled'
        $evidence = '[基线证据](../' + $session + ')'
        Set-CurrentState -Root $root -FocusMode 'exit_review' -FocusState 'sampled' -FocusEvidence $evidence -NextActivity 'assessment'
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '目标依赖不能由检查点之后的证据倒填' -Arrange {
        param($root)
        Set-StageDependency -Root $root -StageId 'quantum-foundations' -Dependency 'target:MC-01'
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -Date '2026-08-10')
        $quantumSession = Add-Session -Root $root -StageId 'quantum-foundations' -Status reviewed
        Add-Checkpoint -Root $root -StageId 'quantum-foundations' -SessionRelativePath $quantumSession
    } -ExpectedExitCode 1 -ExpectedCodes @('CHECKPOINT_UNMET_DEPENDENCY')

    Invoke-TestCase -Name '同日目标依赖不能支持下游独立证据' -Arrange {
        param($root)
        Set-StageDependency -Root $root -StageId 'quantum-foundations' -Dependency 'target:MC-01'
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'independent' -Date '2026-08-10')
        [void](Add-Session -Root $root -StageId 'quantum-foundations' -Status reviewed -EvidenceState 'independent' -Date '2026-08-10')
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_LOCKED_STAGE_EVIDENCE')

    Invoke-TestCase -Name '前一日目标依赖可支持次日下游独立证据' -Arrange {
        param($root)
        Set-StageDependency -Root $root -StageId 'quantum-foundations' -Dependency 'target:MC-01'
        [void](Add-Session -Root $root -StageId 'motion-change' -Status reviewed -EvidenceState 'independent' -Date '2026-08-10')
        [void](Add-Session -Root $root -StageId 'quantum-foundations' -Status reviewed -EvidenceState 'independent' -Date '2026-08-11')
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '同日上游检查点不能支持下游独立证据' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        Close-Stage -Root $root -StageId 'probability-thermal'
        $qfSession = Add-Session -Root $root -StageId 'quantum-foundations' -Status reviewed -Date '2026-08-04'
        Add-Checkpoint -Root $root -StageId 'quantum-foundations' -SessionRelativePath $qfSession -Date '2026-08-05'
        [void](Add-Session -Root $root -StageId 'quantum-statistics' -Status reviewed -EvidenceState 'independent' -Date '2026-08-05')
    } -ExpectedExitCode 1 -ExpectedCodes @('SESSION_LOCKED_STAGE_EVIDENCE')

    Invoke-TestCase -Name '前一日上游检查点可支持次日下游独立证据' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        Close-Stage -Root $root -StageId 'probability-thermal'
        $qfSession = Add-Session -Root $root -StageId 'quantum-foundations' -Status reviewed -Date '2026-08-04'
        Add-Checkpoint -Root $root -StageId 'quantum-foundations' -SessionRelativePath $qfSession -Date '2026-08-05'
        [void](Add-Session -Root $root -StageId 'quantum-statistics' -Status reviewed -EvidenceState 'independent' -Date '2026-08-06')
        Set-CurrentState -Root $root -FocusStageId 'motion-change'
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '量子统计缺一个汇合检查点时锁定' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        Close-Stage -Root $root -StageId 'probability-thermal'
        Set-CurrentState -Root $root -FocusStageId 'quantum-statistics'
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_LOCKED_FOCUS', 'NEXT_LOCKED_STAGE')

    Invoke-TestCase -Name '量子统计两个上游检查点齐备后解锁' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        Close-Stage -Root $root -StageId 'probability-thermal'
        Close-Stage -Root $root -StageId 'quantum-foundations'
        Set-CurrentState -Root $root -FocusStageId 'quantum-statistics'
    } -ExpectedExitCode 0

    Invoke-TestCase -Name '方向选择缺一个项目检查点时锁定' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        Close-Stage -Root $root -StageId 'trial-quantum-information'
        Close-Stage -Root $root -StageId 'trial-condensed-matter'
        Set-CurrentState -Root $root -FocusStageId 'direction-selection'
    } -ExpectedExitCode 1 -ExpectedCodes @('CURRENT_LOCKED_FOCUS', 'NEXT_LOCKED_STAGE')

    Invoke-TestCase -Name '方向选择三个项目检查点齐备后解锁' -Arrange {
        param($root)
        Close-Stage -Root $root -StageId 'baseline-diagnostic'
        Close-Stage -Root $root -StageId 'trial-quantum-information'
        Close-Stage -Root $root -StageId 'trial-condensed-matter'
        Close-Stage -Root $root -StageId 'trial-optics'
        Set-CurrentState -Root $root -FocusStageId 'direction-selection'
    } -ExpectedExitCode 0
}
finally {
    if (Test-Path -LiteralPath $script:SuiteRoot -PathType Container) {
        [System.IO.Directory]::Delete($script:SuiteRoot, $true)
    }
}

Write-Output ("生命周期检查器夹具测试完成：{0} 通过，{1} 失败。" -f $script:Passed, $script:Failed)
if ($script:Failed -gt 0) { exit 1 }
exit 0
