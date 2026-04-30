# Add a dotfile template

## Goal

Convert a static dotfile into a chezmoi template so it can render
different content on different Macs (e.g. `git config user.email` for
work vs personal machines).

## Prereqs

- A dotfile already tracked by Sojourn.
- The Dotfiles pane open on that file.

## Steps

1. **Open the file in the Dotfiles pane**, click the *Make template*
   button.
2. Sojourn renames the source from `dot_gitconfig` to
   `dot_gitconfig.tmpl` and opens the chezmoi templating help.
3. **Insert template variables.** Use chezmoi's `data` substitutions
   (`.chezmoi.hostname`, `.chezmoi.os`, custom `.data.*` blocks).

   Example:

   ```gotmpl
   [user]
       name  = Suhail
       email = {{ if eq .chezmoi.hostname "binghzals-MBP" }}work@example.com{{ else }}personal@example.com{{ end }}
   ```

4. **Preview** with the *Preview render* button. Sojourn calls
   `chezmoi execute-template --file <path>` and shows the rendered
   output.
5. **Apply** with *Save and apply* — `chezmoi apply --dry-run` first,
   then real apply on confirm.

## Verification

- The source filename in the data repo ends in `.tmpl`.
- `chezmoi diff` against the rendered output shows no changes after
  apply.
- The same template renders different values on a different Mac.

## Troubleshooting

- **"Template fails to render"** — chezmoi templates use Go's
  `text/template`. Check brace balance + quote handling.
- **"`.data.foo` is empty"** — set it in `~/.config/chezmoi/chezmoi.toml`
  or via `promptOnce`.

## See also

- [reference/chezmoi-features.md](../../reference/chezmoi-features.md).
- [reference/backends/chezmoi.md](../../reference/backends/chezmoi.md).
