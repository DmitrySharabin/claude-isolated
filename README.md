# claude-isolated

Run Claude Code in Docker with full plugin/config isolation from your host `~/.claude`. Each profile gets its own persistent state — sessions, settings, installed plugins — while sharing nothing with the host.

## Prerequisites

You need a Docker-compatible runtime. Either:

- **[OrbStack](https://orbstack.dev/)** (recommended for macOS) — lighter, faster, less battery drain: `brew install orbstack`
- **[Docker Desktop](https://www.docker.com/products/docker-desktop/)**: `brew install --cask docker`

## Setup

```bash
# Clone the repo
git clone https://github.com/DmitrySharabin/claude-isolated.git
cd claude-isolated
chmod +x claude-isolated

# Build the image (first time takes a few minutes)
./claude-isolated --build
```

## First run

On first launch of a new profile, Claude Code will prompt you to authenticate via browser — open the URL, log in, paste the code back. The token is saved in the profile and persists across runs.

## Usage

```bash
# Test a plugin in an isolated profile
./claude-isolated <profile_name> --plugin-dir /path/to/your/plugin

# Test plugin against a specific project
./claude-isolated <profile_name> --plugin-dir /path/to/your/plugin --workspace /path/to/your/project

# Launch a profile with no plugins
./claude-isolated <profile_name>

# Multiple plugins
./claude-isolated <profile_name> --plugin-dir /path/to/plugin-a --plugin-dir /path/to/plugin-b

# Pass extra flags to Claude Code
./claude-isolated <profile_name> --plugin-dir /path/to/your/plugin -- --model sonnet

# List profiles
./claude-isolated --list

# Delete a profile
./claude-isolated --delete <profile_name>
```

## What's inside the container

| Tool | Version | Purpose |
|---|---|---|
| Claude Code | Latest (native installer, auto-updates) | AI coding agent |
| Node.js | 24 (LTS) | Runtime for web projects |
| npm / npx | Bundled with Node.js | Package management |
| Playwright + Chromium | Latest | Browser testing |
| git | System | Version control |
| curl, jq, ripgrep | System | Dev utilities |

The container has full internet access — `npm install`, dev servers, API calls, and browser testing all work out of the box.

## How it works

| Mount | Container path | Mode | Purpose |
|---|---|---|---|
| `~/.claude-profiles/<name>` | `/home/claude/.claude` | read-write | Profile state: auth, sessions, settings, plugins |
| Plugin dir | `/home/claude/plugin` | read-write | Your plugin under test |
| Workspace | `/home/claude/workspace` | read-write | Project directory to work against |

The host `~/.claude` is never mounted. No plugin state, no marketplace config, no settings leak from the host.

Auth tokens are stored at `~/.claude.json` by Claude Code, which is outside the profile mount. The entrypoint symlinks this file into the persistent profile directory so tokens survive container restarts.

## Profile persistence

Profiles live at `~/.claude-profiles/` (override with `CLAUDE_ISOLATED_PROFILES_DIR`). Each profile persists:

- Auth tokens (login once per profile)
- Sessions and history
- `settings.json`
- MCP server config
- Installed plugins (only those you install inside the container)

## Editing profile settings from the host

Profile directories are regular folders on your Mac. You can edit them directly and the container picks up changes on next launch — no rebuild needed.

```bash
# Edit settings
nano ~/.claude-profiles/<profile_name>/settings.json

# View what's in a profile
ls ~/.claude-profiles/<profile_name>/
```

This is a live volume mount, not a copy. Any file you add, edit, or remove in `~/.claude-profiles/<profile>/` is immediately reflected inside the container at `/home/claude/.claude/`.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Image: Node.js 24 LTS, Playwright, Claude Code (native), dev tools |
| `entrypoint.sh` | Ensures auth tokens are stored inside the profile dir so they persist across container restarts |
| `claude-isolated` | Launcher script with profile management |
| `.dockerignore` | Keeps image builds clean |

## Limitations

- First run per profile requires browser-based login
- OAuth tokens may expire; re-authenticate with `claude auth login` inside the container
- Container has no access to host MCP servers (by design)
- Git operations work only on mounted workspace directories
- Image is ~1.5GB due to Chromium and Node.js
