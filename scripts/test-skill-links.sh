#!/usr/bin/env bash
# skill 内部链接回归。守两条不变量（编号即用例号）：
#
#   1. skill 里不得出现 `](../../`。
#      skill 会被 scripts/install-skills.sh 软链进 ~/.claude/skills/，在那里
#      本仓的 specs/ 根本不可达。跨目录引用**在源码树里是通的**——你在仓库里
#      跑任何常规链接检查都是绿的——装完才变成死链，而症状不是报错，是 skill
#      退化成一个缺了核心规则的壳，模型自行补全那部分。这条曾经是一次高严重度
#      缺陷，当时只写了文字约定，没拦住。
#
#   2. skill 里每条相对链接都指得到一个真实存在的文件或目录。
#      用例 1 只挡跨目录那一种写法。重写、搬文件、改目录名的时候断掉的是
#      skill 内部的普通链接（references/a.md → references/b.md），那种同样
#      不报错：模型顺指针过去读不到，就地编一段。
#
# 扫描范围是 skills/**，**不含 vendor/**。vendor/ 是只读的第三方副本，上游的
# 链接问题我们既不该改也修不了，把它纳进来就是一条永远修不掉的红灯。
#
# 匹配前会屏蔽围栏代码块与行内代码：那里面的 `](...)` 是举例，不是活链接。
# 所以注入验证要把字符串放在**正文**里，不要放进代码块。
#
# 怎么确认这个测试本身有效（三条，已实跑验证）：
#   ① 往任一 SKILL.md 正文加一行 `](../../specs/x.md)` → 用例 1 必须红
#   ② 把某条链接改成 `](references/nope.md)`            → 用例 2 必须红
#   ③ 不改任何东西                                       → 两条都必须绿
#      （③ 是负面用例：正常链接不得被误报，否则大家会学会绕开这个检查）
#
# 用法：scripts/test-skill-links.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills="$root/skills"

[[ -d "$skills" ]] || { echo "找不到 $skills" >&2; exit 1; }

total_fail=0

python3 - "$skills" <<'PY'
import os, re, sys

skills = sys.argv[1]

FENCE = re.compile(r"^\s*```")
INLINE_CODE = re.compile(r"`[^`\n]*`")
# Markdown 行内链接的目标部分。图片 ![](...) 同样命中，这是想要的。
LINK = re.compile(r"\]\(([^)\s]+)")

def mask(text):
    """去掉围栏代码块，并把行内代码换成等长占位，保持行号可用。"""
    out, in_fence = [], False
    for line in text.split("\n"):
        if FENCE.match(line):
            in_fence = not in_fence
            out.append("")
            continue
        out.append("" if in_fence else INLINE_CODE.sub(lambda m: " " * len(m.group(0)), line))
    return out

md_files = []
for dirpath, _dirs, files in os.walk(skills):
    for fn in sorted(files):
        if fn.endswith(".md"):
            md_files.append(os.path.join(dirpath, fn))
md_files.sort()

cross_bad = []
dead_bad = []
n_links = 0

for path in md_files:
    rel = os.path.relpath(path, os.path.dirname(skills))
    lines = mask(open(path, encoding="utf-8").read())
    for lineno, line in enumerate(lines, 1):
        if "](../../" in line:
            cross_bad.append((rel, lineno, line.strip()[:90]))
        for m in LINK.finditer(line):
            target = m.group(1)
            if target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            n_links += 1
            # 去掉锚点与标题；剩下的按文件所在目录解析。
            bare = target.split("#", 1)[0]
            if not bare:
                continue
            resolved = os.path.normpath(os.path.join(os.path.dirname(path), bare))
            if not os.path.exists(resolved):
                dead_bad.append((rel, lineno, target))

print("════ 用例 1 · skill 里不得出现 `](../../` ════")
if cross_bad:
    for rel, lineno, snippet in cross_bad:
        print(f"  ✗ {rel}:{lineno}  {snippet}")
    print(f"  跨目录引用装进 ~/.claude/skills/ 之后必然断。共 {len(cross_bad)} 处。")
else:
    print(f"  ✓ {len(md_files)} 个文件，无跨目录引用")

print()
print("════ 用例 2 · 每条相对链接都要指得到东西 ════")
if dead_bad:
    for rel, lineno, target in dead_bad:
        print(f"  ✗ {rel}:{lineno}  指向不存在的 {target}")
    print(f"  共 {len(dead_bad)} 条死链。")
else:
    print(f"  ✓ {n_links} 条相对链接全部可解析")

sys.exit(1 if (cross_bad or dead_bad) else 0)
PY
total_fail=$?

echo
if [[ $total_fail -eq 0 ]]; then
  echo "✓ skill 链接回归全绿"
else
  echo "✗ skill 链接回归有失败"
fi
exit $total_fail
