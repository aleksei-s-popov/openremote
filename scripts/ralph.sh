#!/usr/bin/env bash
# Ralph Wiggum Autonomous Loop for AI Coding implemented to run with Github Spec Kit
# Inspired by: https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum

set -e

notify() {
  local text="$1" # First argument
  echo $text
  if [ -z "${RALPH_SLACK_WEBHOOK_URL}" ]; then
    echo "RALPH_SLACK_WEBHOOK_URL is not set. Skipping slack webhook."
  else
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$text\"}" "${RALPH_SLACK_WEBHOOK_URL}"  || true
  fi
}

ITERATIONS=""

# accept -i=1 or --iterations=1 (also easy to extend)
for arg in "$@"; do
  case "$arg" in
    -i=*|--iterations=*)
      ITERATIONS="${arg#*=}"
      ;;
  esac
done

if [[ -z "$ITERATIONS" || ! "$ITERATIONS" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: $0 -i=<iterations>  (positive integer)" >&2
  exit 1
fi

notify "--- Ralph Wiggum Loop for Github Opencode Spec Kit Started ---"

# TODO: this needs to be improved
# is_limit_or_quota_error() {
#  # Heuristics across providers + common OpenCode error surfaces.
#  # Only call this when opencode exits non-zero (or you explicitly want to treat output as an error).
#  local text="$1"
#
#  shopt -s nocasematch
#  if [[ "$text" == *"rate limit"* ]] || [[ "$text" == *"rate_limit"* ]] || [[ "$text" == *"too many requests"* ]] || [[ "$text" == *"429"* ]] || [[ "$text" == *"exceed the rate limit"* ]]; then
#    shopt -u nocasematch
#    return 0
#  fi
#
#  if [[ "$text" == *"insufficient_quota"* ]] || [[ "$text" == *"quota"* && "$text" == *"exceeded"* ]] || [[ "$text" == *"billing"* ]]; then
#    shopt -u nocasematch
#    return 0
#  fi
#
#  # “Out of tokens” / context-length-ish failures (providers phrase this differently)
#  if [[ "$text" == *"out of tokens"* ]] || [[ "$text" == *"token limit"* ]] || [[ "$text" == *"maximum context"* ]] || [[ "$text" == *"context length"* ]]; then
#    shopt -u nocasematch
#    return 0
#  fi
#
#  shopt -u nocasematch
#  return 1
#}

if [[ -n "${RALPH_PROMPT}" ]]; then
  PROMPT="${RALPH_PROMPT}"
else
  PROMPT=$(
    cat <<EOF
/speckit.implement

Rules for the implementation run :
1) Execute exactly one task from speckit tasks list. If there are no tasks to start, output: <promise>COMPLETE</promise>
2) Run feedback loops (types/tests/lint) as needed. If you encounter an error, fix it. 
3) Stage and commit to git work you did (single focused commit). Review the code before committing.
6) When one task is done, or if there are no tasks to start, stop and exit.

ONLY WORK ON A SINGLE SPEKKIT TASK.
EOF
  )
fi

cd /workspace/project

for ((i=1; i<=ITERATIONS; i++)); do
  echo
  notify "----- Iteration $i / $ITERATIONS -----"

  # Capture output to a temporary file while showing it in real-time.
  # PIPESTATUS[0] captures the exit code of opencode (the first command in the pipe).
  tmp_log=$(mktemp -t ralph_output.XXXXXX)
  opencode run "$PROMPT" 2>&1 | tee "$tmp_log"
  status=${PIPESTATUS[0]}
  output=$(cat "$tmp_log")
  rm "$tmp_log"

  if [[ $status -ne 0 ]]; then
#    if is_limit_or_quota_error "$output"; then
#      echo "OpenCode hit a rate limit / quota / token limit. Exiting Ralph loop."
#      exit 0
#    fi

    notify "OpenCode failed (exit=$status). Exiting."
    exit "$status"
  fi

  if [[ "$output" == *"<promise>COMPLETE</promise>"* ]]; then
    notify "PRD complete, exiting."
    exit 0
  fi
done

notify "Reached iteration limit ($ITERATIONS). Exiting."