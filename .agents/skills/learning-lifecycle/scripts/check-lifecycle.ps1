[CmdletBinding()]
param(
    [Parameter()]
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:ErrorCount = 0
$script:RootPath = [System.IO.Path]::GetFullPath($Root)
$script:Stages = @{}
$script:Targets = @{}
$script:Sessions = @{}
$script:Checkpoints = @{}
$script:CurrentRows = @{}
$script:CurrentEvidenceLinks = @{}
$script:CurrentCutoffDate = ''

function Add-LifecycleError {
    param(
        [string]$Code,
        [string]$Path,
        [string]$Message
    )

    $script:ErrorCount++
    # 绕开 PowerShell 成功输出管道，防止错误文本污染解析函数的返回对象。
    [Console]::Out.WriteLine(('ERROR [{0}] {1}: {2}' -f $Code, $Path, $Message))
}

function Get-RelativePath {
    param([string]$Path)

    $base = $script:RootPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $baseUri = [System.Uri]::new($base)
    $targetUri = [System.Uri]::new([System.IO.Path]::GetFullPath($Path))
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('\', '/')
}

function Get-CleanCell {
    param([AllowEmptyString()][string]$Value)

    if ($null -eq $Value) { return '' }
    return ($Value.Trim() -replace '^`|`$', '').Trim()
}

function Get-ScalarValue {
    param([AllowEmptyString()][string]$Value)

    $clean = $Value.Trim()
    if ($clean.Length -ge 2) {
        if (($clean.StartsWith('"') -and $clean.EndsWith('"')) -or ($clean.StartsWith("'") -and $clean.EndsWith("'"))) {
            return $clean.Substring(1, $clean.Length - 2)
        }
    }
    return $clean
}

function ConvertTo-ValueList {
    param($Value)

    if ($null -eq $Value) { return @() }
    if ($Value -is [System.Collections.IList] -and $Value -isnot [string]) {
        return @($Value | ForEach-Object { Get-ScalarValue -Value ([string]$_) })
    }

    $text = Get-ScalarValue -Value ([string]$Value)
    if ([string]::IsNullOrWhiteSpace($text) -or $text -in @('none', '[]')) { return @() }
    if ($text.StartsWith('[') -and $text.EndsWith(']')) {
        $text = $text.Substring(1, $text.Length - 2)
    }
    return @(($text -split ',') | ForEach-Object { (Get-ScalarValue -Value $_).Trim() } | Where-Object { $_ })
}

function Read-FrontMatter {
    param(
        [string]$Content,
        [string]$RelativePath,
        [string[]]$ExpectedKeys,
        [string]$CodePrefix
    )

    $match = [regex]::Match($Content, '(?s)\A---\s*\r?\n(?<body>.*?)\r?\n---(?:\r?\n|\z)')
    if (-not $match.Success) {
        Add-LifecycleError -Code ($CodePrefix + '_FRONTMATTER') -Path $RelativePath -Message '缺少可解析的 YAML 前置区。'
        return $null
    }

    $values = [ordered]@{}
    $keys = [System.Collections.Generic.List[string]]::new()
    $currentListKey = $null
    $lineNumber = 1
    foreach ($line in ($match.Groups['body'].Value -split "`r?`n")) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s*#') { continue }

        $keyMatch = [regex]::Match($line, '^(?<key>[A-Za-z_][A-Za-z0-9_-]*)\s*:\s*(?<value>.*)$')
        if ($keyMatch.Success) {
            $key = $keyMatch.Groups['key'].Value
            if ($values.Contains($key)) {
                Add-LifecycleError -Code ($CodePrefix + '_DUPLICATE_FIELD') -Path $RelativePath -Message ("前置区字段重复：$key")
                continue
            }
            $keys.Add($key)
            $raw = $keyMatch.Groups['value'].Value
            if ([string]::IsNullOrWhiteSpace($raw)) {
                $values[$key] = [System.Collections.Generic.List[string]]::new()
                $currentListKey = $key
            }
            else {
                $values[$key] = Get-ScalarValue -Value $raw
                $currentListKey = $null
            }
            continue
        }

        $itemMatch = [regex]::Match($line, '^\s{2,}-\s+(?<value>\S.*)$')
        if ($itemMatch.Success -and $null -ne $currentListKey) {
            $values[$currentListKey].Add((Get-ScalarValue -Value $itemMatch.Groups['value'].Value))
            continue
        }

        Add-LifecycleError -Code ($CodePrefix + '_YAML_PARSE') -Path $RelativePath -Message ("前置区第 $lineNumber 行无法解析。")
    }

    foreach ($key in $ExpectedKeys) {
        if (-not $values.Contains($key)) {
            Add-LifecycleError -Code ($CodePrefix + '_MISSING_FIELD') -Path $RelativePath -Message ("缺少前置字段：$key")
        }
    }
    foreach ($key in $keys) {
        if ($key -notin $ExpectedKeys) {
            $code = if ($CodePrefix -eq 'CURRENT' -and $key -match 'completed|available|locked') { 'CURRENT_DERIVED_FIELD' } else { $CodePrefix + '_UNKNOWN_FIELD' }
            Add-LifecycleError -Code $code -Path $RelativePath -Message ("包含未定义前置字段：$key")
        }
    }

    if ($keys.Count -eq $ExpectedKeys.Count) {
        for ($index = 0; $index -lt $ExpectedKeys.Count; $index++) {
            if ($keys[$index] -ne $ExpectedKeys[$index]) {
                Add-LifecycleError -Code ($CodePrefix + '_FIELD_ORDER') -Path $RelativePath -Message ('前置字段必须按顺序排列：{0}' -f ($ExpectedKeys -join ', '))
                break
            }
        }
    }

    return [pscustomobject]@{
        Values = $values
        BodyStart = $match.Length
    }
}

function Get-MarkdownLinesOutsideFences {
    param([string]$Content)

    $result = [System.Collections.Generic.List[string]]::new()
    $inside = $false
    $fence = ''
    foreach ($line in ($Content -split "`r?`n")) {
        $fenceMatch = [regex]::Match($line, '^\s*(?<fence>`{3,}|~{3,})')
        if ($fenceMatch.Success) {
            $character = $fenceMatch.Groups['fence'].Value.Substring(0, 1)
            if (-not $inside) { $inside = $true; $fence = $character }
            elseif ($character -eq $fence) { $inside = $false; $fence = '' }
            continue
        }
        if (-not $inside) { $result.Add($line) }
    }
    return @($result)
}

function Split-MarkdownRow {
    param([string]$Line)

    $trimmed = $Line.Trim()
    if (-not $trimmed.StartsWith('|')) { return @() }
    return @(($trimmed.Trim('|') -split '\|') | ForEach-Object { $_.Trim() })
}

function Find-MarkdownTable {
    param(
        [string]$Content,
        [string[]]$Headers,
        [string]$RelativePath = '.',
        [string]$MalformedCode = 'TABLE_PARSE'
    )

    $lines = @(Get-MarkdownLinesOutsideFences -Content $Content)
    $headerIndexes = [System.Collections.Generic.List[int]]::new()
    for ($scanIndex = 0; $scanIndex -lt $lines.Count; $scanIndex++) {
        $scanCells = @(Split-MarkdownRow -Line $lines[$scanIndex])
        if ($scanCells.Count -ne $Headers.Count) { continue }
        $scanNormalized = @($scanCells | ForEach-Object { (Get-CleanCell -Value $_).ToLowerInvariant() })
        $scanExpected = @($Headers | ForEach-Object { $_.ToLowerInvariant() })
        if (($scanNormalized -join '|') -eq ($scanExpected -join '|')) { $headerIndexes.Add($scanIndex) }
    }
    if ($headerIndexes.Count -gt 1) {
        Add-LifecycleError -Code ($MalformedCode + '_DUPLICATE') -Path $RelativePath -Message ('同一机器区块出现重复表头，所在行：{0}' -f (@($headerIndexes | ForEach-Object { $_ + 1 }) -join ', '))
    }

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $cells = @(Split-MarkdownRow -Line $lines[$index])
        if ($cells.Count -ne $Headers.Count) { continue }
        $normalized = @($cells | ForEach-Object { (Get-CleanCell -Value $_).ToLowerInvariant() })
        $expected = @($Headers | ForEach-Object { $_.ToLowerInvariant() })
        if (($normalized -join '|') -ne ($expected -join '|')) { continue }
        if ($index + 1 -ge $lines.Count -or $lines[$index + 1] -notmatch '^\s*\|') { continue }

        $rows = [System.Collections.Generic.List[object]]::new()
        $malformedLines = [System.Collections.Generic.List[int]]::new()
        $separatorCells = @(Split-MarkdownRow -Line $lines[$index + 1])
        if ($separatorCells.Count -ne $Headers.Count -or @($separatorCells | Where-Object { (Get-CleanCell -Value $_) -notmatch '^:?-{3,}:?$' }).Count -gt 0) {
            $malformedLines.Add($index + 2)
        }
        for ($rowIndex = $index + 2; $rowIndex -lt $lines.Count; $rowIndex++) {
            if ($lines[$rowIndex] -notmatch '^\s*\|') { break }
            $rowCells = @(Split-MarkdownRow -Line $lines[$rowIndex])
            if ($rowCells.Count -ne $Headers.Count) {
                $malformedLines.Add($rowIndex + 1)
                continue
            }
            $rows.Add([pscustomobject]@{ Cells = $rowCells; Line = $rowIndex + 1 })
        }
        if ($malformedLines.Count -gt 0) {
            Add-LifecycleError -Code $MalformedCode -Path $RelativePath -Message ('Markdown 表格存在无法解析的行：{0}' -f (@($malformedLines) -join ', '))
        }
        return [pscustomobject]@{ Rows = @($rows); Line = $index + 1; MalformedLines = @($malformedLines) }
    }
    return $null
}

function Get-MarkdownSection {
    param(
        [string]$Content,
        [string]$Heading
    )

    $pattern = '(?ms)^##\s+' + [regex]::Escape($Heading) + '\s*\r?\n(?<body>.*?)(?=^##\s+|\z)'
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) { return $null }
    return $match.Groups['body'].Value
}

function Test-MeaningfulContent {
    param([AllowNull()][string]$Content)

    if ($null -eq $Content) { return $false }
    $clean = [regex]::Replace($Content, '(?s)<!--.*?-->', '')
    $lines = @($clean -split "`r?`n")
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $value = $lines[$index].Trim()
        if (-not $value -or $value -match '^>' -or $value -match '^\|?\s*:?-{3,}' -or $value -match '^(?:[-*]\s*)?(?:待填写|暂无|none)\.?$') { continue }
        if ($value -match '^\|.*\|$') {
            $next = if ($index + 1 -lt $lines.Count) { $lines[$index + 1].Trim() } else { '' }
            if ($next -match '^\|?\s*:?-{3,}') { continue }
            $cells = @(Split-MarkdownRow -Line $value | ForEach-Object { (Get-CleanCell -Value $_) } | Where-Object { $_ -and $_ -notin @('待填写', '暂无', 'none') })
            if ($cells.Count -gt 0) { return $true }
            continue
        }
        return $true
    }
    return $false
}

function Test-IsoDate {
    param([string]$Value)
    $parsed = [datetime]::MinValue
    return $Value -match '^\d{4}-(0[1-9]|1[0-2])-([0-2]\d|3[01])$' -and [datetime]::TryParseExact($Value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)
}

function Get-DependencyList {
    param([string]$Value)

    $clean = (Get-CleanCell -Value $Value) -replace '<br\s*/?>', ','
    if ($clean -in @('', '-', '—', 'none', '无')) { return @() }
    return @(($clean -split ',') | ForEach-Object { (Get-CleanCell -Value $_).Trim() } | Where-Object { $_ })
}

function Get-RouteFileFromCell {
    param([string]$Value)

    $match = [regex]::Match($Value, '\]\((?<path>[^\)]*)\)')
    if ($match.Success) {
        $target = $match.Groups['path'].Value
        if ($target.StartsWith('#')) { return 'index.md' }
        return ($target -split '#', 2)[0]
    }
    return Get-CleanCell -Value $Value
}

function Read-RouteRegistry {
    $relativePath = 'roadmap/index.md'
    $path = Join-Path $script:RootPath $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-LifecycleError -Code 'ROUTE_REGISTRY_MISSING' -Path $relativePath -Message '路线总览不存在。'
        return
    }

    $content = [System.IO.File]::ReadAllText($path)
    $table = Find-MarkdownTable -Content $content -Headers @('stage_id', 'contract_version', 'route_file', 'depends_on', 'unlocks') -RelativePath $relativePath -MalformedCode 'ROUTE_REGISTRY_PARSE'
    if ($null -eq $table) {
        Add-LifecycleError -Code 'ROUTE_REGISTRY_FORMAT' -Path $relativePath -Message '缺少固定阶段注册表。'
        return
    }

    foreach ($row in $table.Rows) {
        $stageId = Get-CleanCell -Value $row.Cells[0]
        $version = Get-CleanCell -Value $row.Cells[1]
        $routeFile = Get-RouteFileFromCell -Value $row.Cells[2]
        $dependencies = @(Get-DependencyList -Value $row.Cells[3])
        $unlocks = @(Get-DependencyList -Value $row.Cells[4])

        if ($stageId -notmatch '^[a-z][a-z0-9-]*$') {
            Add-LifecycleError -Code 'ROUTE_STAGE_ID' -Path $relativePath -Message ("第 $($row.Line) 行阶段 ID 非法：$stageId")
            continue
        }
        if ($script:Stages.ContainsKey($stageId)) {
            Add-LifecycleError -Code 'ROUTE_DUPLICATE_STAGE' -Path $relativePath -Message ("阶段 ID 重复：$stageId")
            continue
        }
        if ($version -notmatch '^[1-9]\d*$') {
            Add-LifecycleError -Code 'ROUTE_CONTRACT_VERSION' -Path $relativePath -Message ("$stageId 的 contract_version 非法：$version")
        }
        if ([string]::IsNullOrWhiteSpace($routeFile)) {
            Add-LifecycleError -Code 'ROUTE_FILE' -Path $relativePath -Message ("$stageId 缺少 route_file。")
        }

        $script:Stages[$stageId] = [pscustomobject]@{
            Id = $stageId
            Version = $version
            RouteFile = $routeFile.Replace('\', '/')
            Dependencies = $dependencies
            Unlocks = $unlocks
            Targets = [System.Collections.Generic.List[string]]::new()
        }
    }
    if ($script:Stages.Count -eq 0) {
        Add-LifecycleError -Code 'ROUTE_REGISTRY_EMPTY' -Path $relativePath -Message '阶段注册表没有数据行。'
    }
}

function Read-StageContracts {
    foreach ($stage in @($script:Stages.Values)) {
        $routeRelative = if ($stage.RouteFile.StartsWith('roadmap/')) { $stage.RouteFile } else { 'roadmap/' + $stage.RouteFile }
        $routePath = Join-Path $script:RootPath ($routeRelative.Replace('/', '\'))
        $routeFullPath = [System.IO.Path]::GetFullPath($routePath)
        $rootPrefix = $script:RootPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        if (-not $routeFullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            Add-LifecycleError -Code 'ROUTE_FILE_SCOPE' -Path 'roadmap/index.md' -Message ("阶段 $($stage.Id) 的 route_file 超出项目根目录。")
            continue
        }
        if (-not (Test-Path -LiteralPath $routeFullPath -PathType Leaf)) {
            Add-LifecycleError -Code 'ROUTE_FILE_MISSING' -Path $routeRelative -Message ("阶段 $($stage.Id) 的路线文件不存在。")
            continue
        }

        $content = [System.IO.File]::ReadAllText($routeFullPath)
        $headingPattern = '(?m)^##\s+阶段：[^\r\n]+\s+\{#' + [regex]::Escape($stage.Id) + '\}\s*$'
        $headingMatches = @([regex]::Matches($content, $headingPattern))
        if ($headingMatches.Count -ne 1) {
            Add-LifecycleError -Code 'ROUTE_CONTRACT_HEADING' -Path $routeRelative -Message ("阶段 $($stage.Id) 必须且只能有一个契约标题。")
            continue
        }

        $start = $headingMatches[0].Index + $headingMatches[0].Length
        $tail = $content.Substring($start).TrimStart("`r", "`n")
        $metadata = [regex]::Match($tail, '\A- stage_id:\s*(?<id>[^\r\n]+)\r?\n- contract_version:\s*(?<version>[^\r\n]+)\r?\n- pace_hint:\s*(?<pace>[^\r\n]+)\r?\n- depends_on:\s*(?<deps>[^\r\n]+)(?:\r?\n|\z)')
        if (-not $metadata.Success) {
            Add-LifecycleError -Code 'ROUTE_CONTRACT_METADATA' -Path $routeRelative -Message ("阶段 $($stage.Id) 的四项元数据缺失、乱序或未紧跟标题。")
            continue
        }
        $metadataId = Get-CleanCell -Value $metadata.Groups['id'].Value
        $metadataVersion = Get-CleanCell -Value $metadata.Groups['version'].Value
        $metadataDependencies = @(Get-DependencyList -Value $metadata.Groups['deps'].Value)
        if ($metadataId -ne $stage.Id) {
            Add-LifecycleError -Code 'ROUTE_CONTRACT_ID' -Path $routeRelative -Message ("标题、元数据和注册表的 stage_id 不一致：$($stage.Id) / $metadataId")
        }
        if ($metadataVersion -ne $stage.Version) {
            Add-LifecycleError -Code 'ROUTE_CONTRACT_VERSION_MISMATCH' -Path $routeRelative -Message ("$($stage.Id) 的契约版本与注册表不一致。")
        }
        if ([string]::IsNullOrWhiteSpace((Get-CleanCell -Value $metadata.Groups['pace'].Value))) {
            Add-LifecycleError -Code 'ROUTE_PACE_HINT' -Path $routeRelative -Message ("$($stage.Id) 缺少 pace_hint。")
        }
        if ((@($metadataDependencies | Sort-Object) -join '|') -ne (@($stage.Dependencies | Sort-Object) -join '|')) {
            Add-LifecycleError -Code 'ROUTE_DEPENDENCY_MISMATCH' -Path $routeRelative -Message ("$($stage.Id) 的 depends_on 与注册表不一致。")
        }

        $nextHeading = [regex]::Match($content.Substring($start), '(?m)^##\s+')
        $sectionLength = if ($nextHeading.Success) { $nextHeading.Index } else { $content.Length - $start }
        $section = $content.Substring($start, $sectionLength)
        if ($section -match '(?m)^- unlocks\s*:') {
            Add-LifecycleError -Code 'ROUTE_CONTRACT_DUPLICATE_UNLOCKS' -Path $routeRelative -Message ("阶段 $($stage.Id) 不得复制注册表的 unlocks 元数据。")
        }
        Test-StageContractSections -Content $section -RelativePath $routeRelative -StageId $stage.Id
        $targetTable = Find-MarkdownTable -Content $section -Headers @('target_id', '类型', '可观察表现', '最低证据', '代表性任务') -RelativePath $routeRelative -MalformedCode 'ROUTE_TARGET_PARSE'
        if ($null -eq $targetTable -or $targetTable.Rows.Count -eq 0) {
            Add-LifecycleError -Code 'ROUTE_TARGET_TABLE' -Path $routeRelative -Message ("$($stage.Id) 缺少非空目标表。")
            continue
        }

        foreach ($row in $targetTable.Rows) {
            $targetId = Get-CleanCell -Value $row.Cells[0]
            $kind = (Get-CleanCell -Value $row.Cells[1]).ToLowerInvariant()
            $observable = Get-CleanCell -Value $row.Cells[2]
            $minimum = (Get-CleanCell -Value $row.Cells[3]).ToLowerInvariant()
            $representative = Get-CleanCell -Value $row.Cells[4]
            if ($targetId -notmatch '^[A-Z][A-Z0-9]*-\d{2}$') {
                Add-LifecycleError -Code 'ROUTE_TARGET_ID' -Path $routeRelative -Message ("$($stage.Id) 包含非法目标 ID：$targetId")
                continue
            }
            if ($script:Targets.ContainsKey($targetId)) {
                Add-LifecycleError -Code 'ROUTE_DUPLICATE_TARGET' -Path $routeRelative -Message ("目标 ID 重复：$targetId")
                continue
            }
            if ([string]::IsNullOrWhiteSpace($kind) -or [string]::IsNullOrWhiteSpace($observable) -or [string]::IsNullOrWhiteSpace($representative)) {
                Add-LifecycleError -Code 'ROUTE_TARGET_EMPTY' -Path $routeRelative -Message ("目标 $targetId 的类型、表现或代表性任务为空。")
            }
            if ($minimum -notin @('sampled', 'independent', 'robust')) {
                Add-LifecycleError -Code 'ROUTE_TARGET_EVIDENCE' -Path $routeRelative -Message ("目标 $targetId 的最低证据非法：$minimum")
            }
            if ($stage.Id -eq 'baseline-diagnostic' -and $minimum -ne 'sampled') {
                Add-LifecycleError -Code 'ROUTE_BASELINE_EVIDENCE' -Path $routeRelative -Message ("基线目标 $targetId 的最低证据必须是 sampled。")
            }
            if ($stage.Id -ne 'baseline-diagnostic' -and $minimum -eq 'sampled') {
                Add-LifecycleError -Code 'ROUTE_LEARNING_EVIDENCE' -Path $routeRelative -Message ("教学阶段目标 $targetId 不能以 sampled 作为退出证据。")
            }
            $script:Targets[$targetId] = [pscustomobject]@{
                Id = $targetId
                StageId = $stage.Id
                Kind = $kind
                Minimum = $minimum
            }
            $stage.Targets.Add($targetId)
        }
    }
}

function Resolve-DependencyOwner {
    param(
        [string]$Dependency,
        [string]$RelativePath
    )

    if ($Dependency.StartsWith('target:')) {
        $targetId = $Dependency.Substring(7)
        if (-not $script:Targets.ContainsKey($targetId)) {
            Add-LifecycleError -Code 'ROUTE_UNKNOWN_DEPENDENCY' -Path $RelativePath -Message ("未知目标依赖：$Dependency")
            return $null
        }
        return $script:Targets[$targetId].StageId
    }
    if (-not $script:Stages.ContainsKey($Dependency)) {
        Add-LifecycleError -Code 'ROUTE_UNKNOWN_DEPENDENCY' -Path $RelativePath -Message ("未知阶段依赖：$Dependency")
        return $null
    }
    return $Dependency
}

function Visit-StageDependency {
    param(
        [string]$StageId,
        [hashtable]$Marks,
        [System.Collections.Generic.List[string]]$Stack
    )

    if ($Marks[$StageId] -eq 2) { return }
    if ($Marks[$StageId] -eq 1) {
        $cycle = @($Stack) + $StageId
        Add-LifecycleError -Code 'ROUTE_CYCLE' -Path 'roadmap/index.md' -Message ('阶段依赖存在环：{0}' -f ($cycle -join ' -> '))
        return
    }

    $Marks[$StageId] = 1
    $Stack.Add($StageId)
    foreach ($dependency in $script:Stages[$StageId].Dependencies) {
        $owner = Resolve-DependencyOwner -Dependency $dependency -RelativePath 'roadmap/index.md'
        if ($null -ne $owner -and $owner -ne $StageId) {
            Visit-StageDependency -StageId $owner -Marks $Marks -Stack $Stack
        }
        elseif ($owner -eq $StageId) {
            Add-LifecycleError -Code 'ROUTE_CYCLE' -Path 'roadmap/index.md' -Message ("阶段 $StageId 依赖自身。")
        }
    }
    [void]$Stack.RemoveAt($Stack.Count - 1)
    $Marks[$StageId] = 2
}

function Test-RouteGraph {
    foreach ($stage in @($script:Stages.Values)) {
        foreach ($dependency in $stage.Dependencies) {
            [void](Resolve-DependencyOwner -Dependency $dependency -RelativePath 'roadmap/index.md')
        }
        foreach ($unlocked in $stage.Unlocks) {
            if (-not $script:Stages.ContainsKey($unlocked)) {
                Add-LifecycleError -Code 'ROUTE_UNKNOWN_UNLOCK' -Path 'roadmap/index.md' -Message ("阶段 $($stage.Id) 引用未知解锁阶段：$unlocked")
            }
            elseif ($unlocked -eq $stage.Id) {
                Add-LifecycleError -Code 'ROUTE_SELF_UNLOCK' -Path 'roadmap/index.md' -Message ("阶段 $($stage.Id) 的 unlocks 导航摘要不能指向自身。")
            }
        }
    }

    $marks = @{}
    foreach ($stageId in $script:Stages.Keys) { $marks[$stageId] = 0 }
    foreach ($stageId in $script:Stages.Keys) {
        if ($marks[$stageId] -eq 0) {
            Visit-StageDependency -StageId $stageId -Marks $marks -Stack ([System.Collections.Generic.List[string]]::new())
        }
    }
}

function Test-EvidenceStateAllowed {
    param(
        [string]$TargetId,
        [string]$State
    )

    if (-not $script:Targets.ContainsKey($TargetId)) { return $false }
    if ($script:Targets[$TargetId].Minimum -eq 'sampled') {
        return $State -in @('unsampled', 'sampled')
    }
    return $State -in @('not_started', 'learning', 'guided', 'independent', 'robust', 'needs_refresh')
}

function Get-EvidenceRank {
    param([string]$State)

    switch ($State) {
        'unsampled' { return 0 }
        'not_started' { return 0 }
        'learning' { return 1 }
        'guided' { return 2 }
        'sampled' { return 3 }
        'independent' { return 3 }
        'robust' { return 4 }
        'needs_refresh' { return -1 }
        default { return -2 }
    }
}

function Test-EvidenceMeets {
    param(
        [string]$State,
        [string]$Minimum
    )

    if ($State -eq 'needs_refresh') { return $false }
    return (Get-EvidenceRank -State $State) -ge (Get-EvidenceRank -State $Minimum)
}

function Test-RequiredHeadings {
    param(
        [string]$Content,
        [string]$RelativePath,
        [string[]]$Required,
        [string]$CodePrefix
    )

    $headings = @(
        Get-MarkdownLinesOutsideFences -Content $Content |
            Where-Object { $_ -match '^##\s+\S' } |
            ForEach-Object { ($_ -replace '^##\s+', '').Trim() }
    )
    $lastIndex = -1
    foreach ($heading in $Required) {
        $indexes = @()
        for ($index = 0; $index -lt $headings.Count; $index++) {
            if ($headings[$index] -eq $heading) { $indexes += $index }
        }
        if ($indexes.Count -eq 0) {
            Add-LifecycleError -Code ($CodePrefix + '_MISSING_HEADING') -Path $RelativePath -Message ("缺少二级标题：$heading")
            continue
        }
        if ($indexes.Count -gt 1) {
            Add-LifecycleError -Code ($CodePrefix + '_DUPLICATE_HEADING') -Path $RelativePath -Message ("二级标题重复：$heading")
        }
        if ($indexes[0] -lt $lastIndex) {
            Add-LifecycleError -Code ($CodePrefix + '_HEADING_ORDER') -Path $RelativePath -Message ('二级标题顺序必须为：{0}' -f ($Required -join '、'))
            return
        }
        $lastIndex = $indexes[0]
    }
}

function Test-StageContractSections {
    param(
        [string]$Content,
        [string]$RelativePath,
        [string]$StageId
    )

    $required = @('阶段目的', '教学范围', '局部活动门槛', '退出目标', '阶段成果', '退出条件与解锁')
    $headings = @(
        Get-MarkdownLinesOutsideFences -Content $Content |
            Where-Object { $_ -match '^###\s+\S' } |
            ForEach-Object { ($_ -replace '^###\s+', '').Trim() }
    )
    $lastIndex = -1
    foreach ($heading in $required) {
        $indexes = @()
        for ($index = 0; $index -lt $headings.Count; $index++) {
            if ($headings[$index] -eq $heading) { $indexes += $index }
        }
        if ($indexes.Count -ne 1) {
            Add-LifecycleError -Code 'ROUTE_CONTRACT_SECTION' -Path $RelativePath -Message ("阶段 $StageId 的三级章节必须唯一存在：$heading")
            continue
        }
        if ($indexes[0] -lt $lastIndex) {
            Add-LifecycleError -Code 'ROUTE_CONTRACT_SECTION_ORDER' -Path $RelativePath -Message ("阶段 $StageId 的三级章节顺序非法。")
            return
        }
        $lastIndex = $indexes[0]
        $section = [regex]::Match($Content, '(?ms)^###\s+' + [regex]::Escape($heading) + '\s*\r?\n(?<body>.*?)(?=^###\s+|\z)')
        if (-not $section.Success -or -not (Test-MeaningfulContent -Content $section.Groups['body'].Value)) {
            Add-LifecycleError -Code 'ROUTE_CONTRACT_SECTION_EMPTY' -Path $RelativePath -Message ("阶段 $StageId 的三级章节为空：$heading")
        }
    }
}

function Test-SessionDocument {
    param(
        [string]$Content,
        [string]$RelativePath,
        [switch]$Template
    )

    $front = Read-FrontMatter -Content $Content -RelativePath $RelativePath -ExpectedKeys @('date', 'stage_id', 'activity', 'target_ids', 'topic', 'planned_minutes', 'status') -CodePrefix 'SESSION'
    if ($null -eq $front) { return $null }
    $values = $front.Values
    foreach ($key in @('date', 'stage_id', 'activity', 'target_ids', 'topic', 'planned_minutes', 'status')) {
        if (-not $values.Contains($key)) { return $null }
    }

    $date = [string]$values['date']
    $stageId = [string]$values['stage_id']
    $activity = ([string]$values['activity']).ToLowerInvariant()
    $targetIds = @(ConvertTo-ValueList -Value $values['target_ids'])
    $topic = [string]$values['topic']
    $minutes = [string]$values['planned_minutes']
    $status = ([string]$values['status']).ToLowerInvariant()

    if (-not (Test-IsoDate -Value $date)) {
        Add-LifecycleError -Code 'SESSION_DATE' -Path $RelativePath -Message ("date 非法：$date")
    }
    $pathMatch = [regex]::Match($RelativePath, '^sessions/(?<year>\d{4})/(?<month>\d{2})/(?<date>\d{4}-\d{2}-\d{2})-[^/]+\.md$')
    if (-not $pathMatch.Success) {
        Add-LifecycleError -Code 'SESSION_PATH' -Path $RelativePath -Message '学习单路径必须为 sessions/YYYY/MM/YYYY-MM-DD-<topic>.md。'
    }
    elseif ($date -ne $pathMatch.Groups['date'].Value -or -not $date.StartsWith($pathMatch.Groups['year'].Value + '-' + $pathMatch.Groups['month'].Value)) {
        Add-LifecycleError -Code 'SESSION_PATH_DATE' -Path $RelativePath -Message '学习单日期与目录或文件名不一致。'
    }
    if ($activity -notin @('diagnostic', 'learning', 'assessment', 'project')) {
        Add-LifecycleError -Code 'SESSION_ACTIVITY' -Path $RelativePath -Message ("activity 非法：$activity")
    }
    if ($status -notin @('planned', 'submitted', 'reviewed')) {
        Add-LifecycleError -Code 'SESSION_STATUS' -Path $RelativePath -Message ("status 非法：$status")
    }
    if ($minutes -notmatch '^[1-9]\d*$') {
        Add-LifecycleError -Code 'SESSION_MINUTES' -Path $RelativePath -Message ("planned_minutes 必须是正整数：$minutes")
    }
    if ([string]::IsNullOrWhiteSpace($topic)) {
        Add-LifecycleError -Code 'SESSION_TOPIC' -Path $RelativePath -Message 'topic 不能为空。'
    }
    if (-not $script:Stages.ContainsKey($stageId)) {
        Add-LifecycleError -Code 'SESSION_UNKNOWN_STAGE' -Path $RelativePath -Message ("未知 stage_id：$stageId")
    }
    if ($targetIds.Count -eq 0) {
        Add-LifecycleError -Code 'SESSION_TARGETS_EMPTY' -Path $RelativePath -Message 'target_ids 至少包含一个目标。'
    }
    if (@($targetIds | Sort-Object -Unique).Count -ne $targetIds.Count) {
        Add-LifecycleError -Code 'SESSION_DUPLICATE_TARGET' -Path $RelativePath -Message 'target_ids 包含重复目标。'
    }
    $hasPrimaryTarget = $false
    foreach ($targetId in $targetIds) {
        if (-not $script:Targets.ContainsKey($targetId)) {
            Add-LifecycleError -Code 'SESSION_UNKNOWN_TARGET' -Path $RelativePath -Message ("未知 target_id：$targetId")
        }
        elseif ($script:Targets[$targetId].StageId -eq $stageId) {
            $hasPrimaryTarget = $true
        }
    }
    if ($script:Stages.ContainsKey($stageId) -and -not $hasPrimaryTarget) {
        Add-LifecycleError -Code 'SESSION_PRIMARY_TARGET' -Path $RelativePath -Message '主要阶段必须至少拥有一个引用目标。'
    }

    Test-RequiredHeadings -Content $Content -RelativePath $RelativePath -Required @('本次目标', '前置检查', '学习内容', '练习', '用户结果', 'AI 批阅', '下一步', '相关项目与资料') -CodePrefix 'SESSION'
    $userResult = Get-MarkdownSection -Content $Content -Heading '用户结果'
    $aiReview = Get-MarkdownSection -Content $Content -Heading 'AI 批阅'
    if ($status -in @('submitted', 'reviewed') -and -not (Test-MeaningfulContent -Content $userResult)) {
        Add-LifecycleError -Code 'SESSION_EMPTY_USER_RESULT' -Path $RelativePath -Message "$status 学习单必须包含真实用户结果。"
    }
    if ($status -eq 'reviewed' -and -not (Test-MeaningfulContent -Content $aiReview)) {
        Add-LifecycleError -Code 'SESSION_EMPTY_AI_REVIEW' -Path $RelativePath -Message 'reviewed 学习单必须包含 AI 批阅。'
    }

    $evidence = @{}
    if ($status -eq 'reviewed' -and $null -ne $aiReview) {
        $table = Find-MarkdownTable -Content $aiReview -Headers @('target_id', 'help', 'evidence_state', 'evidence', 'correction_closure', 'review_debt') -RelativePath $RelativePath -MalformedCode 'SESSION_EVIDENCE_PARSE'
        if ($null -eq $table) {
            Add-LifecycleError -Code 'SESSION_EVIDENCE_TABLE' -Path $RelativePath -Message 'AI 批阅缺少固定逐目标证据表。'
        }
        else {
            foreach ($row in $table.Rows) {
                $targetId = Get-CleanCell -Value $row.Cells[0]
                $state = (Get-CleanCell -Value $row.Cells[2]).ToLowerInvariant()
                if ($evidence.ContainsKey($targetId)) {
                    Add-LifecycleError -Code 'SESSION_EVIDENCE_DUPLICATE' -Path $RelativePath -Message ("逐目标证据重复：$targetId")
                    continue
                }
                if ($targetId -notin $targetIds) {
                    Add-LifecycleError -Code 'SESSION_EVIDENCE_EXTRA' -Path $RelativePath -Message ("逐目标证据包含未声明目标：$targetId")
                }
                if (-not (Test-EvidenceStateAllowed -TargetId $targetId -State $state)) {
                    Add-LifecycleError -Code 'SESSION_EVIDENCE_STATE' -Path $RelativePath -Message ("$targetId 的 evidence_state 非法：$state")
                }
                elseif ($script:Targets[$targetId].Minimum -eq 'sampled' -and $state -eq 'sampled' -and $activity -notin @('diagnostic', 'assessment')) {
                    Add-LifecycleError -Code 'SESSION_DIAGNOSTIC_SOURCE' -Path $RelativePath -Message ("诊断目标 $targetId 的 sampled 证据必须来自 diagnostic 或无提示 assessment，不能把教学后表现倒写成基线样本。")
                }
                $help = (Get-CleanCell -Value $row.Cells[1]).ToLowerInvariant()
                if ($help -notin @('none', 'clarification', 'hint', 'framework', 'solution')) {
                    Add-LifecycleError -Code 'SESSION_HELP_LEVEL' -Path $RelativePath -Message ("$targetId 的 help 非法或仍是占位值：$help")
                }
                elseif ($script:Targets[$targetId].Minimum -eq 'sampled' -and $state -eq 'sampled' -and $activity -eq 'assessment' -and $help -notin @('none', 'clarification')) {
                    Add-LifecycleError -Code 'SESSION_DIAGNOSTIC_SOURCE' -Path $RelativePath -Message ("基线 assessment 的 sampled 证据必须无方法提示：$targetId 使用了 $help。")
                }
                $evidenceText = Get-CleanCell -Value $row.Cells[3]
                if ([string]::IsNullOrWhiteSpace($evidenceText) -or ($state -notin @('unsampled', 'not_started', 'learning') -and $evidenceText -in @('none', '暂无', '-', '—', '待填写'))) {
                    Add-LifecycleError -Code 'SESSION_EVIDENCE_EMPTY' -Path $RelativePath -Message ("$targetId 的 evidence 为空或仍是占位值。")
                }
                $closure = Get-CleanCell -Value $row.Cells[4]
                $hasIndependentClosure = $closure -match '^independently_closed(?:\s*[:：-]\s*\S.*)?$'
                if ($help -in @('hint', 'framework', 'solution') -and $state -in @('independent', 'robust') -and -not $hasIndependentClosure) {
                    Add-LifecycleError -Code 'SESSION_HELP_EVIDENCE_CONFLICT' -Path $RelativePath -Message ("$targetId 使用了 $help 帮助，但未明确完成等价任务无提示闭环，不能登记为 $state。")
                }
                foreach ($cellIndex in 4, 5) {
                    $cell = Get-CleanCell -Value $row.Cells[$cellIndex]
                    if ([string]::IsNullOrWhiteSpace($cell) -or $cell -in @('none', '暂无', '-', '—', '待填写')) {
                        Add-LifecycleError -Code 'SESSION_EVIDENCE_EMPTY' -Path $RelativePath -Message ("$targetId 的逐目标证据字段为空或仍是占位值。")
                    }
                }
                $evidence[$targetId] = [pscustomobject]@{ State = $state; Line = $row.Line }
            }
            foreach ($targetId in $targetIds) {
                if (-not $evidence.ContainsKey($targetId)) {
                    Add-LifecycleError -Code 'SESSION_EVIDENCE_MISSING' -Path $RelativePath -Message ("逐目标证据未覆盖：$targetId")
                }
            }
        }
    }

    return [pscustomobject]@{
        RelativePath = $RelativePath
        Date = $date
        StageId = $stageId
        Activity = $activity
        TargetIds = $targetIds
        Status = $status
        Evidence = $evidence
        IsTemplate = [bool]$Template
    }
}

function Read-Sessions {
    $sessionsRoot = Join-Path $script:RootPath 'sessions'
    if (-not (Test-Path -LiteralPath $sessionsRoot -PathType Container)) { return }
    foreach ($file in (Get-ChildItem -LiteralPath $sessionsRoot -Recurse -File -Filter '*.md')) {
        $relative = Get-RelativePath -Path $file.FullName
        $session = Test-SessionDocument -Content ([System.IO.File]::ReadAllText($file.FullName)) -RelativePath $relative
        if ($null -ne $session) { $script:Sessions[$relative] = $session }
    }
}

function Resolve-EvidenceLinks {
    param(
        [string]$Cell,
        [string]$SourceRelativePath,
        [string]$CodePrefix,
        [switch]$AllowNone
    )

    $clean = Get-CleanCell -Value $Cell
    if ($clean -in @('', 'none', '-', '—', '无')) {
        if (-not $AllowNone) {
            Add-LifecycleError -Code ($CodePrefix + '_EVIDENCE_LINK') -Path $SourceRelativePath -Message '证据列必须包含相对链接。'
        }
        return @()
    }

    $matches = @([regex]::Matches($clean, '!?(?:\[[^\]]*\])\((?<target>[^\)]+)\)'))
    if ($matches.Count -eq 0) {
        Add-LifecycleError -Code ($CodePrefix + '_EVIDENCE_LINK') -Path $SourceRelativePath -Message ("无法从证据列解析相对链接：$clean")
        return @()
    }

    $resolvedPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($match in $matches) {
        $target = $match.Groups['target'].Value.Trim()
        if ($target -match '^<(?<inner>[^>]+)>$') { $target = $Matches['inner'] }
        $target = ($target -split '#', 2)[0]
        $target = ($target -split '\?', 2)[0]
        if ([System.IO.Path]::IsPathRooted($target) -or $target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') {
            Add-LifecycleError -Code ($CodePrefix + '_EVIDENCE_LINK') -Path $SourceRelativePath -Message ("证据必须使用项目内相对链接：$target")
            continue
        }
        try {
            $sourceDirectory = Split-Path -Parent (Join-Path $script:RootPath ($SourceRelativePath.Replace('/', '\')))
            $full = [System.IO.Path]::GetFullPath((Join-Path $sourceDirectory ([System.Uri]::UnescapeDataString($target))))
            $prefix = $script:RootPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
            if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                Add-LifecycleError -Code ($CodePrefix + '_EVIDENCE_LINK') -Path $SourceRelativePath -Message ("证据链接超出项目：$target")
                continue
            }
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
                Add-LifecycleError -Code ($CodePrefix + '_EVIDENCE_MISSING') -Path $SourceRelativePath -Message ("证据文件不存在：$target")
                continue
            }
            $resolvedPaths.Add((Get-RelativePath -Path $full))
        }
        catch {
            Add-LifecycleError -Code ($CodePrefix + '_EVIDENCE_LINK') -Path $SourceRelativePath -Message ("证据链接无法解析：$target")
        }
    }
    return @($resolvedPaths)
}

function Read-Checkpoints {
    $checkpointRoot = Join-Path $script:RootPath 'checkpoints\stages'
    if (-not (Test-Path -LiteralPath $checkpointRoot -PathType Container)) { return }
    foreach ($file in (Get-ChildItem -LiteralPath $checkpointRoot -File -Filter '*.md')) {
        $relative = Get-RelativePath -Path $file.FullName
        $content = [System.IO.File]::ReadAllText($file.FullName)
        $front = Read-FrontMatter -Content $content -RelativePath $relative -ExpectedKeys @('stage_id', 'contract_version', 'completed_on', 'decision') -CodePrefix 'CHECKPOINT'
        if ($null -eq $front) { continue }
        $values = $front.Values
        $missingField = $false
        foreach ($key in @('stage_id', 'contract_version', 'completed_on', 'decision')) {
            if (-not $values.Contains($key)) { $missingField = $true }
        }
        if ($missingField) { continue }
        $stageId = [string]$values['stage_id']
        $version = [string]$values['contract_version']
        $completedOn = [string]$values['completed_on']
        $decision = ([string]$values['decision']).ToLowerInvariant()

        $pathMatch = [regex]::Match($relative, '^checkpoints/stages/(?<date>\d{4}-\d{2}-\d{2})-(?<stage>[a-z][a-z0-9-]*)\.md$')
        if (-not $pathMatch.Success) {
            Add-LifecycleError -Code 'CHECKPOINT_PATH' -Path $relative -Message '检查点路径必须为 checkpoints/stages/YYYY-MM-DD-<stage-id>.md。'
        }
        elseif ($completedOn -ne $pathMatch.Groups['date'].Value -or $stageId -ne $pathMatch.Groups['stage'].Value) {
            Add-LifecycleError -Code 'CHECKPOINT_PATH_MISMATCH' -Path $relative -Message '文件名与 stage_id 或 completed_on 不一致。'
        }
        if (-not (Test-IsoDate -Value $completedOn)) {
            Add-LifecycleError -Code 'CHECKPOINT_DATE' -Path $relative -Message ("completed_on 非法：$completedOn")
        }
        if ($decision -ne 'passed') {
            Add-LifecycleError -Code 'CHECKPOINT_DECISION' -Path $relative -Message '阶段检查点只允许 decision: passed。'
        }
        if (-not $script:Stages.ContainsKey($stageId)) {
            Add-LifecycleError -Code 'CHECKPOINT_UNKNOWN_STAGE' -Path $relative -Message ("未知 stage_id：$stageId")
            continue
        }
        if ($script:Checkpoints.ContainsKey($stageId)) {
            Add-LifecycleError -Code 'CHECKPOINT_DUPLICATE_STAGE' -Path $relative -Message ("阶段 $stageId 已有检查点。")
            continue
        }
        if ($version -ne $script:Stages[$stageId].Version) {
            Add-LifecycleError -Code 'CHECKPOINT_CONTRACT_VERSION' -Path $relative -Message ("检查点版本 $version 与当前契约版本 $($script:Stages[$stageId].Version) 不一致。")
        }

        Test-RequiredHeadings -Content $content -RelativePath $relative -Required @('逐目标证据', '独立性与迁移说明', '非阻断问题', '解锁结果') -CodePrefix 'CHECKPOINT'
        $evidenceSection = Get-MarkdownSection -Content $content -Heading '逐目标证据'
        $table = if ($null -ne $evidenceSection) { Find-MarkdownTable -Content $evidenceSection -Headers @('target_id', 'evidence_level', 'evidence_files', 'independence_or_transfer') -RelativePath $relative -MalformedCode 'CHECKPOINT_EVIDENCE_PARSE' } else { $null }
        $rows = @{}
        if ($null -eq $table) {
            Add-LifecycleError -Code 'CHECKPOINT_EVIDENCE_TABLE' -Path $relative -Message '缺少固定逐目标证据表。'
        }
        else {
            foreach ($row in $table.Rows) {
                $targetId = Get-CleanCell -Value $row.Cells[0]
                $level = (Get-CleanCell -Value $row.Cells[1]).ToLowerInvariant()
                $explanation = Get-CleanCell -Value $row.Cells[3]
                if ($rows.ContainsKey($targetId)) {
                    Add-LifecycleError -Code 'CHECKPOINT_DUPLICATE_TARGET' -Path $relative -Message ("检查点目标重复：$targetId")
                    continue
                }
                if (-not $script:Targets.ContainsKey($targetId) -or $script:Targets[$targetId].StageId -ne $stageId) {
                    Add-LifecycleError -Code 'CHECKPOINT_TARGET_SCOPE' -Path $relative -Message ("目标不属于阶段 $stageId：$targetId")
                    continue
                }
                if (-not (Test-EvidenceStateAllowed -TargetId $targetId -State $level)) {
                    Add-LifecycleError -Code 'CHECKPOINT_EVIDENCE_LEVEL' -Path $relative -Message ("$targetId 的 evidence_level 非法：$level")
                }
                elseif (-not (Test-EvidenceMeets -State $level -Minimum $script:Targets[$targetId].Minimum)) {
                    Add-LifecycleError -Code 'CHECKPOINT_MINIMUM_EVIDENCE' -Path $relative -Message ("$targetId 的 $level 未达到最低证据 $($script:Targets[$targetId].Minimum)。")
                }
                if ([string]::IsNullOrWhiteSpace($explanation) -or $explanation -in @('none', '-', '—') -or $explanation -match '^(待填写|实例化后)') {
                    $message = if ($stageId -eq 'baseline-diagnostic') { "$targetId 缺少起点结论。" } else { "$targetId 缺少独立性或迁移说明。" }
                    Add-LifecycleError -Code 'CHECKPOINT_EVIDENCE_EXPLANATION' -Path $relative -Message $message
                }

                $evidenceFiles = @(Resolve-EvidenceLinks -Cell $row.Cells[2] -SourceRelativePath $relative -CodePrefix 'CHECKPOINT')
                $hasStrongSource = $false
                foreach ($evidenceFile in $evidenceFiles) {
                    if (-not $evidenceFile.StartsWith('sessions/')) {
                        Add-LifecycleError -Code 'CHECKPOINT_EVIDENCE_TYPE' -Path $relative -Message ("检查点证据必须引用学习单：$evidenceFile")
                        continue
                    }
                    if (-not $script:Sessions.ContainsKey($evidenceFile)) { continue }
                    $session = $script:Sessions[$evidenceFile]
                    if ($session.Status -ne 'reviewed') {
                        Add-LifecycleError -Code 'CHECKPOINT_UNREVIEWED_EVIDENCE' -Path $relative -Message ("证据学习单尚未 reviewed：$evidenceFile")
                        continue
                    }
                    if ((Test-IsoDate -Value $session.Date) -and (Test-IsoDate -Value $completedOn) -and [datetime]$session.Date -gt [datetime]$completedOn) {
                        Add-LifecycleError -Code 'CHECKPOINT_EVIDENCE_DATE' -Path $relative -Message ("证据学习单日期晚于检查点完成日期：$evidenceFile")
                        continue
                    }
                    if (-not $session.Evidence.ContainsKey($targetId)) {
                        Add-LifecycleError -Code 'CHECKPOINT_TARGET_NOT_IN_EVIDENCE' -Path $relative -Message ("$evidenceFile 没有 $targetId 的逐目标证据。")
                        continue
                    }
                    if (Test-EvidenceMeets -State $session.Evidence[$targetId].State -Minimum $level) {
                        $hasStrongSource = $true
                    }
                }
                if ($evidenceFiles.Count -gt 0 -and -not $hasStrongSource) {
                    Add-LifecycleError -Code 'CHECKPOINT_EVIDENCE_STRENGTH' -Path $relative -Message ("已批阅证据不足以支持 $targetId 的 $level 声明。")
                }
                $effectiveAtCompletion = Get-TargetStateAtDate -TargetId $targetId -CutoffDate $completedOn
                if (-not (Test-EvidenceMeets -State $effectiveAtCompletion -Minimum $level)) {
                    Add-LifecycleError -Code 'CHECKPOINT_STALE_EVIDENCE' -Path $relative -Message ("$targetId 在 completed_on 时的最新有效状态是 $effectiveAtCompletion，不能用旧证据登记为 $level。")
                }
                $rows[$targetId] = [pscustomobject]@{ Level = $level; EvidenceFiles = $evidenceFiles }
            }
        }
        foreach ($targetId in $script:Stages[$stageId].Targets) {
            if (-not $rows.ContainsKey($targetId)) {
                Add-LifecycleError -Code 'CHECKPOINT_TARGET_MISSING' -Path $relative -Message ("检查点未覆盖退出目标：$targetId")
            }
        }
        if ($rows.Count -ne $script:Stages[$stageId].Targets.Count) {
            Add-LifecycleError -Code 'CHECKPOINT_TARGET_COVERAGE' -Path $relative -Message '检查点必须恰好覆盖当前契约的全部退出目标。'
        }
        foreach ($heading in @('独立性与迁移说明', '非阻断问题', '解锁结果')) {
            $sectionContent = Get-MarkdownSection -Content $content -Heading $heading
            $plain = if ($null -ne $sectionContent) { [regex]::Replace($sectionContent, '(?s)<!--.*?-->', '').Trim() } else { '' }
            if ([string]::IsNullOrWhiteSpace($plain) -or $plain -match '(?m)^\s*[-*]?\s*(待填写|实例化后|通过后填写)' -or $plain -match '或记录') {
                Add-LifecycleError -Code 'CHECKPOINT_SECTION_PLACEHOLDER' -Path $relative -Message ("$heading 为空或仍包含模板占位说明。")
            }
        }

        $script:Checkpoints[$stageId] = [pscustomobject]@{
            RelativePath = $relative
            StageId = $stageId
            CompletedOn = $completedOn
            Rows = $rows
        }
    }
}

function Get-TargetEvidenceState {
    param(
        [string]$TargetId,
        [AllowEmptyString()][string]$CutoffDate = ''
    )

    $state = if ($script:Targets[$TargetId].Minimum -eq 'sampled') { 'unsampled' } else { 'not_started' }
    if ($CutoffDate -and -not (Test-IsoDate -Value $CutoffDate)) { return $state }

    $events = [System.Collections.Generic.List[object]]::new()
    $ownerStage = $script:Targets[$TargetId].StageId
    if ($script:Checkpoints.ContainsKey($ownerStage)) {
        $checkpoint = $script:Checkpoints[$ownerStage]
        if (
            $checkpoint.Rows.ContainsKey($TargetId) -and
            (Test-IsoDate -Value $checkpoint.CompletedOn) -and
            (-not $CutoffDate -or [datetime]$checkpoint.CompletedOn -le [datetime]$CutoffDate)
        ) {
            $events.Add([pscustomobject]@{
                Date = $checkpoint.CompletedOn
                Order = 0
                Path = $checkpoint.RelativePath
                State = $checkpoint.Rows[$TargetId].Level
            })
        }
    }
    foreach ($session in $script:Sessions.Values) {
        if (
            $session.Status -eq 'reviewed' -and
            $session.Evidence.ContainsKey($TargetId) -and
            (Test-IsoDate -Value $session.Date) -and
            (-not $CutoffDate -or [datetime]$session.Date -le [datetime]$CutoffDate)
        ) {
            $events.Add([pscustomobject]@{
                Date = $session.Date
                Order = 1
                Path = $session.RelativePath
                State = $session.Evidence[$TargetId].State
            })
        }
    }

    # 学习单只有日期，没有日内时间。同一日期只要出现 needs_refresh，就保守地压过
    # 当天所有强证据；恢复必须来自更晚日期，不能借文件名排序伪造先后。
    foreach ($dateGroup in @($events | Group-Object Date | Sort-Object Name)) {
        $dayStates = @($dateGroup.Group | ForEach-Object { $_.State })
        if ($dayStates -contains 'needs_refresh') {
            $state = 'needs_refresh'
            continue
        }
        $candidate = @($dayStates | Sort-Object { Get-EvidenceRank -State $_ } -Descending | Select-Object -First 1)
        if ($candidate.Count -eq 0) { continue }
        $bestState = [string]$candidate[0]
        if ($state -eq 'needs_refresh' -or (Get-EvidenceRank -State $bestState) -gt (Get-EvidenceRank -State $state)) {
            $state = $bestState
        }
    }
    return $state
}

function Test-TargetHasOpenRefreshDebt {
    param([string]$TargetId)

    if (-not $script:Targets.ContainsKey($TargetId)) { return $false }
    $ownerStage = $script:Targets[$TargetId].StageId
    if (-not $script:Checkpoints.ContainsKey($ownerStage)) { return $false }
    $checkpointDate = $script:Checkpoints[$ownerStage].CompletedOn
    if (-not (Test-IsoDate -Value $checkpointDate)) { return $false }

    $cutoff = if ($script:CurrentCutoffDate) { $script:CurrentCutoffDate } else { (Get-Date).ToString('yyyy-MM-dd') }
    $events = @(
        $script:Sessions.Values |
            Where-Object {
                $_.Status -eq 'reviewed' -and
                $_.Evidence.ContainsKey($TargetId) -and
                (Test-IsoDate -Value $_.Date) -and
                [datetime]$_.Date -gt [datetime]$checkpointDate -and
                [datetime]$_.Date -le [datetime]$cutoff
            }
    )
    $refreshDates = @(
        $events |
            Where-Object { $_.Evidence[$TargetId].State -eq 'needs_refresh' } |
            ForEach-Object { $_.Date } |
            Sort-Object -Descending
    )
    if ($refreshDates.Count -eq 0) { return $false }
    $latestRefreshDate = [string]$refreshDates[0]

    # 同日没有可靠日内顺序，所以只有更晚日期达到契约最低证据才关闭债务。
    foreach ($session in $events) {
        if (
            [datetime]$session.Date -gt [datetime]$latestRefreshDate -and
            (Test-EvidenceMeets -State $session.Evidence[$TargetId].State -Minimum $script:Targets[$TargetId].Minimum)
        ) {
            return $false
        }
    }
    return $true
}

function Test-StageHasOpenRefreshDebt {
    param([string]$StageId)

    if (-not $script:Stages.ContainsKey($StageId)) { return $false }
    foreach ($targetId in $script:Stages[$StageId].Targets) {
        if (Test-TargetHasOpenRefreshDebt -TargetId $targetId) { return $true }
    }
    return $false
}

function Get-SessionEffectiveState {
    param([string]$TargetId)
    return Get-TargetEvidenceState -TargetId $TargetId -CutoffDate $script:CurrentCutoffDate
}

function Get-TargetStateAtDate {
    param([string]$TargetId, [string]$CutoffDate)
    return Get-TargetEvidenceState -TargetId $TargetId -CutoffDate $CutoffDate
}

function Test-StageUnlockedAtDate {
    param(
        [string]$StageId,
        [string]$EvidenceDate
    )

    if (-not $script:Stages.ContainsKey($StageId) -or -not (Test-IsoDate -Value $EvidenceDate)) { return $false }
    $priorDate = ([datetime]$EvidenceDate).AddDays(-1).ToString('yyyy-MM-dd')
    foreach ($dependency in $script:Stages[$StageId].Dependencies) {
        if ($dependency.StartsWith('target:')) {
            $targetId = $dependency.Substring(7)
            if (-not $script:Targets.ContainsKey($targetId)) { return $false }
            $state = Get-TargetStateAtDate -TargetId $targetId -CutoffDate $priorDate
            if (-not (Test-EvidenceMeets -State $state -Minimum $script:Targets[$targetId].Minimum)) { return $false }
        }
        else {
            if (-not $script:Checkpoints.ContainsKey($dependency)) { return $false }
            $checkpoint = $script:Checkpoints[$dependency]
            if (-not (Test-IsoDate -Value $checkpoint.CompletedOn) -or [datetime]$checkpoint.CompletedOn -ge [datetime]$EvidenceDate) { return $false }
        }
    }
    return $true
}

function Test-SessionEvidenceEligibility {
    foreach ($session in @($script:Sessions.Values | Where-Object { $_.Status -eq 'reviewed' })) {
        if (-not (Test-IsoDate -Value $session.Date)) { continue }
        foreach ($targetId in $session.Evidence.Keys) {
            if (-not $script:Targets.ContainsKey($targetId)) { continue }
            $state = $session.Evidence[$targetId].State
            $ownerStage = $script:Targets[$targetId].StageId
            if (-not (Test-StageUnlockedAtDate -StageId $ownerStage -EvidenceDate $session.Date)) {
                if ($session.Activity -ne 'learning' -or $state -notin @('not_started', 'learning', 'guided')) {
                    Add-LifecycleError -Code 'SESSION_LOCKED_STAGE_EVIDENCE' -Path $session.RelativePath -Message ("目标 $targetId 所属阶段 $ownerStage 尚未解锁；预览只允许 learning 活动并且证据最高为 guided，当前是 $($session.Activity)/$state。")
                }
            }
        }
    }
}

function Test-CurrentStateFreshness {
    param(
        [string]$TargetId,
        [string]$State,
        [string]$RelativePath
    )

    $effective = Get-SessionEffectiveState -TargetId $TargetId
    $isStale =
        ($effective -eq 'needs_refresh' -and $State -ne 'needs_refresh') -or
        ($State -ne 'needs_refresh' -and (Get-EvidenceRank -State $State) -gt (Get-EvidenceRank -State $effective))
    if ($isStale) {
        Add-LifecycleError -Code 'CURRENT_STALE_EVIDENCE' -Path $RelativePath -Message ("$TargetId 的当前状态 $State 高于按日期汇总后的有效状态 $effective。")
    }
}

function Test-CurrentEvidenceRow {
    param(
        [string]$TargetId,
        [string]$State,
        [string]$EvidenceCell,
        [string]$RelativePath
    )

    if (-not (Test-EvidenceStateAllowed -TargetId $TargetId -State $State)) {
        Add-LifecycleError -Code 'CURRENT_EVIDENCE_STATE' -Path $RelativePath -Message ("$TargetId 的 state 非法：$State")
        return
    }

    $initial = $State -in @('unsampled', 'not_started', 'learning')
    $links = @(Resolve-EvidenceLinks -Cell $EvidenceCell -SourceRelativePath $RelativePath -CodePrefix 'CURRENT' -AllowNone:$initial)
    $script:CurrentEvidenceLinks[$TargetId] = @($links)
    if ($initial) {
        # 初始状态可以链接相关教学经历，但链接仍必须指向已批阅学习单或有效检查点。
        foreach ($link in $links) {
            if ($script:Sessions.ContainsKey($link)) {
                if ($script:Sessions[$link].Status -ne 'reviewed') {
                    Add-LifecycleError -Code 'CURRENT_UNREVIEWED_EVIDENCE' -Path $RelativePath -Message ("当前状态引用未批阅学习单：$link")
                }
            }
            elseif ($link.StartsWith('checkpoints/stages/')) {
                $knownCheckpoint = @($script:Checkpoints.Values | Where-Object { $_.RelativePath -eq $link }).Count -gt 0
                if (-not $knownCheckpoint) {
                    Add-LifecycleError -Code 'CURRENT_INVALID_CHECKPOINT' -Path $RelativePath -Message ("当前状态引用无效阶段检查点：$link")
                }
            }
            else {
                Add-LifecycleError -Code 'CURRENT_EVIDENCE_TYPE' -Path $RelativePath -Message ("当前状态证据必须引用已批阅学习单或有效阶段检查点：$link")
            }
        }
        # 链接存在不把初始状态升级为诊断或独立证据。
        Test-CurrentStateFreshness -TargetId $TargetId -State $State -RelativePath $RelativePath
        return
    }

    $hasSupport = $false
    foreach ($link in $links) {
        if ($script:Sessions.ContainsKey($link)) {
            $session = $script:Sessions[$link]
            if ($session.Status -ne 'reviewed') {
                Add-LifecycleError -Code 'CURRENT_UNREVIEWED_EVIDENCE' -Path $RelativePath -Message ("当前状态引用未批阅学习单：$link")
                continue
            }
            if (
                $script:CurrentCutoffDate -and
                (Test-IsoDate -Value $session.Date) -and
                [datetime]$session.Date -gt [datetime]$script:CurrentCutoffDate
            ) {
                Add-LifecycleError -Code 'CURRENT_FUTURE_REVIEWED_EVIDENCE' -Path $link -Message '当前执行板不能引用晚于 updated 的 reviewed 学习单。'
                continue
            }
            if (-not $session.Evidence.ContainsKey($TargetId)) {
                Add-LifecycleError -Code 'CURRENT_TARGET_NOT_IN_EVIDENCE' -Path $RelativePath -Message ("$link 没有 $TargetId 的逐目标证据。")
                continue
            }
            $sourceState = $session.Evidence[$TargetId].State
            if (($State -eq 'needs_refresh' -and $sourceState -eq 'needs_refresh') -or ($State -ne 'needs_refresh' -and (Test-EvidenceMeets -State $sourceState -Minimum $State))) {
                $hasSupport = $true
            }
        }
        elseif ($State -ne 'needs_refresh' -and $link.StartsWith('checkpoints/stages/')) {
            $checkpoint = @($script:Checkpoints.Values | Where-Object { $_.RelativePath -eq $link } | Select-Object -First 1)
            if ($checkpoint.Count -eq 1 -and $checkpoint[0].Rows.ContainsKey($TargetId) -and (Test-EvidenceMeets -State $checkpoint[0].Rows[$TargetId].Level -Minimum $State)) {
                $hasSupport = $true
            }
        }
        else {
            Add-LifecycleError -Code 'CURRENT_EVIDENCE_TYPE' -Path $RelativePath -Message ("当前状态证据必须引用学习单或阶段检查点：$link")
        }
    }
    if (-not $hasSupport) {
        Add-LifecycleError -Code 'CURRENT_EVIDENCE_STRENGTH' -Path $RelativePath -Message ("证据不足以支持 $TargetId 的 $State 状态。")
    }
    Test-CurrentStateFreshness -TargetId $TargetId -State $State -RelativePath $RelativePath
}

function Get-EffectiveTargetState {
    param([string]$TargetId)

    $historyState = Get-SessionEffectiveState -TargetId $TargetId
    if ($script:CurrentRows.ContainsKey($TargetId)) {
        $currentState = $script:CurrentRows[$TargetId].State
        if ($historyState -eq 'needs_refresh' -and $currentState -ne 'needs_refresh') { return $historyState }
        if ($currentState -ne 'needs_refresh' -and (Get-EvidenceRank -State $currentState) -gt (Get-EvidenceRank -State $historyState)) { return $historyState }
        return $currentState
    }
    return $historyState
}

function Test-StageUnlocked {
    param([string]$StageId)

    if (-not $script:Stages.ContainsKey($StageId)) { return $false }
    foreach ($dependency in $script:Stages[$StageId].Dependencies) {
        if ($dependency.StartsWith('target:')) {
            $targetId = $dependency.Substring(7)
            if (-not $script:Targets.ContainsKey($targetId)) { return $false }
            $state = Get-EffectiveTargetState -TargetId $targetId
            if (-not (Test-EvidenceMeets -State $state -Minimum $script:Targets[$targetId].Minimum)) { return $false }
        }
        elseif (-not $script:Checkpoints.ContainsKey($dependency)) {
            return $false
        }
    }
    return $true
}

function Read-CurrentState {
    $relative = 'state/current.md'
    $path = Join-Path $script:RootPath $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-LifecycleError -Code 'CURRENT_MISSING' -Path $relative -Message '唯一当前执行板不存在。'
        return $null
    }
    $content = [System.IO.File]::ReadAllText($path)
    Test-RequiredHeadings -Content $content -RelativePath $relative -Required @('当前阶段目标状态', '合法的并行学习线', '关键能力复核队列', '唯一下一学习任务') -CodePrefix 'CURRENT'
    $front = Read-FrontMatter -Content $content -RelativePath $relative -ExpectedKeys @('updated', 'focus_stage_id', 'focus_mode', 'parallel_stage_ids') -CodePrefix 'CURRENT'
    if ($null -eq $front) { return $null }
    $values = $front.Values
    foreach ($key in @('updated', 'focus_stage_id', 'focus_mode', 'parallel_stage_ids')) {
        if (-not $values.Contains($key)) { return $null }
    }
    $updated = [string]$values['updated']
    $focus = [string]$values['focus_stage_id']
    $mode = ([string]$values['focus_mode']).ToLowerInvariant()
    $parallel = @(ConvertTo-ValueList -Value $values['parallel_stage_ids'])
    if (-not (Test-IsoDate -Value $updated)) {
        Add-LifecycleError -Code 'CURRENT_DATE' -Path $relative -Message ("updated 非法：$updated")
    }
    else {
        $script:CurrentCutoffDate = $updated
    }
    if (-not $script:Stages.ContainsKey($focus)) {
        Add-LifecycleError -Code 'CURRENT_UNKNOWN_STAGE' -Path $relative -Message ("未知 focus_stage_id：$focus")
    }
    if ($mode -notin @('work', 'exit_review')) {
        Add-LifecycleError -Code 'CURRENT_MODE' -Path $relative -Message ("focus_mode 非法：$mode")
    }
    if (@($parallel | Sort-Object -Unique).Count -ne $parallel.Count) {
        Add-LifecycleError -Code 'CURRENT_DUPLICATE_PARALLEL' -Path $relative -Message 'parallel_stage_ids 包含重复阶段。'
    }
    foreach ($stageId in $parallel) {
        if (-not $script:Stages.ContainsKey($stageId)) {
            Add-LifecycleError -Code 'CURRENT_UNKNOWN_PARALLEL' -Path $relative -Message ("未知并行阶段：$stageId")
        }
        if ($stageId -eq $focus) {
            Add-LifecycleError -Code 'CURRENT_ILLEGAL_PARALLEL' -Path $relative -Message '焦点阶段不能同时列为并行阶段。'
        }
    }

    $focusSection = Get-MarkdownSection -Content $content -Heading '当前阶段目标状态'
    $focusTable = if ($null -ne $focusSection) { Find-MarkdownTable -Content $focusSection -Headers @('target_id', 'state', 'evidence', 'unmet') -RelativePath $relative -MalformedCode 'CURRENT_TARGET_PARSE' } else { $null }
    $focusTargetIds = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $focusTable) {
        Add-LifecycleError -Code 'CURRENT_TARGET_TABLE' -Path $relative -Message '缺少当前阶段目标状态表。'
    }
    else {
        foreach ($row in $focusTable.Rows) {
            $targetId = Get-CleanCell -Value $row.Cells[0]
            $state = (Get-CleanCell -Value $row.Cells[1]).ToLowerInvariant()
            if ($script:CurrentRows.ContainsKey($targetId)) {
                Add-LifecycleError -Code 'CURRENT_DUPLICATE_TARGET' -Path $relative -Message ("当前目标重复：$targetId")
                continue
            }
            if (-not $script:Targets.ContainsKey($targetId) -or $script:Targets[$targetId].StageId -ne $focus) {
                Add-LifecycleError -Code 'CURRENT_TARGET_SCOPE' -Path $relative -Message ("目标不属于焦点阶段 $focus：$targetId")
                continue
            }
            if ([string]::IsNullOrWhiteSpace((Get-CleanCell -Value $row.Cells[3]))) {
                Add-LifecycleError -Code 'CURRENT_UNMET_EMPTY' -Path $relative -Message ("$targetId 的 unmet 不能为空。")
            }
            Test-CurrentEvidenceRow -TargetId $targetId -State $state -EvidenceCell $row.Cells[2] -RelativePath $relative
            $script:CurrentRows[$targetId] = [pscustomobject]@{ StageId = $focus; State = $state; Evidence = $row.Cells[2] }
            $focusTargetIds.Add($targetId)
        }
    }
    if ($script:Stages.ContainsKey($focus)) {
        foreach ($targetId in $script:Stages[$focus].Targets) {
            if ($targetId -notin $focusTargetIds) {
                Add-LifecycleError -Code 'CURRENT_TARGET_MISSING' -Path $relative -Message ("当前执行板未列出焦点退出目标：$targetId")
            }
        }
        if ($focusTargetIds.Count -ne $script:Stages[$focus].Targets.Count) {
            Add-LifecycleError -Code 'CURRENT_TARGET_COVERAGE' -Path $relative -Message '当前阶段目标表必须恰好覆盖焦点阶段目标。'
        }
    }

    $parallelSection = Get-MarkdownSection -Content $content -Heading '合法的并行学习线'
    $parallelTable = if ($null -ne $parallelSection) { Find-MarkdownTable -Content $parallelSection -Headers @('stage_id', 'target_ids', 'state', 'evidence', 'unmet') -RelativePath $relative -MalformedCode 'CURRENT_PARALLEL_PARSE' } else { $null }
    $seenParallel = [System.Collections.Generic.HashSet[string]]::new()
    if ($null -eq $parallelTable) {
        Add-LifecycleError -Code 'CURRENT_PARALLEL_TABLE' -Path $relative -Message '缺少合法的并行学习线表。'
    }
    else {
        foreach ($row in $parallelTable.Rows) {
            $stageId = Get-CleanCell -Value $row.Cells[0]
            $targetIds = @(ConvertTo-ValueList -Value $row.Cells[1])
            $state = (Get-CleanCell -Value $row.Cells[2]).ToLowerInvariant()
            [void]$seenParallel.Add($stageId)
            if ($stageId -notin $parallel) {
                Add-LifecycleError -Code 'CURRENT_PARALLEL_SCOPE' -Path $relative -Message ("并行表包含未声明阶段：$stageId")
            }
            if ($targetIds.Count -eq 0) {
                Add-LifecycleError -Code 'CURRENT_PARALLEL_TARGETS_EMPTY' -Path $relative -Message ("并行阶段 $stageId 没有 target_ids。")
            }
            foreach ($targetId in $targetIds) {
                if ($script:CurrentRows.ContainsKey($targetId)) {
                    Add-LifecycleError -Code 'CURRENT_DUPLICATE_TARGET' -Path $relative -Message ("当前目标重复：$targetId")
                    continue
                }
                if (-not $script:Targets.ContainsKey($targetId) -or $script:Targets[$targetId].StageId -ne $stageId) {
                    Add-LifecycleError -Code 'CURRENT_PARALLEL_TARGET_SCOPE' -Path $relative -Message ("目标不属于并行阶段 $stageId：$targetId")
                    continue
                }
                Test-CurrentEvidenceRow -TargetId $targetId -State $state -EvidenceCell $row.Cells[3] -RelativePath $relative
                $script:CurrentRows[$targetId] = [pscustomobject]@{ StageId = $stageId; State = $state; Evidence = $row.Cells[3] }
            }
            if ([string]::IsNullOrWhiteSpace((Get-CleanCell -Value $row.Cells[4]))) {
                Add-LifecycleError -Code 'CURRENT_UNMET_EMPTY' -Path $relative -Message ("并行阶段 $stageId 的 unmet 不能为空。")
            }
        }
    }
    foreach ($stageId in $parallel) {
        if (-not $seenParallel.Contains($stageId)) {
            Add-LifecycleError -Code 'CURRENT_PARALLEL_MISSING' -Path $relative -Message ("并行表未记录阶段：$stageId")
        }
    }

    $queueSection = Get-MarkdownSection -Content $content -Heading '关键能力复核队列'
    $queueTable = if ($null -ne $queueSection) { Find-MarkdownTable -Content $queueSection -Headers @('target_id', 'due', 'task', 'status') -RelativePath $relative -MalformedCode 'CURRENT_REVIEW_QUEUE_PARSE' } else { $null }
    if ($null -eq $queueTable) {
        Add-LifecycleError -Code 'CURRENT_REVIEW_QUEUE' -Path $relative -Message '缺少关键能力复核队列表。'
    }
    else {
        foreach ($row in $queueTable.Rows) {
            $targetId = Get-CleanCell -Value $row.Cells[0]
            $status = (Get-CleanCell -Value $row.Cells[3]).ToLowerInvariant()
            if (-not $script:Targets.ContainsKey($targetId)) {
                Add-LifecycleError -Code 'CURRENT_REVIEW_TARGET' -Path $relative -Message ("复核队列引用未知目标：$targetId")
            }
            if ($status -notin @('not_ready', 'pending', 'scheduled', 'completed')) {
                Add-LifecycleError -Code 'CURRENT_REVIEW_STATUS' -Path $relative -Message ("复核状态非法：$status")
            }
            if ([string]::IsNullOrWhiteSpace((Get-CleanCell -Value $row.Cells[1])) -or [string]::IsNullOrWhiteSpace((Get-CleanCell -Value $row.Cells[2]))) {
                Add-LifecycleError -Code 'CURRENT_REVIEW_EMPTY' -Path $relative -Message ("$targetId 的 due 或 task 不能为空。")
            }
        }
    }

    $nextSection = Get-MarkdownSection -Content $content -Heading '唯一下一学习任务'
    $next = $null
    if ($null -eq $nextSection) {
        Add-LifecycleError -Code 'NEXT_TASK_MISSING' -Path $relative -Message '缺少唯一下一学习任务。'
    }
    else {
        $nextMatch = [regex]::Match($nextSection.Trim(), '\A- stage_id:\s*(?<stage>[^\r\n]+)\r?\n- activity:\s*(?<activity>[^\r\n]+)\r?\n- target_ids:\s*(?<targets>[^\r\n]+)\r?\n- task:\s*(?<task>[^\r\n]+)\s*\z')
        if (-not $nextMatch.Success) {
            Add-LifecycleError -Code 'NEXT_TASK_FORMAT' -Path $relative -Message '唯一下一学习任务必须使用四个固定字段且只能有一项。'
        }
        else {
            $next = [pscustomobject]@{
                StageId = Get-CleanCell -Value $nextMatch.Groups['stage'].Value
                Activity = (Get-CleanCell -Value $nextMatch.Groups['activity'].Value).ToLowerInvariant()
                TargetIds = @(ConvertTo-ValueList -Value $nextMatch.Groups['targets'].Value)
                Task = Get-CleanCell -Value $nextMatch.Groups['task'].Value
            }
        }
    }

    return [pscustomobject]@{
        Updated = $updated
        FocusStageId = $focus
        FocusMode = $mode
        ParallelStageIds = $parallel
        Next = $next
    }
}

function Test-CurrentLifecycle {
    param($Current)

    if ($null -eq $Current) { return }
    $relative = 'state/current.md'
    $focus = $Current.FocusStageId
    if (-not $script:Stages.ContainsKey($focus)) { return }
    if (Test-IsoDate -Value $Current.Updated) {
        $currentDate = [datetime]$Current.Updated
        $today = (Get-Date).Date
        if ($currentDate -gt $today) {
            Add-LifecycleError -Code 'CURRENT_FUTURE_DATE' -Path $relative -Message 'updated 不能晚于当前日期。'
        }
        foreach ($checkpoint in $script:Checkpoints.Values) {
            if ((Test-IsoDate -Value $checkpoint.CompletedOn) -and ([datetime]$checkpoint.CompletedOn -gt $currentDate -or [datetime]$checkpoint.CompletedOn -gt $today)) {
                Add-LifecycleError -Code 'CURRENT_FUTURE_CHECKPOINT' -Path $checkpoint.RelativePath -Message 'passed checkpoint 的 completed_on 不能晚于 current.updated 或当前日期。'
            }
        }
        $relevantTargetIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($targetId in $script:CurrentRows.Keys) { [void]$relevantTargetIds.Add($targetId) }
        $relevantStageIds = @($focus) + @($Current.ParallelStageIds)
        if ($null -ne $Current.Next) { $relevantStageIds += $Current.Next.StageId }
        foreach ($stageId in $relevantStageIds) {
            if (-not $script:Stages.ContainsKey($stageId)) { continue }
            foreach ($dependency in $script:Stages[$stageId].Dependencies) {
                if ($dependency.StartsWith('target:')) { [void]$relevantTargetIds.Add($dependency.Substring(7)) }
            }
        }
        if ($null -ne $Current.Next) {
            foreach ($targetId in $Current.Next.TargetIds) { [void]$relevantTargetIds.Add($targetId) }
        }
        foreach ($session in $script:Sessions.Values) {
            if ($session.Status -ne 'reviewed' -or -not (Test-IsoDate -Value $session.Date)) { continue }
            $sessionDate = [datetime]$session.Date
            if ($sessionDate -gt $today) {
                Add-LifecycleError -Code 'CURRENT_FUTURE_REVIEWED_EVIDENCE' -Path $session.RelativePath -Message 'reviewed 学习单日期不能晚于当前日期；未来任务应保持 planned。'
                continue
            }
            if ($sessionDate -le $currentDate) { continue }

            if (@($session.Evidence.Values | Where-Object { $_.State -eq 'needs_refresh' }).Count -gt 0) {
                Add-LifecycleError -Code 'CURRENT_FUTURE_REVIEWED_EVIDENCE' -Path $session.RelativePath -Message 'current.updated 之后出现 needs_refresh，必须同步执行板并安排局部重开。'
                continue
            }

            $directlyReferenced = @($script:CurrentEvidenceLinks.Values | Where-Object { $_ -contains $session.RelativePath }).Count -gt 0
            $changesRelevantState = $false
            foreach ($targetId in $session.Evidence.Keys) {
                if (-not $relevantTargetIds.Contains($targetId)) { continue }
                $atCurrent = Get-TargetStateAtDate -TargetId $targetId -CutoffDate $Current.Updated
                $atToday = Get-TargetStateAtDate -TargetId $targetId -CutoffDate $today.ToString('yyyy-MM-dd')
                if ($atCurrent -ne $atToday) { $changesRelevantState = $true; break }
            }
            if ($directlyReferenced -or $changesRelevantState) {
                Add-LifecycleError -Code 'CURRENT_FUTURE_REVIEWED_EVIDENCE' -Path $session.RelativePath -Message '晚于 current.updated 的 reviewed 学习单已被当前状态引用或会改变当前解锁，应先同步执行板。'
            }
        }
    }
    if ($script:Stages.ContainsKey('baseline-diagnostic') -and $focus -ne 'baseline-diagnostic' -and -not $script:Checkpoints.ContainsKey('baseline-diagnostic')) {
        Add-LifecycleError -Code 'CURRENT_BASELINE_NOT_CLOSED' -Path $relative -Message '焦点离开 baseline-diagnostic 前必须已有有效的基线通过检查点。'
    }
    if ($script:Checkpoints.ContainsKey($focus) -and -not (Test-StageHasOpenRefreshDebt -StageId $focus)) {
        Add-LifecycleError -Code 'CURRENT_COMPLETED_FOCUS' -Path $relative -Message ("焦点阶段已有通过检查点：$focus")
    }
    if (-not (Test-StageUnlocked -StageId $focus)) {
        Add-LifecycleError -Code 'CURRENT_LOCKED_FOCUS' -Path $relative -Message ("焦点阶段依赖尚未满足：$focus")
    }
    foreach ($stageId in $Current.ParallelStageIds) {
        if (-not $script:Stages.ContainsKey($stageId)) { continue }
        if ($script:Checkpoints.ContainsKey($stageId) -and -not (Test-StageHasOpenRefreshDebt -StageId $stageId)) {
            Add-LifecycleError -Code 'CURRENT_COMPLETED_PARALLEL' -Path $relative -Message ("并行阶段已有通过检查点：$stageId")
        }
        if (-not (Test-StageUnlocked -StageId $stageId)) {
            Add-LifecycleError -Code 'CURRENT_ILLEGAL_PARALLEL' -Path $relative -Message ("并行阶段依赖尚未满足：$stageId")
        }
    }

    $allFocusTargetsSatisfied = $true
    foreach ($targetId in $script:Stages[$focus].Targets) {
        if (-not $script:CurrentRows.ContainsKey($targetId) -or -not (Test-EvidenceMeets -State $script:CurrentRows[$targetId].State -Minimum $script:Targets[$targetId].Minimum)) {
            $allFocusTargetsSatisfied = $false
        }
    }
    if ($Current.FocusMode -eq 'exit_review' -and -not $allFocusTargetsSatisfied) {
        Add-LifecycleError -Code 'CURRENT_PREMATURE_EXIT_REVIEW' -Path $relative -Message '尚有退出目标未满足，不能进入 exit_review。'
    }
    if ($Current.FocusMode -eq 'work' -and $allFocusTargetsSatisfied) {
        Add-LifecycleError -Code 'CURRENT_EXIT_REVIEW_REQUIRED' -Path $relative -Message '焦点退出目标已满足，应进入 exit_review 而不是继续标记 work。'
    }

    $next = $Current.Next
    if ($null -eq $next) { return }
    if ($next.Activity -notin @('diagnostic', 'learning', 'assessment', 'project')) {
        Add-LifecycleError -Code 'NEXT_ACTIVITY' -Path $relative -Message ("下一任务 activity 非法：$($next.Activity)")
    }
    if ([string]::IsNullOrWhiteSpace($next.Task) -or $next.Task -eq '待填写') {
        Add-LifecycleError -Code 'NEXT_TASK_EMPTY' -Path $relative -Message '下一任务的 task 不能为空。'
    }
    if (-not $script:Stages.ContainsKey($next.StageId)) {
        Add-LifecycleError -Code 'NEXT_UNKNOWN_STAGE' -Path $relative -Message ("下一任务引用未知阶段：$($next.StageId)")
        return
    }
    if ($next.StageId -ne $focus -and $next.StageId -notin $Current.ParallelStageIds) {
        Add-LifecycleError -Code 'NEXT_STAGE_SCOPE' -Path $relative -Message ("下一任务阶段既不是当前焦点，也未登记为合法并行线：$($next.StageId)")
    }
    $nextCompletedWithoutRefresh = $script:Checkpoints.ContainsKey($next.StageId) -and -not (Test-StageHasOpenRefreshDebt -StageId $next.StageId)
    if ($nextCompletedWithoutRefresh -or -not (Test-StageUnlocked -StageId $next.StageId)) {
        Add-LifecycleError -Code 'NEXT_LOCKED_STAGE' -Path $relative -Message ("下一任务指向锁定或已完成阶段：$($next.StageId)")
    }
    if ($next.TargetIds.Count -eq 0) {
        Add-LifecycleError -Code 'NEXT_TARGETS_EMPTY' -Path $relative -Message '下一任务至少引用一个目标。'
    }
    $hasPrimary = $false
    foreach ($targetId in $next.TargetIds) {
        if (-not $script:Targets.ContainsKey($targetId)) {
            Add-LifecycleError -Code 'NEXT_UNKNOWN_TARGET' -Path $relative -Message ("下一任务引用未知目标：$targetId")
            continue
        }
        $owner = $script:Targets[$targetId].StageId
        if ($owner -eq $next.StageId) { $hasPrimary = $true }
        if (-not (Test-StageUnlocked -StageId $owner)) {
            Add-LifecycleError -Code 'NEXT_LOCKED_TARGET' -Path $relative -Message ("下一任务目标所属阶段尚未解锁：$targetId")
        }
        $state = Get-EffectiveTargetState -TargetId $targetId
        if ($script:Checkpoints.ContainsKey($next.StageId) -and -not (Test-TargetHasOpenRefreshDebt -TargetId $targetId)) {
            Add-LifecycleError -Code 'NEXT_REOPEN_TARGET' -Path $relative -Message ("已通过阶段只能重开 needs_refresh 目标：$targetId")
        }
        $isExitAssessment = $Current.FocusMode -eq 'exit_review' -and $next.Activity -eq 'assessment' -and $next.StageId -eq $focus -and $owner -eq $focus
        if ((Test-EvidenceMeets -State $state -Minimum $script:Targets[$targetId].Minimum) -and -not $isExitAssessment) {
            Add-LifecycleError -Code 'NEXT_SATISFIED_TARGET' -Path $relative -Message ("下一任务指向已经满足的目标：$targetId")
        }
    }
    if (-not $hasPrimary) {
        Add-LifecycleError -Code 'NEXT_PRIMARY_TARGET' -Path $relative -Message '下一任务主要阶段必须至少拥有一个引用目标。'
    }
}

function Test-CheckpointDependencies {
    foreach ($checkpoint in @($script:Checkpoints.Values)) {
        $stage = $script:Stages[$checkpoint.StageId]
        if ($checkpoint.StageId -ne 'baseline-diagnostic') {
            if (-not $script:Checkpoints.ContainsKey('baseline-diagnostic')) {
                Add-LifecycleError -Code 'CHECKPOINT_BASELINE_NOT_CLOSED' -Path $checkpoint.RelativePath -Message '基线期间可以积累并行证据，但不能提前生成非 baseline 阶段检查点。'
            }
            else {
                $baselineCheckpoint = $script:Checkpoints['baseline-diagnostic']
                if ((Test-IsoDate -Value $baselineCheckpoint.CompletedOn) -and (Test-IsoDate -Value $checkpoint.CompletedOn) -and [datetime]$baselineCheckpoint.CompletedOn -ge [datetime]$checkpoint.CompletedOn) {
                    Add-LifecycleError -Code 'CHECKPOINT_BASELINE_NOT_CLOSED' -Path $checkpoint.RelativePath -Message '基线通过检查点必须严格早于非 baseline 阶段检查点。'
                }
            }
        }
        foreach ($dependency in $stage.Dependencies) {
            if ($dependency.StartsWith('target:')) {
                $targetId = $dependency.Substring(7)
                if (-not $script:Targets.ContainsKey($targetId)) { continue }
                $priorDate = ([datetime]$checkpoint.CompletedOn).AddDays(-1).ToString('yyyy-MM-dd')
                $state = Get-TargetStateAtDate -TargetId $targetId -CutoffDate $priorDate
                if (-not (Test-EvidenceMeets -State $state -Minimum $script:Targets[$targetId].Minimum)) {
                    Add-LifecycleError -Code 'CHECKPOINT_UNMET_DEPENDENCY' -Path $checkpoint.RelativePath -Message ("通过检查点绕过目标依赖：$dependency")
                }
            }
            elseif (-not $script:Checkpoints.ContainsKey($dependency)) {
                Add-LifecycleError -Code 'CHECKPOINT_UNMET_DEPENDENCY' -Path $checkpoint.RelativePath -Message ("通过检查点缺少上游阶段检查点：$dependency")
            }
            else {
                $upstream = $script:Checkpoints[$dependency]
                if ((Test-IsoDate -Value $upstream.CompletedOn) -and (Test-IsoDate -Value $checkpoint.CompletedOn) -and [datetime]$upstream.CompletedOn -ge [datetime]$checkpoint.CompletedOn) {
                    Add-LifecycleError -Code 'CHECKPOINT_DEPENDENCY_DATE' -Path $checkpoint.RelativePath -Message ("上游阶段 $dependency 的完成日期必须严格早于当前检查点。")
                }
            }
        }
    }
}

function Test-LearningSessionTemplate {
    $relative = 'templates/learning-session.md'
    $path = Join-Path $script:RootPath $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-LifecycleError -Code 'TEMPLATE_MISSING' -Path $relative -Message '学习单模板不存在。'
        return
    }
    $content = [System.IO.File]::ReadAllText($path)
    $front = Read-FrontMatter -Content $content -RelativePath $relative -ExpectedKeys @('date', 'stage_id', 'activity', 'target_ids', 'topic', 'planned_minutes', 'status') -CodePrefix 'TEMPLATE'
    if ($null -eq $front -or $script:Stages.Count -eq 0 -or $script:Targets.Count -eq 0) { return }
    $rawReviewSection = Get-MarkdownSection -Content $content -Heading 'AI 批阅'
    if ($null -eq $rawReviewSection -or $null -eq (Find-MarkdownTable -Content $rawReviewSection -Headers @('target_id', 'help', 'evidence_state', 'evidence', 'correction_closure', 'review_debt') -RelativePath $relative -MalformedCode 'TEMPLATE_REVIEW_TABLE_PARSE')) {
        Add-LifecycleError -Code 'TEMPLATE_REVIEW_TABLE' -Path $relative -Message '学习单模板的 AI 批阅区缺少固定逐目标证据表。'
    }
    $stage = @($script:Stages.Values | Where-Object { $_.Targets.Count -gt 0 } | Select-Object -First 1)
    if ($stage.Count -eq 0) { return }
    $targetId = $stage[0].Targets[0]
    $activity = if ($script:Targets[$targetId].Minimum -eq 'sampled') { 'diagnostic' } else { 'learning' }
    $body = $content.Substring($front.BodyStart)
    $instantiated = @"
---
date: 2099-01-01
stage_id: $($stage[0].Id)
activity: $activity
target_ids:
  - $targetId
topic: 模板结构验证
planned_minutes: 90
status: planned
---
$body
"@
    $before = $script:ErrorCount
    [void](Test-SessionDocument -Content $instantiated -RelativePath 'sessions/2099/01/2099-01-01-template-instance.md' -Template)
    if ($script:ErrorCount -gt $before) {
        Add-LifecycleError -Code 'TEMPLATE_INSTANTIATION' -Path $relative -Message '学习单模板按真实字段实例化后未通过学习单结构检查。'
    }

    $reviewed = $instantiated -replace '(?m)^status:\s*planned\s*$', 'status: reviewed'
    $reviewed = [regex]::Replace($reviewed, '(?ms)(^##\s+用户结果\s*\r?\n).*?(?=^##\s+AI 批阅)', ('$1' + "`n- 学习者提交了可验证结果。`n`n"))
    $reviewTable = @"
| target_id | help | evidence_state | evidence | correction_closure | review_debt |
|---|---|---|---|---|---|
| $targetId | none | $($script:Targets[$targetId].Minimum) | 已定位到本学习单的用户结果 | not_needed | 无待处理复核债务 |
"@
    $reviewed = [regex]::Replace($reviewed, '(?ms)(^##\s+AI 批阅\s*\r?\n).*?(?=^##\s+下一步)', ('$1' + "`n" + $reviewTable + "`n"))
    $beforeReviewed = $script:ErrorCount
    [void](Test-SessionDocument -Content $reviewed -RelativePath 'sessions/2099/01/2099-01-01-template-reviewed.md' -Template)
    if ($script:ErrorCount -gt $beforeReviewed) {
        Add-LifecycleError -Code 'TEMPLATE_REVIEWED_INSTANTIATION' -Path $relative -Message '学习单模板实例化为 reviewed 后未通过逐目标证据结构检查。'
    }
}

function Test-CheckpointTemplate {
    $relative = 'templates/stage-checkpoint.md'
    $path = Join-Path $script:RootPath $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
    $content = [System.IO.File]::ReadAllText($path)
    [void](Read-FrontMatter -Content $content -RelativePath $relative -ExpectedKeys @('stage_id', 'contract_version', 'completed_on', 'decision') -CodePrefix 'TEMPLATE_CHECKPOINT')
    Test-RequiredHeadings -Content $content -RelativePath $relative -Required @('逐目标证据', '独立性与迁移说明', '非阻断问题', '解锁结果') -CodePrefix 'TEMPLATE_CHECKPOINT'
    $section = Get-MarkdownSection -Content $content -Heading '逐目标证据'
    $table = if ($null -ne $section) { Find-MarkdownTable -Content $section -Headers @('target_id', 'evidence_level', 'evidence_files', 'independence_or_transfer') -RelativePath $relative -MalformedCode 'TEMPLATE_CHECKPOINT_TABLE_PARSE' } else { $null }
    if ($null -eq $table) {
        Add-LifecycleError -Code 'TEMPLATE_CHECKPOINT_TABLE' -Path $relative -Message '阶段检查点模板缺少固定逐目标证据表。'
    }
    else {
        $templateRows = @($table.Rows)
        $evidenceCell = if ($templateRows.Count -gt 0) { [string]$templateRows[0].Cells[2] } else { '' }
        if ($templateRows.Count -eq 0 -or $evidenceCell -notmatch '\[[^\]]+\]\((?![a-zA-Z][a-zA-Z0-9+.-]*:|/)[^\)]+\)') {
            Add-LifecycleError -Code 'TEMPLATE_CHECKPOINT_EVIDENCE_LINK' -Path $relative -Message '阶段检查点模板的 evidence_files 示例必须是项目内 Markdown 相对链接。'
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $script:RootPath -PathType Container)) {
        Add-LifecycleError -Code 'ROOT_MISSING' -Path $Root -Message '项目根目录不存在。'
    }
    else {
        Read-RouteRegistry
        Read-StageContracts
        Test-RouteGraph
        Read-Sessions
        Read-Checkpoints
        Test-SessionEvidenceEligibility
        $current = Read-CurrentState
        Test-CurrentLifecycle -Current $current
        Test-CheckpointDependencies
        Test-LearningSessionTemplate
        Test-CheckpointTemplate
    }
}
catch {
    Add-LifecycleError -Code 'UNHANDLED' -Path '.' -Message $_.Exception.Message
}

Write-Output ('生命周期检查完成：{0} 个阶段，{1} 个目标，{2} 份学习单，{3} 个通过检查点，{4} 个错误。' -f $script:Stages.Count, $script:Targets.Count, $script:Sessions.Count, $script:Checkpoints.Count, $script:ErrorCount)
if ($script:ErrorCount -gt 0) { exit 1 }
exit 0
