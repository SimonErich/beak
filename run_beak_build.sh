#!/usr/bin/env bash
#
# run_beak_build.sh — Autonomous, timeout- and rate-limit-proof build loop for Beak.
#
# It repeatedly launches Claude Code in headless ("print") mode, one PHASE per
# invocation. Each invocation is stateless: Claude re-reads PLAN/STATE.md to find
# the next unfinished phase, executes it test-first, runs the Definition-of-Done
# gate, updates STATE.md, and commits. The harness loops until the sentinel file
# BUILD_COMPLETE appears.
#
# WHY one phase per invocation:
#   * Context hygiene — Claude only loads the current phase file, never all 16.
#   * Timeout resilience — every invocation is short and bounded; if it dies
#     mid-way, the next invocation resumes from git + STATE.md.
#   * Rate-limit resilience — on any non-completing exit we sleep and retry.
#
# USAGE:
#   chmod +x run_beak_build.sh
#   ./run_beak_build.sh            # runs to completion, unattended
#   TAIL=1 ./run_beak_build.sh     # also tail build.log to the terminal
#
# PREREQUISITES (checked below):
#   * `claude` CLI on PATH (Claude Code). Verify flags once with: claude --help
#   * ./packages/worm exists (worm + drivers vendored here)
#   * ~/Flutters/obers_ui exists (obers_ui + obers_ui_autoforms + obers_ui_charts)
#   * docker + docker compose available (Postgres + MinIO come up in Phase 0/15)
#   * dart + flutter on PATH; melos activated (`dart pub global activate melos`)
#
set -uo pipefail

# ---- Tunables ---------------------------------------------------------------
MODEL="${BEAK_MODEL:-claude-fable-5}"      # override with BEAK_MODEL=...
SLEEP_SECONDS="${BEAK_SLEEP:-90}"          # wait between invocations / on retry
MAX_INVOCATIONS="${BEAK_MAX_INVOCATIONS:-500}"
STALL_LIMIT="${BEAK_STALL_LIMIT:-6}"       # give up if STATE.md unchanged N times
LOG_FILE="build.log"
SENTINEL="BUILD_COMPLETE"
NEEDS_HUMAN="NEEDS_HUMAN.md"

# Claude Code headless flags. These are the full-autonomy flags; confirm the
# exact spelling for your installed version with `claude --help`. The common
# alternates are noted inline.
#   -p / --print              : headless, non-interactive
#   --permission-mode bypassPermissions : never prompt for tool permissions
#     (older/newer builds: --dangerously-skip-permissions)
#   --model <id>              : pick the model
CLAUDE_FLAGS=(--print --permission-mode bypassPermissions --model "$MODEL")

# ---- Pre-flight -------------------------------------------------------------
fail() { printf '\n[run_beak_build] FATAL: %s\n' "$1" >&2; exit 1; }

command -v claude >/dev/null 2>&1 || fail "the 'claude' CLI is not on PATH."
command -v git    >/dev/null 2>&1 || fail "git is not on PATH."
[ -f PROMPT.md ]      || fail "PROMPT.md not found. Run this from the repo root."
[ -f CLAUDE.md ]      || fail "CLAUDE.md not found. Run this from the repo root."
[ -f PLAN/STATE.md ]  || fail "PLAN/STATE.md not found."
[ -d packages/worm ]  || printf '[run_beak_build] WARN: ./packages/worm missing — Phase 0 will fail its gate until vendored.\n'
[ -d "$HOME/Flutters/obers_ui" ] || printf '[run_beak_build] WARN: ~/Flutters/obers_ui missing — frontend phases will fail their gate until present.\n'

# Ensure a git repo exists so each phase can commit.
if [ ! -d .git ]; then
  git init -q
  git add -A
  git commit -q -m "chore: import Beak build kit (pre-phase-0 baseline)" || true
fi

: > "$LOG_FILE"
printf '[run_beak_build] Starting Beak autonomous build @ %s\n' "$(date)" | tee -a "$LOG_FILE"
printf '[run_beak_build] model=%s sleep=%ss max=%s\n' "$MODEL" "$SLEEP_SECONDS" "$MAX_INVOCATIONS" | tee -a "$LOG_FILE"

# A leftover NEEDS_HUMAN.md is a PER-RUN stop-signal from a previous run. If we don't
# clear it, the very next invocation of THIS run trips the check below and aborts —
# even when that invocation made real progress. Re-running the script is itself the
# human's acknowledgment; Claude re-creates the file (and we stop) only if a genuine
# external blocker recurs this run. BUILD_COMPLETE is deliberately NOT cleared — if it
# exists the build is finished and the loop should not start.
if [ -f "$NEEDS_HUMAN" ]; then
  printf '[run_beak_build] Clearing stale %s left by a previous run.\n' "$NEEDS_HUMAN" | tee -a "$LOG_FILE"
  rm -f "$NEEDS_HUMAN"
fi

# Progress = the ledger advanced OR a new commit landed. Watching STATE.md's hash alone
# false-stalls on big, multi-invocation phases: Claude can commit partial work for
# several invocations before it flips the ledger row to ✅ DONE. Folding the HEAD SHA and
# commit count in means genuine forward motion resets the stall counter.
progress_signature() {
  printf '%s|%s|%s' \
    "$(md5sum PLAN/STATE.md 2>/dev/null | awk '{print $1}')" \
    "$(git rev-parse HEAD 2>/dev/null)" \
    "$(git rev-list --count HEAD 2>/dev/null)"
}

prev_sig="$(progress_signature)"
stall=0
i=0

# ---- Main loop --------------------------------------------------------------
while [ ! -f "$SENTINEL" ]; do
  i=$((i + 1))
  if [ "$i" -gt "$MAX_INVOCATIONS" ]; then
    printf '[run_beak_build] Reached MAX_INVOCATIONS=%s without completion. Stopping.\n' "$MAX_INVOCATIONS" | tee -a "$LOG_FILE"
    exit 1
  fi

  printf '\n========== INVOCATION #%s @ %s ==========\n' "$i" "$(date)" | tee -a "$LOG_FILE"

  # Run Claude Code headless on the loop prompt. A fresh session every time.
  if [ "${TAIL:-0}" = "1" ]; then
    claude "${CLAUDE_FLAGS[@]}" "$(cat PROMPT.md)" 2>&1 | tee -a "$LOG_FILE"
    status=${PIPESTATUS[0]}
  else
    claude "${CLAUDE_FLAGS[@]}" "$(cat PROMPT.md)" >> "$LOG_FILE" 2>&1
    status=$?
  fi

  # Completed?
  if [ -f "$SENTINEL" ]; then break; fi

  # Human-attention sentinel (Claude writes this only when a phase is truly stuck).
  if [ -f "$NEEDS_HUMAN" ]; then
    printf '[run_beak_build] Claude requested human attention. See %s. Stopping.\n' "$NEEDS_HUMAN" | tee -a "$LOG_FILE"
    exit 2
  fi

  # Stall detection: if neither the ledger nor the commit graph advanced, count it.
  cur_sig="$(progress_signature)"
  if [ "$cur_sig" = "$prev_sig" ]; then
    stall=$((stall + 1))
    printf '[run_beak_build] No STATE.md/commit progress this invocation (stall %s/%s). exit=%s\n' "$stall" "$STALL_LIMIT" "$status" | tee -a "$LOG_FILE"
    if [ "$stall" -ge "$STALL_LIMIT" ]; then
      {
        echo "# Build stalled"
        echo
        echo "PLAN/STATE.md did not advance across $STALL_LIMIT consecutive invocations."
        echo "Last claude exit status: $status. Inspect build.log and the current phase gate."
      } > "$NEEDS_HUMAN"
      printf '[run_beak_build] Stall limit hit; wrote %s and stopping.\n' "$NEEDS_HUMAN" | tee -a "$LOG_FILE"
      exit 3
    fi
  else
    stall=0
    prev_sig="$cur_sig"
  fi

  printf '[run_beak_build] Sleeping %ss before next phase/retry...\n' "$SLEEP_SECONDS" | tee -a "$LOG_FILE"
  sleep "$SLEEP_SECONDS"
done

printf '\n[run_beak_build] 🎉 BUILD_COMPLETE detected @ %s — Beak build finished.\n' "$(date)" | tee -a "$LOG_FILE"
printf '[run_beak_build] Review: git log --oneline, and PLAN/STATE.md for the full ledger.\n' | tee -a "$LOG_FILE"
