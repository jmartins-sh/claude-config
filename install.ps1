<#
.SYNOPSIS
    Aplica a configuracao deste repositorio ao Claude Code local (Windows PowerShell 5.1 ou PowerShell 7).

.DESCRIPTION
    1. Mescla config/settings.json com ~/.claude/settings.json:
       - objetos sao mesclados recursivamente;
       - listas recebem os itens do repositorio que ainda nao existem;
       - valores simples do repositorio substituem os locais;
       - chaves que so existem localmente (por exemplo, autoMode) sao preservadas.
    2. Copia config/CLAUDE.md, se existir.
    3. Instala as skills de terceiros listadas em skills.json (requer Node.js/npx).
    Antes de alterar qualquer arquivo, grava uma copia em ~/.claude/backups.

.EXAMPLE
    .\install.ps1 -DryRun
    .\install.ps1
    .\install.ps1 -SkipSkills
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipSkills
)

$ErrorActionPreference = 'Stop'
$RepoDir = $PSScriptRoot
$ClaudeDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$BackupDir = Join-Path $ClaudeDir 'backups'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }

function ConvertTo-Key($Value) { ConvertTo-Json -InputObject $Value -Compress -Depth 100 }

function Merge-Json($Base, $Over) {
    if ($Base -is [System.Management.Automation.PSCustomObject] -and $Over -is [System.Management.Automation.PSCustomObject]) {
        foreach ($prop in $Over.PSObject.Properties) {
            $existing = $Base.PSObject.Properties[$prop.Name]
            if ($existing) {
                $Base.($prop.Name) = Merge-Json $existing.Value $prop.Value
            } else {
                $Base | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
            }
        }
        return $Base
    }
    if ($Base -is [System.Array] -and $Over -is [System.Array]) {
        $result = New-Object System.Collections.ArrayList
        $seen = @{}
        foreach ($item in @($Base) + @($Over)) {
            $key = ConvertTo-Key $item
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                [void]$result.Add($item)
            }
        }
        return , $result.ToArray()
    }
    return $Over
}

function Backup-File([string]$Path) {
    if (Test-Path $Path) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        $dest = Join-Path $BackupDir ("{0}.{1}.bak" -f (Split-Path $Path -Leaf), $Stamp)
        Copy-Item $Path $dest
        Write-Host "    copia de seguranca: $dest"
    }
}

# 1. settings.json
Write-Step 'Mesclando settings.json'
$repoSettingsPath = Join-Path $RepoDir 'config/settings.json'
$localSettingsPath = Join-Path $ClaudeDir 'settings.json'
$repoSettings = [System.IO.File]::ReadAllText($repoSettingsPath) | ConvertFrom-Json
if (Test-Path $localSettingsPath) {
    $localSettings = [System.IO.File]::ReadAllText($localSettingsPath) | ConvertFrom-Json
} else {
    $localSettings = New-Object PSObject
}
$merged = Merge-Json $localSettings $repoSettings
$mergedJson = ConvertTo-Json -InputObject $merged -Depth 100

if ($DryRun) {
    Write-Host $mergedJson
} else {
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    Backup-File $localSettingsPath
    [System.IO.File]::WriteAllText($localSettingsPath, $mergedJson + "`n", $Utf8NoBom)
    Write-Host "    gravado: $localSettingsPath"
}

# 2. CLAUDE.md
$repoClaudeMd = Join-Path $RepoDir 'config/CLAUDE.md'
if (Test-Path $repoClaudeMd) {
    Write-Step 'Copiando CLAUDE.md'
    $localClaudeMd = Join-Path $ClaudeDir 'CLAUDE.md'
    if ($DryRun) {
        Write-Host "    copiaria para $localClaudeMd"
    } else {
        Backup-File $localClaudeMd
        Copy-Item $repoClaudeMd $localClaudeMd -Force
    }
}

# 3. Skills de terceiros
if (-not $SkipSkills) {
    Write-Step 'Instalando skills de terceiros (skills.json)'
    $manifest = [System.IO.File]::ReadAllText((Join-Path $RepoDir 'skills.json')) | ConvertFrom-Json
    $npx = Get-Command npx -ErrorAction SilentlyContinue
    foreach ($skill in $manifest.skills) {
        if (Test-Path (Join-Path $ClaudeDir "skills/$($skill.name)")) {
            Write-Host "    ja instalada: $($skill.name)"
        } elseif (-not $npx) {
            Write-Warning "npx nao encontrado; instale o Node.js e rode: npx skills add $($skill.source) --skill $($skill.name) -g -a claude-code -y"
        } elseif ($DryRun) {
            Write-Host "    instalaria: $($skill.name) ($($skill.source))"
        } else {
            & npx -y skills add $skill.source --skill $skill.name -g -a claude-code -y
            if ($LASTEXITCODE -ne 0) { Write-Warning "falha ao instalar $($skill.name)" }
        }
    }
}

Write-Step 'Concluido. Abra o Claude Code para que ele instale os plugins listados em enabledPlugins.'
