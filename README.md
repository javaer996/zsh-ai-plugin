# zsh-ai-plugin

一个在 macOS 终端内使用 OpenAI 格式接口的 zsh 插件，让自然语言描述和命令解释都能在命令行完成。

## 功能亮点

- **可配置的 OpenAI 兼容接口**：支持自定义 Base URL、API Key、模型、温度等参数，也可自定义授权头适配 Azure/OpenAI 等服务。
- **`zq <自然语言>`**：将描述转换成 1~5 条真实 shell 命令，并配上简短说明；集成 `fzf` 选择器，没有 `fzf` 时回退到 zsh `select`。
- **`ze <命令>`**：用中文解释命令作用、危险点以及可选变体，帮助快速理解陌生命令。
- **`zai-config` 命令组**：交互式维护配置，支持查看、全量编辑、选择性编辑或直接传入 `KEY=VALUE`，保存后立即生效；`zai_config_init` 则可生成模板。
- **`zai-help`**：在终端里列出所有可用能力与常见环境变量。

## 安装

1. **一键安装脚本（推荐）**

   ```zsh
   sh install.sh
   ```

   脚本会检测依赖（zsh、git、curl、python3、fzf）、提示缺失项的安装命令、克隆/复制仓库、为 `.zshrc` 添加 `source` 行并引导配置 `~/.config/zsh-ai-plugin/config.zsh`。  
   可通过环境变量自定义：`ZAI_INSTALL_DIR`（插件目录）、`ZAI_CONFIG_FILE`（配置路径）、`ZAI_INSTALL_REPO_URL`（仓库地址）。

2. **手动克隆仓库并在 `.zshrc` 里 source**

   ```zsh
   git clone https://github.com/<your-account>/zsh-ai-plugin.git ~/.zsh/zsh-ai-plugin
   echo 'source ~/.zsh/zsh-ai-plugin/zsh-ai-plugin.plugin.zsh' >> ~/.zshrc
   ```

3. **使用插件管理器**

   - **Antigen**：`antigen bundle /path/to/zsh-ai-plugin`
   - **zinit**：`zinit light /path/to/zsh-ai-plugin`
   - **Oh My Zsh**：将仓库放入 `~/.oh-my-zsh/custom/plugins` 后，在 `.zshrc` 的 `plugins=(...)` 中加入 `zsh-ai-plugin`。

更新到最新脚本时，可在仓库目录执行：

```zsh
sh update.sh
```

脚本会自动识别 `.zshrc` 中的 `source .../zsh-ai-plugin.plugin.zsh` 路径（或读取 `ZAI_INSTALL_DIR`），然后将仓库内容同步过去，既不会覆盖 `~/.config/zsh-ai-plugin` 下的配置，也无需重新安装依赖。

## 配置

首次运行 `zai_config_init` 会生成 `~/.config/zsh-ai-plugin/config.zsh` 模板。按需修改：

```zsh
export ZAI_API_BASE="https://api.openai.com/v1"
export ZAI_API_ENDPOINT="/chat/completions"
export ZAI_API_KEY="sk-xxx"
# Azure 等服务可以改成自定义头
# export ZAI_API_AUTH_HEADER="api-key: xxx"

export ZAI_MODEL="gpt-4o-mini"
export ZAI_TEMPERATURE="0.2"
# export ZAI_REQUEST_TIMEOUT="45"

# 可选自定义系统提示
# export ZAI_SYSTEM_HINT="你是我的终端搭档..."
export ZAI_PROMPT_ZQ="你是一个资深的 macOS 终端助手，会把需求转成 1-5 条命令并以 JSON {\"commands\":...} 回应"
export ZAI_PROMPT_ZE="你是 shell 教程讲师，以简洁的三段式说明命令并提供安全提示"
# export ZAI_DEBUG="1"
# export ZAI_CONFIRM_BEFORE_EXECUTE="1"
```

此后可使用 `zai-config` 命令进行维护，流程如下：

- `zai-config show`：查看当前配置（敏感项自动打码）。
- `zai-config all`：逐项询问所有字段，可输入 `-` 清空当前值。
- `zai-config pick`：选择部分字段（支持 `fzf` 多选或编号输入）。
- `zai-config set KEY=VALUE ...`：脚本中快速覆盖某些字段。
- 直接运行 `zai-config` 会进入交互式菜单，`zai-config init` 则重新生成模板。

配置会立即写入文件并 `source`，无需重启 shell。

## 使用方法

- `zq <需求>`：例如 `zq 列出当前目录的所有 markdown 文件并按更新时间排序`。插件会请求 AI，把自然语言转成命令列表。若系统安装了 `fzf` 会进入交互式选择，否则采用 zsh 默认 `select`。选中后命令会被写入当前提示符（可自行编辑后按 Enter 执行），若环境不支持则直接打印命令供复制。
- `ze <命令>`：例如 `ze find . -name '*.log' -delete`。AI 会返回命令的逐段解释、潜在风险和替代写法。
- `zai-help`：输出全部可用命令及常见环境变量。
- `zai-config ...`：按上一节描述管理配置，也可以在脚本里 `zai-config set KEY=VALUE` 批量修改。可通过 `ZAI_PROMPT_ZQ` / `ZAI_PROMPT_ZE` 自由定制系统提示词。
- `ZAI_SKIP_AUTO_CONFIG=1`：若想完全自行设置环境变量，可通过该变量禁止插件自动加载配置文件。
- `ZAI_DEBUG=1`：调试模式，打印系统提示、用户提示、请求体与 AI 原始响应等详细日志。

## 依赖

- macOS (已在 zsh 5.8+ 测试)
- `curl` 与 `python3`
- 可选：`fzf`（若存在则优先用于命令选择）

## 注意事项

- AI 生成的命令具有不确定性，执行前请仔细确认提示内容，尤其是带有写入或删除操作的命令。
- 若使用公司或私有化部署，需要保证返回格式为 OpenAI Chat Completions 兼容的 JSON。
