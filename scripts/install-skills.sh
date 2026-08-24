#!/usr/bin/env bash
# 把本仓 skill 与 vendor skill 软链到 ~/.claude/skills/，幂等、路径无关。
#
# 为什么要脚本而不是手册里几行 ln -s：
#   - `ln -s` 对已存在的目标直接报 File exists，而升级场景下目标**总是**已存在
#     （指向旧仓）。手册里的裸 ln -s 会静默失败，看起来装完了，实际还在跑旧实现。
#   - 硬编码作者路径换台机器就是悬空软链。
#   - ~/.claude/skills 可能不存在。
#
# 归属原则（这个脚本最重要的一条）：
#   **只动能证明是本框架装的东西。** ~/.claude/skills/ 是用户的全局目录，里面可能有
#   他自己装的同名 skill——名字像 design-review / system-design 这么通用，撞名是常态。
#   证明方式三选一：指向本仓、指向已知旧仓、或本脚本的安装清单记过。都不满足就
#   报错退出，让用户自己决定——**静默改指向和静默删除一样糟**，区别只是后者更明显。
#
# 用法：
#   scripts/install-skills.sh           # 安装/修复
#   scripts/install-skills.sh --check   # 只检查不改
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
manifest="$dest/.solo-vibe-installed"
check_only=false
[[ "${1:-}" == "--check" ]] && check_only=true

# 本仓自有
declare -a OWN=(vertical-slicing design-review)
# vendor（第三方只读拷贝）
# 往这里加一个名字（新装或从 RETIRED 装回），**必须同时加进 sync-vendor.sh 的 SKILLS
# 数组**。漏了那一步是全仓最安静的失效：managed_in() 靠遍历 SKILLS 枚举受管文件，
# 名字不在里面 → 目录不被扫、文件不进 manifest → 漂移检查打印绿字说一切正常，
# 而这个 skill 已经软链出去、正在被 agent 触发，且每晚的上游 diff 永远不会看它一眼。
declare -a VENDORED=(grilling grill-me grill-with-docs domain-modeling prototype writing-for-agents)
# 已退役：软链若还在就删掉。留着会继续被触发，把需求接走去走废弃流程。
# lofi-prototype 退役：新流程里全量高保真在切片**之前**就定稿，task 内再出一次低保真
# 等于跟定稿构成两个结构源真。它承接的「定稿必须进 implement.jsonl」那条实跑结论
# 已改由 vertical-slicing 接住（见 references/third-party.md）。
# domain-modeling 已从退役名单**移回 VENDORED**：grill-with-docs 全文只有一句
# 「Call the Skill tool twice, for "grilling" and "domain-modeling"」，装前者必须有后者。
# ⚠ 这三个名字被 test-install-skills.sh 当**测试夹具**钉死了：用例 2 钉 product-brief
# 与 lofi-prototype（断言退役软链必须被删），用例 4 钉 vertical-slicing（断言指向旧仓的
# 软链必须改指向本仓）。改名、或把它们移出 RETIRED，要同步改那两条用例——否则报错写的是
# 「退役软链必须被删除」，看起来像安装脚本坏了。
declare -a RETIRED=(product-brief prd-generator prd-generator-noweb system-design design-system-java lofi-prototype)
# 本框架旧版本用过的仓库根。指向这些路径下的软链算「我们装的」，可以替换/删除。
# 换过旧仓路径就往这里加一条，别去放宽归属判断本身。
declare -a LEGACY_ROOTS=("$HOME/Developer/skills")

fail=0
$check_only || mkdir -p "$dest"

# ── 归属判断 ──────────────────────────────────────────────────────
# 返回 0 = 能证明是本框架装的，可以安全替换/删除（删的只是软链，目标不动）
owned_link() { # <链接路径> <链接名>
  local link="$1" name="$2" target legacy
  target="$(readlink "$link")"

  # ① 指向本仓 —— 显然是我们装的
  case "$target" in "$root"/*) return 0 ;; esac

  # ② 指向已知旧仓 —— 升级场景，本脚本存在的主要理由
  for legacy in "${LEGACY_ROOTS[@]}"; do
    case "$target" in "$legacy"/*) return 0 ;; esac
  done

  # ③ 清单记过这个 name→target —— 我们上次装的，即使路径已经变了
  [[ -f "$manifest" ]] && grep -Fxq "$name	$target" "$manifest" && return 0

  return 1
}

reject_foreign() { # <链接名> <链接路径> —— 统一措辞，两个分支共用
  echo "  ✗ $1 是软链但指向陌生位置（→ $(readlink "$2")）"
  echo "      不确定是不是你自己装的，未处理。确认后自行移走，或手动删掉这条软链再跑一次。"
  fail=1
}

# 清单：记录本次装了什么。下次运行靠它认领自己装过的链接。
declare -a INSTALLED=()
record() { INSTALLED+=("$1	$2"); }

# ── 安装一个 ──────────────────────────────────────────────────────
install_one() { # <源绝对路径> <链接名>
  local src="$1" name="$2" link="$dest/$2"

  if [[ ! -f "$src/SKILL.md" ]]; then
    echo "  ✗ ${name}：源不存在或缺 SKILL.md（${src}）"; fail=1; return
  fi

  if [[ -L "$link" ]]; then
    local cur; cur="$(readlink "$link")"
    if [[ "$cur" == "$src" ]]; then echo "  = $name 已正确"; record "$name" "$src"; return; fi
    if ! owned_link "$link" "$name"; then reject_foreign "$name" "$link"; return; fi
    $check_only && { echo "  ✗ $name 指向 ${cur}，应为 $src"; fail=1; return; }
    rm "$link"
  elif [[ -e "$link" ]]; then
    # 普通文件/目录：可能是用户自己装的第三方，不敢动。
    echo "  ✗ $name 是普通文件/目录不是软链，未处理——请自行确认后移走"; fail=1; return
  else
    $check_only && { echo "  ✗ $name 缺失"; fail=1; return; }
  fi

  ln -s "$src" "$link"
  if [[ -f "$link/SKILL.md" ]]; then
    echo "  ✓ $name → $src"; record "$name" "$src"
  else
    echo "  ✗ $name 链接建立后读不到 SKILL.md"; fail=1
  fi
}

echo "框架根目录：$root"
echo "安装到　　：$dest"
echo
echo "本仓 skill："
for s in "${OWN[@]}";      do install_one "$root/skills/$s" "$s"; done
echo "vendor skill（第三方，只读）："
for s in "${VENDORED[@]}"; do install_one "$root/vendor/mattpocock-skills/$s" "$s"; done

# 退役项：**只删软链、且只删我们自己装的那条**。
# 两层保护，缺一不可：
#   - 真文件/真目录一律不碰（删了不可恢复）
#   - 指向陌生位置的软链也不碰（那可能是用户自己装的同名 skill，删了他的入口就没了）
echo "已退役（应当不存在）："
for s in "${RETIRED[@]}"; do
  link="$dest/$s"
  if [[ -L "$link" ]]; then
    target="$(readlink "$link")"
    if ! owned_link "$link" "$s"; then reject_foreign "$s" "$link"; continue; fi
    $check_only && { echo "  ✗ $s 软链仍存在（→ ${target}）"; fail=1; continue; }
    rm "$link"; echo "  ✓ $s 软链已删除（原指向 ${target}，目标未动）"
  elif [[ -e "$link" ]]; then
    # 真文件/真目录：可能是用户自己的同名 skill。删了不可恢复，所以只报告。
    echo "  ✗ $s 是普通文件/目录不是软链，未处理——请自行确认后移走"; fail=1
  else
    echo "  = $s 不存在"
  fi
done

# 写清单。--check 不写（它的契约是不改任何东西）。
if ! $check_only; then
  {
    echo "# scripts/install-skills.sh 装过的软链，用来认领自己的东西。"
    echo "# 手改无意义：每次安装重写。删掉它只会让脚本更保守（认不出的链接一律不动）。"
    for line in ${INSTALLED[@]+"${INSTALLED[@]}"}; do echo "$line"; done
  } > "$manifest"
fi

echo
if [[ $fail -eq 0 ]]; then
  echo "✓ 全部就绪"
else
  echo "✗ 有未处理项，见上"; exit 1
fi
