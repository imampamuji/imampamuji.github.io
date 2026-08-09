#!/usr/bin/env bash
# llmphone one-shot setup for Termux (Android)
# Installs llama.cpp, downloads Qwen3-0.6B Q4_K_M, writes chat/server helpers.
#
# One-liner (after you host this file, or copy it onto the phone):
#   curl -fsSL <URL-to-install.sh> | bash
# Start API server at the end:
#   curl -fsSL <URL-to-install.sh> | bash -s -- --server
#
# Env overrides:
#   LLMPHONE_HOME   install dir (default: ~/llmphone)
#   LLMPHONE_MODEL  model filename under models/ (default: Qwen3-0.6B-Q4_K_M.gguf)
#   THREADS / CTX / PORT / HOST / NGL  passed through to server.sh
set -euo pipefail

START_SERVER=0
for arg in "$@"; do
  case "$arg" in
    --server|-s) START_SERVER=1 ;;
    --help|-h)
      cat <<'EOF'
Usage: install.sh [--server]

  --server   start llama-server after setup (blocks)
EOF
      exit 0
      ;;
  esac
done

log() { printf '+ %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# --- Termux check ---
if [[ -z "${PREFIX:-}" || "$PREFIX" != *com.termux* ]]; then
  if [[ ! -d /data/data/com.termux/files/usr ]]; then
    die "run this inside Termux on Android"
  fi
  # shellcheck disable=SC1091
  [[ -f /data/data/com.termux/files/usr/etc/profile ]] && . /data/data/com.termux/files/usr/etc/profile || true
fi

command -v pkg >/dev/null 2>&1 || die "pkg not found (Termux only)"

HOME_DIR="${LLMPHONE_HOME:-$HOME/llmphone}"
MODEL_NAME="${LLMPHONE_MODEL:-Qwen3-0.6B-Q4_K_M.gguf}"
MODEL_PATH="$HOME_DIR/models/$MODEL_NAME"
MIN_BYTES="${LLMPHONE_MIN_BYTES:-300000000}"

# Prefer ModelScope (often more reliable on mobile); Hugging Face fallback
MODEL_URLS=(
  "https://www.modelscope.cn/models/unsloth/Qwen3-0.6B-GGUF/resolve/master/Qwen3-0.6B-Q4_K_M.gguf"
  "https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf"
)

log "install dir: $HOME_DIR"
mkdir -p "$HOME_DIR/models"

log "pkg update + install llama-cpp curl"
pkg update -y
pkg install -y llama-cpp curl

command -v llama-cli >/dev/null 2>&1 || die "llama-cli missing after pkg install"
command -v llama-server >/dev/null 2>&1 || die "llama-server missing after pkg install"

write_chat() {
  cat >"$HOME_DIR/chat.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
THREADS="${THREADS:-4}"
CTX="${CTX:-2048}"
NGL="${NGL:-0}"

pick_model() {
  local candidates=(
    "${MODEL:-}"
    "$ROOT/models/Qwen3-1.7B-Q4_K_M.gguf"
    "$ROOT/models/Qwen3-0.6B-Q4_K_M.gguf"
    "$ROOT/models/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
  )
  local c
  for c in "${candidates[@]}"; do
    [[ -n "$c" && -f "$c" ]] && { echo "$c"; return 0; }
  done
  return 1
}

MODEL="$(pick_model)" || {
  echo "No GGUF under $ROOT/models/" >&2
  exit 1
}

echo "Model: $MODEL"
echo "Threads: $THREADS  Context: $CTX"
echo "Tip: prefix with /no_think for faster Qwen3 replies."
echo
exec llama-cli \
  -m "$MODEL" \
  -t "$THREADS" \
  -c "$CTX" \
  -ngl "$NGL" \
  --temp 0.7 \
  --top-p 0.9 \
  --repeat-penalty 1.1 \
  -n 512 \
  --conversation \
  --jinja \
  "$@"
EOF
  chmod +x "$HOME_DIR/chat.sh"
}

write_server() {
  cat >"$HOME_DIR/server.sh" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
THREADS="${THREADS:-4}"
CTX="${CTX:-2048}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"
NGL="${NGL:-0}"

pick_model() {
  local candidates=(
    "${MODEL:-}"
    "$ROOT/models/Qwen3-1.7B-Q4_K_M.gguf"
    "$ROOT/models/Qwen3-0.6B-Q4_K_M.gguf"
    "$ROOT/models/Qwen_Qwen3-0.6B-Q4_K_M.gguf"
  )
  local c
  for c in "${candidates[@]}"; do
    [[ -n "$c" && -f "$c" ]] && { echo "$c"; return 0; }
  done
  return 1
}

MODEL="$(pick_model)" || {
  echo "No GGUF under $ROOT/models/" >&2
  exit 1
}

echo "Model: $MODEL"
echo "API:  http://127.0.0.1:${PORT}/v1/chat/completions"
echo "UI:   http://127.0.0.1:${PORT}"
echo "Threads: $THREADS  Context: $CTX"
echo
exec llama-server \
  -m "$MODEL" \
  -t "$THREADS" \
  -c "$CTX" \
  -ngl "$NGL" \
  --host "$HOST" \
  --port "$PORT" \
  --jinja \
  "$@"
EOF
  chmod +x "$HOME_DIR/server.sh"
}

log "write chat.sh + server.sh"
write_chat
write_server

download_model() {
  local url out tmp size
  out="$MODEL_PATH"
  tmp="${out}.partial"

  if [[ -f "$out" ]]; then
    size=$(wc -c <"$out" | tr -d ' ')
    if [[ "$size" -ge "$MIN_BYTES" ]]; then
      log "model already present ($(numfmt --to=iec "$size" 2>/dev/null || echo "$size bytes"))"
      return 0
    fi
    log "existing model too small ($size); re-download"
  fi

  for url in "${MODEL_URLS[@]}"; do
    log "download: $url"
    if curl --http1.1 -fL -C - --retry 30 --retry-delay 5 --retry-all-errors \
      -o "$tmp" "$url"; then
      size=$(wc -c <"$tmp" | tr -d ' ')
      if [[ "$size" -ge "$MIN_BYTES" ]]; then
        mv -f "$tmp" "$out"
        log "model ready: $out ($size bytes)"
        return 0
      fi
      log "download too small ($size); try next mirror"
    else
      log "download failed; try next mirror"
    fi
  done
  die "could not download $MODEL_NAME"
}

log "fetch $MODEL_NAME (~462 MB)"
download_model

cat >"$HOME_DIR/README.txt" <<EOF
llmphone ready.

Chat:   cd $HOME_DIR && ./chat.sh
Server: cd $HOME_DIR && ./server.sh

API: http://127.0.0.1:8080/v1/chat/completions
Tip: start prompts with /no_think on Qwen3.
EOF

echo
log "setup complete"
echo "  chat:   cd $HOME_DIR && ./chat.sh"
echo "  server: cd $HOME_DIR && ./server.sh"
echo

if [[ "$START_SERVER" -eq 1 ]]; then
  log "starting llama-server (Ctrl+C to stop)"
  exec "$HOME_DIR/server.sh"
fi
