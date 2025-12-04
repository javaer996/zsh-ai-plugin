# shellcheck shell=zsh

typeset -g ZAI_PLUGIN_DIR
ZAI_PLUGIN_DIR="${0:A:h}"

: "${ZAI_CONFIG_FILE:=${HOME}/.config/zsh-ai-plugin/config.zsh}"
: "${ZAI_CONFIG_DIR:=${ZAI_CONFIG_FILE:h}}"

if [[ -z "${ZAI_SKIP_AUTO_CONFIG:-}" && -r "${ZAI_CONFIG_FILE}" ]]; then
  source "${ZAI_CONFIG_FILE}"
fi

for module in helpers config api commands; do
  module_file="${ZAI_PLUGIN_DIR}/lib/${module}.zsh"
  if [[ -f "${module_file}" ]]; then
    source "${module_file}"
  else
    print -u2 "zsh-ai-plugin: 缺少模块 ${module_file}"
  fi
done
