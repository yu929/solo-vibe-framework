#!/usr/bin/env bash
# sync-vendor.sh 的漂移检测回归测试。**完全离线**，不碰真实 vendor 目录。
#
# 守的不变量：vendor/ 里的内容必须等于 .upstream-sha 指定的上游版本。
# 曾经的缺陷是「pinned SHA == 上游 latest 就直接 exit 0」——文件被改、被删、
# 被塞进新文件时 .upstream-sha 一个字都不会变，于是漂移被报成「已是最新」。
#
# 之所以能离线测：漂移判据是 .upstream-manifest 里的 sha256，不是网络请求。
# 这不只是为了测试方便——网络判据在沙箱里本来就会抖（实测过 TLS 拦截导致的偶发失败），
# 靠网络的检查没法当回归测试用。
#
# 怎么确认这个测试本身有效：把 sync-vendor.sh 的 verify_local() 改成直接 `return 0`，
# 用例 2–6 必须全红。改回来必须全绿。
#
# 用法：scripts/test-sync-vendor.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="$root/scripts/sync-vendor.sh"
src_vendor="$root/vendor/mattpocock-skills"

[[ -x "$target" ]]        || { echo "找不到或不可执行：$target" >&2; exit 1; }
[[ -d "$src_vendor" ]]    || { echo "找不到 $src_vendor" >&2; exit 1; }
[[ -f "$src_vendor/.upstream-manifest" ]] || {
  echo "真实 vendor 还没有 .upstream-manifest，先跑一次 scripts/sync-vendor.sh --pull" >&2; exit 1; }

total_fail=0
case_fail=0
sandbox=""
out=""

setup() { # 每个用例一份全新的 vendor 副本
  sandbox="$(mktemp -d)"
  cp -R "$src_vendor" "$sandbox/vendor"
  export SOLO_VIBE_VENDOR_DIR="$sandbox/vendor"
  case_fail=0
  out="$sandbox/out.txt"
}
teardown() { [[ -n "$sandbox" ]] && rm -rf "$sandbox"; sandbox=""; }

# --verify 是纯离线路径，测试只用它，绝不联网
run_verify() { "$target" --verify > "$out" 2>&1; }

ok()  { echo "    ✓ $1"; }
bad() { echo "    ✗ $1"; case_fail=$((case_fail+1)); total_fail=$((total_fail+1)); }

assert_exit() { # <期望> <实际> <描述>
  if [[ "$1" == "$2" ]]; then ok "$3（exit $2）"; else bad "$3：期望 exit $1，实际 exit $2"; fi
}
assert_says() { # <关键片段> <描述>
  if grep -q -- "$1" "$out"; then ok "$2"; else bad "$2：输出里找不到「$1」"; fi
}
report_case() {
  if [[ $case_fail -ne 0 ]]; then
    echo "  ── 被测脚本输出 ──"; sed 's/^/    | /' "$out"
  fi
}

echo "被测脚本：$target"
echo "样本来源：${src_vendor}（只读，测试在副本上做）"
echo

# ── 用例 1：未改动 → 通过（反向用例：干净状态不得误报）────────────────
echo "用例 1 · 未改动的副本"
setup
run_verify; rc=$?
assert_exit 0 "$rc" "干净副本必须通过"
assert_says "一致" "应报告与固定版本一致"
report_case; teardown

# ── 用例 2：改一个文件 → 必须报出是哪个（核心回归）────────────────────
echo "用例 2 · 篡改一个 skill 文件（核心回归）"
setup
printf '\n<!-- 偷偷加一行 -->\n' >> "$SOLO_VIBE_VENDOR_DIR/grilling/SKILL.md"
run_verify; rc=$?
assert_exit 1 "$rc" "内容被改必须失败"
assert_says "grilling/SKILL.md" "必须指出是哪个文件"
report_case; teardown

# ── 用例 3：删一个文件 ────────────────────────────────────────────
echo "用例 3 · 删掉一个受管文件"
setup
rm "$SOLO_VIBE_VENDOR_DIR/grill-me/agents/openai.yaml"
run_verify; rc=$?
assert_exit 1 "$rc" "文件被删必须失败"
assert_says "grill-me/agents/openai.yaml" "必须指出是哪个文件"
report_case; teardown

# ── 用例 4：塞进一个清单外的新文件 ────────────────────────────────
echo "用例 4 · 塞进清单外的新文件"
setup
echo "本地私自加的" > "$SOLO_VIBE_VENDOR_DIR/grilling/EXTRA.md"
run_verify; rc=$?
assert_exit 1 "$rc" "多出文件必须失败"
assert_says "清单外" "必须说明是清单外的文件"
report_case; teardown

# ── 用例 5：LICENSE 缺失 → MIT 再分发条件 ─────────────────────────
echo "用例 5 · LICENSE 缺失"
setup
rm "$SOLO_VIBE_VENDOR_DIR/LICENSE"
run_verify; rc=$?
assert_exit 1 "$rc" "缺 LICENSE 必须失败"
assert_says "LICENSE" "必须点名 LICENSE"
report_case; teardown

# ── 用例 6：清单本身被删 → 不能当作「没问题」────────────────────────
echo "用例 6 · 清单本身缺失"
setup
rm "$SOLO_VIBE_VENDOR_DIR/.upstream-manifest"
run_verify; rc=$?
assert_exit 1 "$rc" "没有清单必须失败，而不是默认通过"
report_case; teardown

echo
if [[ $total_fail -eq 0 ]]; then
  echo "✓ 全部用例通过"
else
  echo "✗ $total_fail 条断言失败"; exit 1
fi
