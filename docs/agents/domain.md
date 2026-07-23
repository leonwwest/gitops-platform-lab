# Domain docs

This repository uses a single-context documentation layout.

## Before exploring

Read these files when they exist and are relevant:

- `CONTEXT.md` at the repository root
- architecture decision records under `docs/adr/`

If they do not exist yet, proceed without creating empty placeholders. Domain-modeling workflows create or update them when terminology or architectural decisions are actually resolved.

## Expected structure

```text
/
├── CONTEXT.md
├── docs/
│   ├── adr/
│   └── agents/
└── src/
```

## Vocabulary and decisions

- Use terminology defined in `CONTEXT.md` consistently in issues, tests, documentation and code.
- Surface conflicts with an existing architecture decision explicitly instead of silently overriding it.
