# shellcheck shell=zsh

typeset -g ZAI_LIB_DIR="${0:A:h}"
if [[ -z "${ZAI_PROMPT_ZQ_DEFAULT:-}" || -z "${ZAI_PROMPT_ZE_DEFAULT:-}" ]]; then
  if [[ -r "${ZAI_LIB_DIR}/defaults.sh" ]]; then
    source "${ZAI_LIB_DIR}/defaults.sh"
  fi
fi

typeset -ga ZAI_CONFIG_KEYS=(
  ZAI_API_BASE
  ZAI_API_ENDPOINT
  ZAI_API_KEY
  ZAI_API_AUTH_HEADER
  ZAI_MODEL
  ZAI_TEMPERATURE
  ZAI_REQUEST_TIMEOUT
  ZAI_SYSTEM_HINT
  ZAI_PROMPT_ZQ
  ZAI_PROMPT_ZE
  ZAI_DEBUG
)

typeset -gA ZAI_CONFIG_DESCRIPTIONS=(
  [ZAI_API_BASE]="OpenAI 兼容 API Base URL"
  [ZAI_API_ENDPOINT]="Chat Completions Endpoint"
  [ZAI_API_KEY]="用于 Authorization Bearer 的 API Key"
  [ZAI_API_AUTH_HEADER]="自定义认证头（Azure 等场景）"
  [ZAI_MODEL]="模型 ID"
  [ZAI_TEMPERATURE]="回复温度 (0-2)"
  [ZAI_REQUEST_TIMEOUT]="请求超时时间（秒）"
  [ZAI_SYSTEM_HINT]="全局附加系统提示"
  [ZAI_PROMPT_ZQ]="zq 专用系统提示（命令生成）"
  [ZAI_PROMPT_ZE]="ze 专用系统提示（命令解释）"
  [ZAI_DEBUG]="调试开关 (1 输出调试日志)"
)

typeset -gA ZAI_CONFIG_SENSITIVE=(
  [ZAI_API_KEY]=1
  [ZAI_API_AUTH_HEADER]=1
)

: "${ZAI_PROMPT_ZQ:=${ZAI_PROMPT_ZQ_DEFAULT:-}}"
: "${ZAI_PROMPT_ZE:=${ZAI_PROMPT_ZE_DEFAULT:-}}"

zai_config_init() {
  mkdir -p "${ZAI_CONFIG_DIR}" || {
    _zai_err "无法创建目录: ${ZAI_CONFIG_DIR}"
    return 1
  }

  if [[ -f "${ZAI_CONFIG_FILE}" && -z "${ZAI_FORCE_OVERWRITE:-}" ]]; then
    _zai_err "配置文件已存在: ${ZAI_CONFIG_FILE}"
    _zai_info "若需覆盖请设置 ZAI_FORCE_OVERWRITE=1 后再次执行"
    return 1
  fi

  cat >"${ZAI_CONFIG_FILE}" <<'EOF'
# zsh-ai-plugin 配置模板
# 该文件会被自动 source，请确保语法正确。

export ZAI_API_BASE="https://api.openai.com/v1"
export ZAI_API_ENDPOINT="/chat/completions"
# export ZAI_API_KEY="在这里放置你的 API Key"
# export ZAI_API_AUTH_HEADER="api-key: xxx"

export ZAI_MODEL="gpt-4o-mini"
export ZAI_TEMPERATURE="0.2"
# export ZAI_REQUEST_TIMEOUT="45"

# export ZAI_SYSTEM_HINT="你是..."
# export ZAI_DEBUG="1"
EOF

  {
    printf 'export ZAI_PROMPT_ZQ=%s\n' "$(_zai_quote_value "${ZAI_PROMPT_ZQ_DEFAULT}")"
    printf 'export ZAI_PROMPT_ZE=%s\n' "$(_zai_quote_value "${ZAI_PROMPT_ZE_DEFAULT}")"
  } >> "${ZAI_CONFIG_FILE}"

  _zai_info "配置模板已写入 ${ZAI_CONFIG_FILE}"
  _zai_info "请运行 'zai-config all' 或 'zai-config pick' 完成配置"
}

_zai_config_show() {
  local key value display desc
  print -P "%F{33}当前配置（${ZAI_CONFIG_FILE}）:%f"
  for key in "${ZAI_CONFIG_KEYS[@]}"; do
    value="${(P)key}"
    desc="${ZAI_CONFIG_DESCRIPTIONS[$key]}"
    if [[ -z "${value}" ]]; then
      display="<未设置>"
    elif [[ -n "${ZAI_CONFIG_SENSITIVE[$key]}" ]]; then
      display="***已设置***"
    else
      display="${value}"
    fi
    print -P "  %F{70}${key}%f = ${display}  # ${desc}"
  done
}

_zai_config_write_file() {
  local key value
  mkdir -p "${ZAI_CONFIG_DIR}" || {
    _zai_err "无法创建目录: ${ZAI_CONFIG_DIR}"
    return 1
  }

  {
    print "# 自动生成于 $(date +'%Y-%m-%d %H:%M:%S')"
    for key in "${ZAI_CONFIG_KEYS[@]}"; do
      value="${(P)key}"
      if [[ -n "${value}" ]]; then
        printf 'export %s=%s\n' "${key}" "$(_zai_quote_value "${value}")"
      else
        printf '# export %s=\n' "${key}"
      fi
    done
  } >| "${ZAI_CONFIG_FILE}"
}

_zai_config_reload() {
  if [[ -r "${ZAI_CONFIG_FILE}" ]]; then
    source "${ZAI_CONFIG_FILE}"
  fi
}

_zai_config_prompt_keys() {
  local key desc current display prompt new_value
  for key in "$@"; do
    desc="${ZAI_CONFIG_DESCRIPTIONS[$key]}"
    current="${(P)key}"
    if [[ -n "${ZAI_CONFIG_SENSITIVE[$key]}" ]]; then
      if [[ -n "${current}" ]]; then
        display="***已设置***"
      else
        display="<未设置>"
      fi
      prompt="${key} (${desc}) [${display}]："
      print -n -- "${prompt}"
      read -rs new_value
      print ""
    else
      display="${current:-<未设置>}"
      read -r "new_value?${key} (${desc}) [${display}]："
    fi
    if [[ -z "${new_value}" ]]; then
      continue
    fi
    if [[ "${new_value}" == "-" ]]; then
      unset "${key}"
      continue
    fi
    typeset -g "${key}=${new_value}"
  done

  _zai_config_write_file || return 1
  _zai_config_reload
  _zai_info "配置已保存并生效"
}

_zai_config_select_keys() {
  local -a entries chosen_keys
  local idx=1 key desc
  for key in "${ZAI_CONFIG_KEYS[@]}"; do
    desc="${ZAI_CONFIG_DESCRIPTIONS[$key]}"
    entries+=("${idx}) ${key} - ${desc}")
    ((idx++))
  done

  local selection choice_idx line token
  if _zai_use_fzf; then
    selection="$(printf '%s\n' "${entries[@]}" | fzf --multi --prompt "选择要修改的字段> " --ansi)" || return 1
    while IFS= read -r line; do
      choice_idx="${line%%)*}"
      if [[ -n "${choice_idx}" ]]; then
        chosen_keys+=("${ZAI_CONFIG_KEYS[$choice_idx]}")
      fi
    done <<<"${selection}"
  else
    print "请选择要修改的字段编号（空格分隔，留空取消）:"
    for entry in "${entries[@]}"; do
      print "  ${entry}"
    done
    read -r "selection?编号: "
    if [[ -z "${selection}" ]]; then
      return 1
    fi
    for token in ${=selection}; do
      if [[ "${token}" -gt 0 && "${token}" -le ${#ZAI_CONFIG_KEYS} ]]; then
        chosen_keys+=("${ZAI_CONFIG_KEYS[$token]}")
      fi
    done
  fi

  if (( ${#chosen_keys} == 0 )); then
    _zai_info "未选择任何字段"
    return 1
  fi

  printf '%s\n' "${chosen_keys[@]}"
}

_zai_config_prompt_selective() {
  local selection="$(_zai_config_select_keys)" || return 1
  local IFS=$'\n'
  local -a keys=(${=selection})
  _zai_config_prompt_keys "${keys[@]}"
}

_zai_config_prompt_all() {
  _zai_config_prompt_keys "${ZAI_CONFIG_KEYS[@]}"
}

_zai_config_set_pairs() {
  if (( $# == 0 )); then
    _zai_err "用法: zai-config set KEY=VALUE ..."
    return 1
  fi

  local pair key value
  for pair in "$@"; do
    if [[ "${pair}" != *=* ]]; then
      _zai_err "参数格式错误: ${pair}"
      return 1
    fi
    key="${pair%%=*}"
    value="${pair#*=}"
    if [[ -z "${key}" ]]; then
      _zai_err "缺少键名: ${pair}"
      return 1
    fi
    local index=${ZAI_CONFIG_KEYS[(I)${key}]}
    if (( index > ${#ZAI_CONFIG_KEYS} )); then
      _zai_err "未知配置项: ${key}"
      return 1
    fi
    typeset -g "${key}=${value}"
  done

  _zai_config_write_file || return 1
  _zai_config_reload
  _zai_info "配置已写入 ${ZAI_CONFIG_FILE}"
}

_zai_config_menu() {
  local choice
  while true; do
    cat <<'EOF'
zai-config 菜单:
  1) 查看当前配置
  2) 全量配置
  3) 选择性配置
  4) 重新生成模板
  5) 退出
EOF
    read -r "choice?请选择操作: "
    case "${choice}" in
      1) _zai_config_show ;;
      2) _zai_config_prompt_all ;;
      3) _zai_config_prompt_selective ;;
      4) zai_config_init ;;
      5|"") return 0 ;;
      *) _zai_err "无效选择: ${choice}" ;;
    esac
  done
}

zai_config() {
  local action="${1:-menu}"
  case "${action}" in
    show|list)
      _zai_config_show
      ;;
    all|full)
      _zai_config_prompt_all
      ;;
    pick|select)
      _zai_config_prompt_selective
      ;;
    set)
      shift
      _zai_config_set_pairs "$@"
      ;;
    init)
      zai_config_init
      ;;
    menu|"")
      _zai_config_menu
      ;;
    *)
      _zai_err "未知参数: ${action}"
      print "可用子命令: show | all | pick | set | init | menu"
      return 1
      ;;
  esac
}
