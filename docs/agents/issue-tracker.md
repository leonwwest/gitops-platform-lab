# Issue tracker: GitHub

Issues and specifications for this repository live as GitHub Issues. Use the `gh` CLI for all operations.

## Conventions

- Create an issue with `gh issue create`.
- Read an issue with `gh issue view <number> --comments`.
- List issues with `gh issue list`.
- Comment with `gh issue comment <number>`.
- Close an issue with `gh issue close <number>`.
- Infer the repository from `git remote -v`; the `gh` CLI does this automatically inside the repository.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## Skill terminology

- When a skill says "publish to the issue tracker", create a GitHub Issue.
- When a skill says "fetch the relevant ticket", read the corresponding GitHub Issue including its comments.
- GitHub Issues are the canonical record for specifications, implementation tasks, decisions and completion notes.
