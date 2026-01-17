#!/usr/bin/env bash
# Ralph Wiggum Autonomous Loop for AI Coding
# Inspired by: https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum

set -e

PLAN_FILE="/workspace/project/PLAN.txt"
PROGRESS_FILE="/workspace/project/RALPH_PROGRESS.txt"

if [[ ! -f "$PLAN_FILE" ]]; then
    echo "Progress file is missing: $PLAN_FILE"
    exit 0
fi

if [[ ! -f "$PROGRESS_FILE" ]]; then
    echo "Progress file is missing: $PROGRESS_FILE"
    exit 0
fi

echo "--- Ralph Wiggum Loop Started ---"

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>"
  exit 1
fi

# For each iteration, run Opencode with the following prompt.
# This prompt is basic, we'll expand it later.
for ((i=1; i<=$1; i++)); do
  opencode run "@$PLAN_FILE @$PROGRESS_FILE \
1. Decide which task to work on next. \
This should be the one YOU decide has the highest priority, \
- not necessarily the first in the list. \
2. Check any feedback loops, such as types and tests. \
3. Append your progress to the $PROGRESS_FILE file. \
4. Make a git commit of that feature. \
ONLY WORK ON A SINGLE FEATURE. \
If, while implementing the feature, you notice that all work \
is complete, output <promise>COMPLETE</promise>. \
")

  echo "$result"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "PRD complete, exiting."
    exit 0
  fi
done