#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
ZSHRC="${ZSHRC:-$HOME/.zshrc}"

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
  if [[ -n "${ZAI_INSTALL_DIR:-}" ]]; then
    printf '%s\n' "${ZAI_INSTALL_DIR}"
    return
  fi

  local detected
  detected="$(detect_from_zshrc || true)"
  if [[ -n "${detected}" ]]; then
    printf '%s\n' "${detected}"
    return
  fi

  if [[ -d "${SCRIPT_DIR}/lib" ]]; then
    printf '%s\n' "${SCRIPT_DIR}"
    return
  fi

  printf '%s\n' "${HOME}/.zsh/zsh-ai-plugin"
}

copy_files() {
  local target="$1"
  if [[ "${target}" == "${SCRIPT_DIR}" ]]; then
    warn "插件目录与当前仓库相同，无需拷贝"
    return
  fi
  info "同步文件到 ${target}"
  mkdir -p "${target}"
  rsync -a \
    --exclude '.git/' \
    --exclude '.gitignore' \
    --exclude '.DS_Store' \
    --exclude '.claude/' \
    "${SCRIPT_DIR}/" "${target}/"
}

main() {
  info "开始更新 zsh-ai-plugin"
  local install_dir
  install_dir="$(resolve_install_dir)"
  if [[ -z "${install_dir}" ]]; then
    error "无法确定安装目录，请设置 ZAI_INSTALL_DIR=/path/to/zsh-ai-plugin"
  fi

  copy_files "${install_dir}"
  info "更新完成。请在终端执行 'source ${ZSHRC}' 或重新打开窗口以加载最新脚本。"
}

main "$@"
