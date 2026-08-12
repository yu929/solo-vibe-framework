#!/usr/bin/env bash
# spec 模板的安装态测试：**按 Trellis 实际装出来的样子**校验，不是按源码树。
#
# 守的两条不变量：
#
#   1. 每个模板装完之后，内部 Markdown 相对链接都还指得到东西。
#      为什么不能只查源码树：registry 安装时 specs/<id>/ 那一层会被**抹平**
#      （specs/web-fullstack/backend/index.md → .trellis/spec/backend/index.md）。
#      所以 `../../universal/guides/x.md` 在源码树里是通的、装完就断——这条缺陷
#      正是这么漏过去的：仓库里跑任何常规链接检查都是绿的。
#
#   2. 每条轨的模板都**自带** guides，且与权威源一致。
#      理由见 scripts/sync-spec-guides.sh 头部：Trellis 只持久化一个 spec 模板，
#      一个项目只能装一个，所以轨模板不自带 guides 就等于装不上。
#
# 怎么确认这个测试本身有效（已实跑验证）：
#   把 specs/web-fullstack/backend/index.md 里的 `../guides/cross-layer.md`
#   改回 `../../universal/guides/cross-layer.md`，用例 1 必须变红；改回来必须全绿。
#
# 用法：scripts/test-spec-templates.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
index="$root/index.json"

[[ -f "$index" ]] || { echo "找不到 $index" >&2; exit 1; }

total_fail=0

echo "════ 用例 1 · 按安装树校验每个模板的相对链接 ════"
python3 - "$root" <<'PY'
import json, os, re, sys, shutil, tempfile

root = sys.argv[1]
idx = json.load(open(os.path.join(root, "index.json"), encoding="utf-8"))
bad = 0
checked = 0

for tpl in idx.get("templates", []):
    tid, tpath = tpl["id"], tpl["path"]
    src = os.path.join(root, tpath)
    if not os.path.isdir(src):
        print(f"  ✗ {tid}: path 指向的目录不存在：{tpath}")
        bad += 1
        continue

    # 模拟 Trellis 的安装：specs/<id>/ 的**内容**拷进 .trellis/spec/，<id>/ 那层被抹平。
    tmp = tempfile.mkdtemp()
    dest = os.path.join(tmp, ".trellis", "spec")
    shutil.copytree(src, dest)

    n_files = n_links = 0
    for dirpath, _dirs, files in os.walk(dest):
        for fn in files:
            if not fn.endswith(".md"):
                continue
            n_files += 1
            p = os.path.join(dirpath, fn)
            txt = open(p, encoding="utf-8").read()
            for m in re.finditer(r'\]\((?!https?://|#|mailto:)([^)\s]+)\)', txt):
                link = m.group(1).split("#")[0]
                if not link or "<" in link or "{" in link:
                    continue
                n_links += 1
                checked += 1
                tgt = os.path.normpath(os.path.join(dirpath, link))
                rel_src = os.path.relpath(p, dest)
                if not os.path.exists(tgt):
                    want = os.path.relpath(tgt, tmp)
                    print(f"  ✗ {tid}: .trellis/spec/{rel_src} → {link}")
                    print(f"      装完后解析到 {want}，那里没有东西")
                    bad += 1
                # 链接不许爬出 .trellis/spec/ —— 爬出去就意味着依赖安装树之外的东西
                elif not os.path.abspath(tgt).startswith(os.path.abspath(dest) + os.sep):
                    print(f"  ✗ {tid}: .trellis/spec/{rel_src} → {link} 指到了 .trellis/spec/ 之外")
                    bad += 1
    print(f"  {'✓' if bad == 0 else ' '} {tid}: {n_files} 个 md / {n_links} 条相对链接")
    shutil.rmtree(tmp)

print(f"  共检查 {checked} 条链接")
sys.exit(1 if bad else 0)
PY
rc=$?
[[ $rc -eq 0 ]] && echo "  ✓ 安装树内全部链接可解析" || total_fail=$((total_fail+1))

echo
echo "════ 用例 2 · 每条轨自带 guides 且与权威源一致 ════"
if "$root/scripts/sync-spec-guides.sh" --check > /tmp/spec-guides-check.txt 2>&1; then
  echo "  ✓ guides 副本与权威源一致，且每条轨都已登记进 index.json"
else
  sed 's/^/  /' /tmp/spec-guides-check.txt
  total_fail=$((total_fail+1))
fi

echo
echo "════ 用例 3 · 模板之间不得有跨模板相对链接 ════"
# 一个项目只能装一个模板（Trellis 只持久化一个 registry.spec.template），
# 所以跨模板引用装完必然断。这条抓的是「写的时候按源码树想问题」这个复发形态。
if grep -rn '](\.\./\.\./' --include='*.md' "$root/specs" > /tmp/spec-crosslink.txt 2>&1; then
  echo "  ✗ 发现跨模板相对链接（装完会断）："
  sed 's/^/    /' /tmp/spec-crosslink.txt
  total_fail=$((total_fail+1))
else
  echo "  ✓ 无 ](../../ 形式的跨模板链接"
fi

echo
if [[ $total_fail -eq 0 ]]; then
  echo "✓ 全部用例通过"
else
  echo "✗ $total_fail 个用例失败"; exit 1
fi
