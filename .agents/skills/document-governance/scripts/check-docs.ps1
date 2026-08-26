[CmdletBinding()]
param(
    [Parameter()]
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
)

$ErrorActionPreference = 'Stop'
$script:NoticeCount = 0
$script:WarningCount = 0
$script:ErrorCount = 0

function Write-CheckMessage {
    param(
        [ValidateSet('NOTICE', 'WARN', 'ERROR')]
        [string]$Level,
        [string]$Code,
        [string]$Message
    )

    switch ($Level) {
        'NOTICE' { $script:NoticeCount++ }
        'WARN' { $script:WarningCount++ }
        'ERROR' { $script:ErrorCount++ }
    }

    Write-Output ('{0} [{1}] {2}' -f $Level, $Code, $Message)
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $targetFullPath = [System.IO.Path]::GetFullPath($TargetPath)
    $baseUri = [System.Uri]::new($baseFullPath)
    $targetUri = [System.Uri]::new($targetFullPath)
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('\', '/')
}

function Get-MarkdownContentOutsideFences {
    param([string]$Content)

    $outside = [System.Collections.Generic.List[string]]::new()
    $insideFence = $false
    $fenceMarker = $null

    foreach ($line in ($Content -split "`r?`n")) {
        if ($line -match '^\s*(```|~~~)') {
            $marker = $Matches[1]
            if (-not $insideFence) {
                $insideFence = $true
                $fenceMarker = $marker
            }
            elseif ($marker -eq $fenceMarker) {
                $insideFence = $false
                $fenceMarker = $null
            }
            continue
        }

        if (-not $insideFence) {
            $outside.Add($line)
        }
    }

    return $outside
}

function Get-SizeBudget {
    param([string]$RelativePath)

    $leaf = Split-Path -Leaf $RelativePath
    if ($RelativePath -ieq 'AGENTS.md') {
        return @{ Target = 8KB; Warn = 12KB; Fail = 16KB; Type = '根 AGENTS.md' }
    }
    if ($leaf -ieq 'AGENTS.md') {
        return @{ Target = 4KB; Warn = 6KB; Fail = 8KB; Type = '子目录 AGENTS.md' }
    }
    if ($leaf -ieq 'SKILL.md') {
        return @{ Target = 8KB; Warn = 12KB; Fail = 24KB; Type = 'SKILL.md' }
    }
    if ($RelativePath -match '^sessions/') {
        return @{ Target = 24KB; Warn = 40KB; Fail = $null; Type = '学习记录' }
    }
    if (
        $leaf -ieq 'README.md' -or
        $leaf -ieq 'index.md' -or
        $RelativePath -match '^(state|templates)/'
    ) {
        return @{ Target = 8KB; Warn = 12KB; Fail = 24KB; Type = '导航、状态或模板' }
    }
    return @{ Target = 16KB; Warn = 24KB; Fail = 48KB; Type = '普通主题文档' }
}

function Test-DocumentSize {
    param(
        [string]$RelativePath,
        [long]$Bytes
    )

    $budget = Get-SizeBudget -RelativePath $RelativePath
    $sizeText = '{0:N1} KiB' -f ($Bytes / 1KB)

    if ($null -ne $budget.Fail -and $Bytes -gt $budget.Fail) {
        Write-CheckMessage -Level 'ERROR' -Code 'SIZE' -Message "$RelativePath 为 $sizeText，超过 $($budget.Fail / 1KB) KiB 失败线。"
    }
    elseif ($Bytes -gt $budget.Warn) {
        Write-CheckMessage -Level 'WARN' -Code 'SIZE' -Message "$RelativePath 为 $sizeText，超过 $($budget.Warn / 1KB) KiB 警告线。"
    }
    elseif ($Bytes -gt $budget.Target) {
        Write-CheckMessage -Level 'NOTICE' -Code 'SIZE' -Message "$RelativePath 为 $sizeText，超过 $($budget.Target / 1KB) KiB 建议目标。"
    }
}

function Test-RelativeLinks {
    param(
        [string]$FilePath,
        [string]$RelativePath,
        [string[]]$Lines
    )

    $content = $Lines -join "`n"
    $linkPattern = '!?(?:\[[^\]]*\])\((?<target>[^\)]+)\)'
    foreach ($match in [regex]::Matches($content, $linkPattern)) {
        $target = $match.Groups['target'].Value.Trim()
        if ($target -match '^<(?<value>[^>]+)>$') {
            $target = $Matches['value']
        }
        elseif ($target -match '^(?<value>\S+)(?:\s+["''][^"'']*["''])$') {
            $target = $Matches['value']
        }

        if (
            [string]::IsNullOrWhiteSpace($target) -or
            $target.StartsWith('#') -or
            $target.StartsWith('//') -or
            $target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:' -or
            [System.IO.Path]::IsPathRooted($target)
        ) {
            continue
        }

        $pathPart = ($target -split '#', 2)[0]
        $pathPart = ($pathPart -split '\?', 2)[0]
        if ([string]::IsNullOrWhiteSpace($pathPart)) {
            continue
        }

        try {
            $decodedPath = [System.Uri]::UnescapeDataString($pathPart)
            $resolved = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $FilePath) $decodedPath))
        }
        catch {
            Write-CheckMessage -Level 'ERROR' -Code 'LINK' -Message "$RelativePath 包含无法解析的相对链接：$target"
            continue
        }

        $rootPrefix = $script:RootFullPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-CheckMessage -Level 'ERROR' -Code 'LINK' -Message "$RelativePath 的相对链接超出项目根目录：$target"
            continue
        }
        if (-not (Test-Path -LiteralPath $resolved)) {
            Write-CheckMessage -Level 'ERROR' -Code 'LINK' -Message "$RelativePath 指向不存在的路径：$target"
        }
    }
}

function Test-LearningSession {
    param(
        [string]$RelativePath,
        [string]$Content,
        [string[]]$Lines
    )

    if ($RelativePath -notmatch '^sessions/\d{4}/\d{2}/.+\.md$') {
        return
    }

    if ($Content -notmatch '(?s)\A---\s*\r?\n(?<frontmatter>.*?)\r?\n---(?:\r?\n|\z)') {
        Write-CheckMessage -Level 'ERROR' -Code 'SESSION' -Message "$RelativePath 缺少有效的 YAML 前置区。"
        return
    }

    $frontmatter = $Matches['frontmatter']
    foreach ($field in @('date', 'stage', 'topic', 'planned_minutes', 'status')) {
        if ($frontmatter -notmatch "(?m)^$([regex]::Escape($field))\s*:\s*\S.*$") {
            Write-CheckMessage -Level 'ERROR' -Code 'SESSION' -Message "$RelativePath 缺少前置字段：$field"
        }
    }

    if ($frontmatter -match '(?m)^status\s*:\s*["'']?(?<status>[^\s"'']+)["'']?\s*$') {
        if ($Matches['status'] -notin @('planned', 'submitted', 'reviewed')) {
            Write-CheckMessage -Level 'ERROR' -Code 'SESSION' -Message "$RelativePath 使用非法状态：$($Matches['status'])"
        }
    }

    $headings = @($Lines | Where-Object { $_ -match '^##\s+' } | ForEach-Object { ($_ -replace '^##\s+', '').Trim() })
    foreach ($requiredHeading in @('本次目标', '前置检查', '学习内容', '练习', '用户结果', 'AI 批阅', '下一步', '相关项目与资料')) {
        if ($requiredHeading -notin $headings) {
            Write-CheckMessage -Level 'ERROR' -Code 'SESSION' -Message "$RelativePath 缺少二级章节：$requiredHeading"
        }
    }
}

function Test-AgentChains {
    param([object[]]$AgentFiles)

    foreach ($agent in $AgentFiles) {
        $agentDirectory = (Split-Path -Parent $agent.RelativePath).Replace('\', '/')
        $chainBytes = 0L

        foreach ($candidate in $AgentFiles) {
            $candidateDirectory = (Split-Path -Parent $candidate.RelativePath).Replace('\', '/')
            $isRootAgent = [string]::IsNullOrWhiteSpace($candidateDirectory)
            $isAncestor = $isRootAgent -or $agentDirectory -ieq $candidateDirectory -or $agentDirectory.StartsWith(($candidateDirectory.TrimEnd('/') + '/'), [System.StringComparison]::OrdinalIgnoreCase)
            if ($isAncestor) {
                $chainBytes += $candidate.Bytes
            }
        }

        $sizeText = '{0:N2} KiB' -f ($chainBytes / 1KB)
        if ($chainBytes -gt 24KB) {
            Write-CheckMessage -Level 'ERROR' -Code 'AGENT_CHAIN' -Message "$($agent.RelativePath) 的有效 AGENTS 指令链为 $sizeText，超过 24 KiB 失败线。"
        }
        elseif ($chainBytes -gt 20KB) {
            Write-CheckMessage -Level 'WARN' -Code 'AGENT_CHAIN' -Message "$($agent.RelativePath) 的有效 AGENTS 指令链为 $sizeText，超过 20 KiB 警告线。"
        }
        elseif ($chainBytes -gt 16KB) {
            Write-CheckMessage -Level 'NOTICE' -Code 'AGENT_CHAIN' -Message "$($agent.RelativePath) 的有效 AGENTS 指令链为 $sizeText，超过 16 KiB 建议目标。"
        }
    }
}

function Test-ProjectSkills {
    param([string]$RootPath)

    $skillsRoot = Join-Path $RootPath '.agents\skills'
    if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
        return
    }

    foreach ($skillDirectory in (Get-ChildItem -LiteralPath $skillsRoot -Directory)) {
        $skillName = $skillDirectory.Name
        $skillFile = Join-Path $skillDirectory.FullName 'SKILL.md'
        $metadataFile = Join-Path $skillDirectory.FullName 'agents\openai.yaml'

        if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
            Write-CheckMessage -Level 'ERROR' -Code 'SKILL' -Message ".agents/skills/$skillName 缺少 SKILL.md。"
        }

        if (-not (Test-Path -LiteralPath $metadataFile -PathType Leaf)) {
            Write-CheckMessage -Level 'ERROR' -Code 'SKILL_METADATA' -Message ".agents/skills/$skillName 缺少 agents/openai.yaml。"
            continue
        }

        $metadata = [System.IO.File]::ReadAllText($metadataFile)
        $defaultPrompt = $null
        foreach ($field in @('display_name', 'short_description', 'default_prompt')) {
            $fieldPattern = '(?m)^\s{2}' + [regex]::Escape($field) + '\s*:\s*["''](?<value>.+)["'']\s*$'
            $fieldMatch = [regex]::Match($metadata, $fieldPattern)
            if (-not $fieldMatch.Success) {
                Write-CheckMessage -Level 'ERROR' -Code 'SKILL_METADATA' -Message ".agents/skills/$skillName 的 agents/openai.yaml 缺少有效的 $field。"
                continue
            }

            $fieldValue = $fieldMatch.Groups['value'].Value
            if ($field -eq 'default_prompt') {
                $defaultPrompt = $fieldValue
            }

            if ($fieldValue -notmatch '[\u4e00-\u9fff]') {
                Write-CheckMessage -Level 'ERROR' -Code 'SKILL_LANGUAGE' -Message ".agents/skills/$skillName 的 $field 必须包含中文界面文案。"
            }

            if ($field -eq 'short_description' -and ($fieldValue.Length -lt 25 -or $fieldValue.Length -gt 64)) {
                Write-CheckMessage -Level 'ERROR' -Code 'SKILL_METADATA' -Message ".agents/skills/$skillName 的 short_description 必须为 25 至 64 个字符，当前为 $($fieldValue.Length) 个。"
            }
        }

        $invocation = '$' + $skillName
        if ([string]::IsNullOrWhiteSpace($defaultPrompt) -or -not $defaultPrompt.Contains($invocation)) {
            Write-CheckMessage -Level 'ERROR' -Code 'SKILL_METADATA' -Message ".agents/skills/$skillName 的 default_prompt 未使用准确调用标记：$invocation"
        }
    }
}

$script:RootFullPath = [System.IO.Path]::GetFullPath($Root)
if (-not (Test-Path -LiteralPath $script:RootFullPath -PathType Container)) {
    Write-Error "项目根目录不存在：$Root"
}

$excludedDirectories = @('.git', '.venv', 'node_modules', '.cache', '__pycache__')
$markdownFiles = @(
    Get-ChildItem -LiteralPath $script:RootFullPath -Recurse -Force -File -Filter '*.md' |
        Where-Object {
            $relative = Get-RelativePath -BasePath $script:RootFullPath -TargetPath $_.FullName
            -not ($excludedDirectories | Where-Object { $relative -match "(^|/)$([regex]::Escape($_))(/|$)" })
        }
)

$agentFiles = [System.Collections.Generic.List[object]]::new()
foreach ($file in $markdownFiles) {
    $relativePath = Get-RelativePath -BasePath $script:RootFullPath -TargetPath $file.FullName
    $bytes = ([System.IO.File]::ReadAllBytes($file.FullName)).LongLength
    $content = [System.IO.File]::ReadAllText($file.FullName)
    $lines = @(Get-MarkdownContentOutsideFences -Content $content)

    Test-DocumentSize -RelativePath $relativePath -Bytes $bytes

    $h1Count = @($lines | Where-Object { $_ -match '^#\s+\S' }).Count
    if ($h1Count -ne 1) {
        Write-CheckMessage -Level 'ERROR' -Code 'H1' -Message "$relativePath 应有且仅有一个一级标题，实际为 $h1Count 个。"
    }

    Test-RelativeLinks -FilePath $file.FullName -RelativePath $relativePath -Lines $lines
    Test-LearningSession -RelativePath $relativePath -Content $content -Lines $lines

    if ((Split-Path -Leaf $relativePath) -ieq 'AGENTS.md') {
        $agentFiles.Add([pscustomobject]@{ RelativePath = $relativePath; Bytes = $bytes })
    }
}

Test-AgentChains -AgentFiles $agentFiles
Test-ProjectSkills -RootPath $script:RootFullPath

Write-Output ('已检查 {0} 个 Markdown 文件：{1} 条提示，{2} 条警告，{3} 个错误。' -f $markdownFiles.Count, $script:NoticeCount, $script:WarningCount, $script:ErrorCount)
if ($script:ErrorCount -gt 0) {
    exit 1
}
exit 0
