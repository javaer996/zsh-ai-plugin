# zsh-ai-plugin

**[中文说明 / Chinese Version](README.zh.md)**

A macOS-focused zsh plugin that keeps AI assistance inside your terminal: describe what you need with `zq` to receive runnable commands, or ask `ze` to explain what an unfamiliar command does. Everything speaks the OpenAI Chat Completions protocol, so it works with OpenAI, Azure, and compatible self-hosted gateways.

## Highlights

- **Flexible API controls** – configure base URL, API key, model, temperature, request timeout, and even custom auth headers for Azure/OpenAI-compatible providers.
- **`zq` command synthesis** – turns natural-language descriptions into 1–5 commands. When `fzf` is present, an interactive picker with a preview pane displays the full script; otherwise it falls back to zsh `select`.
- **`ze` command explaining** – summarizes purpose, risks, and alternative invocations for any command; adjust the tone by editing `ZAI_PROMPT_ZE`.
- **Config tooling** – `zai-config` offers show/all/pick/set modes for interactive editing, while `zai_config_init` scaffolds the default template. Changes are sourced immediately.
- **Help & debugging** – `zai-help` lists every helper; set `ZAI_DEBUG=1` to print prompts, payloads, and raw responses when troubleshooting.

## Installation

### One-shot script (recommended)

```zsh
sh install.sh
```

- Checks prerequisites (`zsh`, `git`, `curl`, `python3`, optional `fzf`) and suggests commands for installing missing components.
- Copies the plugin to `~/.zsh/zsh-ai-plugin` and appends `source ~/.zsh/zsh-ai-plugin/zsh-ai-plugin.plugin.zsh` to `~/.zshrc`.
- Guides you through creating `~/.config/zsh-ai-plugin/config.zsh`; you can skip and adjust later via `zai-config`.
- If [`zsh-autosuggestions`](https://github.com/zsh-users/zsh-autosuggestions) is missing, the installer can clone it to `~/.zsh/zsh-autosuggestions` (override with `ZAI_AUTOSUGGEST_DIR`) and add the required `source` line so you get grey inline hints immediately.
- Run `sh uninstall.sh` inside the install directory to remove the plugin, clean up the `source` line, and optionally delete the config file.

Environment variables: `ZAI_CONFIG_FILE` (config path), `ZAI_INSTALL_REPO_URL` (alternate repo), `ZAI_AUTOSUGGEST_DIR` (autosuggestions location). Re-running `sh install.sh` updates the plugin in place without touching your config.

### Manual options

- **Manual clone**
  ```zsh
  git clone https://github.com/<your-account>/zsh-ai-plugin.git ~/.zsh/zsh-ai-plugin
  echo 'source ~/.zsh/zsh-ai-plugin/zsh-ai-plugin.plugin.zsh' >> ~/.zshrc
  ```
- **Plugin managers** – e.g. `antigen bundle /path/to/zsh-ai-plugin`, `zinit light /path/to/zsh-ai-plugin`, or drop the repo under `~/.oh-my-zsh/custom/plugins` and list it in `plugins=(...)`.

## Configuration

Run `zai_config_init` once to scaffold the config file. Common fields:

```zsh
export ZAI_API_BASE="https://api.openai.com/v1"
export ZAI_API_ENDPOINT="/chat/completions"
export ZAI_API_KEY="sk-xxx"
# export ZAI_API_AUTH_HEADER="api-key: xxx"   # Azure / self-hosted

export ZAI_MODEL="gpt-4o-mini"
export ZAI_TEMPERATURE="0.2"
# export ZAI_REQUEST_TIMEOUT="45"

# export ZAI_SYSTEM_HINT="You are my shell co-pilot..."
export ZAI_PROMPT_ZQ="You are a senior macOS terminal assistant..."
export ZAI_PROMPT_ZE="You are a shell instructor..."
# export ZAI_DISABLE_SPINNER="1"
# export ZAI_DEBUG="1"
# export ZAI_CONFIRM_BEFORE_EXECUTE="1"
```

Use `zai-config show/all/pick/set` to inspect or edit fields interactively (with `fzf` multi-select when available). All changes are sourced immediately—no need to restart the shell.

## Usage

- `zq <request>` – describe what you want; the `fzf` picker lists up to 5 commands with a live preview of the full script. Selecting an entry pushes it into your prompt so you can tweak it before execution.
- `ze <command>` – explains the command in plain language, covering purpose, risks, and alternatives.
- `zai-help` – displays all helper commands and relevant environment variables.
- Additional toggles:
  - `ZAI_SKIP_AUTO_CONFIG=1` – skip auto-loading the config file.
  - `ZAI_DISABLE_SPINNER=1` – hide the spinner while waiting for AI responses.
  - `ZAI_DEBUG=1` – enable verbose logging of prompts and responses.

### Grey inline suggestions

- If you accepted the autosuggestions install during `sh install.sh`, the plugin already cloned and sourced it. Otherwise run `git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions` manually.
- Add `bindkey '^I' autosuggest-accept` to `~/.zshrc` if you prefer accepting suggestions with Tab.

## Requirements

- macOS with zsh 5.8+
- `curl`, `python3`
- Optional: `fzf` (strongly recommended for the command picker + preview)

## Notes

- Always double-check AI-generated commands, especially anything that writes or deletes files.
- Custom/self-hosted endpoints must implement the OpenAI Chat Completions schema.
