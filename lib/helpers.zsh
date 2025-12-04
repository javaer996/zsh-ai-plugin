# shellcheck shell=zsh

typeset -gi ZAI_SPINNER_ACTIVE=0
typeset -gi ZAI_SPINNER_PID=0
typeset -g ZAI_SPINNER_MESSAGE=""
typeset -gi ZAI_SPINNER_CURSOR_HIDDEN=0

_zai_info() {
  print -P "%F{36}[zai]%f $*"
}

_zai_err() {
  print -P "%F{160}[zai]%f $*" >&2
}

_zai_debug() {
  case "${ZAI_DEBUG:-0}" in
    1|true|TRUE|on|ON|yes|YES)
      print -P "%F{244}[zai][debug]%f $*" >&2
      ;;
    *) ;;
  esac
}

_zai_require_binary() {
  local bin="$1"
  if ! command -v "${bin}" &>/dev/null; then
    _zai_err "缺少依赖: ${bin}"
    return 1
  fi
}

_zai_quote_value() {
  local value="$1"
  printf '%q' "${value}"
}

_zai_prompt_confirm() {
  local prompt="${1:-确认?}"
  if ! read -q "reply?${prompt} [y/N] "; then
    print ""
    return 1
  fi
  print ""
  return 0
}

_zai_use_fzf() {
  command -v fzf &>/dev/null
}

_zai_decode_base64() {
  local input="$1"
  ZAI_B64_INPUT="${input}" python3 - <<'PY'
import base64
import os
import sys

data = os.environ.get("ZAI_B64_INPUT", "")
try:
    decoded = base64.b64decode(data).decode("utf-8")
except Exception:
    sys.exit(1)

sys.stdout.write(decoded)
PY
}

_zai_start_spinner() {
  local message="${1:-正在请求 AI...}"
  if (( ZAI_SPINNER_ACTIVE )); then
    return 0
  fi
  ZAI_SPINNER_MESSAGE="${message}"
  ZAI_SPINNER_ACTIVE=1
  if [[ ! -t 2 ]]; then
    print -P "%F{36}[zai]%f ${message}" >&2
    ZAI_SPINNER_PID=0
    return 0
  fi
  if (( ! ZAI_SPINNER_CURSOR_HIDDEN )); then
    printf '\e[?25l' >&2
    ZAI_SPINNER_CURSOR_HIDDEN=1
  fi
  {
    local frames=('|' '/' '-' '\\')
    local idx=0
    while true; do
      printf '\r%s %s' "${message}" "${frames[$(( idx % ${#frames[@]} ))]}" >&2
      ((idx++))
      sleep 0.1
    done
  } &
  ZAI_SPINNER_PID=$!
  disown "${ZAI_SPINNER_PID}" 2>/dev/null
  return 0
}

_zai_stop_spinner() {
  if (( ! ZAI_SPINNER_ACTIVE )); then
    return 0
  fi
  if (( ZAI_SPINNER_PID > 0 )); then
    kill "${ZAI_SPINNER_PID}" 2>/dev/null
    wait "${ZAI_SPINNER_PID}" 2>/dev/null
  fi
  if [[ -t 2 ]]; then
    printf '\r\033[K' >&2
    if (( ZAI_SPINNER_CURSOR_HIDDEN )); then
      printf '\e[?25h' >&2
      ZAI_SPINNER_CURSOR_HIDDEN=0
    fi
  else
    print "" >&2
  fi
  ZAI_SPINNER_ACTIVE=0
  ZAI_SPINNER_PID=0
  ZAI_SPINNER_MESSAGE=""
  return 0
}

_zai_enqueue_command() {
  local cmd="$1"
  if [[ -o interactive ]] && command -v print >/dev/null 2>&1; then
    if print -z -- "${cmd}" 2>/dev/null; then
      _zai_debug "命令已写入当前提示符，可直接按 Enter 执行或编辑"
      return 0
    fi
  fi

  print -r -- "${cmd}"
}
