#!/bin/sh
# Regression tests for the two setup scripts: local files are never silently overwritten.
#   sh tools/tests/setup-test.sh
# Offline: a throwaway git "upstream" and a fake plugin folder in a temporary directory. Needs sh, git, awk, cksum.
#   plugin/skills/lemo-opuscar/scripts/setup.sh   clone once, update only on `update`, never over local work
#   tools/directory/setup.sh                      copy a new edition only over files the last edition put there
ROOT=$(cd "$(dirname "$0")/../.." && pwd -P)
SETUP=$ROOT/plugin/skills/lemo-opuscar/scripts/setup.sh
DIRSETUP=$ROOT/tools/directory/setup.sh
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ✓ $1"; }
bad() { fail=$((fail + 1)); echo "  ✗ $1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
g() { git -c user.email=test@example.com -c user.name=test -c init.defaultBranch=main "$@"; }
# A variable set in front of a function call (VAR=x fn) is unspecified in POSIX and stays set afterwards in macOS's
# /bin/sh (bash 3.2): set it inside a subshell instead.
# the scripts' last lines report missing tools: tests read only their own markers and exit codes
run() { sh "$SETUP" "$@" > "$T/out" 2>&1; echo $? > "$T/rc"; }
rc() { cat "$T/rc"; }
head_of() { git -C "$1" rev-parse --short HEAD; }

# ---------- 1. setup.sh (clone edition) ----------
echo "setup.sh"
mkdir -p "$T/src/core/render" "$T/src/styles/demo-a/demo"
cd "$T/src" && g init -q && echo agents > AGENTS.md && echo r > core/render/r.js && echo note > MAINTAINING.md \
  && echo code > styles/demo-a/demo/code.js && echo style > styles/demo-a/STYLE.md && mkdir -p styles/demo-a/demo/片段 && echo shipped > styles/demo-a/demo/片段/說明.txt && printf 'local/\nstyles/*/demo/out/\n' > .gitignore \
  && g add -A && g commit -qm init && cd "$T" || exit 1
g clone -q --bare src up.git
push() { (cd "$T/src" && g add -A -f && g commit -qm "$1" && g push -q "$T/up.git" main); }
export LEMO_OPUSCAR_REPO="file://$T/up.git" LEMO_OPUSCAR_HOME="$T/lib"
L=$T/lib

run; check "first run clones the library" '[ "$(rc)" = 0 ] && [ -f "$L/AGENTS.md" ]'
check "the clone is marked as managed" '[ "$(git -C "$L" config lemo.managed)" = true ]'

h=$(head_of "$L"); echo two >> src/MAINTAINING.md; push u1
run; check "a plain run does not update" '[ "$(rc)" = 0 ] && [ "$(head_of "$L")" = "$h" ]'

run update; check "update fast-forwards" '[ "$(rc)" = 0 ] && [ "$(head_of "$L")" = "$(git -C up.git rev-parse --short main)" ]'

echo "MY EDIT" >> "$L/AGENTS.md"; h=$(head_of "$L"); echo three >> src/MAINTAINING.md; push u2
run update; check "update stops on a local edit, exit 1" '[ "$(rc)" = 1 ] && grep -q "local changes" "$T/out"'
check "  …the edit and HEAD are kept" '[ "$(tail -1 "$L/AGENTS.md")" = "MY EDIT" ] && [ "$(head_of "$L")" = "$h" ]'
run; check "a plain run keeps the local edit" '[ "$(tail -1 "$L/AGENTS.md")" = "MY EDIT" ]'
git -C "$L" checkout -q -- AGENTS.md

# the case behind --no-overwrite-ignore: an ignored local file that upstream starts tracking
run update; mkdir -p "$L/local"; echo "MY PRIVATE NOTES" > "$L/local/notes.txt"; h=$(head_of "$L")
mkdir -p src/local && echo "upstream version" > src/local/notes.txt && push "track local/notes.txt"
run update; check "update stops when it would overwrite an ignored local file, exit 1" '[ "$(rc)" = 1 ] && grep -q "files of its own" "$T/out"'
check "  …the ignored file and HEAD are kept" '[ "$(cat "$L/local/notes.txt")" = "MY PRIVATE NOTES" ] && [ "$(head_of "$L")" = "$h" ]'
check "  …and the file is named in the message" 'grep -q "local/notes.txt" "$T/out"'
mv "$L/local/notes.txt" "$T/notes.saved"
run update; check "  …after moving it away, update goes through" '[ "$(rc)" = 0 ] && [ "$(cat "$L/local/notes.txt")" = "upstream version" ]'

# the same with a non-ASCII name: git quotes such paths by default ("\347\254\224…")
mkdir -p "$L/local"; echo "我的筆記" > "$L/local/筆記 一.txt"; h=$(head_of "$L")
echo "upstream" > "src/local/筆記 一.txt" && push "track a Chinese file name"
run update; check "update stops on an ignored file with a non-ASCII name, exit 1" '[ "$(rc)" = 1 ] && [ "$(cat "$L/local/筆記 一.txt")" = "我的筆記" ] && [ "$(head_of "$L")" = "$h" ]'
check "  …and names it as it is on disk" 'grep -q "local/筆記 一.txt" "$T/out"'
rm "$L/local/筆記 一.txt"; run update

# an untracked (not ignored) file in the way
echo "MINE" > "$L/NEW.md"; h=$(head_of "$L"); echo theirs > src/NEW.md; push "add NEW.md"
run update; check "update stops on an untracked file in the way, exit 1" '[ "$(rc)" = 1 ] && [ "$(cat "$L/NEW.md")" = MINE ] && [ "$(head_of "$L")" = "$h" ]'
rm "$L/NEW.md"; run update

# ignored files under a demo folder survive `setup.sh demo`, which widens the sparse checkout
mkdir -p "$L/styles/demo-a/demo/out"; echo "MY RENDER" > "$L/styles/demo-a/demo/out/frame.txt"
echo "MY CODE" > "$L/styles/demo-a/demo/code.js"; mkdir -p "$L/styles/demo-a/demo/片段"; echo "我的" > "$L/styles/demo-a/demo/片段/說明.txt"
run demo demo-a; check "setup.sh demo stops when a local file sits where a demo file goes, exit 1" '[ "$(rc)" = 1 ] && grep -q "demo not added" "$T/out" && [ "$(cat "$L/styles/demo-a/demo/code.js")" = "MY CODE" ]'
check "  …including one with a non-ASCII name" '[ "$(cat "$L/styles/demo-a/demo/片段/說明.txt")" = "我的" ] && grep -q "片段/說明.txt" "$T/out"'
rm "$L/styles/demo-a/demo/code.js" "$L/styles/demo-a/demo/片段/說明.txt"
run demo demo-a; check "setup.sh demo adds the demo" '[ "$(rc)" = 0 ] && [ "$(cat "$L/styles/demo-a/demo/code.js")" = code ]'
check "  …and keeps ignored files in the demo folder" '[ "$(cat "$L/styles/demo-a/demo/out/frame.txt")" = "MY RENDER" ]'

# local commits
g -C "$L" commit -qm mine --allow-empty; h=$(head_of "$L")
run update; check "local commits on top of an unchanged main are kept, exit 0" '[ "$(rc)" = 0 ] && [ "$(head_of "$L")" = "$h" ] && grep -q "keeps its own commits" "$T/out"'
echo four >> src/MAINTAINING.md; push u4
run update; check "update stops when local commits diverge, exit 1" '[ "$(rc)" = 1 ] && [ "$(head_of "$L")" = "$h" ]'
git -C "$L" reset -q --hard HEAD~1

# origin is never rewritten
(LEMO_OPUSCAR_REPO="https://example.invalid/other.git"; run update)
check "update warns when origin differs and leaves it as it is" 'grep -q "updates from" "$T/out" && [ "$(git -C "$L" remote get-url origin)" = "file://$T/up.git" ]'

# a clone the user made is theirs: update refuses
g clone -q up.git own; (LEMO_OPUSCAR_HOME="$T/own"; run update)
check "update refuses a clone setup.sh didn't make, exit 1" '[ "$(rc)" = 1 ] && grep -q "your own clone" "$T/out"'

# ---------- 2. tools/directory/setup.sh (plugin directory edition) ----------
echo "tools/directory/setup.sh"
P=$T/plugin; S=$P/skills/lemo-opuscar
mkdir -p "$S/scripts" "$S/library/tools" "$S/library/core"
cp "$DIRSETUP" "$S/scripts/setup.sh"
printf '#!/bin/sh\necho LIB=x\n' > "$S/library/tools/setup.sh"
edition() { echo "$1" > "$S/library/.edition"; }
D=$T/dlib
drun() { LEMO_OPUSCAR_HOME="$D" sh "$S/scripts/setup.sh" > "$T/out" 2>&1; echo $? > "$T/rc"; }

echo v1 > "$S/library/core/a.txt"; echo v1 > "$S/library/AGENTS.md"; edition 1.0.0
drun; check "first copy" '[ "$(rc)" = 0 ] && [ "$(cat "$D/core/a.txt")" = v1 ] && [ -f "$D/.edition-files" ]'
mkdir -p "$D/node_modules" && echo pkg > "$D/node_modules/p"
drun; check "same edition: nothing copied" '[ "$(rc)" = 0 ] && ! grep -q "ready in" "$T/out"'

echo v2 > "$S/library/core/a.txt"; edition 2.0.0
drun; check "new edition replaces files the last edition put there" '[ "$(cat "$D/core/a.txt")" = v2 ] && [ "$(cat "$D/.edition")" = 2.0.0 ]'
check "  …packages are left alone" '[ "$(cat "$D/node_modules/p")" = pkg ]'

echo "MY EDIT" > "$D/core/a.txt"; echo v3 > "$S/library/core/a.txt"; edition 3.0.0
drun; check "new edition does not replace a file changed here" '[ "$(rc)" = 0 ] && [ "$(cat "$D/core/a.txt")" = "MY EDIT" ]'
check "  …keeps the old edition and names the file" '[ "$(cat "$D/.edition")" = 2.0.0 ] && grep -q "core/a.txt" "$T/out"'
drun; check "  …and still does on the next run" '[ "$(cat "$D/core/a.txt")" = "MY EDIT" ]'
mv "$D/core/a.txt" "$T/a.saved"; drun
check "  …after moving it away, the new edition is copied" '[ "$(cat "$D/core/a.txt")" = v3 ] && [ "$(cat "$D/.edition")" = 3.0.0 ]'

echo "MINE" > "$D/core/b.txt"; echo shipped > "$S/library/core/b.txt"; edition 4.0.0
drun; check "new edition does not replace a file added here at a path it now ships" '[ "$(cat "$D/core/b.txt")" = MINE ] && [ "$(cat "$D/.edition")" = 3.0.0 ]'
rm "$D/core/b.txt"; drun

# a folder where the new edition puts a file, and a file where it puts a folder: nothing is copied, the marker stays
mkdir -p "$D/core/c.txt"; echo keep > "$D/core/c.txt/inside"; echo shipped > "$S/library/core/c.txt"; edition 4.1.0
drun; check "new edition does not copy when a folder sits where a file goes" '[ "$(cat "$D/.edition")" = 4.0.0 ] && [ "$(cat "$D/core/c.txt/inside")" = keep ] && grep -q "core/c.txt" "$T/out"'
check "  …and no other file was replaced" '[ "$(cat "$D/core/a.txt")" = v3 ]'
rm -rf "$D/core/c.txt"; echo v4 > "$S/library/core/a.txt"; drun
check "  …after moving it away, the new edition is copied" '[ "$(cat "$D/.edition")" = 4.1.0 ] && [ "$(cat "$D/core/c.txt")" = shipped ]'
echo "MINE" > "$D/docs"; mkdir -p "$S/library/docs"; echo shipped > "$S/library/docs/d.txt"; edition 4.2.0
drun; check "new edition does not copy when a file sits where a folder goes" '[ "$(cat "$D/.edition")" = 4.1.0 ] && [ "$(cat "$D/docs")" = MINE ]'
rm "$D/docs"; drun

# A stand-in for cp that breaks the copy at one file: it writes half of that file (a truncated copy), then either
# fails (mode fail) or kills the setup script outright, as Ctrl-C, a kill or a power cut would (mode kill: no trap,
# no clean-up runs). The destination is cp's last argument.
realcp=$(command -v cp); mkdir -p "$T/badbin"
badcp() {
  printf '#!/bin/sh\nfor dst; do :; done\ncase "$dst" in *%s) printf half > "$dst"; [ %s = kill ] && kill -KILL $PPID; exit 1 ;; esac\nexec "%s" "$@"\n' \
    "$2" "$1" "$realcp" > "$T/badbin/cp"; chmod +x "$T/badbin/cp"
}
leftovers() { find "$D" -name '*.lemo-new' | wc -l | tr -d ' '; }

# a copy that fails half-way keeps the old marker and record, so the next start tries again
badcp fail 'core/a.txt.lemo-new'; echo v6 > "$S/library/core/a.txt"; edition 4.3.0; rec=$(cksum < "$D/.edition-files")
(PATH="$T/badbin:$PATH"; drun)
check "a copy that fails half-way exits 1 and keeps the old edition marker" '[ "$(rc)" = 1 ] && [ "$(cat "$D/.edition")" = 4.2.0 ] && grep -q "core/a.txt" "$T/out"'
check "  …the old record, the old file whole, and no temporary file" '[ "$(cksum < "$D/.edition-files")" = "$rec" ] && [ "$(cat "$D/core/a.txt")" = v4 ] && [ "$(leftovers)" = 0 ]'
drun; check "  …and the next start completes the copy" '[ "$(rc)" = 0 ] && [ "$(cat "$D/.edition")" = 4.3.0 ] && [ "$(cat "$D/core/a.txt")" = v6 ]'

# the copy is killed in the middle of a file: no marker or record moves, nothing is left half-written
for i in 1 2 3 4 5; do echo "k$i v2" > "$S/library/core/k$i.txt"; done; edition 4.35.0; drun
for i in 1 2 3 4 5; do echo "k$i v3" > "$S/library/core/k$i.txt"; done; echo v7 > "$S/library/core/a.txt"; edition 4.4.0
rec=$(cksum < "$D/.edition-files")
badcp kill 'core/k3.txt.lemo-new'; (PATH="$T/badbin:$PATH"; drun)
check "a copy killed mid-file leaves the old edition marker and record" '[ "$(cat "$D/.edition")" = 4.35.0 ] && [ "$(cksum < "$D/.edition-files")" = "$rec" ]'
check "  …and the file it was writing whole (old)" '[ "$(cat "$D/core/k3.txt")" = "k3 v2" ]'
drun; check "  …the next start completes it, without taking the copied files for edits" '[ "$(rc)" = 0 ] && [ "$(cat "$D/.edition")" = 4.4.0 ] && [ "$(cat "$D/core/k3.txt")" = "k3 v3" ] && [ "$(cat "$D/core/a.txt")" = v7 ] && ! grep -q "changed or added" "$T/out"'
check "  …and leaves no temporary file" '[ "$(leftovers)" = 0 ]'

# killed after every file is in place but before the record and marker: the next start finishes
echo v8 > "$S/library/core/a.txt"; edition 4.5.0
badcp kill '.edition-files.lemo-new'; (PATH="$T/badbin:$PATH"; drun)
check "a copy killed before the marker is written keeps the old marker" '[ "$(cat "$D/.edition")" = 4.4.0 ] && [ "$(cat "$D/core/a.txt")" = v8 ]'
drun; check "  …and the next start finishes it" '[ "$(rc)" = 0 ] && [ "$(cat "$D/.edition")" = 4.5.0 ] && [ "$(leftovers)" = 0 ]'

# the very first copy is killed: the next start recognises the folder as its own and finishes
D0=$D; D=$T/dlib-first
badcp kill 'core/k2.txt.lemo-new'; (PATH="$T/badbin:$PATH"; drun)
check "a first copy killed half-way leaves no edition marker" '[ ! -f "$D/.edition" ] && [ -f "$D/.lemo-library" ]'
drun; check "  …and the next start finishes it instead of refusing the folder" '[ "$(rc)" = 0 ] && [ "$(cat "$D/.edition")" = 4.5.0 ] && [ "$(cat "$D/core/k2.txt")" = "k2 v3" ]'
D=$D0

# two starts at once: one copies, the other waits for it; both end with the whole new edition and no lock left
for i in 1 2 3 4 5; do echo "k$i v4" > "$S/library/core/k$i.txt"; done; echo v9 > "$S/library/core/a.txt"; edition 4.6.0
(LEMO_OPUSCAR_HOME="$D" sh "$S/scripts/setup.sh" > "$T/out1" 2>&1; echo $? > "$T/rc1") &
(LEMO_OPUSCAR_HOME="$D" sh "$S/scripts/setup.sh" > "$T/out2" 2>&1; echo $? > "$T/rc2") &
wait
check "two starts at once both succeed" '[ "$(cat "$T/rc1")" = 0 ] && [ "$(cat "$T/rc2")" = 0 ]'
check "  …the folder has the whole new edition, once" '[ "$(cat "$D/.edition")" = 4.6.0 ] && [ "$(cat "$D/core/a.txt")" = v9 ] && [ "$(cat "$D/core/k5.txt")" = "k5 v4" ] && [ "$(cat "$T/out1" "$T/out2" | grep -c "ready in")" = 1 ]'
check "  …and no lock or temporary file is left" '[ ! -e "$D/.lemo-lock" ] && [ "$(leftovers)" = 0 ]'
# a lock left by a copy that was killed is taken over
mkdir "$D/.lemo-lock"; sh -c 'echo $$' > "$D/.lemo-lock/pid"; echo v10 > "$S/library/core/a.txt"; edition 4.7.0
drun; check "a lock whose process is gone is taken over" '[ "$(rc)" = 0 ] && [ "$(cat "$D/.edition")" = 4.7.0 ] && [ ! -e "$D/.lemo-lock" ]'

# a folder copied by the old setup.sh has no record of what it shipped: changed files are backed up before the copy
rm "$D/.edition-files"; echo "OLD EDIT" > "$D/core/a.txt"; echo v5 > "$S/library/core/a.txt"; edition 5.0.0
drun; check "without a record, changed files are backed up before the copy" '[ "$(cat "$D/core/a.txt")" = v5 ] && [ "$(cat "$D"/.lemo-backup-*/core/a.txt)" = "OLD EDIT" ]'

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
