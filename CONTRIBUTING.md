# Contributing

Spellforge is currently in pre-production. The design and roadmap are proposals and may change after prototype testing.

## Before contributing
- Check existing issues and the design documents under `docs/`.
- For substantial changes, propose scope and acceptance criteria in an issue first.
- Keep contributions aligned with the constrained MVP and avoid unrequested expansions.

## Pull request expectations
1. Explain the gameplay or engineering problem.
2. Describe the change and affected systems.
3. Include reproduction steps for bugs and tests for rules changes.
4. Document new spell semantics or important decisions.
5. Attach actual screenshots/video only when relevant and available.
6. State how you verified the change.

## Engineering guidelines
- Favor clear, small, testable systems and deterministic gameplay logic.
- Add regression tests when fixing spell interactions.
- Do not introduce backend services, invasive telemetry, or performance-specific native extensions without a demonstrated need.
- Do not commit secrets, proprietary assets, or third-party art/audio without redistribution rights.

## Issue template (suggested)
```text
Goal:
Scope:
Acceptance criteria:
Out of scope:
Testing/validation:
Related roadmap stage:
```

## Code of conduct
Be constructive, focus on reproducible technical feedback, and respect all contributors. A formal code of conduct may be added if public contributions become active.

## Licensing
The project does not yet specify an open-source license. Contributions and reuse should not assume a license grant; settle licensing before accepting external code/assets.
