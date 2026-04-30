# yarn

Node.js alternative to npm. Backend: `mpm`. Tier **D** (prompt, 7d).

## Binary

`~/.yarn/bin/yarn` or `/opt/homebrew/bin/yarn`. Classic yarn (v1) and
Berry (v2+) coexist; mpm handles the split.

## Key invocations

- `yarn global list --json` — installed (Classic).
- Berry global is project-scoped (`yarn dlx`); Sojourn doesn't sync this.

## Known issues

- Yarn 1 is in maintenance mode; Berry (v2+) is the active line.
- Same lifecycle-script risk as npm but tier D rather than E because
  yarn's exposure is smaller in practice.
