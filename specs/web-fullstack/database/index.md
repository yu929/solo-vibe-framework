# 数据库规范 · Web Fullstack 轨

> SQL 只出现在 `supabase/migrations/`。轨总览与禁止清单见 [`../README.md`](../README.md)。

## 速查

| 场景 | 做法 |
|---|---|
| 改 schema | `supabase migration new <名>` → `pnpm db:reset` → `pnpm db:types` |
| 建表 | 必须三件套：grant + enable RLS + 策略 |
| 数据隔离 | RLS 策略 `(select auth.uid()) = user_id`；insert 显式带 `user_id` |
| 生成类型 | `pnpm db:types`，**勿手改** `database.types.ts` |

## 1. 数据隔离（RLS）

每用户数据**必须**开 RLS。

- 策略写 `(select auth.uid()) = user_id`
- insert 必须**显式带** `user_id`
- **不绕过 RLS**：不用 service-role client 读写用户数据

**唯一受控例外**是异构子服务的 worker，范围与不变量定义在 [`../backend/index.md`](../backend/index.md) §6.1，**只在那里定义一次**。**项目里没有 `services/` 目录时，这条例外不存在**——那时上面那句「不绕过 RLS」没有任何例外，本段可以整段跳过。要点：worker 的入参只有 job id，job 的归属在创建时由用户作用域路径 + RLS 钉死；worker 读用户表一律经显式校验归属的数据库函数，不按外部传入的主键取数。别处想用 service-role 时不要照抄「子服务可以」这个结论。

## 2. 新表三件套

每个建表迁移必须**同时**包含这三样，少一个就出问题：

```sql
-- ① 授权：Supabase 不再自动暴露新表给 Data API，缺 grant 会报 "permission denied"
grant select, insert, update, delete on table <name> to authenticated;

-- ② 打开行级安全
alter table <name> enable row level security;

-- ③ 各操作的 RLS 策略
create policy "..." on <name> for select using ((select auth.uid()) = user_id);
-- insert / update / delete 同理
```

**`anon` 默认不授权。** 骨架里全站需登录，所以它一条 anon 授权都没有——**那是骨架的形状，不是本轨的上限**。真要有公开可读的数据（落地页内容、公开榜单、分享链接），照样是 grant + RLS 策略那一套，只是策略写成 `using (true)` 或按可见性列过滤，**并且在迁移里写一行注释说明匿名到底能读到哪些行**。

不许做的是另一件事：**用「反正要公开」当借口跳过 RLS**。公开表也要 enable RLS + 显式策略——`grant` 给 anon 而不开 RLS，等于把整张表连同以后加进去的每一列都交出去了。

## 3. 迁移流程

```bash
supabase migration new <名>   # 写迁移
pnpm db:reset                 # 验证能干净重放
pnpm db:types                 # 更新生成类型
pnpm typecheck                # 确认类型仍绿
```

四步缺一不可。**改了 schema 必须连带更新 migration 和重新生成 `database.types.ts`。**

## 4. 生成文件不手改

`src/lib/supabase/database.types.ts` 由 `pnpm db:types` 生成。手改会在下次生成时被覆盖，且让类型与真实 schema 不一致。

## 5. 本地栈的项目名陷阱

新项目第一步跑 `pnpm init:project <项目名>`。它一次改掉全部模板名残留（supabase `project_id` / `package.json` name / auth cookie 名 / 镜像前缀与 LABEL / `MASTER.md` 标题）。

**`project_id` 决定本地 Supabase 容器与数据卷名。** 不改则所有模板生成的项目共享同一套本地栈——**A 项目的 `db:reset` 会静默清掉 B 项目的表**。这是实战踩过的坑。

---

## Pre-Development Checklist

- [ ] SQL 只写在 `supabase/migrations/`，没有写进应用代码？
- [ ] 建表迁移包含**三件套**（grant + enable RLS + 策略）？
- [ ] RLS 策略是 `(select auth.uid()) = user_id`？insert 显式带 `user_id`？
- [ ] 这张表要公开可读吗？**默认不授权 anon**——要公开就在迁移里显式 grant + 写策略 + 注释说明匿名能读到哪些行，**RLS 照样要开**
- [ ] 新项目跑过 `pnpm init:project <项目名>` 了吗？（不跑会共享本地栈，`db:reset` 互相清表）

## Quality Check

```bash
pnpm db:reset      # 迁移能干净重放
pnpm db:types      # 重新生成类型
pnpm typecheck     # 类型仍绿
```

额外自检：

- [ ] `database.types.ts` 是生成的，本次**没有手改**
- [ ] 用第二个账号验过 RLS 真的隔离（写了策略 ≠ 生效）
