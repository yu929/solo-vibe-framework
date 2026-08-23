#!/usr/bin/env bash
# spec 注入的**运行时**测试：一次编辑真正到达 agent 的是什么。
#
# 与 test-spec-templates.sh 的分工：那个守模板的**静态正确性**（链接、guides 一致性、
# §N、frontmatter），零外部依赖；这个守**注入结果**，必须调用 Trellis 自己的匹配器与
# 装配器，因而依赖已安装的 Trellis。两者分文件，是为了让 Trellis 缺失时只有这一条挂，
# 不连累那五条静态检查。
#
# 守的四条断言（对每个样本路径，按**冷事件**判定——全新 context 的子 agent 就是冷的）：
#
#   ① rank-1 是预期的那份核心。
#      命中项按 glob 特异度排序，排序键是 (精确?, -字面段数, 通配符数, -字面长度)
#      （spec_match.py:373-378）。字面段数**先于**通配符数比较，所以
#      `backend/src/main/java/**`（2 通配符 / 4 字面段）**赢过**
#      `backend/src/main/java/**/*Repository.java`（3 通配符 / 4 字面段）——
#      后缀式收窄斗不过 catch-all，目录式收窄才行。指错了不报错，只是换一份 spec 拿正文。
#
#   ② rank-1 未被截断。
#      预算按**字符**算：每份 9400、每次 9500（inject-spec-context.py:132-133），
#      而 Claude Code 对 hook 输出硬顶 10000 字符。超预算的 spec 被**头部切**，
#      末尾附一句「truncated at N characters」——切掉的正是每份末尾的
#      Pre-Development Checklist 与 Quality Check，而那句提示不说少了什么。
#
#   ③ 该路径**只命中一份** spec，也就是「每个命中簇恰好一份带 paths 的核心」。
#      为什么断言命中数、而不是断言「每份都拿到正文」：两份共享一个 9500 的预算时，
#      装配器会把后面那份**截断**到塞得下为止，而不是降级——于是「都拿到正文」是真的，
#      正文却是残的。这种失效是渐进的（今天塞得下，加两段就塞不下），且两头都不报错。
#      断言命中数为 1，把一个会随内容漂移的算术问题换成一个结构约束。
#
#   ④ 预期核心 ≤ 9,000 字符，也就是 AGENTS.md 立的那条安全边际。
#      ② 只在**真截断**（9,400）时才红，而 wrapper 长度随被编辑文件的路径长度变化，
#      所以一份 9,390 的核心在浅路径上全到、在深路径上被截断——两边都不报错。
#      ④ 把这条边际本身变成机器判据；没有它，那条规则只是 AGENTS.md 里的一句话。
#
# 四条都**没有症状**：截断不报错，降级不报错，指错不报错，逼近上限更不报错。
#
# 样本表填的是**目标态**。还没做到目标态的样本列进 KNOWN_RED 基线：它们照常打印、
# 照常算进进度表，但**不计入退出码**——否则 CI 长期红，新引入的破坏和已知欠账混在
# 同一个红点里分不开。基线是双向的，样本全绿了同样失败，逼你把那一行删掉。
#
# 怎么确认这个测试本身有效（每条断言各注入一次，2026-08-23 实跑验证）：
#   ① 给 specs/java-stack/database/index.md 的 paths 加一条
#      `backend/src/main/java/**/notes/**`（6 字面段，赢过 backend 的 4 段）
#      → 两条 notes 下的样本 rank-1 变成 database。
#   ② 往 specs/java-stack/guides/task-artifacts.md 尾部塞 6000 字符
#      → 它超过每份 9400 的上限被截断。
#   ③ 给 specs/web-fullstack/guides/code-reuse.md 加一段 frontmatter
#      `paths: [supabase/migrations/**]` → 那条迁移样本命中数变 2。
#      注意这个注入下第二份拿到的是**被截断的正文**而不是索引行——这正是把断言写成
#      「只命中一份」而不是「都拿到正文」的原因，后者会放过它。
#   ④ 往任一 `<layer>/index.md` 尾部塞 200 字符 → 它越过 9,000 边际，但 ② 仍然是绿的。
#   基线：从 KNOWN_RED 里删掉任意一行 → 那条样本的失败开始计入退出码；
#         把一条已经全绿的样本加进 KNOWN_RED → 报「基线已过期」并失败。
#
#   还原用**事先备份的副本**覆盖回去，不要 git checkout —— 那会连同未提交的工作一起扔掉。
#
# 用法：scripts/test-spec-injection.sh
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Trellis 的版本钉死在这里。本仓所有关于注入行为的结论都锚在这个版本上；
# 上游改了排序算法或预算默认值，应当表现为一次**显式的、要人拍板的**版本升级，
# 而不是某天 CI 莫名其妙变红。checks.yml 里装的就是这个版本。
TRELLIS_PIN="0.7.0-beta.3"

python3 - "$root" "$TRELLIS_PIN" <<'PY'
import json, os, re, shutil, sys, tempfile, unicodedata

root, pin = sys.argv[1], sys.argv[2]

# ── 定位 Trellis，断言版本；缺失或不符一律硬失败，绝不 skip ──────────────────
# skip 会让这条检查在没装 Trellis 的机器上安静变绿，那正是它要防的失效形态。
exe = shutil.which("trellis")
if not exe:
    print(f"✗ 找不到 trellis。装它：npm i -g @mindfoldhq/trellis@{pin}")
    sys.exit(1)
pkg = os.path.dirname(os.path.dirname(os.path.realpath(exe)))
try:
    meta = json.load(open(os.path.join(pkg, "package.json"), encoding="utf-8"))
except OSError:
    print(f"✗ {exe} 解析到 {pkg}，那里没有 package.json")
    sys.exit(1)
if meta.get("name") != "@mindfoldhq/trellis":
    print(f"✗ {pkg} 是 {meta.get('name')}，不是 @mindfoldhq/trellis")
    sys.exit(1)
if meta.get("version") != pin:
    print(f"✗ Trellis 版本是 {meta.get('version')}，本仓的结论锚在 {pin}")
    print(f"    要跟随新版就改脚本里的 TRELLIS_PIN 与 checks.yml，并重跑本脚本确认排序与预算没变。")
    sys.exit(1)

common = os.path.join(pkg, "dist", "templates", "trellis", "scripts", "common")
hook = os.path.join(pkg, "dist", "templates", "shared-hooks", "inject-spec-context.py")
for p in (common, hook):
    if not os.path.exists(p):
        print(f"✗ Trellis {pin} 里找不到 {p}")
        sys.exit(1)

# 预算从 hook 源码里读，不硬编码——它们要是挪了位置，这里立刻报错，
# 而不是拿两个过时的数字安静地算出一份错的进度表。
src = open(hook, encoding="utf-8").read()


def const(name):
    m = re.search(rf'^{name}\s*=\s*(\d+)', src, re.M)
    if not m:
        print(f"✗ 在 {hook} 里找不到 {name}")
        sys.exit(1)
    return int(m.group(1))


MAX_SPEC = const("DEFAULT_MAX_SPEC_CHARS")
MAX_TOTAL = const("DEFAULT_MAX_TOTAL_CHARS")
WIN = const("DEFAULT_REFRESH_WINDOW_SECONDS")

print(f"Trellis {pin} · 每份 {MAX_SPEC} 字符 / 每次 {MAX_TOTAL} 字符")

# ── 样本表：源文件路径 → 预期拿到正文的那份核心（**目标态**）────────────────
# 路径相对 .trellis/spec/。加一条轨、改一次 paths、拆一次簇，都要回来同步这张表——
# 那正是应该被强制想一遍的时刻。
#
# 刻意不收录判定含糊的样本（例如 web 的 src/lib/x.test.ts 同时命中 backend 与
# testing，谁该赢是一个还没拍过的产品决定）——把猜测写进断言等于把它变成需求。
SAMPLES = {
    "java-stack": [
        ("backend/src/main/java/com/example/app/notes/NoteRepository.java", "backend/index.md"),
        ("backend/src/main/java/com/example/app/notes/NoteService.java", "backend/index.md"),
        ("backend/src/main/java/com/example/app/config/SecurityConfig.java", "backend/index.md"),
        ("backend/src/main/resources/db/migration/V2__notes.sql", "database/index.md"),
        ("backend/src/test/java/com/example/app/NoteIT.java", "testing/index.md"),
        ("frontend/src/components/NoteList.tsx", "frontend/index.md"),
        ("frontend/src/routes/notes.tsx", "frontend/index.md"),
        ("frontend/e2e/notes.spec.ts", "testing/index.md"),
        (".trellis/tasks/t-01/design.md", "guides/task-artifacts.md"),
        ("docs/discovery/slices.md", "guides/source-of-truth.md"),
    ],
    "web-fullstack": [
        ("src/lib/notes.ts", "backend/index.md"),
        ("src/app/notes/actions.ts", "backend/index.md"),
        ("src/components/note-card.tsx", "frontend/index.md"),
        ("supabase/migrations/001_init.sql", "database/index.md"),
        ("e2e/notes.spec.ts", "testing/index.md"),
        (".trellis/tasks/t-01/design.md", "guides/task-artifacts.md"),
        ("docs/discovery/slices.md", "guides/source-of-truth.md"),
    ],
    "universal-guides": [
        (".trellis/tasks/t-01/design.md", "guides/task-artifacts.md"),
        ("docs/discovery/slices.md", "guides/source-of-truth.md"),
    ],
}

idx = json.load(open(os.path.join(root, "index.json"), encoding="utf-8"))
templates = {t["id"]: t["path"] for t in idx.get("templates", [])}

missing = set(SAMPLES) - set(templates)
if missing:
    print(f"✗ 样本表里有 index.json 没登记的模板：{sorted(missing)}")
    sys.exit(1)
untested = set(templates) - set(SAMPLES)
if untested:
    print(f"✗ index.json 登记了但样本表没覆盖的模板：{sorted(untested)}")
    print(f"    每个模板都要有样本，否则新加的轨会安静地不被验。")
    sys.exit(1)

# AGENTS.md 的「每份 index.md 保持在 9,000 字符以内」就是断言 ④。9,400 是硬上限，
# 9,000 是安全边际：编辑的文件路径越长，wrapper 越长，能装进去的正文就越少——一份
# 刚好 9,390 的核心在浅路径上全到、在深路径上被截断，而两边都不报错。
# 改这个数要同时改 AGENTS.md。
SAFE_MAX = 9000

# 已知欠账：这些样本还没拆，红是预期的，**不计入退出码**——否则 CI 长期红，
# 新引入的破坏和欠账混在同一个红点里分不开。
# 但基线是双向的：**样本全绿了也会失败**，因为那说明这一行该删掉了。留着过期基线
# 等于给将来的回归开一个永久豁免。
KNOWN_RED = {
    ("web-fullstack", "src/lib/notes.ts"),
    ("web-fullstack", "src/app/notes/actions.ts"),
    ("web-fullstack", "src/components/note-card.tsx"),
}

LABEL = {
    1: "rank-1 是预期的核心",
    2: "rank-1 完整未截断",
    3: "只命中一份（每簇一核心）",
    4: f"核心 ≤ {SAFE_MAX} 字符（安全边际）",
}
gated = {n: 0 for n in LABEL}      # 非基线样本的失败：卡退出码
baselined = {n: 0 for n in LABEL}  # 基线内的失败：只报，不卡
stale = []                         # 基线里已经全绿的样本
rows = 0

for tid in sorted(SAMPLES):
    src_dir = os.path.join(root, templates[tid])
    tmp = tempfile.mkdtemp()
    # 模拟 Trellis 的安装：specs/<id>/ 的内容拷进 .trellis/spec/，<id>/ 那层被抹平。
    shutil.copytree(src_dir, os.path.join(tmp, ".trellis", "spec"))
    scripts_dir = os.path.join(tmp, ".trellis", "scripts")
    os.makedirs(scripts_dir)
    shutil.copytree(common, os.path.join(scripts_dir, "common"))

    sys.path.insert(0, scripts_dir)
    for mod in [m for m in sys.modules if m == "common" or m.startswith("common.")]:
        del sys.modules[mod]
    from common.spec_match import match_specs_for_file
    from common.spec_inject import assemble_payload

    print(f"\n──── {tid} ────")
    for edited, expect in SAMPLES[tid]:
        rows += 1
        known = (tid, edited) in KNOWN_RED
        want = f".trellis/spec/{expect}"
        matches = match_specs_for_file(tmp, edited)
        _payload, records = assemble_payload(
            edited, matches, False, {}, {"ts": 0, "reset": "cold"},
            MAX_SPEC, MAX_TOTAL, WIN,
        )
        full = {r["spec"]: r for r in records if r["mode"] == "full"}
        tag = "  (known-red)" if known else ""

        # ④ 量的是**预期核心**的体量，与谁排第一无关——它守的是文件大小规则本身。
        core_size = len(open(os.path.join(tmp, want), encoding="utf-8").read())
        a4 = core_size <= SAFE_MAX

        print(f"  ▸ {edited}{tag}")
        if not matches:
            print(f"      ✗ 没有任何 spec 命中，预期 {expect}")
            for n in (1, 2, 3, 4):
                (baselined if known else gated)[n] += 1
            continue

        top = matches[0].rel_path
        a1 = top == want
        rec = full.get(top)
        a2 = rec is not None and rec.get("complete", True)
        a3 = len(matches) == 1

        size = len(open(os.path.join(tmp, top), encoding="utf-8").read())
        # 交付字符数从装配出来的 payload 里量，不从记录推算——记录只说完整与否。
        m = re.search(
            rf'<spec-context file="[^"]*" spec="{re.escape(top)}" sha256="[^"]*">\n(.*?)\n</spec-context>',
            _payload, re.S)
        got = len(m.group(1)) if m else 0

        pct = f"{100 * got // size:>3}%" if size else "  -"
        ok = {1: a1, 2: a2, 3: a3, 4: a4}
        marks = " ".join(f"{s}{'✓' if ok[n] else '✗'}" for n, s in
                         ((1, "①"), (2, "②"), (3, "③"), (4, "④")))
        print(f"      rank-1 {top[len('.trellis/spec/'):]:<28} {got:>6}/{size:<6} {pct}   {marks}")

        if not a1:
            print(f"        ① 预期 {expect}，实际 {top[len('.trellis/spec/'):]}")
        if not a2:
            why = "降级成索引行" if rec is None else "被截断"
            print(f"        ② {why}，末尾的 Pre-Development Checklist 与 Quality Check 到不了")
        if not a3:
            print(f"        ③ 命中 {len(matches)} 份，共享同一个 {MAX_TOTAL} 字符预算：")
            for other in matches[1:]:
                r = full.get(other.rel_path)
                got_what = ("索引行，正文没到" if r is None
                            else "完整正文" if r.get("complete", True) else "被截断的正文")
                print(f"            {other.rel_path[len('.trellis/spec/'):]} 拿到{got_what}")
        if not a4:
            print(f"        ④ {expect} 有 {core_size} 字符，超过 {SAFE_MAX} 的安全边际"
                  f"（硬上限 {MAX_SPEC}，深路径会先撞上）")

        bad = [n for n in ok if not ok[n]]
        for n in bad:
            (baselined if known else gated)[n] += 1
        if known and not bad:
            stale.append(f"{tid} · {edited}")

    sys.path.remove(scripts_dir)
    shutil.rmtree(tmp)

def pad(s, width):
    """按显示宽度补空格：CJK 与全角标点算两列。"""
    w = sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)
    return s + " " * max(0, width - w)


print(f"\n{'─' * 60}")
for n, label in LABEL.items():
    note = f"   （另有 {baselined[n]} 条在基线内，不计入退出码）" if baselined[n] else ""
    print(f"  {'①②③④'[n - 1]} {pad(label, 34)}{rows - gated[n] - baselined[n]}/{rows}{note}")
for s in stale:
    print(f"  ✗ 基线已过期：{s} 现在全绿，把它从 KNOWN_RED 里删掉")
sys.exit(1 if (any(gated.values()) or stale) else 0)
PY
rc=$?

echo
if [[ $rc -eq 0 ]]; then
  echo "✓ 通过（基线内的已知欠账仍会打印，但不卡门禁）"
else
  echo "✗ 有基线之外的断言未通过——上面的表就是进度表"
  exit 1
fi
