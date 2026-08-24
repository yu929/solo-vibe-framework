# Writing a Check Here

What the five regressions have in common, the traps in adding a sixth, and the two checks that are known to be missing.

## What earns a check

All five guard defects that have **no symptom**: installing two templates does not error, a modified `vendor/` file leaves the SHA unchanged, a link that breaks on install is green in the source tree, a spec truncated to half its length arrives looking complete, and a skill whose cross-directory reference is dead reads as a skill that simply has fewer rules. Nothing will come and tell you, so a machine has to.

That is the bar. A rule whose violation shows up on its own does not need one.

Two kinds of check are worth distinguishing, because they become worth building at different times:

- **Mechanical facts** — defined inputs, defined outputs, no room for interpretation. Path resolution, checksums, character counts. Worth building the moment the rule exists.
- **Cross-file text invariants** — whether wording has drifted. Worth building only once the rule itself has stopped moving; an earlier attempt encodes a phrasing you are about to change.

The previous version of this repository shipped two invariant scripts with 28 check points aimed at a PRD skill that had since been retired. They guarded something that no longer existed. That is the failure mode this distinction exists to avoid.

## Traps, each one paid for

- **Anchor a negative check on the clause, not the line.** A Markdown paragraph is one line, so "skip this line if it contains a negation" is silently disabled by any "do not X" anywhere in the paragraph.
- **Do not build a multi-byte negated character class in `grep`** — patterns like `[^。；]`. BSD `/usr/bin/grep` works byte by byte, and a Chinese character's interior bytes overlap with `。`, so the pattern never matches. The same pattern behaves correctly under GNU grep, which presents as "it works when I run it and not from the script". Write these in `python3`.
- **Inject a matching bug for every check you add, and confirm it goes red.** A green run against the real repository proves nothing about whether the check can fail.
- **Add a negative case too: legitimate content must not be reported.** The same word can be correct in one branch and wrong in another, and an unscoped check condemns correct writing — which trains everybody to route around it.
- **Judge by paragraph, not by line**, and include the em dash among clause separators.
- **Mask quotations before matching**, so an example inside quotes is not read as an assertion.
- **Track context by section rather than a fixed number of lines back**, and when a branch declaration sits inside backticks, read the original text rather than the masked copy.
- **The keyword is not the criterion; the qualifier in front of it is.** Measured during one refactor: `grep '全量屏|全部屏'` returned 16 hits, and reading all of them showed every one was legitimate. "This slice's full set of screens" is correct; "the MVP's full set of screens" is drift — and the two share a keyword. What works is taking a window of context before the match and sorting by qualifier: slice-scoped qualifiers pass, product-scoped qualifiers fail, and no qualifier goes to a human.
- **Sentences describing history always trip the check, so leave a human-review exit.** "The old version read this as 'covers the whole MVP'" and "that shortcut has been deleted" cannot be written without the forbidden phrase. Do not add an exemption pattern — it will exempt real drift too. Report them, flagged for review, outside the pass/fail count.

## The current five

| Script | Guards | How it was proven able to fail |
|---|---|---|
| `test-install-skills.sh` | Retirement removes symlinks only, and only ones this framework installed | The `rm -rf` path would delete a user's real directory; text conventions cannot stop it |
| `test-sync-vendor.sh` | Vendored content equals the pinned upstream, offline by checksum | Comparing SHAs alone reports local drift as "already up to date" |
| `test-spec-templates.sh` | Install-tree links, guides matching source, `§N` resolution, frontmatter carrying `paths` or nothing | Restore a `](../../` link, or point a `§N` at a section that does not exist |
| `test-spec-injection.sh` | The expected core ranks first, arrives whole, and is the only spec matched | Three injections, one per assertion; the recipes are in the script's header |
| `test-skill-links.sh` | No `](../../` inside a skill, and every relative link resolves | Two injections plus a negative case; the recipes are in the script's header |

## Still to build

Both are known to be needed. Neither is built, because a rule that has never survived a real run is a rule that is still moving.

| Check | Why | Bug to inject |
|---|---|---|
| **The four sources of truth hold no copies of each other** | Requirements, terminology, decisions and interface structure each have one home. A copy diverges, and the divergence shows nothing for months | Put a glossary into the PRD template — the check must fail. Write "terminology is in `CONTEXT.md`" — the check must **not** fire |
| **The pasted planning prompt and `task-artifacts.md` still agree** | The `implement.jsonl` rule lives in two files by design: one ships with the registry, one a person pastes into their own `workflow.md`. Drift is silent — the pasted copy keeps working while the shipped one moves on | Delete the spec-index lines from the prompt block in [`../playbook/setup/04-workflow-prompts.md`](../playbook/setup/04-workflow-prompts.md) step 2; the check must fail |

**Add a check with any new cross-file rule.** A text convention has no mechanism at all for noticing drift; that is the lesson every entry above is an instance of.
