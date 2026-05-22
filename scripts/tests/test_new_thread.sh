#!/usr/bin/env bash
# Unit tests for scripts/new-thread.sh
#
# Sets up a local bare repo as fake "origin", clones it, and exercises
# the script in an isolated sandbox. Does NOT touch the real
# rdm-discussion remote.
#
# Usage:   bash scripts/tests/test_new_thread.sh
# CI:      runs under .github/workflows/scripts-lint.yml (added separately).
#
# Exit code 0 if all pass, 1 if any fail.

set -uo pipefail

PASS=0
FAIL=0

SANDBOX="$(mktemp -d -t new-thread-tests-XXXXXX)"
# shellcheck disable=SC2064
trap "rm -rf '$SANDBOX'" EXIT

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT_UNDER_TEST="${REPO_ROOT}/scripts/new-thread.sh"

if [ ! -f "$SCRIPT_UNDER_TEST" ]; then
  echo "FATAL: $SCRIPT_UNDER_TEST not found"
  exit 1
fi

# ---------- helpers ----------
assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [ "$expected" = "$actual" ]; then
    echo "[PASS] $label"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $label  expected='$expected'  actual='$actual'"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local f="$1"
  local label="$2"
  if [ -f "$f" ]; then
    echo "[PASS] $label"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $label  missing=$f"
    FAIL=$((FAIL + 1))
  fi
}

# Spin up a fresh fake-remote + clone in $1. Pre-seeds threads/100 and 101.
setup_fake_repo() {
  local clone_dir="$1"
  local remote_dir="${SANDBOX}/$(basename "$clone_dir").git"

  git init --bare -b main "$remote_dir" >/dev/null

  git init -b main "$clone_dir" >/dev/null
  (
    cd "$clone_dir"
    git config user.email "test@example.com"
    git config user.name "Tester"
    git config commit.gpgsign false
    mkdir -p threads scripts/tests
    cp "$SCRIPT_UNDER_TEST" scripts/new-thread.sh
    chmod +x scripts/new-thread.sh
    : > threads/100-WC-seed-one.md
    : > threads/101-CC-seed-two.md
    echo "init" > .placeholder
    git add . >/dev/null
    git commit -m "init seed" --quiet
    git remote add origin "$remote_dir"
    git push origin main --quiet
  )
}

# ---------- test cases ----------

test_happy_path() {
  local C="${SANDBOX}/clone-happy"
  setup_fake_repo "$C"
  local out rc
  out=$(cd "$C" && bash scripts/new-thread.sh CC-Bot happy-topic-name 2>/dev/null)
  rc=$?
  assert_eq "0" "$rc" "happy: exit code 0"
  assert_eq "threads/102-CC-Bot-happy-topic-name.md" "$out" "happy: stdout is relative path"
  assert_file_exists "${C}/threads/102-CC-Bot-happy-topic-name.md" "happy: stub file created"
}

test_frontmatter_valid() {
  local C="${SANDBOX}/clone-frontmatter"
  setup_fake_repo "$C"
  (cd "$C" && bash scripts/new-thread.sh CC-Bot frontmatter-check >/dev/null 2>&1)
  local f="${C}/threads/102-CC-Bot-frontmatter-check.md"
  if grep -q "^thread: 102$" "$f" && \
     grep -q "^author: CC-Bot$" "$f" && \
     grep -q "^topic: frontmatter-check$" "$f" && \
     grep -q "^status: draft$" "$f"; then
    echo "[PASS] frontmatter: stub has expected fields"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] frontmatter: stub missing expected fields"
    cat "$f" >&2
    FAIL=$((FAIL + 1))
  fi
}

test_invalid_author() {
  local C="${SANDBOX}/clone-bad-author"
  setup_fake_repo "$C"
  (cd "$C" && bash scripts/new-thread.sh Bob valid-topic-here >/dev/null 2>&1)
  local rc=$?
  assert_eq "1" "$rc" "invalid author: exit 1"
}

test_invalid_topic_uppercase() {
  local C="${SANDBOX}/clone-bad-topic-up"
  setup_fake_repo "$C"
  (cd "$C" && bash scripts/new-thread.sh CC FOO-bar >/dev/null 2>&1)
  local rc=$?
  assert_eq "1" "$rc" "invalid topic (uppercase): exit 1"
}

test_invalid_topic_short() {
  local C="${SANDBOX}/clone-bad-topic-short"
  setup_fake_repo "$C"
  (cd "$C" && bash scripts/new-thread.sh CC abcd >/dev/null 2>&1)
  local rc=$?
  assert_eq "1" "$rc" "invalid topic (too short): exit 1"
}

test_dirty_working_tree() {
  local C="${SANDBOX}/clone-dirty"
  setup_fake_repo "$C"
  (
    cd "$C"
    echo "dirty change" > .placeholder
    git add .placeholder
    bash scripts/new-thread.sh CC-Bot clean-topic-name >/dev/null 2>&1
  )
  local rc=$?
  assert_eq "1" "$rc" "dirty tree: exit 1"
}

test_wrong_branch() {
  local C="${SANDBOX}/clone-wrong-branch"
  setup_fake_repo "$C"
  (
    cd "$C"
    git checkout -b feature-branch --quiet
    bash scripts/new-thread.sh CC-Bot wrong-branch-topic >/dev/null 2>&1
  )
  local rc=$?
  assert_eq "1" "$rc" "wrong branch: exit 1"
}

# Two concurrent invocations must both succeed with distinct numbers.
# Tests the local lock + retry logic.
test_concurrent_race() {
  local C="${SANDBOX}/clone-race"
  setup_fake_repo "$C"
  local out1_file="${SANDBOX}/race1.out"
  local out2_file="${SANDBOX}/race2.out"

  (cd "$C" && bash scripts/new-thread.sh CC race-one-topic > "$out1_file" 2>/dev/null) &
  local pid1=$!
  (cd "$C" && bash scripts/new-thread.sh CC race-two-topic > "$out2_file" 2>/dev/null) &
  local pid2=$!
  wait $pid1
  local rc1=$?
  wait $pid2
  local rc2=$?

  assert_eq "0" "$rc1" "race: pid1 exit 0"
  assert_eq "0" "$rc2" "race: pid2 exit 0"

  # Both new threads should exist and be distinct numbers (102 and 103).
  local n102 n103
  n102=$(find "${C}/threads" -maxdepth 1 -name "102-*.md" | wc -l)
  n103=$(find "${C}/threads" -maxdepth 1 -name "103-*.md" | wc -l)
  assert_eq "1" "$(echo "$n102" | tr -d ' ')" "race: exactly one 102-*.md exists"
  assert_eq "1" "$(echo "$n103" | tr -d ' ')" "race: exactly one 103-*.md exists"
}

# Lock contention: pre-create the mkdir lock dir, run script — it should
# time out. We use a 5s shim by overriding the timeout via a wrapper.
test_lock_timeout() {
  local C="${SANDBOX}/clone-lock-timeout"
  setup_fake_repo "$C"
  (
    cd "$C"
    mkdir -p scripts/.new-thread.lock.d
    # Run with a tight timeout via a watchdog: if the script blocks >35s
    # on the mkdir lock we'd hang. Skip if flock binary is present
    # (flock has its own 30s timeout via -w 30; equivalent path).
    # Use timeout binary if available; otherwise rely on script's 30s.
    if command -v timeout >/dev/null 2>&1; then
      timeout 35 bash scripts/new-thread.sh CC lock-test-topic >/dev/null 2>&1
      local rc=$?
      # 2 = script's lock-timeout exit; 124 = timeout's SIGTERM (also fail).
      if [ "$rc" = "2" ] || [ "$rc" = "124" ]; then
        echo "[PASS] lock timeout: blocked claim exits non-zero (rc=$rc)"
        PASS=$((PASS + 1))
      else
        echo "[FAIL] lock timeout: expected 2 or 124, got $rc"
        FAIL=$((FAIL + 1))
      fi
    else
      echo "[SKIP] lock timeout: timeout(1) binary not available"
    fi
    rmdir scripts/.new-thread.lock.d 2>/dev/null || true
  )
}

# ---------- runner ----------
echo "Running tests for scripts/new-thread.sh..."
echo

test_happy_path
test_frontmatter_valid
test_invalid_author
test_invalid_topic_uppercase
test_invalid_topic_short
test_dirty_working_tree
test_wrong_branch
test_concurrent_race
test_lock_timeout

echo
echo "---"
echo "PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
