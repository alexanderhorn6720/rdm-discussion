#!/usr/bin/env bash
# Atomically claim the next thread number and create a stub on main.
#
# Solves the race condition documented in thread/172 (27/204 threads
# = 13% had collisions). Combines a local lock (flock or mkdir fallback)
# with fetch+retry on push rejection.
#
# Usage:   scripts/new-thread.sh <author> <topic-slug>
# Example: scripts/new-thread.sh CC-Bot kv-bug-fix-report
#
# Behavior:
#   1. Validate inputs (author enum, topic regex/length).
#   2. Require clean working tree on main.
#   3. Acquire local lock (flock if available, else mkdir).
#   4. Loop up to 5 attempts: fetch origin/main, compute next number,
#      write stub, commit, push. On non-fast-forward, undo commit and
#      retry with random jitter (500-2000ms).
#   5. Print the relative path of the new stub to stdout on success.
#
# Exit codes:
#   0  success
#   1  bad args / invalid state
#   2  lock timeout (>30s)
#   3  push failed after retries
#
# Reference: thread/175 (T1), CLAUDE.md atomic claim scripts.

set -euo pipefail

# ---------- args ----------
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <author> <topic-slug>" >&2
  echo "Example: $0 CC-Bot kv-bug-fix-report" >&2
  exit 1
fi
AUTHOR="$1"
TOPIC="$2"

# ---------- validation ----------
case "$AUTHOR" in
  WC|WC-Platform|WC-Impl|CC|CC-Bot|CC-Data|CC-Pago|CC-Web|Alex) ;;
  *)
    echo "ERROR: invalid author '${AUTHOR}'." >&2
    echo "Valid: WC, WC-Platform, WC-Impl, CC, CC-Bot, CC-Data, CC-Pago, CC-Web, Alex" >&2
    exit 1
    ;;
esac

if ! [[ "$TOPIC" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "ERROR: invalid topic-slug '${TOPIC}'. Use lowercase-kebab-case." >&2
  exit 1
fi
if [ "${#TOPIC}" -lt 5 ]; then
  echo "ERROR: topic-slug must be at least 5 chars (T3 schema requirement)." >&2
  exit 1
fi

# ---------- locate repo ----------
ROOT="$(git rev-parse --show-toplevel)"
THREADS_DIR="${ROOT}/threads"
LOCK_FILE="${ROOT}/scripts/.new-thread.lock"
LOCK_DIR="${ROOT}/scripts/.new-thread.lock.d"

if [ ! -d "$THREADS_DIR" ]; then
  echo "ERROR: ${THREADS_DIR} not found. Run inside an rdm-discussion clone." >&2
  exit 1
fi

cd "$ROOT"

# ---------- preconditions ----------
BRANCH_TARGET="main"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "$BRANCH_TARGET" ]; then
  echo "ERROR: must run from '${BRANCH_TARGET}' (currently on '${CURRENT_BRANCH}')." >&2
  echo "       Thread stubs commit directly to main; switch and re-run." >&2
  exit 1
fi

# Refuse if working tree has tracked modifications. Untracked files are OK
# (sister CC sessions may have report drafts unrelated to this claim).
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: working tree has uncommitted tracked changes." >&2
  echo "       Commit or stash before claiming a thread." >&2
  exit 1
fi

# ---------- locking ----------
release_mkdir_lock() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

acquire_lock() {
  if command -v flock >/dev/null 2>&1; then
    # FD-based flock with 30s timeout
    exec 9>"$LOCK_FILE"
    if ! flock -w 30 9; then
      echo "ERROR: timeout (30s) acquiring flock on ${LOCK_FILE}." >&2
      exit 2
    fi
    return
  fi

  # Fallback: atomic mkdir lock (POSIX + Windows NTFS).
  local elapsed=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    if [ $elapsed -ge 30 ]; then
      echo "ERROR: timeout (30s) acquiring mkdir lock on ${LOCK_DIR}." >&2
      echo "       If no other claim is running, rmdir ${LOCK_DIR} manually." >&2
      exit 2
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  trap release_mkdir_lock EXIT
}

acquire_lock

# ---------- retry helpers ----------
sleep_jitter() {
  local ms=$((500 + RANDOM % 1500))
  # Portable fractional sleep via awk.
  sleep "$(awk -v ms="$ms" 'BEGIN{printf "%.3f\n", ms/1000}')"
}

# ---------- main loop ----------
DATE_TODAY="$(date -u +%Y-%m-%d)"
MAX_ATTEMPTS=5
attempt=0
claimed_path=""

while [ $attempt -lt $MAX_ATTEMPTS ]; do
  attempt=$((attempt + 1))

  # Fetch + sync local main with origin (fast-forward only).
  if ! git fetch origin "$BRANCH_TARGET" --quiet; then
    echo "WARN: git fetch failed (attempt ${attempt}/${MAX_ATTEMPTS}). Retrying." >&2
    sleep_jitter
    continue
  fi
  if ! git merge --ff-only "origin/${BRANCH_TARGET}" --quiet 2>/dev/null; then
    # If we cannot fast-forward, our local main has diverged from origin.
    # This is unexpected on a fresh clone; surface and abort.
    echo "ERROR: local '${BRANCH_TARGET}' diverged from origin. Resolve manually." >&2
    exit 1
  fi

  # Compute next number based on the now-synced threads dir.
  HIGHEST=$(ls "$THREADS_DIR/" 2>/dev/null | grep -oE '^[0-9]+' | sort -n | tail -1 || echo "0")
  NEXT=$((HIGHEST + 1))
  PATH_REL="threads/${NEXT}-${AUTHOR}-${TOPIC}.md"
  PATH_ABS="${ROOT}/${PATH_REL}"

  if [ -e "$PATH_ABS" ]; then
    # Should never happen after fetch+ff; treat as collision and bail.
    echo "ERROR: ${PATH_REL} already exists after sync. Aborting." >&2
    exit 1
  fi

  # Write stub. Frontmatter is T3-schema compliant.
  cat > "$PATH_ABS" <<EOF
---
thread: ${NEXT}
author: ${AUTHOR}
date: ${DATE_TODAY}
topic: ${TOPIC}
mode: brain
status: draft
---

# Stub claimed via \`scripts/new-thread.sh\`

Replace this content with the real thread body, then commit and push.
EOF

  git add "$PATH_REL"
  git commit -m "thread/${NEXT}: stub (atomic claim) - ${AUTHOR} ${TOPIC}" --quiet

  if git push origin "${BRANCH_TARGET}" --quiet 2>/dev/null; then
    claimed_path="$PATH_REL"
    break
  fi

  # Push rejected (non-fast-forward). Undo our commit + file and retry.
  echo "WARN: push rejected on attempt ${attempt}/${MAX_ATTEMPTS}, retrying with jitter." >&2
  git reset --soft "HEAD~1" --quiet
  git restore --staged "$PATH_REL" 2>/dev/null || true
  rm -f "$PATH_ABS"
  sleep_jitter
done

if [ -z "$claimed_path" ]; then
  echo "ERROR: push failed after ${MAX_ATTEMPTS} attempts." >&2
  exit 3
fi

# stdout = path only (so callers can capture it cleanly).
echo "$claimed_path"
exit 0
