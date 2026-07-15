# forge-vfx Agent Guide

Instructions for coding agents working in `pkg/forge-vfx`, the emit module behind the [VFX Forge](https://devforum.roblox.com/t/3867553) Roblox plugin.

Follow this whether you are changing code here directly or preparing a PR. Code that does not match the style below will be sent back.

**Before writing any Luau, load the `forge-luau-style` skill** (`.claude/skills/forge-luau-style/`). It is the canonical rule set: `SKILL.md` for the rules and procedure, `reference.md` for the full evidence and worked corrections. This file is the summary; the skill is the authority.

## Layout

| Path | Contents |
|---|---|
| `src/effects/` | One module per effect (`beam`, `lightning`, `shockwave_ring`, ...) |
| `src/mod/` | Plain-table helper namespaces (`tween`, `lerp`, `logger`, `attributes`) |
| `src/mod/common/` | Pure helpers with no engine access, requirable under lune |
| `src/obj/` | Class modules with metatables (`Bezier`, `ObjectCache`) |
| `src/services/` | Long-lived services (`effects`, `caches`, `texture_loader`) |
| `src/emitters.luau` | Dispatch layer mapping instances to effect modules |
| `src/types.luau` | Shared exported types |

Require via the `.luaurc` aliases (`@mod`, `@obj`, `@vfx`, `@srv`, `@root`, `@pkg`). Do not write relative requires; there is exactly one in the whole tree and it is an outlier.

## Setup

```sh
rokit install --no-trust-check
```

`--no-trust-check` is required because `UpliftGames/wally` is untrusted by default and plain `rokit install` aborts on it. This is the same invocation the plugin repo's release workflow uses.

If `stylua` reports `No such file or directory`, you skipped this step: `rokit.toml` pins StyLua 2.4.0 while the parent plugin repo pins 2.5.2, so the shim will not resolve until the pinned build is fetched. Never work around it by calling a binary out of `~/.rokit/tool-storage/`; that silently formats with the wrong version.

## Always run stylua

```sh
stylua --config-path ./stylua.toml src/
```

Required before every commit. stylua is necessary but not sufficient: it will not sort your requires, remove a header comment, or fix a bare `error()`.

Build with `rojo-build-noalias -o output.rbxm`. The TypeScript surface (`index.d.ts`) is separate: `bun run typecheck`, `bun run lint`.

## Style summary

- **2-space indent.** Enforced by stylua.
- **No `--!strict`.** Most files carry no mode comment at all. `--!native` / `--!optimize 2` only for genuinely hot numeric code.
- **No header comments.** Never open a file with a prose block explaining it.
- **Comment rarely**, only where the code cannot say it itself. Lowercase fragment, no trailing period, labelling the lines beneath. Many files here have zero comments and that is correct.
- **Blank line after every closing `end`.** Separate logical blocks.
- **Annotate every parameter. Leave return types inferred** unless the return is optional, a tuple, or a named type.
- **Guards are three lines.** No one-line `if x then return end`, ever.
- **Errors go through `@mod/logger`**, not bare `error()`. Per-frame hot paths absorb bad input silently instead.
- **Sort interchangeable siblings by identifier length, ascending, within each blank-line group.** Governs requires and flat lists. It does not override semantic order: `scaleStart` still precedes `scaleEnd`.
- **Naming:** `snake_case` files and object internals, `camelCase` locals and functions and config fields, `PascalCase` class modules and exported types and public API fields, `UPPER_CASE` constants.
- **No em or en dashes anywhere**, in code, comments, or docs. This includes ` -- ` used as a prose dash. Rewrite with a comma or a second sentence.

Where this package and the [Roblox Lua style guide](https://roblox.github.io/lua-style-guide/) disagree, this package wins. The guide is a gap-filler only.

## Files that are not examples

Three files have drifted and are **not** precedent. Do not copy their conventions, however recent they are. Recency is not authority:

- `src/schema.luau`
- `src/mod/common/path.luau`
- `src/mod/modifiers.luau`

Two more are vendored MIT code by Daniel P H Fox and were never house style:

- `src/mod/color/Oklab.luau`
- `src/mod/color/sRGB.luau`

Those five are the only files in the package with `--!strict`. That is a symptom, not a convention.

**Imitate these instead:** `src/mod/recolor.luau`, `src/effects/shockwave_ring.luau`, `src/obj/ObjectCache.luau`, `src/types.luau`.

## Before you finish

1. `stylua --config-path ./stylua.toml src/`
2. Confirm you added no `--!strict`, no header comment, and no one-line guards.
3. Confirm no em or en dashes, including ` -- ` in prose.
4. Keep the diff focused. Unrelated reformatting makes review harder.
