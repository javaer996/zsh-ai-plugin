# zsh-ai-plugin / 终端 AI 插件

**[English Version / 英文说明](README.md)**

这是一个专为 macOS 终端打造的 zsh 插件：
- 使用 `zq <自然语言>`，AI 会把需求转换成 1~5 条真实命令，并通过 `fzf` 选择器预览完整脚本；
- 使用 `ze <命令>`，AI 会讲解命令的用途、潜在风险与替代写法；
- 所有能力都基于 OpenAI Chat Completions 接口，兼容 Azure 或其他同类服务。

## 功能亮点

- **完全可定制的 AI 接口**：可配置 Base URL、API Key、模型、温度、响应超时以及自定义授权头。
- **命令生成 (`zq`)**：把自然语言描述转成真实命令；`fzf` 状态下会多出一个脚本预览窗口，便于查看多行脚本，未安装 `fzf` 时自动退回 zsh `select`。
- **命令讲解 (`ze`)**：输出命令功能、风险、替代方案，默认中文，可通过 `ZAI_PROMPT_ZE` 改写语气。
- **配置工具 (`zai-config`)**：支持 show/all/pick/set 等模式，随时查看或修改配置；`zai_config_init` 可生成模板。
- **内置帮助与调试**：`zai-help` 列出所有能力；`ZAI_DEBUG=1` 时会打印系统提示、请求体与原始响应，方便排查。

## 安装

### 一键脚本（推荐）

```zsh
sh install.sh
```

- 自动检测依赖（zsh、git、curl、python3、fzf），并给出缺失组件的安装建议。
- 将插件固定复制到 `~/.zsh/zsh-ai-plugin`，并在 `~/.zshrc` 末尾追加 `source ~/.zsh/zsh-ai-plugin/zsh-ai-plugin.plugin.zsh`。
- 引导创建 `~/.config/zsh-ai-plugin/config.zsh`，也可以跳过，稍后用 `zai-config` 调整。
- 若本机没有 [`zsh-autosuggestions`](https://github.com/zsh-users/zsh-autosuggestions)，脚本会询问是否自动克隆到 `~/.zsh/zsh-autosuggestions`（可通过 `ZAI_AUTOSUGGEST_DIR` 自定义）并写入 `source` 行，让灰色自动补全立即生效。
- 需要卸载时，在安装目录执行 `sh uninstall.sh` 即可删除插件、移除 `source` 行，并可选择是否保留配置文件。

可用环境变量：`ZAI_CONFIG_FILE`（配置路径）、`ZAI_INSTALL_REPO_URL`（仓库地址）、`ZAI_AUTOSUGGEST_DIR`（autosuggestions 目录）。再次运行 `sh install.sh` 就能覆盖更新，配置文件不会被改写。

### 其他方式

- **手动克隆**
  ```zsh
  git clone https://github.com/<your-account>/zsh-ai-plugin.git ~/.zsh/zsh-ai-plugin
  echo 'source ~/.zsh/zsh-ai-plugin/zsh-ai-plugin.plugin.zsh' >> ~/.zshrc
  ```
- **插件管理器**：`antigen bundle ...`、`zinit light ...`、或放入 `~/.oh-my-zsh/custom/plugins` 后在 `plugins=(...)` 中加入 `zsh-ai-plugin`。

## 配置

`zai_config_init` 会在 `~/.config/zsh-ai-plugin/config.zsh` 生成模板，常见字段示例：

```zsh
export ZAI_API_BASE="https://api.openai.com/v1"
export ZAI_API_ENDPOINT="/chat/completions"
export ZAI_API_KEY="sk-xxx"
# export ZAI_API_AUTH_HEADER="api-key: xxx"   # 适配 Azure/自建服务

export ZAI_MODEL="gpt-4o-mini"
export ZAI_TEMPERATURE="0.2"
# export ZAI_REQUEST_TIMEOUT="45"

# export ZAI_SYSTEM_HINT="你是我的终端搭档..."
export ZAI_PROMPT_ZQ="你是一个资深的 macOS 终端助手，会把需求转成 1-5 条命令并以 JSON {\"commands\":...} 回应"
export ZAI_PROMPT_ZE="你是 shell 教程讲师，以简洁的三段式说明命令并提供安全提示"
# export ZAI_DISABLE_SPINNER="1"   # 请求 AI 时关闭动态提示
# export ZAI_DEBUG="1"
# export ZAI_CONFIRM_BEFORE_EXECUTE="1"
```

常用维护命令：

- `zai-config show`：查看当前配置（敏感项自动打码）。
- `zai-config all / pick`：交互式修改全部或部分字段（支持 `fzf` 多选）。
- `zai-config set KEY=VALUE ...`：脚本或 CI 中批量写入。
- `zai-config init`：重新生成模板。

修改后立即 `source`，无需重启 shell。

## 使用方法

- `zq <需求>`：AI 返回最多 5 条命令，`fzf` 界面自带脚本预览窗口，选中的命令会写入当前提示符，执行前仍可手动调整。
- `ze <命令>`：解释命令的行为、潜在风险与替代写法。
- `zai-help`：列出全部命令与常用环境变量。
- 其他环境变量：
  - `ZAI_SKIP_AUTO_CONFIG=1`：完全自行管理配置。
  - `ZAI_DISABLE_SPINNER=1`：请求 AI 时不显示动态提示。
  - `ZAI_DEBUG=1`：输出更详细的日志。

### 灰色自动补全

- 若在一键安装时选择自动安装 autosuggestions，脚本会帮你克隆并写入 `source` 行；否则可随时手动执行 `git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions`。
- 想用 Tab 接受建议，可在 `~/.zshrc` 追加 `bindkey '^I' autosuggest-accept`。

## 依赖

- macOS（已在 zsh 5.8+ 环境验证）
- `curl`、`python3`
- 可选：`fzf`（可获得更好的命令选择体验与脚本预览）

## 注意事项

- AI 生成的命令具有不确定性，执行前务必检查，尤其是写入或删除操作。
- 如使用自建或企业接口，需要保证返回格式兼容 OpenAI Chat Completions。
