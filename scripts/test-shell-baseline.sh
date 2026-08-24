#!/usr/bin/env bash
# shell 的 **bash 3.2 基线**测试：AGENTS.md 立了这条规矩，这里把它变成机器判据。
#
# 为什么需要它：macOS 自带的 /bin/bash 就是 3.2.57，而 `#!/usr/bin/env bash` 在没装
# homebrew bash 的机器上正好解析到它。CI 跑的 ubuntu 是 bash 5，两边行为不同的地方
# **CI 永远绿**，只有本机会炸——而本机正是这些脚本唯一的运行场所。
# 只扫 `*.sh`：workflow 里的 run 块跑在 ubuntu 的 bash 5 上，这条基线管不着它们。
#
# 守两条：
#
#   ① 不出现「未加花括号的变量展开紧跟多字节字符」。
#      bash 3.2 判定标识符字符用的是逐**字节**的 isalnum()，在 UTF-8 locale 下
#      0x80–0xFF 段的字节被判为字母数字，于是变量名会把后面那个标点的首字节吃进去。
#      实测证据（2026-08-24）：
#        $ LC_ALL=en_US.UTF-8 /bin/bash -c 'set -u; v=V; echo "${v}<全角逗号>"'   # 正常
#        $ LC_ALL=en_US.UTF-8 /bin/bash -c 'set -u; v=V; echo "$v<全角逗号>"'
#        /bin/bash: v<EF>: unbound variable
#      带 `set -u` 时整脚本当场死；不带时**值被静默吞掉**，只剩半个乱码标点。
#      LC_ALL=C 下一切正常，所以「我这儿能跑」不构成反证——它只说明你的 locale 是 C。
#      本仓五个脚本全带 set -u，所以症状是硬失败：修之前 test-sync-vendor.sh 的开场
#      横幅就在这条上，任何 UTF-8 locale 下它第一屏就死。写法上一律用 `${var}`，代价为零。
#
#   ② 不出现 bash 4+ 才有的内建与展开：readarray / mapfile / 关联数组 / 大小写展开。  bash32-allow
#      它们在 3.2 上是语法错或未定义命令，表现各不相同，但都不是「稍微差一点」。
#
# 自赦标记：本脚本自己的模式表和上面的反例，写的就是要抓的形态，扫自己必然命中。
# 带 `bash32-allow` 的行跳过；同时**校验这个标记只出现在本文件里**，免得它变成
# 一个谁都能用来消音的开关。除这些行之外，本脚本和其他脚本一样被完整扫描。
#
# 怎么确认这个测试本身有效（2026-08-24 实跑验证）：
#   ① 把 scripts/test-sync-vendor.sh 第 60 行的 `${src_vendor}` 改回不带花括号
#      → 用例 1 变红并指名该行；同时那个脚本在 UTF-8 locale 下开场即死。
#   ② 往任一脚本插一行关联数组声明 → 用例 2 变红。
#   ③ 把 `bash32-allow` 抄进另一个脚本 → 用例 3 变红。
#   三次都用事先备份的副本还原，不要 git checkout。
#
# 为什么不用 `bash -n`：这两类问题**语法都是合法的**。`bash -n` 对前者一声不吭，
# 对后者在 3.2 上也只报运行期错误。所以只能按词法扫。
#
# 用法：scripts/test-shell-baseline.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$root" <<'PY'
import os, re, sys

root = sys.argv[1]
SELF = "scripts/test-shell-baseline.sh"
ALLOW = b"bash32-" + b"allow"          # 拆开写，否则这一行自己就是一处标记

UNBRACED = re.compile(rb'\$([A-Za-z_][A-Za-z0-9_]*)(?=[\xc2-\xf4][\x80-\xbf])')

BASH4 = [                                                        # bash32-allow
    (re.compile(rb'(?<![\w-])readarray\b'), "readarray"),        # bash32-allow
    (re.compile(rb'(?<![\w-])mapfile\b'), "mapfile"),            # bash32-allow
    (re.compile(rb'(?<![\w-])(?:declare|local|typeset)\s+-[a-zA-Z]*A(?![a-zA-Z])'),
     "关联数组声明"),                                             # bash32-allow
    (re.compile(rb'\$\{[A-Za-z_][A-Za-z0-9_]*\^\^?\}'), "大写展开 ${x^^}"),   # bash32-allow
    (re.compile(rb'\$\{[A-Za-z_][A-Za-z0-9_]*,,?\}'), "小写展开 ${x,,}"),     # bash32-allow
]

targets = []
for dirpath, dirs, files in os.walk(root):
    dirs[:] = [d for d in dirs if d != ".git"]
    for fn in sorted(files):
        if fn.endswith(".sh"):
            targets.append(os.path.join(dirpath, fn))

def lines_of(p):
    for i, line in enumerate(open(p, "rb").read().split(b"\n"), 1):
        if ALLOW in line:
            continue
        yield i, line

bad1 = bad2 = bad3 = 0
n_lines = 0

print("════ 用例 1 · 未加花括号的展开不得紧跟多字节字符 ════")
for p in targets:
    rel = os.path.relpath(p, root)
    for i, line in lines_of(p):
        n_lines += 1
        for m in UNBRACED.finditer(line):
            name = m.group(1).decode()
            print(f"  ✗ {rel}:{i} → ${name} 后面直接跟了多字节字符")
            print(f"      bash 3.2 在 UTF-8 locale 下会把变量名读成 {name} 加那个字符的首字节，")
            print(f"      带 set -u 时当场 unbound variable。改成 ${{{name}}}。")
            bad1 += 1
print(f"  {'✓' if not bad1 else ' '} 扫了 {len(targets)} 个脚本 / {n_lines} 行（已跳过自赦行）")

print()
print("════ 用例 2 · 不得使用 bash 4+ 专有构造 ════")
for p in targets:
    rel = os.path.relpath(p, root)
    for i, line in lines_of(p):
        for pat, what in BASH4:
            if pat.search(line):
                print(f"  ✗ {rel}:{i} 用了 {what}（bash 4+，3.2 上没有）")
                bad2 += 1
print(f"  {'✓' if not bad2 else ' '} {len(targets)} 个脚本")

print()
print("════ 用例 3 · 自赦标记只许出现在本脚本里 ════")
for p in targets:
    rel = os.path.relpath(p, root)
    if rel == SELF:
        continue
    if ALLOW in open(p, "rb").read():
        print(f"  ✗ {rel} 用了自赦标记。它只为本脚本的模式表而存在，")
        print(f"      不是给别处消音用的开关——那一行要么改对，要么说明为什么不能改。")
        bad3 += 1
print(f"  {'✓' if not bad3 else ' '} 标记未外泄")

print()
if bad1 or bad2 or bad3:
    print(f"✗ bash 3.2 基线未通过：用例 1 有 {bad1} 处，用例 2 有 {bad2} 处，用例 3 有 {bad3} 处")
    sys.exit(1)
print("✓ bash 3.2 基线全绿")
PY
