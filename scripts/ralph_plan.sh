#!/usr/bin/env bash
# Ralph Wiggum Autonomous Loop for AI Coding
# Inspired by: https://www.aihero.dev/tips-for-ai-coding-with-ralph-wiggum

set -e

PLAN_FILE="/workspace/project/PLAN.txt"
PROGRESS_FILE="/workspace/project/RALPH_PROGRESS.txt"

if [[ ! -f "$PLAN_FILE" ]]; then
    touch "$PLAN_FILE"
fi

if [[ ! -f "$PROGRESS_FILE" ]]; then
    touch "$PROGRESS_FILE"
fi

echo "--- Ralph Wiggum Planning Started ---"

#TODO - convert open