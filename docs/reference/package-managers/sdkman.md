# sdkman

JVM ecosystem version manager (Java, Gradle, Maven, Kotlin, etc.). **Not
a service actor**; synced as dotfile-classified per audit §2.4.8.

## Files synced

- `~/.sdkman/etc/config` — sdkman global config.
- `~/.sdkman/var/version` — installed sdkman version (advisory).

The list of installed candidate versions lives in
`~/.sdkman/candidates/` — these are large blobs (~500 MB+ for a JVM
collection) and are **not** synced. Sdkman re-downloads on `sdk install`.

## Tier

n/a.
