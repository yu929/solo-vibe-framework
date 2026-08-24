#!/usr/bin/env bash
# install-skills.sh 的回归测试。
#
# 为什么需要它：那个脚本会往 ~/.claude/skills/ 里写，也会删东西。删除逻辑出过一个
# critical 缺陷——退役名如果是用户**自己的真目录**，正常安装会把它连同内容 rm -rf 掉。
# 纯文字约定挡不住这类缺陷复发（AGENTS.md 的实战教训），所以用测试卡住。
#
# 全程在 mktemp -d 里跑：install-skills.sh 支持 CLAUDE_SKILLS_DIR 覆盖，
# **本测试碰不到真实的 ~/.claude/skills/**。
#
# 怎么确认这个测试本身有效（已实跑验证）：把 install-skills.sh 的退役分支改回
#   if [[ -L "$link" || -e "$link" ]]; then rm -rf "$link"
# **用例 1 必须变红**（3 条断言失败，被测脚本会打出「✓ system-design 已删除」）；
# 改回来必须全绿。只跑"真实仓库全绿"什么都证明不了。
#
# 注入那个 bug 时用例 2 仍然是绿的——`rm -rf` 作用在软链上只删链接不删目标。
# 所以守住 critical 缺陷的是用例 1，用例 2 守的是另一件事（别把目标一起删了）。
#
# 用法：scripts/test-install-skills.sh
set -uo pipefail   # 故意不开 -e：每个用例要自己判断被测脚本的退出码

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="$root/scripts/install-skills.sh"

[[ -x "$target" ]] || { echo "找不到或不可执行：$target" >&2; exit 1; }

total_fail=0
case_fail=0
sandbox=""
out=""

# ── 从被测脚本里读数组，避免测试和脚本各存一份名单而漂移 ────────────────
names_of() { # <数组名> → 空格分隔的名字
  grep -E "^declare -a $1=\(" "$target" | sed -e 's/^[^(]*(//' -e 's/).*$//'
}
OWN_NAMES="$(names_of OWN)"
VENDORED_NAMES="$(names_of VENDORED)"
RETIRED_NAMES="$(names_of RETIRED)"

# ── 沙箱 ───────────────────────────────────────────────────────────
setup() {
  sandbox="$(mktemp -d)"
  export CLAUDE_SKILLS_DIR="$sandbox/skills"
  case_fail=0
  out="$sandbox/output.txt"
}
teardown() {
  [[ -n "$sandbox" ]] && rm -rf "$sandbox"
  sandbox=""
}
run() { # 跑被测脚本，输出留到 ${out}，返回它的退出码
  "$target" "$@" > "$out" 2>&1
}

# ── 断言 ───────────────────────────────────────────────────────────
ok()  { echo "    ✓ $1"; }
bad() { echo "    ✗ $1"; case_fail=$((case_fail + 1)); total_fail=$((total_fail + 1)); }

assert_exit() { # <期望> <实际> <描述>
  if [[ "$1" == "$2" ]]; then ok "$3（exit $2）"; else bad "$3：期望 exit $1，实际 exit $2"; fi
}
assert_dir() { # <路径> <描述>
  if [[ -d "$1" && ! -L "$1" ]]; then ok "$2"; else bad "$2：$1 不是真目录"; fi
}
assert_file_contains() { # <路径> <内容> <描述>
  if [[ -f "$1" ]] && grep -q "$2" "$1"; then ok "$3"; else bad "$3：$1 缺失或内容已变"; fi
}
assert_absent() { # <路径> <描述>
  if [[ ! -e "$1" && ! -L "$1" ]]; then ok "$2"; else bad "$2：$1 仍然存在"; fi
}
assert_symlink_to() { # <链接> <期望目标> <描述>
  if [[ ! -L "$1" ]]; then bad "$3：$1 不是软链"; return; fi
  local cur; cur="$(readlink "$1")"
  if [[ "$cur" == "$2" ]]; then ok "$3"; else bad "$3：指向 ${cur}，期望 $2"; fi
}
report_case() { # <用例名>
  if [[ $case_fail -ne 0 ]]; then
    echo "  ── 被测脚本输出 ──"
    sed 's/^/    | /' "$out"
  fi
}

echo "被测脚本：$target"
echo "OWN      : $OWN_NAMES"
echo "VENDORED : $VENDORED_NAMES"
echo "RETIRED  : $RETIRED_NAMES"
echo

# ── 用例 1：退役名是用户的真目录 → 必须报错退出，且一个字节都不许动 ──────
echo "用例 1 · 退役名被真目录占用（核心回归：这里曾经 rm -rf 用户数据）"
setup
mkdir -p "$CLAUDE_SKILLS_DIR/system-design"
echo "这是用户自己写的 skill" > "$CLAUDE_SKILLS_DIR/system-design/SKILL.md"
run; rc=$?
assert_exit 1 "$rc" "真目录占用退役名时必须报错退出"
assert_dir "$CLAUDE_SKILLS_DIR/system-design" "真目录必须原样保留"
assert_file_contains "$CLAUDE_SKILLS_DIR/system-design/SKILL.md" "用户自己写的" "目录内容必须原样保留"
report_case
teardown

# ── 用例 2：退役名是**我们装的**软链 → 删软链，但不碰它指向的目标 ─────────
# 两种真实形态都测：指向已知旧仓（product-brief 那批），指向本仓（lofi-prototype
# 退役前就是软链到 skills/）。指向陌生位置的情况归用例 7 管，那里必须**不删**。
echo "用例 2 · 退役名是我们装的软链"
setup
mkdir -p "$CLAUDE_SKILLS_DIR"
ln -s "$HOME/Developer/skills/product-brief" "$CLAUDE_SKILLS_DIR/product-brief"        # 已知旧仓
ln -s "$root/skills/design-review" "$CLAUDE_SKILLS_DIR/lofi-prototype"                 # 本仓（真实退役形态）
run; rc=$?
assert_exit 0 "$rc" "只有我们装的退役软链时应当正常完成"
assert_absent "$CLAUDE_SKILLS_DIR/product-brief" "指向旧仓的退役软链必须被删除"
assert_absent "$CLAUDE_SKILLS_DIR/lofi-prototype" "指向本仓的退役软链必须被删除"
assert_dir "$root/skills/design-review" "软链指向的本仓目录必须原封不动"
report_case
teardown

# ── 用例 3：干净环境 → 全部软链建对；--check 不得写任何东西 ─────────────
echo "用例 3 · 干净环境"
setup
run --check; rc=$?
assert_exit 1 "$rc" "--check 在干净环境应当报缺失"
assert_absent "$CLAUDE_SKILLS_DIR" "--check 不得创建任何目录"
run; rc=$?
assert_exit 0 "$rc" "正常安装应当 exit 0"
for s in $OWN_NAMES; do
  assert_symlink_to "$CLAUDE_SKILLS_DIR/$s" "$root/skills/$s" "本仓 $s 软链正确"
done
for s in $VENDORED_NAMES; do
  assert_symlink_to "$CLAUDE_SKILLS_DIR/$s" "$root/vendor/mattpocock-skills/$s" "vendor $s 软链正确"
done
for s in $RETIRED_NAMES; do
  assert_absent "$CLAUDE_SKILLS_DIR/$s" "退役项 $s 不得被创建"
done
run --check; rc=$?
assert_exit 0 "$rc" "装完后 --check 应当全绿"
report_case
teardown

# ── 用例 4：软链指向已知旧仓（升级场景）→ 替换，且不删旧仓 ──────────────
echo "用例 4 · 软链指向已知旧仓"
setup
legacy="$HOME/Developer/skills"           # 与脚本 LEGACY_ROOTS 一致
mkdir -p "$CLAUDE_SKILLS_DIR"
ln -s "$legacy/vertical-slicing" "$CLAUDE_SKILLS_DIR/vertical-slicing"   # 悬空也算，判据是路径前缀
run; rc=$?
assert_exit 0 "$rc" "指向已知旧仓的软链应当被静默修好"
assert_symlink_to "$CLAUDE_SKILLS_DIR/vertical-slicing" "$root/skills/vertical-slicing" "软链已改指向本仓"
report_case
teardown

# ── 用例 5：在用名被真目录占用 → 报告不动（反向用例：不得误删合法目录）──
echo "用例 5 · 在用名被真目录占用（反向用例）"
setup
mkdir -p "$CLAUDE_SKILLS_DIR/design-review"
echo "用户自己装的第三方" > "$CLAUDE_SKILLS_DIR/design-review/SKILL.md"
run; rc=$?
assert_exit 1 "$rc" "在用名被真目录占用时必须报错退出"
assert_dir "$CLAUDE_SKILLS_DIR/design-review" "真目录必须原样保留"
assert_file_contains "$CLAUDE_SKILLS_DIR/design-review/SKILL.md" "用户自己装的" "目录内容必须原样保留"
report_case
teardown

# ── 用例 6：在用名是指向陌生位置的软链 → 报错，不动它 ────────────────────
# 「design-review」这种名字很通用，用户完全可能用软链装了自己的一份。
# 静默改指向和静默删除一样糟，区别只是后者更明显。
echo "用例 6 · 在用名指向陌生位置（归属校验）"
setup
mkdir -p "$sandbox/my-own-skills/design-review" "$CLAUDE_SKILLS_DIR"
echo "我自己写的" > "$sandbox/my-own-skills/design-review/SKILL.md"
ln -s "$sandbox/my-own-skills/design-review" "$CLAUDE_SKILLS_DIR/design-review"
run; rc=$?
assert_exit 1 "$rc" "指向陌生位置时必须报错退出"
assert_symlink_to "$CLAUDE_SKILLS_DIR/design-review" "$sandbox/my-own-skills/design-review" "陌生软链必须原样保留"
assert_file_contains "$sandbox/my-own-skills/design-review/SKILL.md" "我自己写的" "目标内容必须原样保留"
report_case
teardown

# ── 用例 7：退役名是指向陌生位置的软链 → 同样报错，不删 ──────────────────
echo "用例 7 · 退役名指向陌生位置（归属校验）"
setup
mkdir -p "$sandbox/my-own-skills/system-design" "$CLAUDE_SKILLS_DIR"
echo "我自己写的" > "$sandbox/my-own-skills/system-design/SKILL.md"
ln -s "$sandbox/my-own-skills/system-design" "$CLAUDE_SKILLS_DIR/system-design"
run; rc=$?
assert_exit 1 "$rc" "退役名指向陌生位置时必须报错退出"
assert_symlink_to "$CLAUDE_SKILLS_DIR/system-design" "$sandbox/my-own-skills/system-design" "陌生软链必须原样保留"
report_case
teardown

# ── 用例 8：清单认领 —— 装过一次之后，源路径变了也认得出是自己的 ──────────
echo "用例 8 · 靠安装清单认领自己装过的链接"
setup
run > /dev/null 2>&1                                   # 第一次安装，写下清单
recorded="$(readlink "$CLAUDE_SKILLS_DIR/grilling")"
rm "$CLAUDE_SKILLS_DIR/grilling"
ln -s "$recorded" "$CLAUDE_SKILLS_DIR/grilling"        # 同一目标，模拟被重建过
[[ -f "$CLAUDE_SKILLS_DIR/.solo-vibe-installed" ]] && ok "清单文件已写出" || bad "清单文件未写出"
run; rc=$?
assert_exit 0 "$rc" "清单记过的链接应当被正常接管"
report_case
teardown

# ── 用例 9：--check 不得写清单（它的契约是不改任何东西）──────────────────
echo "用例 9 · --check 不写任何文件"
setup
mkdir -p "$CLAUDE_SKILLS_DIR"
run --check > /dev/null 2>&1
assert_absent "$CLAUDE_SKILLS_DIR/.solo-vibe-installed" "--check 不得写安装清单"
report_case
teardown

echo
if [[ $total_fail -eq 0 ]]; then
  echo "✓ 全部用例通过"
else
  echo "✗ $total_fail 条断言失败"; exit 1
fi
