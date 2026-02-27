# Pester 5 tests for Windows PowerShell adapters (.ps1)
# Run: Invoke-Pester -Path tests/adapters-windows.Tests.ps1
#
# These tests validate:
# - PowerShell syntax for all adapter scripts
# - Event mapping logic (Category A: simple translators)
# - Daemon management flags (Category B: filesystem watchers)
# - FileSystemWatcher usage (Category B)
# - Installer structure (Category C: opencode, kilo)
# - No ExecutionPolicy Bypass in any adapter
# - peon.ps1 path resolution patterns

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:AdaptersDir = Join-Path $script:RepoRoot "adapters"
}

# ============================================================
# Syntax validation
# ============================================================

Describe "PowerShell Syntax Validation" {
    $allAdapters = @("codex", "gemini", "copilot", "windsurf", "kiro", "openclaw",
                     "amp", "antigravity", "kimi", "opencode", "kilo")

    It "adapters/<name>.ps1 has valid PowerShell syntax" -ForEach @(
        @{ name = "codex" }, @{ name = "gemini" }, @{ name = "copilot" },
        @{ name = "windsurf" }, @{ name = "kiro" }, @{ name = "openclaw" },
        @{ name = "amp" }, @{ name = "antigravity" }, @{ name = "kimi" },
        @{ name = "opencode" }, @{ name = "kilo" }
    ) {
        $path = Join-Path $script:AdaptersDir "$name.ps1"
        $path | Should -Exist
        $content = Get-Content $path -Raw
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
        $errors.Count | Should -Be 0
    }
}

# ============================================================
# Security: no ExecutionPolicy Bypass
# ============================================================

Describe "No ExecutionPolicy Bypass" {
    It "adapters/<name>.ps1 does not use ExecutionPolicy Bypass" -ForEach @(
        @{ name = "codex" }, @{ name = "gemini" }, @{ name = "copilot" },
        @{ name = "windsurf" }, @{ name = "kiro" }, @{ name = "openclaw" },
        @{ name = "amp" }, @{ name = "antigravity" }, @{ name = "kimi" },
        @{ name = "opencode" }, @{ name = "kilo" }
    ) {
        $path = Join-Path $script:AdaptersDir "$name.ps1"
        $content = Get-Content $path -Raw
        $content | Should -Not -Match "ExecutionPolicy Bypass"
    }

    It "install.ps1 does not use ExecutionPolicy Bypass" {
        $path = Join-Path $script:RepoRoot "install.ps1"
        $content = Get-Content $path -Raw
        $content | Should -Not -Match "ExecutionPolicy Bypass"
    }
}

# ============================================================
# Category A: Simple Event Translators
# ============================================================

Describe "Category A: Codex Adapter" {
    BeforeAll {
        $script:codexContent = Get-Content (Join-Path $script:AdaptersDir "codex.ps1") -Raw
    }

    It "accepts Event parameter" {
        $script:codexContent | Should -Match 'param\('
        $script:codexContent | Should -Match '\[string\]\$Event'
    }

    It "maps agent-turn-complete to Stop" {
        $script:codexContent | Should -Match '"agent-turn-complete".*"complete".*"done"'
        $script:codexContent | Should -Match '\$mapped = "Stop"'
    }

    It "maps start/session-start to SessionStart" {
        $script:codexContent | Should -Match '"start".*"session-start"'
        $script:codexContent | Should -Match '\$mapped = "SessionStart"'
    }

    It "maps permission events to Notification with permission_prompt" {
        $script:codexContent | Should -Match 'permission'
        $script:codexContent | Should -Match '\$ntype = "permission_prompt"'
    }

    It "pipes JSON to peon.ps1" {
        $script:codexContent | Should -Match 'peon\.ps1'
        $script:codexContent | Should -Match 'ConvertTo-Json'
    }
}

Describe "Category A: Gemini Adapter" {
    BeforeAll {
        $script:geminiContent = Get-Content (Join-Path $script:AdaptersDir "gemini.ps1") -Raw
    }

    It "accepts EventType parameter" {
        $script:geminiContent | Should -Match '\[string\]\$EventType'
    }

    It "maps SessionStart to SessionStart" {
        $script:geminiContent | Should -Match '"SessionStart"\s*\{[^}]*\$mapped = "SessionStart"'
    }

    It "maps AfterAgent to Stop" {
        $script:geminiContent | Should -Match '"AfterAgent"\s*\{[^}]*\$mapped = "Stop"'
    }

    It "maps AfterTool with non-zero exit to PostToolUseFailure" {
        $script:geminiContent | Should -Match 'PostToolUseFailure'
    }

    It "reads JSON from stdin" {
        $script:geminiContent | Should -Match 'IsInputRedirected'
        $script:geminiContent | Should -Match 'StreamReader'
    }

    It "returns empty JSON object to Gemini" {
        $script:geminiContent | Should -Match 'Write-Output "\{\}"'
    }
}

Describe "Category A: Copilot Adapter" {
    BeforeAll {
        $script:copilotContent = Get-Content (Join-Path $script:AdaptersDir "copilot.ps1") -Raw
    }

    It "maps sessionStart to SessionStart" {
        $script:copilotContent | Should -Match '"sessionStart"\s*\{[^}]*\$mapped = "SessionStart"'
    }

    It "maps postToolUse to Stop" {
        $script:copilotContent | Should -Match '"postToolUse"\s*\{[^}]*\$mapped = "Stop"'
    }

    It "maps errorOccurred to PostToolUseFailure" {
        $script:copilotContent | Should -Match '"errorOccurred"\s*\{[^}]*\$mapped = "PostToolUseFailure"'
    }

    It "handles first userPromptSubmitted as SessionStart" {
        $script:copilotContent | Should -Match 'copilot-session'
        $script:copilotContent | Should -Match '\$mapped = "SessionStart"'
    }

    It "handles subsequent userPromptSubmitted as UserPromptSubmit" {
        $script:copilotContent | Should -Match '\$mapped = "UserPromptSubmit"'
    }

    It "exits gracefully for sessionEnd" {
        $script:copilotContent | Should -Match '"sessionEnd"'
        $script:copilotContent | Should -Match 'exit 0'
    }

    It "exits gracefully for preToolUse (too noisy)" {
        $script:copilotContent | Should -Match '"preToolUse"'
    }
}

Describe "Category A: Windsurf Adapter" {
    BeforeAll {
        $script:windsurfContent = Get-Content (Join-Path $script:AdaptersDir "windsurf.ps1") -Raw
    }

    It "maps post_cascade_response to Stop" {
        $script:windsurfContent | Should -Match '"post_cascade_response"\s*\{[^}]*\$mapped = "Stop"'
    }

    It "handles pre_user_prompt session detection" {
        $script:windsurfContent | Should -Match 'windsurf-session'
        $script:windsurfContent | Should -Match '"pre_user_prompt"'
    }

    It "maps post_write_code to Stop" {
        $script:windsurfContent | Should -Match '"post_write_code"'
    }

    It "maps post_run_command to Stop" {
        $script:windsurfContent | Should -Match '"post_run_command"'
    }

    It "drains stdin" {
        $script:windsurfContent | Should -Match 'IsInputRedirected'
    }
}

Describe "Category A: Kiro Adapter" {
    BeforeAll {
        $script:kiroContent = Get-Content (Join-Path $script:AdaptersDir "kiro.ps1") -Raw
    }

    It "remaps agentSpawn to SessionStart" {
        $script:kiroContent | Should -Match '"agentSpawn"\s*=\s*"SessionStart"'
    }

    It "remaps userPromptSubmit to UserPromptSubmit" {
        $script:kiroContent | Should -Match '"userPromptSubmit"\s*=\s*"UserPromptSubmit"'
    }

    It "remaps stop to Stop" {
        $script:kiroContent | Should -Match '"stop"\s*=\s*"Stop"'
    }

    It "prefixes session_id with kiro-" {
        $script:kiroContent | Should -Match '"kiro-\$sid"'
    }

    It "skips unknown events" {
        $script:kiroContent | Should -Match 'if \(-not \$mapped\)'
        $script:kiroContent | Should -Match 'exit 0'
    }
}

Describe "Category A: OpenClaw Adapter" {
    BeforeAll {
        $script:openclawContent = Get-Content (Join-Path $script:AdaptersDir "openclaw.ps1") -Raw
    }

    It "maps session.start to SessionStart" {
        $script:openclawContent | Should -Match '"session\.start"'
        $script:openclawContent | Should -Match '\$mapped = "SessionStart"'
    }

    It "maps task.complete to Stop" {
        $script:openclawContent | Should -Match '"task\.complete"'
        $script:openclawContent | Should -Match '\$mapped = "Stop"'
    }

    It "maps task.error to PostToolUseFailure" {
        $script:openclawContent | Should -Match '"task\.error"'
        $script:openclawContent | Should -Match '\$mapped = "PostToolUseFailure"'
    }

    It "maps input.required to Notification with permission_prompt" {
        $script:openclawContent | Should -Match '"input\.required"'
        $script:openclawContent | Should -Match '\$ntype = "permission_prompt"'
    }

    It "maps resource.limit to Notification with resource_limit" {
        $script:openclawContent | Should -Match '"resource\.limit"'
        $script:openclawContent | Should -Match '\$ntype = "resource_limit"'
    }

    It "accepts raw Claude Code event names" {
        $script:openclawContent | Should -Match '"SessionStart", "Stop", "Notification"'
    }
}

# ============================================================
# Category B: Filesystem Watcher Adapters
# ============================================================

Describe "Category B: Amp Adapter" {
    BeforeAll {
        $script:ampContent = Get-Content (Join-Path $script:AdaptersDir "amp.ps1") -Raw
    }

    It "has Install/Uninstall/Status daemon flags" {
        $script:ampContent | Should -Match '\[switch\]\$Install'
        $script:ampContent | Should -Match '\[switch\]\$Uninstall'
        $script:ampContent | Should -Match '\[switch\]\$Status'
    }

    It "uses FileSystemWatcher" {
        $script:ampContent | Should -Match 'System\.IO\.FileSystemWatcher'
    }

    It "watches T-*.json files" {
        $script:ampContent | Should -Match 'T-\*\.json'
    }

    It "has idle detection logic" {
        $script:ampContent | Should -Match 'IdleSeconds'
        $script:ampContent | Should -Match 'StopCooldown'
    }

    It "checks if thread is waiting for user input" {
        $script:ampContent | Should -Match 'Test-ThreadWaiting'
        $script:ampContent | Should -Match 'tool_use'
    }

    It "has PID file management" {
        $script:ampContent | Should -Match '\.amp-adapter\.pid'
    }

    It "tries Windows-native AMP_DATA_DIR path first" {
        $script:ampContent | Should -Match 'LOCALAPPDATA'
    }
}

Describe "Category B: Antigravity Adapter" {
    BeforeAll {
        $script:antigravityContent = Get-Content (Join-Path $script:AdaptersDir "antigravity.ps1") -Raw
    }

    It "has Install/Uninstall/Status daemon flags" {
        $script:antigravityContent | Should -Match '\[switch\]\$Install'
        $script:antigravityContent | Should -Match '\[switch\]\$Uninstall'
        $script:antigravityContent | Should -Match '\[switch\]\$Status'
    }

    It "uses FileSystemWatcher" {
        $script:antigravityContent | Should -Match 'System\.IO\.FileSystemWatcher'
    }

    It "watches *.pb files" {
        $script:antigravityContent | Should -Match '\*\.pb'
    }

    It "has idle detection logic" {
        $script:antigravityContent | Should -Match 'IdleSeconds'
        $script:antigravityContent | Should -Match 'StopCooldown'
    }

    It "has PID file management" {
        $script:antigravityContent | Should -Match '\.antigravity-adapter\.pid'
    }
}

Describe "Category B: Kimi Adapter" {
    BeforeAll {
        $script:kimiContent = Get-Content (Join-Path $script:AdaptersDir "kimi.ps1") -Raw
    }

    It "has Install/Uninstall/Status/Help flags" {
        $script:kimiContent | Should -Match '\[switch\]\$Install'
        $script:kimiContent | Should -Match '\[switch\]\$Uninstall'
        $script:kimiContent | Should -Match '\[switch\]\$Status'
        $script:kimiContent | Should -Match '\[switch\]\$Help'
    }

    It "uses FileSystemWatcher" {
        $script:kimiContent | Should -Match 'System\.IO\.FileSystemWatcher'
    }

    It "watches wire.jsonl files with subdirectory recursion" {
        $script:kimiContent | Should -Match 'wire\.jsonl'
        $script:kimiContent | Should -Match 'IncludeSubdirectories.*true'
    }

    It "maps TurnEnd to Stop" {
        $script:kimiContent | Should -Match '"TurnEnd".*"Stop"'
    }

    It "maps TurnBegin to SessionStart for new sessions" {
        $script:kimiContent | Should -Match '"TurnBegin"'
        $script:kimiContent | Should -Match '"SessionStart"'
    }

    It "maps SubagentEvent with TurnBegin to SubagentStart" {
        $script:kimiContent | Should -Match '"SubagentEvent"'
        $script:kimiContent | Should -Match '"SubagentStart"'
    }

    It "maps CompactionBegin to PreCompact" {
        $script:kimiContent | Should -Match '"CompactionBegin".*"PreCompact"'
    }

    It "has /clear detection logic" {
        $script:kimiContent | Should -Match 'ClearGraceSeconds'
        $script:kimiContent | Should -Match 'lastNewSession'
    }

    It "resolves CWD from workspace hash using MD5" {
        $script:kimiContent | Should -Match 'Resolve-KimiCwd'
        $script:kimiContent | Should -Match 'MD5'
    }

    It "reads new bytes from wire.jsonl using offset tracking" {
        $script:kimiContent | Should -Match 'sessionOffset'
        $script:kimiContent | Should -Match 'FileStream'
    }

    It "has PID file management" {
        $script:kimiContent | Should -Match '\.kimi-adapter\.pid'
    }
}

# ============================================================
# Category C: Installer Adapters
# ============================================================

Describe "Category C: OpenCode Installer" {
    BeforeAll {
        $script:opencodeContent = Get-Content (Join-Path $script:AdaptersDir "opencode.ps1") -Raw
    }

    It "has Uninstall flag" {
        $script:opencodeContent | Should -Match '\[switch\]\$Uninstall'
    }

    It "downloads the peon-ping.ts plugin" {
        $script:opencodeContent | Should -Match 'peon-ping\.ts'
        $script:opencodeContent | Should -Match 'Invoke-WebRequest'
    }

    It "creates default config.json" {
        $script:opencodeContent | Should -Match 'config\.json'
        $script:opencodeContent | Should -Match 'active_pack'
    }

    It "installs default pack from registry" {
        $script:opencodeContent | Should -Match 'peonping\.github\.io/registry'
    }

    It "uses LOCALAPPDATA for Windows-native path" {
        $script:opencodeContent | Should -Match 'LOCALAPPDATA'
    }
}

Describe "Category C: Kilo Installer" {
    BeforeAll {
        $script:kiloContent = Get-Content (Join-Path $script:AdaptersDir "kilo.ps1") -Raw
    }

    It "has Uninstall flag" {
        $script:kiloContent | Should -Match '\[switch\]\$Uninstall'
    }

    It "downloads and patches OpenCode plugin for Kilo" {
        $script:kiloContent | Should -Match 'peon-ping\.ts'
        $script:kiloContent | Should -Match '@kilocode/plugin'
    }

    It "patches config path from opencode to kilo" {
        $script:kiloContent | Should -Match '".config", "kilo", "peon-ping"'
    }

    It "creates default config.json" {
        $script:kiloContent | Should -Match 'config\.json'
        $script:kiloContent | Should -Match 'active_pack'
    }

    It "installs default pack from registry" {
        $script:kiloContent | Should -Match 'peonping\.github\.io/registry'
    }
}

# ============================================================
# install.ps1 adapter installation
# ============================================================

Describe "install.ps1 Adapter Installation" {
    BeforeAll {
        $script:installContent = Get-Content (Join-Path $script:RepoRoot "install.ps1") -Raw
    }

    It "installs adapter scripts to adapters/ directory" {
        $script:installContent | Should -Match 'Installing adapter scripts'
        $script:installContent | Should -Match 'adapters'
    }

    It "installs all 11 adapter files" {
        $script:installContent | Should -Match 'codex\.ps1'
        $script:installContent | Should -Match 'gemini\.ps1'
        $script:installContent | Should -Match 'copilot\.ps1'
        $script:installContent | Should -Match 'windsurf\.ps1'
        $script:installContent | Should -Match 'kiro\.ps1'
        $script:installContent | Should -Match 'openclaw\.ps1'
        $script:installContent | Should -Match 'amp\.ps1'
        $script:installContent | Should -Match 'antigravity\.ps1'
        $script:installContent | Should -Match 'kimi\.ps1'
        $script:installContent | Should -Match 'opencode\.ps1'
        $script:installContent | Should -Match 'kilo\.ps1'
    }

    It "calls Unblock-File on installed adapters" {
        $script:installContent | Should -Match 'Unblock-File'
    }

    It "has execution policy detection" {
        $script:installContent | Should -Match 'Get-ExecutionPolicy'
        $script:installContent | Should -Match 'Restricted'
    }

    It "handles missing Claude Code gracefully" {
        $script:installContent | Should -Match 'ClaudeCodeDetected'
        $script:installContent | Should -Match 'Skipping Claude Code hook registration'
    }
}

# ============================================================
# Cross-cutting: peon.ps1 resolution pattern
# ============================================================

Describe "All adapters resolve peon.ps1 via CLAUDE_PEON_DIR" {
    It "adapters/<name>.ps1 checks CLAUDE_PEON_DIR env var" -ForEach @(
        @{ name = "codex" }, @{ name = "gemini" }, @{ name = "copilot" },
        @{ name = "windsurf" }, @{ name = "kiro" }, @{ name = "openclaw" },
        @{ name = "amp" }, @{ name = "antigravity" }, @{ name = "kimi" }
    ) {
        $path = Join-Path $script:AdaptersDir "$name.ps1"
        $content = Get-Content $path -Raw
        $content | Should -Match 'CLAUDE_PEON_DIR'
    }

    It "adapters/<name>.ps1 falls back to ~/.claude/hooks/peon-ping" -ForEach @(
        @{ name = "codex" }, @{ name = "gemini" }, @{ name = "copilot" },
        @{ name = "windsurf" }, @{ name = "kiro" }, @{ name = "openclaw" },
        @{ name = "amp" }, @{ name = "antigravity" }, @{ name = "kimi" }
    ) {
        $path = Join-Path $script:AdaptersDir "$name.ps1"
        $content = Get-Content $path -Raw
        $content | Should -Match '\.claude\\hooks\\peon-ping'
    }
}
