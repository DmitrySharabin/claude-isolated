# Claude Code Profile Isolation

A method for running Claude Code with fully isolated configurations — no global settings, plugins, MCP servers, or agents leaking between profiles. Useful for testing plugins, experimenting with different setups, or starting from a clean slate without touching your main configuration.

## The Problem

Claude Code reads configuration from multiple locations:

| Source | Location | Contains |
|--------|----------|----------|
| User settings | `~/.claude/settings.json` | Permissions, plugins, hooks, marketplaces |
| User config | `~/.claude/CLAUDE.md` | Global instructions |
| User agents | `~/.claude/agents/` | Custom subagents |
| User commands | `~/.claude/commands/` | Custom slash commands |
| Session/MCP data | `~/.claude.json` | OAuth, MCP servers, project state, caches |
| Plugin cache | `~/.claude/plugins/` | Installed plugin files |
| Project settings | `.claude/settings.json` | Per-project config (in the working directory) |
| Project MCP | `.mcp.json` | Per-project MCP servers |

Simply creating an empty `~/.claude/` directory doesn't help because `~/.claude.json` (outside the folder) still carries MCP servers and session data.

The `CLAUDE_CONFIG_DIR` environment variable redirects most of this to a custom directory — including `.claude.json`, which gets created **inside** the custom config dir rather than at `~/.claude.json`.

## The Solution

Use `CLAUDE_CONFIG_DIR` to point Claude Code at a clean directory, and manage multiple configurations as named directories.

### Setup

Add this function to your `~/.zshrc` (or `~/.bashrc`):

```bash
claude-profile() {
  if [[ -z "$1" ]]; then
    echo "Usage: claude-profile <name> [plugin-dir ...]"
    return 1
  fi

  local profiles_dir="$HOME/claude-profiles"
  local profile="$1"
  local profile_dir="$profiles_dir/$profile"
  local plugin_args=()

  shift
  for dir in "$@"; do
    plugin_args+=(--plugin-dir "$dir")
  done

  mkdir -p "$profile_dir"

  CLAUDE_CONFIG_DIR="$profile_dir" claude "${plugin_args[@]}"
}
```

Then reload your shell:

```bash
source ~/.zshrc
```

### Usage

#### Start a clean profile

```bash
claude-profile experiment-1
```

This creates a new empty directory for the profile (if it doesn't exist) and launches Claude Code pointing at it. No plugins, no MCP servers, no agents, no hooks — a completely fresh start. Any changes Claude Code makes during the session (installed plugins, settings, etc.) are written directly to the profile directory and persist automatically.

#### Load a plugin for testing

```bash
claude-profile experiment-1 ./my-plugin
```

The `--plugin-dir` flag loads the plugin from disk for the session only — it won't be installed permanently. You can pass multiple plugin directories:

```bash
claude-profile experiment-1 ./my-plugin ../another-plugin
```

#### Switch between profiles

```bash
claude-profile experiment-1    # first experiment
claude-profile experiment-2    # different setup
claude-profile experiment-1    # back to first experiment, intact
```

Each profile directory maintains its own independent configuration state.

#### List available profiles

```bash
ls ~/claude-profiles/
```

#### Delete a profile

```bash
rm -rf ~/claude-profiles/experiment-1
```

## Verifying Isolation

To confirm that a profile is truly isolated from your global config, create a profile with distinctive settings and check that none of your global configuration leaks through.

### 1. Create test files

```bash
mkdir -p ~/claude-profiles/guided

cat > ~/claude-profiles/guided/CLAUDE.md << 'EOF'
# Guided Profile

You are in the **guided** isolated environment.

When greeted or asked "who are you", always respond with:
"I am running in the GUIDED isolated environment. No global settings are loaded."

Always end every response with the line:
`[guided profile active]`
EOF

cat > ~/claude-profiles/guided/settings.json << 'EOF'
{
  "permissions": {
    "allow": [
      "Bash(echo:*)",
      "Bash(cat:*)",
      "Bash(ls:*)"
    ],
    "deny": [
      "Bash(git:*)"
    ]
  },
  "enabledPlugins": {},
  "effortLevel": "low"
}
EOF
```

### 2. Launch the profile

```bash
cd /path/to/your/project
claude-profile guided
```

### 3. Run these checks inside the session

| What to do | Expected (isolated) | If isolation failed |
|---|---|---|
| Type `who are you` | Responds with "GUIDED isolated environment" and ends with `[guided profile active]` | Normal response, no tag |
| `/plugins` | "No plugins or MCP servers installed." | Shows your installed plugins |
| `/effort` | Shows `low` | Shows `medium` (or your global value) |
| `/memory` | No auto memory files, or only the profile's CLAUDE.md | Shows memory from your previous sessions |
| Type `run: git status` | Blocked (permission denied) | Runs without asking |

### 4. Compare with your normal setup

Open another terminal in the same directory and run plain `claude` (no profile). The same checks should show your plugins, no `[guided profile active]` tag, `git status` running without prompting, and your normal `effortLevel`.

## Testing a Local Plugin

To test a plugin in an isolated profile, create a minimal plugin and load it with `--plugin-dir`.

### 1. Create the plugin

```bash
mkdir -p ~/my-plugins/hello-test/.claude-plugin ~/my-plugins/hello-test/skills/greet

cat > ~/my-plugins/hello-test/.claude-plugin/plugin.json << 'EOF'
{
  "name": "hello-test",
  "description": "A minimal plugin for testing profile isolation",
  "version": "1.0.0",
  "author": {
    "name": "Test"
  }
}
EOF

cat > ~/my-plugins/hello-test/skills/greet/SKILL.md << 'EOF'
---
description: Say hello from the test plugin. Use when the user types /hello-test:greet.
disable-model-invocation: true
---

# Greet Skill

Respond with exactly:

"Hello from the hello-test plugin! Profile isolation is working correctly."

Then list the current date and time.
EOF
```

This creates:

```
~/my-plugins/hello-test/
  .claude-plugin/
    plugin.json
  skills/
    greet/
      SKILL.md
```

### 2. Launch with the plugin

```bash
cd /path/to/your/project
claude-profile guided ~/my-plugins/hello-test
```

### 3. Verify

Inside the session:

| What to do | Expected |
|---|---|
| `/plugins` | Shows `hello-test` as the only installed plugin |
| Type `/hello-test:greet` | Responds with the greeting message |
| `/plugins` in a normal `claude` session (no profile) | Does **not** show `hello-test` |

The plugin is loaded for this session only and does not affect your main configuration or other profiles.

## Important Caveats

### Don't launch from your home directory

When Claude Code starts, it treats `$CWD/.claude/` as the **project-level** config directory. If you launch from `~`, then `~/.claude/settings.json` gets loaded as **project config** regardless of what `CLAUDE_CONFIG_DIR` is set to. This will leak your real plugins and settings into the clean profile.

Always `cd` into a project directory first:

```bash
cd /path/to/your/project
claude-profile clean-test
```

### Authentication

Each new profile requires a fresh login. The first time you launch Claude Code with a new profile, it will open a browser for authentication. Once authenticated, the credentials are stored inside the profile directory and persist across sessions.

### Project-level settings are separate

Project-level config (`.claude/settings.json`, `.claude/settings.local.json`, `.mcp.json` in the working directory) is **not** controlled by `CLAUDE_CONFIG_DIR`. This is by design — project config belongs to the project, not the profile.

If the project you're working in has its own `.claude/settings.json` with plugins or permissions, those will still load.

### Concurrent sessions

Each profile has its own directory, so you can run multiple profiles simultaneously in different terminals without conflict.

## How It Works

1. `~/claude-profiles/` contains named subdirectories, one per profile.
2. When you run `claude-profile <name>`, the function creates the directory (if new) and launches Claude Code with `CLAUDE_CONFIG_DIR=~/claude-profiles/<name>`.
3. Claude Code writes all its runtime files (`.claude.json`, `settings.json`, `plugins/`, etc.) into the profile directory instead of `~/.claude/` and `~/.claude.json`.
4. Everything persists automatically — no save step needed.

## File Structure

```
~/claude-profiles/
  guided/                       # Profile with test settings
    .claude.json
    settings.json
    plugins/
    agents/
    ...
  experiment-1/                 # Another profile
  plugin-testing/               # Another profile

~/.claude/                      # Your real config (untouched during profiled sessions)
```

## Alternatives

| Method | Isolation Level | Pros | Cons |
|--------|----------------|------|------|
| **This approach** (CLAUDE_CONFIG_DIR + named dirs) | High | Switchable profiles, plugin testing, simple setup | Must avoid launching from `~`; project config still loads |
| `--no-global-config --no-project-config` | Medium | Quick, no setup | No alternative config — just a blank slate with no way to customize |
| **Docker** | Complete | Full filesystem + network isolation | Heavy; requires Docker setup |

## Optional: Add Git for History

If you want the ability to roll back a profile to a previous state, initialize git inside individual profile directories:

```bash
cd ~/claude-profiles/experiment-1
git init
git add -A && git commit -m "initial state"
```

This is entirely optional and independent of the profile switching mechanism.
