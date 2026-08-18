# Cursor Integration Research — Community PR Analysis

**Date:** 2026-07-28  
**Scope:** 4 community PRs that attempted to integrate Cursor into Hermes Agent.

> **Status 2026-08-19.** This page is the July research snapshot. Do not treat
> lawmight#1 as the tree to grow.
>
> - New instances: [`to-ge-da/hermes-agent-sdk`](https://github.com/to-ge-da/hermes-agent-sdk)
>   — latest Nous `main` + [Nous #88212](https://github.com/NousResearch/hermes-agent/pull/88212)
>   (Hermes stays the harness; `cursor-sdk` only infers).
> - Legacy instance: [`to-ge-da/hermes-agent`](https://github.com/to-ge-da/hermes-agent)
>   — v0.19.0 + lawmight `cursor_agent` runtime. Frozen except meter/recycle
>   hotfixes.
> - How to install, isolate, and update both:
>   [testing-custom-forks.md](testing-custom-forks.md).
>
> #88212 is the same *goal* as lawmight#1, not the same git history. Nous still
> has it `needs-decision` and conflicting. The sdk repo exists because an org
> can only **fork** Nous once.

---

## Executive Summary

Four PRs attempted to bring Cursor into Hermes Agent via four different
architectures: a **CLI subprocess shim** (#34096), an **SDK delegation
plugin** (#31844), an **ACP protocol bridge** (#65849), and a **full
cursor-sdk runtime** (lawmight/hermes-agent#1).

Three were closed — but crucially, **all three upstream closures were
policy-driven, not quality-driven**. NousResearch enforces an
"in-tree provider-integration" policy (`AGENTS.md:797-810` /
`AGENTS.md:126-136` in hermes-agent): third-party vendor integrations must
ship as standalone plugins installed into `~/.hermes/plugins/`, never in
the core tree. The automated hermes-sweeper closed #34096, #31844, and
#65849 under this policy regardless of implementation merit.

For a **fork** that adds native Cursor support, that policy objection is
moot — we control the tree. The deciding factors are therefore
architectural soundness and maintenance burden. On those axes, the
maintainer (teknium1) gave explicit guidance on #34096: the official SDK
path is *"the version worth wanting."* The lawmight PR is exactly that
rebuild, and it is the recommended base for our fork.

## Comparison Table

| | #34096 (CLI shim) | #31844 (SDK plugin) | #65849 (ACP bridge) | lawmight#1 (cursor-sdk runtime) |
|---|---|---|---|---|
| **Repo / PR** | NousResearch/hermes-agent#34096 | NousResearch/hermes-agent#31844 | NousResearch/hermes-agent#65849 | lawmight/hermes-agent#1 |
| **Author** | sudoingX | aurokin | vitt76 (+ cursoragent) | lawmight |
| **Approach** | Provider wrapping `cursor-agent -p --output-format stream-json` subprocess | Bundled plugin with a `cursor_agent` delegation tool | External-process provider spawning Cursor CLI `agent acp`; Hermes is the ACP client | First-class provider on official `cursor-sdk` v0.1.9; new `cursor_agent` runtime modeled on codex app-server |
| **Cursor's role** | Agent-in-agent (cursor owns the turn loop) | Separate agent runtime (task delegation only) | Agent-in-agent (Cursor owns tools) | Agent runtime, but Hermes tools injected **into** cursor turns via SDK `custom_tools` |
| **Scope (files)** | 27 files, +6,064 | 12 files, +1,535/−1 | 23 files, +1,317/−47 | 48 files, +6,180 |
| **Core components touched** | `agent/` (new client, compression, display, aux), `hermes_cli/` (auth, picker), provider plugin | `plugins/cursor_agent_sdk/` only + small config/tools registration | `agent/cursor_acp_client.py`, auth, model switch, provider plugin | `agent/transports/` (3 new modules), `agent/cursor_runtime.py`, `hermes_cli/cursor_cli.py`, provider plugin, gateway, TUI, optional skill |
| **Auth method** | Browser OAuth via local `cursor-agent` CLI login (subscription, no API key) | `CURSOR_API_KEY` env var | `agent login` (cursor_login) or `CURSOR_API_KEY` | `CURSOR_API_KEY` (SDK public beta, allowlist gating lifted) |
| **State** | CLOSED 2026-07-13, conflicting | CLOSED 2026-07-13, conflicting | CLOSED 2026-07-18, conflicting | OPEN, **draft**, conflicting |
| **Close/stall reason** | Maintainer architectural objection + sweeper policy close | Sweeper policy close (no in-tree third-party plugins) | Sweeper policy close (standalone plugin route) | Draft; supersedes the others per maintainer guidance |
| **Tests** | 59 shim + 55 registry + more (~191 cursor-touching), dogfooded live | 897-line test file, smoke-tested | 155-line client test + routing tests, manual smoke | 108+ cursor tests across 7 files; full suite parity with main |
| **Viability for a fresh fork** | Medium — proven, but reverse-engineered CLI surface | High for delegation use case only — smallest, cleanest packaging | Medium-low — real protocol, risky auto-allow posture | **Highest** — official SDK, maintainer-endorsed design, most complete; biggest rebase cost |

## Detailed Findings

### 1. NousResearch/hermes-agent#34096 — CLI subprocess shim

**Title:** `feat(cursor): add Cursor agent provider (subscription-based, 100+ models)`
**State:** CLOSED 2026-07-13 · not draft · merge state DIRTY · 27 files, +6,064

**Approach.** Registers `cursor` as a first-class provider. Per turn, Hermes
spawns `cursor-agent -p --output-format stream-json` and translates the JSON
event stream into an OpenAI-shaped chat completion. Cursor's internal
shell/read/edit tool calls bridge to Hermes' `tool_progress_callback` so they
render in the Hermes UI. Session-scoped workspace reuse, event-driven idle
timeout, and the stale detector disabled for cursor.

**Key files.**

- `agent/cursor_agent_client.py` (+1,753) — the subprocess shim / stream-json parser
- `plugins/model-providers/cursor/` — profile + manifest
- `hermes_cli/auth.py` (+97) — external_process auth, CLI status probe
- `hermes_cli/main.py` (+503) — model picker flow with pre-flight panel and CLI installer
- `docs/cursor_architecture.md` (+302) — architecture reference
- Tests: `tests/agent/test_cursor_agent_client.py` (+1,780), `tests/hermes_cli/test_cursor_provider.py` (+915)

**Auth.** Delegated to the local `cursor-agent` CLI's browser-OAuth login —
works with a Cursor subscription, no API key required.

**Why it was closed.** Two layers:

1. **Architectural objection (teknium1, manual review):** in default `agent`
   mode this is *agent-in-agent* — cursor's loop drives the turn, Hermes only
   assembles prompts and renders someone else's tool calls. The shim is
   reverse-engineered from `cursor-agent --help` (undocumented, can break any
   release), defaults to the maximally-permissive posture, and the PR itself
   names the SDK as the better target. Key maintainer quote: the SDK path is
   *"the one that would actually let Hermes drive cursor… **That's the version
   worth wanting**."*
2. **Policy close (hermes-sweeper, automated):** `AGENTS.md:797-810` requires
   new vendor integrations to ship as standalone plugins; closed as
   `not_planned` under `in-tree-provider-integration`.

The author agreed with the objection and said he would pursue official SDK
access and rebuild.

### 2. NousResearch/hermes-agent#31844 — SDK delegation plugin

**Title:** `feat: add Cursor SDK delegation plugin`
**State:** CLOSED 2026-07-13 · not draft · merge state DIRTY · 12 files, +1,535/−1

**Approach.** An opt-in bundled plugin `plugins/cursor_agent_sdk` exposing a
single `cursor_agent` tool that delegates focused coding tasks to the official
Cursor Python SDK (`cursor-sdk==0.1.5`). Cursor is explicitly treated as a
**separate agent runtime, not a model provider**. Supports local and cloud
runtimes; local runs blocked on non-local terminal backends (Docker/SSH/Modal);
wall-clock timeouts and best-effort cancellation; result size caps.

**Key files.**

- `plugins/cursor_agent_sdk/tools.py` (+500) — the delegation handler
- `plugins/cursor_agent_sdk/plugin.yaml`, `__init__.py`, `README.md`
- `hermes_cli/config.py`, `plugins.py`, `tools_config.py` — registration glue
- `tools/lazy_deps.py` — lazy dependency allowlist for `cursor-sdk`
- `tests/plugins/test_cursor_sdk_plugin.py` (+897)

**Auth.** `CURSOR_API_KEY` from environment only — the model can never pass a
key; toolset default-off.

**Why it was closed.** Pure policy: hermes-sweeper closed it under
`AGENTS.md:797-810` — third-party product integrations don't land in the
in-tree `plugins/` directory; publish as a standalone plugin repo / pip entry
point installable into `~/.hermes/plugins/`. Reviewers explicitly noted this
was *"a coupling and maintenance decision, not a judgment on the quality."*
Earlier discussion flagged competing approaches (RFC #30640, #30641, #31280)
needing a maintainer decision — which eventually arrived as policy.

### 3. NousResearch/hermes-agent#65849 — ACP bridge

**Title:** `feat(providers): add cursor-acp (Hermes → Cursor Agent via ACP)`
**State:** CLOSED 2026-07-18 · not draft · merge state DIRTY · 23 files, +1,317/−47

**Approach.** An external-process provider `cursor-acp` that spawns the Cursor
CLI in ACP mode (`agent acp`) — the Agent Client Protocol. Mirrors the
existing `copilot-acp` provider but with the opposite permission policy
(auto-allow instead of deny). Cursor owns its tools; Hermes is the ACP client
and receives final text. Generalizes external-process credential resolution
beyond Copilot, and fixes bare `/model cursor-acp` so Telegram/gateway treat
it as a provider switch.

**Key files.**

- `agent/cursor_acp_client.py` (+580) — the ACP client
- `plugins/model-providers/cursor-acp/` — profile + manifest
- `hermes_cli/auth.py` (+80/−19) — generalized external-process creds
- `hermes_cli/model_switch.py`, `model_setup_flows.py` — routing fixes
- `tests/agent/test_cursor_acp_client.py`, `test_model_switch_bare_provider.py`

**Auth.** `agent login` (cursor_login browser flow) or `CURSOR_API_KEY`.

**Why it was closed.** Same standing policy: sweeper close citing
`AGENTS.md:126-136` — vendor providers ship as standalone plugins under
`~/.hermes/plugins/model-providers/`; the loader already supports
user-installed providers. A bot review also flagged the diff as too large for
confident shallow review. Caveats noted by the author: auto-allow-once
permissions (needed for unattended Telegram/cron) and no `session/load`
between turns.

### 4. lawmight/hermes-agent#1 — cursor-sdk runtime (OPEN)

**Title:** `feat(cursor): Cursor provider via official cursor-sdk — primary models + full SDK surface`
**State:** OPEN · **draft** · mergeable: CONFLICTING · 48 files, +6,180
**Head:** `cursor/bc-3845be2f-...` → base `main`

**Approach.** The SDK rebuild the maintainer asked for. Adds Cursor as a
first-class provider on the official `cursor-sdk` Python package (v0.1.9) plus
the full Cloud Agents surface as a `hermes cursor` CLI and optional skill. The
runtime is modeled 1:1 on the merged **codex app-server runtime** — the
in-tree precedent for "external agent harness as a provider." Crucially,
Hermes **injects its own tool surface into cursor turns** via the SDK's
`custom_tools` (in-process dispatch through `model_tools.handle_function_call()`,
hooks and guardrails included), so Hermes capabilities (web_search, browser,
vision, image gen, skills, TTS, kanban) fire inside the cursor loop.

**Key files.**

- `agent/transports/cursor_sdk_session.py` — session adapter: `Agent.create`/`resume`, stream pump, interrupt→cancel, idle retire, per-session agent-id persistence
- `agent/transports/cursor_event_projector.py` — typed SDK stream → Hermes messages (thinking, tool pairs, usage)
- `agent/transports/cursor_hermes_tools.py` — Hermes tools as SDK `custom_tools` (reuses codex MCP sidecar's `EXPOSED_TOOLS` policy)
- `agent/cursor_runtime.py` + dispatch in `conversation_loop.py` — turn orchestration, DB flush, memory cadence
- `plugins/model-providers/cursor/` — profile with live model catalog over `GET api.cursor.com/v1/models`
- `hermes_cli/cursor_cli.py`, `hermes_cli/subcommands/cursor.py` — Cloud Agents verbs (launch/follow/artifacts/cancel/…)
- `optional-skills/autonomous-ai-agents/cursor-cloud/SKILL.md` — optional skill
- Guards: compression inert on cursor (`compression.cursor_auto: native`), aux side-LLM never routes to cursor, background review falls back

**Auth.** `CURSOR_API_KEY` — the SDK left allowlist gating (public beta), so
plain API-key auth now works (the blocker that pushed #34096 to the CLI).

**Why it matters.** The PR body explicitly supersedes #34096, #50215, #40876,
#31844, #31280 and answers the maintainer's challenge from #34096 ("what does
this give a user they couldn't get by running cursor-agent directly?") with:
Hermes tools inside Composer's loop, transcripts projected into Hermes
sessions, gateway/TUI/cron delivery, and `hermes resume` reattaching via
`Agent.resume()`. 108+ cursor-specific tests green; full suite at parity with
`main` (same 29 pre-existing env failures). Live-dogfooded
(`hermes cursor me`, live catalog, smoke chat OK).

**Caveats.** Still a draft and currently conflicting with its base; it lives
on a personal fork, not against upstream; +6,180 lines is a large surface to
carry through rebases; requires a `CURSOR_API_KEY` (subscription-only OAuth
users are not covered the way #34096's CLI auth covered them).

## Recommendation

**Build the fork's native Cursor support on lawmight/hermes-agent#1 (the
cursor-sdk runtime).**

Rationale:

1. **It's the maintainer-endorsed architecture.** teknium1's review on #34096
   explicitly said the SDK path is "the version worth wanting." The lawmight
   PR is that path, modeled on an already-merged in-tree precedent (codex
   app-server), which also future-proofs us if upstream ever relaxes the
   integration policy.
2. **It stands on a documented surface.** The official `cursor-sdk` (typed
   streaming, structured errors, Windows wheels) instead of reverse-engineered
   CLI internals (#34096) or a young protocol with a risky default-permission
   posture (#65849). Lowest ongoing maintenance liability.
3. **It answers the agent-in-agent objection.** Hermes tools are injected into
   cursor's loop via `custom_tools`, sessions/memory/resume stay Hermes-owned
   with real persistence — the deepest integration of the four.
4. **It's the only living PR.** The other three are closed and will only bit-rot;
   lawmight#1 is open, recently updated, and tested at full-suite parity.

Secondary moves:

- **If API-key-only auth is a blocker** for subscription-only users, cherry-pick
  ideas (not code) from #34096 — its auth probe and picker UX are the best of
  the four — but do not adopt the CLI shim as the runtime.
- **If a minimal first step is wanted before landing the full runtime**, the
  #31844 delegation plugin is the smallest clean unit and its packaging
  (standalone plugin under `~/.hermes/plugins/`) already matches both
  upstream's policy and our fork's needs. It can coexist with the provider
  runtime later (lawmight itself ships the cloud-delegation use case as a CLI
  + skill rather than a core tool).
- **Avoid the ACP route** unless Cursor's `agent acp` matures: auto-allow-once
  permissions and transcript-replay sessions are real limitations for
  unattended Hermes use.

Concrete first step for the fork: create a feature branch off current
upstream `main`, port lawmight#1's four runtime modules
(`cursor_sdk_session.py`, `cursor_event_projector.py`,
`cursor_hermes_tools.py`, `cursor_runtime.py`) plus the provider profile, and
resolve conflicts against our tree — deferring the `hermes cursor` cloud CLI
and optional skill to a follow-up PR to keep the initial diff reviewable.

---

## Sources

- [NousResearch/hermes-agent#34096](https://github.com/NousResearch/hermes-agent/pull/34096) — CLI shim provider (closed)
- [NousResearch/hermes-agent#31844](https://github.com/NousResearch/hermes-agent/pull/31844) — SDK delegation plugin (closed)
- [NousResearch/hermes-agent#65849](https://github.com/NousResearch/hermes-agent/pull/65849) — cursor-acp ACP bridge (closed)
- [lawmight/hermes-agent#1](https://github.com/lawmight/hermes-agent/pull/1) — cursor-sdk runtime (open, draft)
- Maintainer policy: hermes-agent `AGENTS.md:797-810` and `AGENTS.md:126-136` (in-tree provider-integration policy)
