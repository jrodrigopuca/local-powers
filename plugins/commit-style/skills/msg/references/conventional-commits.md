# Conventional Commits types

Based on https://www.conventionalcommits.org/en/v1.0.0/ and the Angular convention.

| Type | Use when the change… | Example |
|------|----------------------|---------|
| `feat` | adds a capability for the user of the code | `feat(auth): add password reset` |
| `fix` | corrects wrong behaviour | `fix(cart): keep quantity on reload` |
| `docs` | touches only documentation | `docs: explain install from git` |
| `style` | changes formatting only, no behaviour (whitespace, semicolons) | `style: apply prettier` |
| `refactor` | restructures code without changing behaviour | `refactor(api): extract client` |
| `perf` | improves performance without changing behaviour | `perf(search): cache index` |
| `test` | adds or fixes tests only | `test(cart): cover empty cart` |
| `build` | changes the build system or dependencies | `build: bump typescript to 5.9` |
| `ci` | changes CI configuration | `ci: run validate on pull requests` |
| `chore` | maintenance that fits nothing above | `chore: update .gitignore` |
| `revert` | reverts a previous commit | `revert: feat(auth): add password reset` |

## Tie-breakers

- Code plus its tests → type of the code (`feat`/`fix`), not `test`.
- A dependency bump that fixes a bug the user sees → `fix`; otherwise `build`.
- Docs inside a feature commit → type of the feature.
- Lockfile-only changes → `build`.
