#!/usr/bin/env bash
set -euo pipefail

ZSHRC="${ZSHRC:-$HOME/.zshrc}"
CONFIG_FILE="${ZAI_CONFIG_FILE:-$HOME/.config/zsh-ai-plugin/config.zsh}"

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

detect_from_zshrc() {
  [[ ! -f "${ZSHRC}" ]] && return
  python3 - "$ZSHRC" <<'PY'
import os
import shlex
import sys

path = sys.argv[1]
try:
    lines = open(path, encoding="utf-8").read().splitlines()
except OSError:
    raise SystemExit

for line in lines:
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    if "zsh-ai-plugin.plugin.zsh" not in line:
        continue
    if not line.startswith("source"):
        continue
    try:
        parts = shlex.split(line, comments=True, posix=True)
    except ValueError:
        continue
    if len(parts) < 2 or parts[0] != "source":
        continue
    candidate = os.path.expanduser(parts[1])
    if candidate.endswith("zsh-ai-plugin.plugin.zsh"):
        print(os.path.dirname(os.path.abspath(candidate)))
        break
PY
}

resolve_install_dir() {
  local detected
  detected="$(detect_from_zshrc || true)"
  if [[ -n "${detected}" ]]; then
    printf '%s\n' "${detected}"
    return
  fi

  printf '%s\n' "${HOME}/.zsh/zsh-ai-plugin"
}

remove_source_line() {
  [[ ! -f "${ZSHRC}" ]] && return
  local result
  result="$(python3 - "$ZSHRC" <<'PY'
import os
import sys

path = sys.argv[1]
try:
    lines = open(path, encoding='utf-8').readlines()
except OSError:
    raise SystemExit

target = "zsh-ai-plugin.plugin.zsh"
new_lines = []
changed = False
for line in lines:
    if target in line:
        changed = True
        if new_lines and new_lines[-1].strip() == "# zsh-ai-plugin":
            new_lines.pop()
        continue
    new_lines.append(line)

if changed:
    with open(path, 'w', encoding='utf-8') as handle:
        handle.writelines(new_lines)
    sys.stdout.write("removed")
PY
)"
  if [[ "${result}" == "removed" ]]; then
    info "已从 ${ZSHRC} 中移除 source 行"
  else
    info "${ZSHRC} 中未找到 zsh-ai-plugin 引用或已手动删除"
  fi
}

maybe_remove_config() {
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    return
  fi
  read -r -p "是否删除配置文件 ${CONFIG_FILE}? [y/N]: " answer
  if [[ "${answer}" =~ ^[Yy]$ ]]; then
    rm -f "${CONFIG_FILE}"
    info "已删除配置文件"
  else
    info "保留配置文件"
  fi
}

remove_install_dir() {
  local dir="$1"
  if [[ ! -d "${dir}" ]]; then
    warn "未找到插件目录 ${dir}"
    return
  fi
  rm -rf "${dir}"
  info "已删除插件目录 ${dir}"
}

main() {
  info "开始卸载 zsh-ai-plugin"
  local install_dir
  install_dir="$(resolve_install_dir)"

  read -r -p "确认删除 ${install_dir} 并移除 zsh-ai-plugin? [y/N]: " confirm
  if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
    info "已取消卸载"
    exit 0
  fi

  remove_install_dir "${install_dir}"
  remove_source_line
  maybe_remove_config
  info "卸载完成，如需重新使用可运行 install.sh"
}

main "$@"
