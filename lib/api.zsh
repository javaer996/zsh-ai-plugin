# shellcheck shell=zsh

_zai_chat_request() {
  local system_prompt="$1"
  local user_prompt="$2"
  local response_format="${3:-${ZAI_RESPONSE_FORMAT:-}}"

  _zai_require_binary "curl" || return 1
  _zai_require_binary "python3" || return 1

  local base="${ZAI_API_BASE:-https://api.openai.com/v1}"
  local endpoint="${ZAI_API_ENDPOINT:-/chat/completions}"
  local url="${base%/}${endpoint}"

  local auth_header="${ZAI_API_AUTH_HEADER:-}"
  if [[ -z "${auth_header}" ]]; then
    if [[ -z "${ZAI_API_KEY:-}" ]]; then
      _zai_err "未设置 ZAI_API_KEY 或 ZAI_API_AUTH_HEADER"
      return 1
    fi
    auth_header="Authorization: Bearer ${ZAI_API_KEY}"
  fi

  local model="${ZAI_MODEL:-gpt-4o-mini}"
  local temperature="${ZAI_TEMPERATURE:-0.2}"
  local max_tokens="${ZAI_MAX_TOKENS:-}"
  local timeout="${ZAI_REQUEST_TIMEOUT:-45}"

  _zai_debug "请求 URL: ${url}"
  _zai_debug "系统提示: ${system_prompt}"
  _zai_debug "用户提示: ${user_prompt}"
  local payload
  payload="$(python3 - "$system_prompt" "$user_prompt" "$model" "$temperature" "$max_tokens" "$response_format" <<'PY'
import json
import sys

def safe_float(value, default):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default

def safe_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None

system_prompt = sys.argv[1] if len(sys.argv) > 1 else ""
user_prompt = sys.argv[2] if len(sys.argv) > 2 else ""
model = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else "gpt-4o-mini"
temperature = safe_float(sys.argv[4] if len(sys.argv) > 4 else None, 0.2)
max_tokens = safe_int(sys.argv[5] if len(sys.argv) > 5 else None)
response_format = sys.argv[6] if len(sys.argv) > 6 else ""

payload = {
    "model": model,
    "temperature": temperature,
    "messages": [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ],
}

if max_tokens:
    payload["max_tokens"] = max_tokens

if response_format:
    payload["response_format"] = {"type": response_format}

print(json.dumps(payload))
PY
)" || {
    _zai_err "无法构建请求负载，请检查 python3 是否可用"
    return 1
  }
  _zai_debug "请求体: ${payload}"

  local raw
  raw="$(printf '%s' "${payload}" | curl --silent --show-error \
    --max-time "${timeout}" \
    -H "Content-Type: application/json" \
    -H "${auth_header}" \
    -X POST "${url}" \
    --data-binary @-)" || {
    _zai_err "请求 AI 接口失败"
    return 1
  }

  _zai_debug "AI 原始响应: ${raw}"

  local content
  content="$(ZAI_RAW_RESPONSE="${raw}" python3 - <<'PY'
import json
import os
import sys

raw = os.environ.get("ZAI_RAW_RESPONSE", "")
if not raw:
    print("空响应", file=sys.stderr)
    sys.exit(1)

try:
    data = json.loads(raw)
except json.JSONDecodeError as exc:
    print(f"JSON 解析失败: {exc}", file=sys.stderr)
    sys.exit(1)

if "error" in data:
    err = data["error"]
    msg = err.get("message") if isinstance(err, dict) else err
    print(f"API 错误: {msg}", file=sys.stderr)
    sys.exit(1)

choices = data.get("choices")
if not choices:
    print("响应中缺少 choices 字段", file=sys.stderr)
    sys.exit(1)

message = choices[0].get("message", {})
content = message.get("content", "")
print(content.strip())
PY
)" || {
    _zai_err "解析 AI 响应失败"
    return 1
  }

  if [[ -z "${content}" ]]; then
    _zai_err "AI 没有返回内容"
    return 1
  fi

  print -r -- "${content}"
}

_zai_parse_command_list() {
  local raw="$1"
  _zai_debug "进入命令解析: ${raw}"
  ZAI_COMMAND_RESPONSE="${raw}" python3 - <<'PY'
import base64
import json
import os
import re
import sys

raw = os.environ.get("ZAI_COMMAND_RESPONSE", "").strip()
if not raw:
    sys.exit(1)

def try_parse(text: str):
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None

data = try_parse(raw)
if data is None:
    start = raw.find('{')
    end = raw.rfind('}')
    if start != -1 and end != -1 and end > start:
        data = try_parse(raw[start:end+1])

if data is None:
    print("PARSE_ERROR", file=sys.stderr)
    print(raw, file=sys.stderr)
    sys.exit(1)

commands = data.get("commands")
if not isinstance(commands, list):
    print("PARSE_ERROR", file=sys.stderr)
    print(raw, file=sys.stderr)
    sys.exit(1)

for item in commands:
    if not isinstance(item, dict):
        continue
    cmd = item.get("cmd") or item.get("command") or item.get("code")
    if not cmd:
        continue
    if not isinstance(cmd, str):
        cmd = str(cmd)
    desc = item.get("description") or item.get("explanation") or ""
    desc = re.sub(r"\s+", " ", desc.strip())
    encoded_cmd = base64.b64encode(cmd.encode("utf-8")).decode("ascii")
    print(f"{encoded_cmd}\t{desc}")
PY
}
