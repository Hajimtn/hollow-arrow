#!/bin/bash
# Runs every headless autotest scenario and prints a summary. Exit code 1 if anything failed.
cd /Users/manhtien/titan-souls
fail=0
for s in smoke dodge dash_iframes run_away touch stamina path_reach checkpoint_align warden warden_hits_armor knight burrower colossus hunter twins regent death menu flow attacks_all; do
  out=$(tools/at.sh $s headless 600 2>&1 | grep -E "FAIL|SCRIPT ERROR|DONE|Parse Error")
  echo "== $s: $(echo "$out" | grep DONE)"
  echo "$out" | grep -E "FAIL|SCRIPT ERROR|Parse Error"
  echo "$out" | grep -q "fails=0" || fail=1
done
exit $fail
