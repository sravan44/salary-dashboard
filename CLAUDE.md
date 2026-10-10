# CLAUDE.md: AI collaboration contract

Sravan owns product understanding, architecture decisions and final quality. Claude is the collaborator.

## Working rules
1. One milestone or prompt at a time (`docs/implementation-milestones.md`). Make the **minimal change** that satisfies it; never broaden scope silently.
2. Before coding: state the acceptance criteria and the tests. Ask when an ambiguity would change business behavior.
3. Tests describe behavior, are deterministic (no network, frozen time, fixed seeds), and keep **coverage ≥ 90%** for backend and frontend. The thresholds are enforced by the test runners.
4. Never claim a command passed without its real output. Mark unrun checks **NOT RUN**.
5. **Pause before every commit.** Show changed files, the staged diff summary, test output and the proposed message. **Apply the uncommitted changes to Sravan's local copy (`/Users/sravanpolamarasetti/salary-dashboard`) for `git diff` review first.** Commit and push only after approval, then fast-forward the local copy. Never amend, rebase or force-push without permission. Use the repo-local git identity.
6. Keep `docs/ai-work-log.md` and `docs/rejected-suggestions.md` current. Put real evidence in `docs/evidence/`.

## Domain rules (non-negotiable)
- Money is `decimal`, serialized as a string, with an ISO-4217 currency always attached.
- Salary history is append-only; a change closes the current record in the same transaction.
- Never aggregate across currencies without an explicit FX conversion (Phase 2).
- No secrets in git; `.env.example` holds placeholders only.

## Conventions
- **Rails:** never edit a committed migration (add a new one); thin controllers; `app/services/<domain>/` for use cases, `app/queries/<domain>/` for read paths; no observers; no business logic in callbacks; RuboCop clean.
- **React:** feature-first `src/modules/<feature>/`; PascalCase components; `useX` hooks; kebab-case filenames; strict TypeScript; ESLint clean.
