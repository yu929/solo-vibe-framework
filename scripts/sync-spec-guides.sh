#!/usr/bin/env bash
# 把轨无关 guides 从**唯一权威源** specs/universal/guides/ 同步进每条轨的模板。
#
# 为什么必须这么做（不是洁癖，是 Trellis 的硬约束）：
#
#   Trellis v0.7.0-beta.3 的 .trellis/config.yaml 里，registry.spec 只有**单数**的
#   `template` 字段（dist/utils/registry-config.js:12-18），而 writeSpecRegistryConfig
#   命中已有的 template 行就整行替换（同文件 :121-126）。所以「先装轨规范、再 --append
#   装 guides」的两步法会把配置改成第二个模板，此后 `trellis update` 只刷新 guides，
#   **含安全规则的轨规范静默失去更新来源**——命令还是成功的，所以不会有人发现。
#
#   结论：一个项目只能装一个模板。于是轨模板必须**自带** guides。
#
# 顺带解决了第二个问题：模板安装时 specs/<id>/ 那一层会被抹平，所以
#   specs/<track>/backend/index.md  →  .trellis/spec/backend/index.md
#   specs/<track>/guides/x.md       →  .trellis/spec/guides/x.md
# guides 与轨规范成为同级目录后，`../guides/x.md` 这个相对链接**在源码树和安装树里
# 指向同一个东西**。旧写法 `../../universal/guides/x.md` 只在源码树成立，装完就断。
#
# 权威源仍然只有一份：specs/universal/guides/。轨目录里的是生成副本，别去改它——
# 改了下次同步就被覆盖，而且 --check 会先报出来。
#
# 用法：
#   scripts/sync-spec-guides.sh           # 同步（源 → 各轨副本）
#   scripts/sync-spec-guides.sh --check   # 只校验，有漂移就 exit 1（CI / 测试用）
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
specs="${SOLO_VIBE_SPECS_DIR:-$root/specs}"
src="$specs/universal/guides"

check_only=false
[[ "${1:-}" == "--check" ]] && check_only=true

[[ -d "$src" ]] || { echo "找不到权威源 $src" >&2; exit 1; }

# 轨 = specs/ 下除 universal 之外的每个目录。
# 有意做成推导而不是写死名单：加一条新轨的 starter spec 时，建个目录就自动带上
# guides，不需要记得回来改这个脚本——「要记得改」正是这类同步最常见的失效方式。
tracks() {
  local d
  for d in "$specs"/*/; do
    d="${d%/}"; d="$(basename "$d")"
    [[ "$d" == "universal" ]] && continue
    echo "$d"
  done
}

fail=0
echo "权威源：$src"
echo

for t in $(tracks); do
  dst="$specs/$t/guides"
  if $check_only; then
    if [[ ! -d "$dst" ]]; then
      echo "  ✗ ${t}：缺少 guides/ 副本 —— 轨模板必须自带 guides，否则装了它的项目拿不到轨无关规范"
      fail=1; continue
    fi
    if diff -ruN "$src" "$dst" > /dev/null 2>&1; then
      echo "  = $t/guides 与权威源一致"
    else
      echo "  ✗ $t/guides 与权威源不一致："
      diff -ruN "$src" "$dst" | sed 's/^/      /'
      echo "      改 guides 请改**权威源** ${src}，然后跑 scripts/sync-spec-guides.sh"
      fail=1
    fi
  else
    mkdir -p "$dst"
    # 先清空再拷：源里删掉的文件，副本里也必须消失。
    rm -rf "${dst:?}"
    cp -R "$src" "$dst"
    echo "  ✓ $t/guides ← 权威源（$(find "$dst" -type f | wc -l | tr -d ' ') 个文件）"
  fi
done

# 顺带校验 index.json：每条轨都要登记，否则 registry 里根本选不到它。
if [[ -f "$root/index.json" ]]; then
  for t in $(tracks); do
    if ! grep -q "\"specs/$t\"" "$root/index.json"; then
      echo "  ✗ $t 没有登记进 index.json —— registry 里选不到这个模板"
      fail=1
    fi
  done
fi

echo
if [[ $fail -eq 0 ]]; then
  echo "✓ 全部一致"
else
  echo "✗ 有不一致项，见上"; exit 1
fi
