# composer

PHP package manager. Backend: `mpm`. Tier **D** (prompt, 7d).

## Binary

`~/.composer/vendor/bin/composer`.

## Key invocations

- `composer global show --format=json` — installed.
- `composer global outdated` — outdated.

## Known issues

- Global packages are usually CLI tools (psalm, phpstan). Project-scoped
  packages live in per-project `composer.json`; not synced.
- Composer's `~/.composer/auth.json` may contain credentials — Sojourn
  surfaces it via the secret-broker path
  ([secret-brokers.md](../secret-brokers.md)).
