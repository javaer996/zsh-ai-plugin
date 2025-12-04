# shellcheck shell=zsh

_zai_select_command() {
  local entries="$1"
  local -a cmd_list desc_list menu_entries
  local line encoded_cmd decoded_cmd desc
  local IFS=$'\n'
  for line in ${=entries}; do
    encoded_cmd="${line%%$'\t'*}"
    desc="${line#*$'\t'}"
    if [[ "${encoded_cmd}" == "${desc}" ]]; then
      desc=""
    fi
    decoded_cmd="$(_zai_decode_base64 "${encoded_cmd}")" || {
      _zai_debug "命令解码失败，条目已跳过"
      continue
    }
    cmd_list+=("${decoded_cmd}")
    desc_list+=("${desc}")
  done

  if (( ${#cmd_list} == 0 )); then
    _zai_err "AI 没有提供可执行命令"
    return 1
  fi

  local idx=1
  local entry display desc_line single_line
  for entry in "${cmd_list[@]}"; do
    desc_line="${desc_list[$idx]}"
    single_line="${entry//$'\n'/\\n}"
    display="${idx}. ${single_line}"
    if [[ -n "${desc_line}" ]]; then
      display="${display} # ${desc_line}"
    fi
    menu_entries+=("${display}")
    ((idx++))
  done

  local selection index selected
  if _zai_use_fzf; then
    local fzf_opts=(
      --prompt "zq> "
      --no-multi
      --ansi
      --height=60%
      --layout=reverse
      --border
    )
    selection="$(printf '%s\n' "${menu_entries[@]}" | fzf "${fzf_opts[@]}")" || return 1
    index="${selection%%.*}"
  else
    local old_ps3="${PS3}"
    PS3=$'选择要执行的命令编号 (Ctrl-C 退出): '
    select selected in "${menu_entries[@]}"; do
      if [[ -z "${selected}" ]]; then
        print "无效选择" >&2
        continue
      fi
      index="${selected%%.*}"
      break
    done
    PS3="${old_ps3}"
  fi

  if [[ -z "${index}" ]]; then
    return 1
  fi

  if [[ ! "${index}" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  local cmd_to_run="${cmd_list[$index]}"
  print -r -- "${cmd_to_run}"
}

zq() {
  if (( $# == 0 )); then
    _zai_err "用法: zq <描述你想做的事>"
    return 1
  fi

  local query="$*"
  local system_prompt="${ZAI_PROMPT_ZQ}"
  if [[ -n "${ZAI_SYSTEM_HINT:-}" ]]; then
    system_prompt="${ZAI_SYSTEM_HINT}\n${system_prompt}"
  fi
  local user_prompt="当前目录: ${PWD}\n任务: ${query}\n请给出可直接执行的命令列表。如果可行，优先返回shell命令，也可以返回python等其他语言命令，但是禁止返回与要求无关的命令！命令返回格式必须遵守以下要求：请以单行字符串形式返回整段脚本命令（在
  JSON里用\n表示换行,示例:\"cat <<'EOF' > geometric_sequence.py\n#!/usr/bin/env python3\n...\nEOF\""

  local raw
  raw="$(_zai_chat_request "${system_prompt}" "${user_prompt}" "" "✨ 正在请求 AI 生成命令...")" || return 1
  local parsed
  parsed="$(_zai_parse_command_list "${raw}")" || {
    _zai_err "AI 返回内容无法解析，请查看原始输出:"
    print -r -- "${raw}"
    return 1
  }

  local chosen
  chosen="$(_zai_select_command "${parsed}")" || return 1
  _zai_enqueue_command "${chosen}"
}

ze() {
  if (( $# == 0 )); then
    _zai_err "用法: ze <需要解释的命令>"
    return 1
  fi

  local target="$*"
  local system_prompt="${ZAI_PROMPT_ZE}"
  if [[ -n "${ZAI_SYSTEM_HINT:-}" ]]; then
    system_prompt="${ZAI_SYSTEM_HINT}\n${system_prompt}"
  fi
  local user_prompt="命令: ${target}\n 返回结构不要太复杂，不要有markdown，html等标签。"

  local result
  result="$(_zai_chat_request "${system_prompt}" "${user_prompt}" "" "✨ 正在请求 AI 解释命令...")" || return 1
  print -r -- "${result}"
}

zai_help() {
  cat <<'EOF'
zsh-ai-plugin 指令速览:
  zq <描述>         将自然语言需求转换为可执行命令，支持 fzf/默认选择器
  ze <命令>         解析命令含义、风险及替代写法
  zai-config        打开配置菜单，可显示/全量/选择性修改并即时生效
  zai-config show   直接查看当前配置
  zai-config all    逐项询问所有字段
  zai-config pick   仅调整指定字段
  zai-config set KEY=VALUE [...] 直接写入配置
  zai_config_init   生成全新配置模板（若文件不存在）
  zai-help          显示此帮助
常用环境变量:
  ZAI_CONFIG_FILE   指定配置文件路径
  ZAI_PROMPT_ZQ     自定义 zq 的系统提示
  ZAI_PROMPT_ZE     自定义 ze 的系统提示
  ZAI_DISABLE_SPINNER 请求 AI 时关闭动态提示行
  ZAI_DEBUG=1       打印系统/用户提示、请求体与 AI 响应等调试日志
EOF
}

alias zai-help=zai_help
alias zai-config=zai_config
