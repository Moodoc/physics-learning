[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$checkerPath = Join-Path $PSScriptRoot 'check-docs.ps1'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$templatePath = Join-Path $repositoryRoot 'templates\learning-session.md'
$script:Passed = 0
$script:Failed = 0

function New-TestRoot {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ('physics-doc-check-' + [guid]::NewGuid().ToString('N'))
    [System.IO.Directory]::CreateDirectory($path) > $null
    return $path
}

function Get-ValidSessionContent {
    $content = [System.IO.File]::ReadAllText($templatePath)
    $content = [regex]::Replace($content, '(?m)^date:\s*.*$', 'date: 2000-01-02')
    $content = [regex]::Replace($content, '(?m)^stage_id:\s*.*$', 'stage_id: sample-stage')
    $content = [regex]::Replace($content, '(?m)^\s+-\s+TARGET-01\s*$', '  - SAMPLE-01', 1)
    $content = [regex]::Replace($content, '(?m)^topic:\s*.*$', 'topic: 模板结构测试')
    return $content
}

function Invoke-CheckCase {
    param(
        [string]$Name,
        [string]$SessionContent,
        [bool]$ShouldPass,
        [string]$ExpectedCode = ''
    )

    $testRoot = New-TestRoot
    try {
        $sessionDirectory = Join-Path $testRoot 'sessions\2000\01'
        $templateDirectory = Join-Path $testRoot 'templates'
        [System.IO.Directory]::CreateDirectory($sessionDirectory) > $null
        [System.IO.Directory]::CreateDirectory($templateDirectory) > $null
        [System.IO.File]::WriteAllText((Join-Path $sessionDirectory '2000-01-02-sample.md'), $SessionContent, [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText((Join-Path $templateDirectory 'learning-session.md'), ([System.IO.File]::ReadAllText($templatePath)), [System.Text.UTF8Encoding]::new($false))

        $output = @(& pwsh -NoProfile -File $checkerPath -Root $testRoot 2>&1)
        $exitCode = $LASTEXITCODE
        $passed = if ($ShouldPass) {
            $exitCode -eq 0
        }
        else {
            $exitCode -ne 0 -and ($output -join "`n").Contains("[$ExpectedCode]")
        }

        if ($passed) {
            $script:Passed++
            Write-Output "PASS $Name"
        }
        else {
            $script:Failed++
            Write-Output "FAIL $Name"
            $output | ForEach-Object { Write-Output "  $_" }
        }
    }
    finally {
        $tempParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        $resolvedRoot = [System.IO.Path]::GetFullPath($testRoot)
        if ($resolvedRoot.StartsWith($tempParent, [System.StringComparison]::OrdinalIgnoreCase) -and [System.IO.Directory]::Exists($resolvedRoot)) {
            [System.IO.Directory]::Delete($resolvedRoot, $true)
        }
    }
}

$valid = Get-ValidSessionContent
Invoke-CheckCase -Name 'valid-session' -SessionContent $valid -ShouldPass $true
Invoke-CheckCase -Name 'missing-heading' -SessionContent ([regex]::Replace($valid, '(?m)^## 练习\r?\n', '')) -ShouldPass $false -ExpectedCode 'SESSION_HEADINGS'
Invoke-CheckCase -Name 'duplicate-heading' -SessionContent ($valid.Replace('## 练习', "## 练习`n`n## 练习")) -ShouldPass $false -ExpectedCode 'SESSION_HEADINGS'
Invoke-CheckCase -Name 'unordered-headings' -SessionContent ($valid.Replace("## 本次目标`n`n- 待填写`n`n## 前置检查", "## 前置检查`n`n- 待填写`n`n## 本次目标")) -ShouldPass $false -ExpectedCode 'SESSION_HEADINGS'
Invoke-CheckCase -Name 'illegal-enum' -SessionContent ($valid.Replace('status: planned', 'status: finished')) -ShouldPass $false -ExpectedCode 'SESSION_FRONTMATTER_VALUE'
Invoke-CheckCase -Name 'duplicate-field' -SessionContent ($valid.Replace('status: planned', "status: planned`nstatus: planned")) -ShouldPass $false -ExpectedCode 'SESSION_FRONTMATTER'
Invoke-CheckCase -Name 'unparseable-frontmatter' -SessionContent ($valid.Replace('activity: learning', 'activity learning')) -ShouldPass $false -ExpectedCode 'SESSION_FRONTMATTER'

Write-Output ("文档检查器测试：{0} 通过，{1} 失败。" -f $script:Passed, $script:Failed)
if ($script:Failed -gt 0) {
    exit 1
}
exit 0
