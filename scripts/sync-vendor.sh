#!/usr/bin/env bash
# vendor/mattpocock-skills/ 的守护脚本：**先查本地漂移，再查上游变化**。
#
# 为什么是这个形态：vendor 里是别人的 MIT 代码，我们只读不改。所以「同步」的正确
# 语义是 diff + 人工决定，不是 auto-merge。自动跟随上游等于让别人的改动在你不知情
# 时改变你的工作流——那正是本仓 references/third-party.md 反对的事。
#
# 两件事，顺序不能反：
#
#   1. 本地漂移（离线，靠 .upstream-manifest 里的 sha256）
#      vendor 的核心不变量是「本地内容 == 固定 SHA 的上游内容」。**只比 SHA 是不够的**：
#      文件被误改、被误删、被塞进新文件时 .upstream-sha 一个字都不会变，只看 SHA
#      就会把漂移报成「已是最新」。清单让这个检查**不依赖网络**，因而可以回归测试
#      （见 scripts/test-sync-vendor.sh）。
#   2. 上游是否前进（要联网）
#
# 用法：
#   scripts/sync-vendor.sh            # 查漂移 + 报告上游差异，不改任何东西
#   scripts/sync-vendor.sh --verify   # 只查本地漂移，**完全离线**（CI / 测试用）
#   scripts/sync-vendor.sh --pull     # 读完 diff、确认要跟随，才更新（并重建清单）
#
# 退出码：0 正常；1 本地漂移或出错。「上游前进了」不算错误，报告完仍是 0。
set -euo pipefail

REPO="mattpocock/skills"
# 目录名 → 上游路径。加 skill 时改这里。
# domain-modeling **不是可选项**：grill-with-docs 全文只有一句「Call the Skill tool
# twice, for "grilling" and "domain-modeling"」，少了它第二次调用指向不存在的东西。
# 它带来的两个源真冲突由本仓让位解决（术语归 CONTEXT.md、决策归 docs/adr/），
# 理由见 references/third-party.md。
declare -a SKILLS=(
  "grilling:skills/productivity/grilling"
  "grill-me:skills/productivity/grill-me"
  "grill-with-docs:skills/engineering/grill-with-docs"
  "domain-modeling:skills/engineering/domain-modeling"
  "prototype:skills/engineering/prototype"
  "writing-for-agents:skills/productivity/writing-for-agents"
)
# 跟着一起管的单文件（上游路径 == 本地相对路径）
declare -a FILES=(LICENSE)

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# 覆盖点存在只为让 scripts/test-sync-vendor.sh 能在沙箱里跑，日常不要设。
vendor="${SOLO_VIBE_VENDOR_DIR:-$root/vendor/mattpocock-skills}"
sha_file="$vendor/.upstream-sha"
manifest="$vendor/.upstream-manifest"
license_file="$vendor/LICENSE"

mode=report
case "${1:-}" in
  --pull)   mode=pull ;;
  --verify) mode=verify ;;
  "")       ;;
  *) echo "未知参数：$1（可用：--verify / --pull）" >&2; exit 1 ;;
esac

# ── 受管文件 ────────────────────────────────────────────────────
# 「受管」= SKILLS 列的每个 skill 目录下的全部文件 + FILES 列的单文件。
# .upstream-sha 与 .upstream-manifest 是本仓自己的元数据，不受管。
managed_in() { # <目录> → 相对该目录的路径，每行一个
  local dir="$1" e name f
  for e in "${SKILLS[@]}"; do
    name="${e%%:*}"
    [[ -d "$dir/$name" ]] || continue
    ( cd "$dir" && find "$name" -type f -print )
  done
  for f in "${FILES[@]}"; do
    [[ -f "$dir/$f" ]] && echo "$f"
  done
  true
}

write_manifest() { # <目录> <输出文件>
  local dir="$1" out="$2" f
  managed_in "$dir" | sort | while read -r f; do
    printf '%s  %s\n' "$( cd "$dir" && shasum -a 256 "$f" | cut -d' ' -f1 )" "$f"
  done > "$out"
}

# ── 1. 本地漂移检查（离线）────────────────────────────────────────
verify_local() {
  local drift=0 want_sum rel have_sum f

  # LICENSE 不是可选项：MIT 要求「副本必须保留版权与许可声明」，vendor/ 就是一份副本。
  # 缺了它这个仓库不满足再分发条件，所以硬卡住，而不是靠人记得。
  if [[ ! -s "$license_file" ]]; then
    echo "  ✗ 缺少或为空：LICENSE —— vendor 是 MIT 代码的副本，必须保留上游许可证"
    drift=1
  fi

  if [[ ! -f "$manifest" ]]; then
    echo "  ✗ 缺少 .upstream-manifest —— 没有清单就无法证明本地内容等于固定版本"
    echo "    重建：scripts/sync-vendor.sh --pull"
    return 1
  fi

  # 1a. 清单里的每个文件：还在吗？内容对吗？
  while read -r want_sum rel; do
    [[ -n "${rel:-}" ]] || continue
    if [[ ! -f "$vendor/$rel" ]]; then
      echo "  ✗ 清单里有、本地没有：${rel}（被删了？）"; drift=1; continue
    fi
    have_sum="$( cd "$vendor" && shasum -a 256 "$rel" | cut -d' ' -f1 )"
    if [[ "$have_sum" != "$want_sum" ]]; then
      echo "  ✗ 内容与固定版本不一致：$rel"; drift=1
    fi
  done < "$manifest"

  # 1b. 本地有、清单里没有的：多出来的文件同样是漂移
  #     用 awk 精确比对第二列，不用 grep——路径里的 `.` 会被当正则。
  while read -r f; do
    [[ -n "${f:-}" ]] || continue
    awk -v want="$f" '$2==want{ok=1} END{exit !ok}' "$manifest" \
      || { echo "  ✗ 本地多出清单外的文件：$f"; drift=1; }
  done < <(managed_in "$vendor" | sort)

  if [[ $drift -eq 0 ]]; then
    echo "  ✓ 与固定版本 ${pinned:0:7} 一致（$(awk 'END{print NR}' "$manifest") 个受管文件）"
    return 0
  fi
  echo
  echo "  vendor/ 是**只读**拷贝，本地内容必须等于固定 SHA 的上游内容。"
  echo "  想恢复：scripts/sync-vendor.sh --pull（会用上游内容覆盖本地改动）"
  return 1
}

[[ -f "$sha_file" ]] || { echo "缺少 $sha_file" >&2; exit 1; }
pinned="$(tr -d '[:space:]' < "$sha_file")"

echo "vendor 固定在 : ${pinned:0:7}"
echo "本地漂移检查 :"
if verify_local; then local_ok=true; else local_ok=false; fi

if [[ "$mode" == verify ]]; then
  $local_ok || exit 1
  exit 0
fi

# 漂移状态下不做上游比对：两种差异混进同一个 diff 就读不出谁是谁。
# --pull 例外——它的职责就是把本地拉回一个确定的版本。
if ! $local_ok && [[ "$mode" != pull ]]; then
  exit 1
fi

# ── 2. 上游是否前进（联网）────────────────────────────────────────
command -v gh >/dev/null || { echo "需要 gh CLI（brew install gh）" >&2; exit 1; }
latest="$(gh api "repos/$REPO/commits/main" --jq '.sha')"
echo
echo "上游 main    : ${latest:0:7}"

if [[ "$pinned" == "$latest" ]] && $local_ok; then
  echo "✓ 已是最新，且本地无漂移"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fetch_at() { # <sha> <上游路径> <落点目录>
  local sha="$1" upath="$2" dest="$3"
  gh api "repos/$REPO/git/trees/$sha?recursive=1" \
    --jq ".tree[] | select(.path|startswith(\"$upath/\")) | select(.type==\"blob\") | .path" \
  | while read -r f; do
      local rel="${f#"$upath"/}"
      mkdir -p "$dest/$(dirname "$rel")"
      gh api "repos/$REPO/contents/$f?ref=$sha" --jq '.content' | base64 -d > "$dest/$rel"
    done
}

fetch_blob() { # <sha> <上游路径> <落点文件>
  gh api "repos/$REPO/contents/$2?ref=$1" --jq '.content' | base64 -d > "$3"
}

# 目标版本：上游动了就取 latest；上游没动（说明是纯本地漂移）就取回 pinned，
# **恢复不顺带升级**——把两件事塞进一次操作，出问题时分不清是哪一件造成的。
if [[ "$pinned" == "$latest" ]]; then
  target="$pinned"
  echo "上游未动 → 本次目标是把本地恢复到固定版本。"
else
  target="$latest"
fi

changed=0
for entry in "${SKILLS[@]}"; do
  name="${entry%%:*}"; upath="${entry#*:}"
  fetch_at "$target" "$upath" "$tmp/$name"
  if diff -ruN "$vendor/$name" "$tmp/$name" > "$tmp/$name.diff" 2>&1; then
    echo "  ✓ $name 无变化"
  else
    changed=1
    echo
    echo "  ⚠ $name 有变化："
    sed 's/^/      /' "$tmp/$name.diff"
  fi
done

for f in "${FILES[@]}"; do
  fetch_blob "$target" "$f" "$tmp/$f"
  if diff -uN "$vendor/$f" "$tmp/$f" > "$tmp/$f.diff" 2>&1; then
    echo "  ✓ $f 无变化"
  else
    changed=1
    echo
    echo "  ⚠ $f 有变化（上游改了许可条款，先读完再决定要不要继续 vendor）："
    sed 's/^/      /' "$tmp/$f.diff"
  fi
done

if [[ $changed -eq 0 ]]; then
  echo
  echo "✓ vendor 内容无变化（上游动的是别处）。更新固定 sha："
  if [[ "$mode" == pull ]]; then
    echo "$target" > "$sha_file"
    pinned="$target"
    write_manifest "$vendor" "$manifest"
    echo "  已更新为 ${target:0:7}"
  else
    echo "  跑 --pull 更新"
  fi
  exit 0
fi

echo
if [[ "$mode" == pull ]]; then
  for entry in "${SKILLS[@]}"; do
    name="${entry%%:*}"
    rm -rf "${vendor:?}/$name"
    cp -R "$tmp/$name" "$vendor/$name"
  done
  for f in "${FILES[@]}"; do cp "$tmp/$f" "$vendor/$f"; done
  echo "$target" > "$sha_file"
  pinned="$target"
  write_manifest "$vendor" "$manifest"
  echo "更新后自检："
  # 拉完再验一次：中途出错也不许留下没有许可证、或与清单对不上的 vendor 目录。
  verify_local || { echo "✗ 更新后仍不一致，别 commit" >&2; exit 1; }
  echo "✓ 已更新到 ${target:0:7}。**读一遍上面的 diff 再 commit** —— 这是别人改了你的工作流。"
else
  $local_ok || echo "注意：同时存在**本地漂移**，--pull 会用上游内容覆盖它。"
  echo "只读模式。确认要跟随就跑：scripts/sync-vendor.sh --pull"
fi
