# Releasing peon-ping

## Two install channels

peon-ping has two install paths that update differently:

| Channel | What users run | What it pulls from |
|---|---|---|
| **curl \| bash** | `curl -fsSL https://raw.githubusercontent.com/NSXBet/peon-nsx/main/install.sh \| bash` | `main` branch (always latest) |
| **Homebrew** | `brew upgrade peon-ping` | Tagged release tarball |

Pushing to `main` is effectively a release for curl users. Tags + tap updates are what make it available to Homebrew users.

## Version numbering

peon-ping uses semver loosely:

- **Patch** (1.6.1): bug fixes, small tweaks, new sound packs
- **Minor** (1.7.0): new features (SSH relay, mobile notifications, new CLI commands)
- **Major** (2.0.0): breaking changes to config format, hook behavior, or CLI interface

## Release steps

### 1. Ensure tests pass

```bash
bats tests/
```

### 2. Update CHANGELOG.md

Add a new section at the top with the version and date:

```markdown
## v1.7.0 (2026-02-13)

### Added
- SSH remote audio support with relay daemon mode
- ...

### Fixed
- ...
```

### 3. Bump VERSION file

```bash
echo "1.7.0" > VERSION
```

### 4. Commit and tag

```bash
git add VERSION CHANGELOG.md
git commit -m "chore: bump version to 1.7.0"
git tag v1.7.0
git push && git push --tags
```

This triggers `.github/workflows/release.yml` which creates a GitHub Release with auto-generated notes and a `checksums.txt` asset.

### 5. Homebrew tap (automatic)

The `update-tap` job in `release.yml` automatically updates `NSXBet/homebrew-tap` after a successful release. It computes the tarball SHA256 and pushes a formula update.

This requires a `TAP_TOKEN` repository secret with write access to the tap repo.

### 6. Verify

- [ ] [GitHub Releases page](https://github.com/NSXBet/peon-nsx/releases) shows the new version with checksums
- [ ] `curl -fsSL https://raw.githubusercontent.com/NSXBet/peon-nsx/main/install.sh | bash` installs the new version (check `cat ~/.claude/hooks/peon-ping/VERSION`)
- [ ] `brew update && brew upgrade peon-ping` pulls the new version

## Hotfix process

For urgent fixes to the current release:

1. Fix the bug on `main`, run tests
2. Bump VERSION as a patch (e.g., 1.7.1)
3. Follow the normal release steps above

There's no release branch — `main` is always the release branch.

## What the release workflow does

`.github/workflows/release.yml` runs on tag push (`v*`):

1. Generates SHA256 checksums for all core files
2. Creates a GitHub Release using `softprops/action-gh-release` with `generate_release_notes: true`
3. Attaches `checksums.txt` as a release asset
4. The `update-tap` job automatically updates `NSXBet/homebrew-tap` with the new tarball SHA256 (requires `TAP_TOKEN` secret)
