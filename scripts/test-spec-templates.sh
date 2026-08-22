#!/usr/bin/env bash
# spec 模板的安装态测试：**按 Trellis 实际装出来的样子**校验，不是按源码树。
#
# 守的五条不变量（编号即用例号）：
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
#   3. 模板之间不得有跨模板相对链接（`](../../`）。
#      一个项目只装一个模板，所以跨模板引用装完必然断。
#
#   4. 每条 §N 章节引用都指得到一个真实存在的章节。
#      §N 是 spec 之间的寻址系统，而用例 1 的链接检查遇到 `#` 就截断，
#      所以 §N 一直在检查面之外——指错了不断链、不报错，只会让下一个 session 读错节。
#
#   5. spec 的 frontmatter 要么带 paths，要么整块不写。
#      Trellis 跳过没有 paths 的 spec（spec_match.py:358），只写 name + description
#      等于三行死代码——而它看起来和真能注入的那些一模一样。
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
echo "════ 用例 4 · 每条 §N 引用都指得到一个真实存在的章节 ════"
# 为什么需要这条：§N 是 spec 之间的**寻址系统**（README 指向 backend/index.md §4.5，
# ui-structure.md 指向 index.md §2.2），但用例 1 只验 `](...)` 形式的文件链接，
# 遇到 `#` 直接截断——§N 完全在它的检查面之外。指错了不断链、不报错、没有症状，
# 只会让下一个 session 读到错的一节。
#
# 三处必须先遮蔽，否则全是误报（每一条都对应语料里的真实句子）：
#   1. 代码围栏      specs/java-stack/README.md 的目录树里有 `见 database §5`
#   2. 「」引号内     specs/universal/guides/review-adjudication.md 用 §3.3 举了个假例子
#   3. "" 引号内     英文文档举例用双引号，同理
# 只扫 specs/：playbook/ 的 §N 指的是目标项目的简报，不是本仓文件。
#
# **机器不猜**：§N 之前有文件指示物、但那个文件不在模板里时（`design-system/MASTER.md`、
# `THIRD_PARTY_NOTICES.md` 指的都是目标项目的文件），退回同文件去比对是在赌。这类
# 归「待人工判读」一档：报出来，不参与 pass/fail。同理，`.md` 指示物出现在 §N **之后**
# 说明语序把它甩到了后面，解析器只看前文——也归这一档。
#
# 怎么确认这个测试本身有效（已实跑验证）：
#   把任意一条 §N 改成一个不存在的号（如 §99），本用例必须变红；改回来必须全绿。
python3 - "$root" <<'PY'
import os, re, sys

root = sys.argv[1]
specs = os.path.join(root, "specs")

FENCE = re.compile(r'^[\s>]*(```|~~~)')
SEC   = re.compile(r'§(\d+(?:\.\d+)*)')
HEAD  = re.compile(r'^#{1,6}\s+(\d+(?:\.\d+)*)\.?\s')
DESIG = re.compile(r'\]\((?!https?://)([^)\s]+\.md)\)|`([^`\n]+\.md)`')
QUOTE = [re.compile(r'「[^」\n]{0,300}」'), re.compile(r'"[^"\n]{0,300}"')]


def masked_lines(path):
    """按行遮蔽：代码围栏整块清空，行内引号替换成等长空格（保留列位）。"""
    out, in_fence = [], False
    for line in open(path, encoding="utf-8").read().split("\n"):
        if FENCE.match(line):
            in_fence = not in_fence
            out.append("")
            continue
        if in_fence:
            out.append("")
            continue
        for q in QUOTE:
            line = q.sub(lambda m: " " * len(m.group(0)), line)
        out.append(line)
    return out


_sections = {}


def sections_of(path):
    """目标文件所有 `## N.` / `### N.M` 的编号集合（用遮蔽后的文本，避开围栏里的 #）。"""
    if path not in _sections:
        nums = set()
        for line in masked_lines(path):
            m = HEAD.match(line)
            if m:
                nums.add(m.group(1))
        _sections[path] = nums
    return _sections[path]


def resolve(target, curdir):
    p = os.path.normpath(os.path.join(curdir, target))
    return p if os.path.isfile(p) else None


def classify(line, at, curdir, self_path):
    """返回 (kind, raw, path)。kind ∈ cross / self / ambiguous。"""
    prefix, suffix = line[:at], line[at:]
    cands = []
    for m in DESIG.finditer(prefix):
        link, code = m.group(1), m.group(2)
        cands.append(("link", link) if link else ("code", code))
    for kind, raw in reversed(cands):
        if kind == "link":
            return "cross", raw, resolve(raw, curdir)
        hit = resolve(raw, curdir)
        if hit:
            return "cross", raw, hit
    if cands:
        return "ambiguous", cands[-1][1], None          # 有指示物但不在模板里
    if DESIG.search(suffix):
        return "ambiguous", "（指示物在 §N 之后）", None   # 语序把指示物甩到后面了
    return "self", None, self_path


bad = external = 0
n = {"cross": 0, "self": 0}
ambiguous = []
raw_total = masked_total = 0

for dirpath, _dirs, files in os.walk(specs):
    for fn in sorted(files):
        if not fn.endswith(".md"):
            continue
        path = os.path.join(dirpath, fn)
        rel = os.path.relpath(path, root)
        raw_total += len(SEC.findall(open(path, encoding="utf-8").read()))
        for lineno, line in enumerate(masked_lines(path), 1):
            for m in SEC.finditer(line):
                masked_total += 1
                num = m.group(1)
                kind, raw, tgt = classify(line, m.start(), dirpath, path)
                if kind == "ambiguous":
                    ambiguous.append((rel, lineno, raw, num))
                    continue
                if tgt is None:
                    print(f"  ✗ {rel}:{lineno} → {raw} §{num}")
                    print(f"      引用的文件不存在")
                    bad += 1
                    continue
                if not os.path.abspath(tgt).startswith(os.path.abspath(specs) + os.sep):
                    external += 1
                    continue
                n[kind] += 1
                if num not in sections_of(tgt):
                    where = "同文件" if tgt == path else os.path.relpath(tgt, dirpath)
                    have = ", ".join("§" + s for s in sorted(sections_of(tgt), key=lambda x: [int(i) for i in x.split(".")]))
                    print(f"  ✗ {rel}:{lineno} → §{num}（{where}）")
                    print(f"      目标文件没有这一节。它有：{have or '（没有编号章节）'}")
                    bad += 1

if ambiguous:
    print(f"  ⚠ {len(ambiguous)} 条待人工判读（不计失败）—— 指示物指向模板之外的文件，机器不替你猜它该比对哪一份：")
    for rel, lineno, raw, num in ambiguous:
        print(f"      {rel}:{lineno} → {raw} §{num}")

skipped = raw_total - masked_total
print(f"  共 {raw_total} 条 §N：跨文件 {n['cross']} · 同文件 {n['self']} · "
      f"待判读 {len(ambiguous)} · 遮蔽跳过 {skipped}（代码围栏与引号内）"
      + (f" · 模板外 {external}" if external else ""))
sys.exit(1 if bad else 0)
PY
rc=$?
[[ $rc -eq 0 ]] && echo "  ✓ 全部 §N 引用可解析" || total_fail=$((total_fail+1))

echo
echo "════ 用例 5 · spec 的 frontmatter 要么带 paths，要么不要写 ════"
# Trellis 的匹配器：`if frontmatter is None or not frontmatter.paths: continue`
# （@mindfoldhq/trellis dist/templates/trellis/scripts/common/spec_match.py:358）。
# 没有 paths 的 spec 根本进不了候选集；而 description 只在**已命中**的 spec 的索引行里
# 被用到（同目录 spec_inject.py:248）。所以「只写 name + description」的 frontmatter
# 一行都不生效——它不注入、不显示，只是让这份文件**看起来**像按路径注入的。
# 这条缺陷没有任何症状，纯文字约定挡不住，所以卡在这里。
python3 - "$root" <<'PY'
import os, re, sys

root = sys.argv[1]
specs = os.path.join(root, "specs")
bad = withpaths = plain = 0

for dirpath, _dirs, files in os.walk(specs):
    for fn in sorted(files):
        if not fn.endswith(".md"):
            continue
        p = os.path.join(dirpath, fn)
        head = open(p, encoding="utf-8").read(4000)
        if not head.startswith("---\n"):
            plain += 1
            continue
        block = head.split("\n---", 1)[0]
        keys = set(re.findall(r'^([a-z_]+):', block, re.M))
        if not keys & {"paths", "name", "description"}:
            plain += 1          # 不是 frontmatter，是正文上面的分隔线
            continue
        if "paths" in keys:
            withpaths += 1
        else:
            print(f"  ✗ {os.path.relpath(p, root)}: frontmatter 只有 {sorted(keys)}，没有 paths")
            print(f"      Trellis 会跳过它（spec_match.py:358），这三行既不注入也不显示。")
            print(f"      要么补 paths，要么整块删掉——留着只会让人以为它在按路径注入。")
            bad += 1

print(f"  {withpaths} 份带 paths · {plain} 份无 frontmatter（正常）")
sys.exit(1 if bad else 0)
PY
rc=$?
[[ $rc -eq 0 ]] && echo "  ✓ 没有不生效的 frontmatter" || total_fail=$((total_fail+1))

echo
if [[ $total_fail -eq 0 ]]; then
  echo "✓ 全部用例通过"
else
  echo "✗ $total_fail 个用例失败"; exit 1
fi
