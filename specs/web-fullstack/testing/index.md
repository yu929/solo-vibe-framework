# 质量门与验证 · Web Fullstack 轨

> 说「做完了」之前必须全绿。轨总览见 [`../README.md`](../README.md)。

## 命令门（每次都要）

```bash
pnpm typecheck   # tsc --noEmit
pnpm lint        # eslint
pnpm test        # vitest run（单元/逻辑）
pnpm build       # next build（再次类型检查 + 产物）
```

## 按改动类型追加

| 动过什么 | 追加 |
|---|---|
| 样式 / 格式 | `pnpm format`（Prettier，含 Tailwind 排序） |
| 页面 / 流程 | `pnpm test:e2e`（Playwright，需先 `pnpm db:start`） |
| DB schema | `supabase migration new` → `pnpm db:reset` → `pnpm db:types` |

**`pnpm format` 的收尾自检**：文档（`*.md`）、`.venv`、`design-system/`、生成文件已在 `.prettierignore` 排除。跑完用 `git status` 看一眼——**如果出现本次任务没编辑过的文件**，先确认原因，必要时回退或拆成单独的格式化变更。

**跑过 `pnpm build` 后再起 `pnpm dev`**：先删 `.next`。production 构建产物与 dev 缓存混用会报错。

## 测试分工

- **Vitest**：单元与逻辑，`*.test.ts`，与被测代码同目录
- **Playwright**：E2E，`e2e/*.spec.ts`，**含 RLS 隔离验证**

## 怎么验证（功能 + 数据）

1. `pnpm dev` → `localhost:3000`：注册 → 登录 → 对某业务模块走通新增/编辑/删除 → 登出
2. **数据隔离**：换第二个账号，确认看不到、也改不动第一个账号的数据（RLS 生效）
3. **异构子服务的越权（有子服务时才需要）**：用 A 账号建一个 job，然后拿**这个 job** 去够 B 账号的资源主键，**必须被拒**。见 [`../backend/index.md`](../backend/index.md) §6.1
4. 命令门全绿；`supabase db reset` 能干净重放迁移
5. 改了 schema：确认 migration + `database.types.ts` 都更新了，且 typecheck 仍绿

第 2、3 条是本轨最容易被跳过、也最贵的两条。**写了不等于生效**——RLS 要用第二个账号真的试，归属校验要用另一个租户的主键真的够一次。

这两条都是**负向测试**：证明「该拒的拒了」，而正向用例全绿并不能证明这一点。所以它们必须单独存在，不能靠「功能跑通了」顺带覆盖。

## 本地后端

```bash
pnpm db:start        # 需先开 Docker / OrbStack
supabase status      # 查状态与密钥
```

## 容器化与发版

```bash
docker compose up -d --build                          # 个人 / 云端
docker compose -f docker-compose.yml \
  -f docker-compose.selfhost.yml up -d --build        # 内网自托管
```

发版走 `vX.Y.Z` / `vX.Y.Z-rc.N` tag：

1. 先改 `package.json` version（含 `services/*/pyproject.toml`，如有）
2. `pnpm release:validate <tag>`
3. tag push 触发 `.github/workflows/release.yml` 的发布质量门

镜像 env 约定见 `.env.example`：`NEXT_DEPLOYMENT_ID` 每发必变，`NEXT_SERVER_ACTIONS_ENCRYPTION_KEY` 跨 rebuild 必须稳定。

---

## Pre-Development Checklist

- [ ] 这次改动要补哪一类测试？逻辑 → Vitest；页面/流程 → Playwright
- [ ] 改的是 bug 吗？**先写一个会失败的测试**，再修
- [ ] 涉及多用户数据吗？E2E 要覆盖 RLS 隔离
- [ ] 动了异构子服务吗？要补**双租户越权负向测试**（A 的 job 够不到 B 的资源）

## Quality Check

见本页「命令门」。说「做完了」之前四条必须全绿，按改动类型追加对应的那条。
