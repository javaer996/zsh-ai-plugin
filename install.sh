#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
DEFAULT_REPO_URL="https://github.com/<your-account>/zsh-ai-plugin.git"
REPO_URL="${ZAI_INSTALL_REPO_URL:-$DEFAULT_REPO_URL}"

if [[ -r "${SCRIPT_DIR}/lib/defaults.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/lib/defaults.sh"
fi

DEFAULT_INSTALL_DIR="${HOME}/.zsh/zsh-ai-plugin"
ZSHRC="${ZSHRC:-$HOME/.zshrc}"
CONFIG_FILE="${ZAI_CONFIG_FILE:-$HOME/.config/zsh-ai-plugin/config.zsh}"
CONFIG_DIR="$(dirname "$CONFIG_FILE")"
DEFAULT_AUTOSUGGEST_DIR="${HOME}/.zsh/zsh-autosuggestions"
AUTOSUGGEST_DIR="${ZAI_AUTOSUGGEST_DIR:-$DEFAULT_AUTOSUGGEST_DIR}"
INSTALL_DIR=""
INSTALL_MODE="install"

SUGGESTIONS=()
add_suggestion() {
  SUGGESTIONS+=("$1")
}

has_autosuggestions() {
  if [[ -f "${ZSHRC}" ]] && grep -q "zsh-autosuggestions" "${ZSHRC}"; then
    return 0
  fi
  local candidates=(
    "${HOME}/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}" ]]; then
      return 0
    fi
  done
  return 1
}

install_autosuggestions() {
  local target="${AUTOSUGGEST_DIR}"
  if [[ -d "${target}" ]]; then
    info "zsh-autosuggestions 已存在于 ${target}"
    return 0
  fi
  info "克隆 zsh-autosuggestions 到 ${target}"
  mkdir -p "$(dirname "${target}")"
  git clone https://github.com/zsh-users/zsh-autosuggestions "${target}"
}

ensure_autosuggestions_source() {
  local source_line="source ${AUTOSUGGEST_DIR}/zsh-autosuggestions.zsh"
  if [[ -f "${ZSHRC}" ]] && grep -F "${source_line}" "${ZSHRC}" >/dev/null 2>&1; then
    return
  fi
  info "在 ${ZSHRC} 追加 zsh-autosuggestions 引用"
  {
    printf '\n# zsh-autosuggestions\n'
    printf '%s\n' "${source_line}"
  } >> "${ZSHRC}"
  add_suggestion "已为 zsh-autosuggestions 更新 ${ZSHRC}，可执行 'source ${ZSHRC}' 使其生效"
}

ensure_autosuggestions() {
  if has_autosuggestions; then
    info "检测到已配置 zsh-autosuggestions，可在需要时使用 Tab 接受灰色补全"
    return
  fi

  read -r -p "是否立即安装 zsh-autosuggestions（灰色自动补全）? [y/N]: " answer
  if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
    add_suggestion "如需灰色自动补全，可运行: git clone https://github.com/zsh-users/zsh-autosuggestions ${AUTOSUGGEST_DIR} && 在 ${ZSHRC} 中 source"
    return
  fi

  install_autosuggestions && ensure_autosuggestions_source &&
    info "zsh-autosuggestions 安装完毕，重新加载 shell 即可生效"
}

resolve_install_dir() {
  printf '%s\n' "${DEFAULT_INSTALL_DIR}"
}

write_config_var() {
  local key="$1"
  local value="$2"
  if [[ -n "${value}" ]]; then
    printf 'export %s=%q\n' "${key}" "${value}"
  else
    printf '# export %s=\n' "${key}"
  fi
}

info() {
  printf '\033[1;34m[信息]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33m[警告]\033[0m %s\n' "$*"
}

error() {
  printf '\033[1;31m[错误]\033[0m %s\n' "$*" >&2
  exit 1
}

check_os() {
  local os_name
  os_name="$(uname -s 2>/dev/null || printf '未知')"
  info "检测系统: ${os_name}"
  if [[ "${os_name}" != "Darwin" ]]; then
    warn "脚本主要针对 macOS，其他系统可能需要手动调整路径"
  fi
}

check_command() {
  local cmd="$1"
  local help="$2"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    warn "未检测到 ${cmd}"
    add_suggestion "${help}"
    return 1
  fi
  info "依赖已就绪: ${cmd}"
  return 0
}

check_dependencies() {
  local missing=0
  check_command "zsh" "安装 zsh: brew install zsh 或使用系统自带" || missing=$((missing + 1))
  check_command "git" "未安装 git，可执行：xcode-select --install 或 brew install git" || missing=$((missing + 1))
  check_command "curl" "安装 curl: brew install curl" || missing=$((missing + 1))
  check_command "python3" "安装 Python 3: brew install python" || missing=$((missing + 1))
  if ! command -v fzf >/dev/null 2>&1; then
    warn "fzf 未安装（可选依赖）"
    add_suggestion "可选安装 fzf 以获得更佳选择体验：brew install fzf"
  else
    info "fzf 已安装"
  fi
  if (( missing > 0 )); then
    error "缺少必要依赖，请根据提示先安装后再执行脚本"
  fi
}

clone_or_copy_repo() {
  local action="安装"
  if [[ -d "${INSTALL_DIR}/lib" ]]; then
    action="更新"
    INSTALL_MODE="update"
    info "检测到已有插件目录: ${INSTALL_DIR}，将执行覆盖更新"
  else
    INSTALL_MODE="install"
    info "准备将插件安装到 ${INSTALL_DIR}"
  fi

  if [[ "${SCRIPT_DIR}" == "${INSTALL_DIR}" ]]; then
    info "当前目录即目标目录，假定代码已更新，跳过文件同步"
    return
  fi

  if [[ -d "${SCRIPT_DIR}/lib" ]]; then
    info "同步文件到 ${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete \
        --exclude '.git/' \
        --exclude '.gitignore' \
        --exclude '.DS_Store' \
        --exclude '.claude/' \
        "${SCRIPT_DIR}/" "${INSTALL_DIR}/"
    else
      rm -rf "${INSTALL_DIR}"
      mkdir -p "${INSTALL_DIR}"
      cp -R "${SCRIPT_DIR}/." "${INSTALL_DIR}/"
      rm -rf "${INSTALL_DIR}/.git" "${INSTALL_DIR}/.claude" "${INSTALL_DIR}/.gitignore" 2>/dev/null || true
    fi
    info "${action}文件同步完成: ${INSTALL_DIR}"
    return
  fi

  info "开始克隆仓库到 ${INSTALL_DIR}"
  mkdir -p "$(dirname "${INSTALL_DIR}")"
  git clone "${REPO_URL}" "${INSTALL_DIR}"
}

ensure_source_line() {
  local source_line="source ${INSTALL_DIR}/zsh-ai-plugin.plugin.zsh"
  if [[ -f "${ZSHRC}" ]] && grep -F "${source_line}" "${ZSHRC}" >/dev/null 2>&1; then
    info ".zshrc 已包含插件引用"
    return
  fi

  info "在 ${ZSHRC} 末尾追加插件引用"
  {
    printf '\n# zsh-ai-plugin\n'
    printf '%s\n' "${source_line}"
  } >> "${ZSHRC}"
  add_suggestion "已更新 ${ZSHRC}，执行 'source ${ZSHRC}' 使其立即生效"
}

prompt_value() {
  local var_name="$1"
  local prompt="$2"
  local default="$3"
  local value=""
  if [[ -n "${default}" ]]; then
    read -r -p "${prompt} [默认: ${default}]: " value
  else
    read -r -p "${prompt}: " value
  fi
  if [[ -z "${value}" ]]; then
    value="${default}"
  fi
  printf -v "${var_name}" '%s' "${value}"
}

configure_file() {
  local api_base api_endpoint api_key model temperature system_hint prompt_zq prompt_ze
  info "配置 AI 接口参数（可留空，稍后使用 zai-config 修改）"
  prompt_value api_base "API Base" "${ZAI_API_BASE:-https://api.openai.com/v1}"
  prompt_value api_endpoint "Endpoint" "${ZAI_API_ENDPOINT:-/chat/completions}"
  read -r -s -p "API Key (留空表示稍后再配置): " api_key; printf '\n'
  prompt_value model "模型 ID" "${ZAI_MODEL:-gpt-4o-mini}"
  prompt_value temperature "Temperature" "${ZAI_TEMPERATURE:-0.2}"
  prompt_value system_hint "系统提示 (可选)" "${ZAI_SYSTEM_HINT:-}"
  prompt_zq="${ZAI_PROMPT_ZQ:-${ZAI_PROMPT_ZQ_DEFAULT:-}}"
  prompt_ze="${ZAI_PROMPT_ZE:-${ZAI_PROMPT_ZE_DEFAULT:-}}"

  mkdir -p "${CONFIG_DIR}"
  {
    write_config_var ZAI_API_BASE "${api_base}"
    write_config_var ZAI_API_ENDPOINT "${api_endpoint}"
    if [[ -n "${api_key}" ]]; then
      write_config_var ZAI_API_KEY "${api_key}"
    else
      printf '# export ZAI_API_KEY="sk-xxx"\n'
    fi
    printf '# export ZAI_API_AUTH_HEADER="api-key: xxx"\n'
    write_config_var ZAI_MODEL "${model}"
    write_config_var ZAI_TEMPERATURE "${temperature}"
    printf '# export ZAI_REQUEST_TIMEOUT="45"\n'
    if [[ -n "${system_hint}" ]]; then
      write_config_var ZAI_SYSTEM_HINT "${system_hint}"
    else
      printf '# export ZAI_SYSTEM_HINT="你是..."\n'
    fi
    write_config_var ZAI_PROMPT_ZQ "${prompt_zq}"
    write_config_var ZAI_PROMPT_ZE "${prompt_ze}"
    printf '# export ZAI_DEBUG="1"\n'
  } > "${CONFIG_FILE}"

  info "配置已写入 ${CONFIG_FILE}"
}

ensure_config() {
  if [[ "${INSTALL_MODE}" == "update" ]]; then
    info "更新模式，保留现有配置 (${CONFIG_FILE})"
    return
  fi
  if [[ -f "${CONFIG_FILE}" ]]; then
    info "检测到已有配置文件: ${CONFIG_FILE}"
    read -r -p "是否重新配置? [y/N]: " answer
    if [[ "${answer}" =~ ^[Yy]$ ]]; then
      configure_file
    else
      info "保留现有配置，可稍后使用 'zai-config' 调整"
    fi
    return
  fi

  read -r -p "尚未检测到配置文件，是否现在创建? [Y/n]: " create_answer
  if [[ "${create_answer}" =~ ^[Nn]$ ]]; then
    add_suggestion "稍后运行 'zai_config_init' 或 'zai-config all' 生成配置"
    return
  fi

  configure_file
}

print_summary() {
  printf '\n\033[1;32m安装流程完成！\033[0m\n'
  printf '插件目录: %s\n' "${INSTALL_DIR}"
  printf '配置文件: %s\n' "${CONFIG_FILE}"
  printf '请重新打开终端或执行: source %s\n' "${ZSHRC}"
  printf '\n建议操作:\n'
  if (( ${#SUGGESTIONS[@]} == 0 )); then
    printf '  - 无，尽情享用 zsh-ai-plugin 吧！\n'
  else
    local suggestion
    for suggestion in "${SUGGESTIONS[@]}"; do
      printf '  - %s\n' "${suggestion}"
    done
  fi
  printf '\n推荐命令：\n'
  printf '  - zai-help            # 查看所有能力\n'
  printf '  - zai-config all      # 随时调整接口参数\n'
  printf '  - zq / ze             # 体验命令生成与解释\n'
  printf '\n卸载: 可在插件目录执行 sh uninstall.sh 根据提示安全移除。\n'
}

main() {
  info "开始一键安装 zsh-ai-plugin"
  check_os
  check_dependencies
  INSTALL_DIR="$(resolve_install_dir)"
  clone_or_copy_repo
  ensure_source_line
  ensure_config
  ensure_autosuggestions
  print_summary
}

main "$@"
