---
name: forge-luau-style
description: Use when writing, editing, reviewing, or refactoring any .luau file in the forge-vfx package, including adding a module, changing an effect, or judging whether existing code matches house style.
---

# forge-vfx Luau Style

## Overview

House Luau style for `pkg/forge-vfx`. It is derived from the code, not from prose: every rule below was measured across the package, and the counts are quoted so you can re-verify.

**Core principle: the code is the spec, but not every file is evidence.** Three files in this package have drifted from house style, and they are the newest ones. Recency is not authority.

## Do not imitate these files

**Known-drifted. Never cite them as precedent:**

- `src/schema.luau`
- `src/mod/common/path.luau`
- `src/mod/modifiers.luau`

**Not house style at all. Vendored MIT code by Daniel P H Fox:**

- `src/mod/color/Oklab.luau`
- `src/mod/color/sRGB.luau`

These five are the only files in `src/` with `--!strict`. That is a symptom, not a convention.

**`pkg/` is third-party in its entirety** (`Z`, `tiniest`, `Promise.luau`, `Shake.luau`). Read it to understand an API you are calling; never cite it as precedent, never reformat it, and keep stylua off it.

**Read these instead.** They are canonical: `src/mod/recolor.luau`, `src/effects/shockwave_ring.luau`, `src/effects/spin.luau`, `src/obj/ObjectCache.luau`, `src/types.luau`, `src/mod/tween.luau`.

## Module skeleton

Every module has these parts, in this order. Omit a part you don't need; never reorder.

```luau
local CollectionService = game:GetService("CollectionService")

local attr = require("@mod/attributes")
local tween = require("@mod/tween")
local types = require("@root/types")
local utility = require("@mod/utility")

local Promise = require("@pkg/Promise")
local ObjectCache = require("@obj/ObjectCache")

local RECYCLE_INTERVAL = 5

local shockwave = {}

local part_cache: ObjectCache.ObjectCache? = nil

function shockwave.emit(ref: Instance, scope: types.scope)
  if not part_cache then
    return
  end

  local scaleStart = attr.get(ref, "Scale_Start", 1)
  local scaleEnd = attr.get(ref, "Scale_End", 1)

  return scaleStart + scaleEnd
end

return shockwave
```

No mode comment. No header comment. Module state sits immediately after the module table, never mid-file.

The module table is named for the file (`local shockwave = {}`), with one exception: modules under `src/mod/common/` name it `local common = {}` and callers alias them `<file>_common`, as in `local flipbook_common = require("@mod/common/flipbook")`.

## Quick reference

| Rule | Detail | Evidence |
|---|---|---|
| Mode comments | No `--!strict`. `--!nolint LocalShadow`, `--!native`, `--!optimize 2`, `--!nocheck` only when warranted | 0 canonical files use `--!strict` |
| Header comments | None. Ever | 0 canonical files have one |
| Comments | Rare, lowercase fragment, no terminal period, labels the next few lines | 13 of 31 files have zero comments |
| Blank line after `end` | Always | 576 vs 30 (95%) |
| Params | Always annotate | 240/251 (96%) |
| Return types | Leave inferred unless optional, tuple, or a named type | only 19/128 (15%) explicit |
| Errors | Route through `@mod/logger`; never bare `error()` | 11 of 13 |
| One-line `if` | Never. Guards are always three lines | 0 in the package |
| Iteration | `for _, v in t`, not `ipairs`/`pairs` | universal |
| Strings | Backtick interpolation, not `..` | 1 exception |
| Indentation | 2 spaces, via stylua | `stylua.toml` |

## Sort by length, precisely

The rule is **not** "sort lines by length". It is:

> Within a blank-line-delimited group, sort **interchangeable siblings** by **identifier** length, ascending.

Key is the identifier, not the line. Requires follow this 29/30 times:

```luau
local attr = require("@mod/attributes")    -- name 4, line 39
local tween = require("@mod/tween")        -- name 5, line 35
local types = require("@root/types")       -- name 5, line 36
local logger = require("@mod/logger")      -- name 6, line 37
local utility = require("@mod/utility")    -- name 7, line 39
```

`attr` leads despite its line being the longest. Sorting by line length would put `tween` first.

**Semantic order beats length.** Inside function bodies the rule is near-chance (15/23) because meaning wins:

```luau
local scaleStart = attr.get(ref, "Scale_Start", 1)   -- longer, but Start
local scaleEnd = attr.get(ref, "Scale_End", 1)       -- shorter, but End
```

Start-before-End, base/start/end, `.Name` first, numbered pairs: leave them alone. Sort only when the lines are genuinely interchangeable.

## Naming

Three tiers:

- **snake_case**: file names, module/file identity, persistent object internals (`excess_lifetime`, `item_map`), and args carrying a module identity (`shared_part_cache`)
- **camelCase**: locals, params, functions, transient config fields
- **PascalCase**: class modules with a metatable (`obj/Bezier.luau`), exported types, public API surface (`Finished`, `Clear`), module-level mutable state tables (`local Cache = {}`)

Constants are `UPPER_CASE`.

Two corrections to older prose docs: table fields are **camelCase**, not snake_case (23 vs 11); and `PascalCase.luau` means **class module**, not "UI component"; this package has no UI.

## Always run stylua

Before you finish, from the package root:

```bash
stylua --config-path ./stylua.toml src/
```

If the `stylua` shim errors with `No such file or directory`, the pinned toolchain isn't installed; run `rokit install` first. Do not work around it by calling a binary out of `~/.rokit/tool-storage/`; that silently uses the wrong version.

stylua is necessary, not sufficient: it will not sort your requires, delete your header comment, or fix a bare `error()`.

## No em or en dashes

Never `—` or `–` in code, comments, or docs.

**This includes the ASCII surrogate.** Using ` -- ` as a prose dash is the same construct spelled differently:

```luau
-- BAD:  requirable under lune as well as in Studio -- unlike @mod/utility
-- GOOD: requirable under lune as well as in Studio, unlike @mod/utility
```

Rewrite with a comma, a semicolon, or two sentences.

## Common mistakes

Every one of these came from a real agent writing a real module in this package.

| Rationalization | Reality |
|---|---|
| "I followed the siblings written most recently" | The newest three files are the drifted ones. Recency is not authority. |
| "`--!strict` is the trend in the newest work" | It is the drift marker. 0 canonical files use it. |
| "Where two styles compete, follow the newer" | Follow `recolor.luau` / `shockwave_ring.luau` / `types.luau`. |
| "`path.luau` is the sibling in the directory I'm writing into" | `path.luau` is on the do-not-imitate list. |
| "Strict costs nothing for pure math" | It marks the file as drifted and teaches the next agent wrong. |
| "A header comment documents the non-obvious" | Put that one fact as a lowercase fragment at its use site. |
| "Under `--!strict`, annotating returns is coherent" | Returns are inferred 85% of the time. Annotate params, infer returns. |
| "The `-- ` in my prose isn't an em dash" | It is the ASCII spelling of one. Rewrite the sentence. |
| "Oklab.luau is canonical and uses `--!strict`" | It is vendored MIT code by someone else. |

## Red flags

Stop if you catch yourself:

- Typing `--!strict`
- Writing a prose block above the first `require`
- Justifying a choice with "the newest file does it"
- Reaching for `error(` instead of `logger.error`
- Collapsing a guard onto one line
- Sorting requires alphabetically

## Where the Roblox guide applies

<https://roblox.github.io/lua-style-guide/> fills gaps, but **this package wins every conflict.**

Adopt from it: one statement per line and no single-line blocks; no semicolons; double-quoted strings; trailing commas in multi-line tables; no trailing whitespace; newline at EOF; no vertical alignment; comments explain *why*, not *what*.

Ignore where it conflicts:

| Roblox says | This package does |
|---|---|
| Indent with tabs | 2 spaces |
| Sort requires alphabetically | Length-ascending by identifier |
| `ipairs` for lists, `pairs` for dicts | Generalized `for _, v in t` |
| Block-comment module headers | No header comments |
| Prefix private members `_camelCase` | Not used |
| Avoid section divider comments | Used as labels in long literals |

## Full detail

See `reference.md` for the complete evidence-backed rule set, per-rule counts, and worked before/after corrections.
