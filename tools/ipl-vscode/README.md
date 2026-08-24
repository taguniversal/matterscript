# MatterScript Invocation Language — VS Code Syntax Highlighting

Basic syntax highlighting and bracket matching for `.ms.il` files.

## What this gives you

- Color highlighting for comments, `$destination` places, `name<>` source
  places, `NAME[...]` definitions, `NAME(...)` invocations, generate-block
  keywords, and numbers.
- **Bracket matching for `{}`, `[]`, `()`, and `<>`** — this is the main
  practical win. VS Code will show you the matching bracket, flag
  mismatches, and color nested bracket levels differently, which catches
  exactly the class of bug (a stray `}`, a missing `:`) that's easy to miss
  by eye in a symbol-dense grammar like this one.

This is a hand-written TextMate grammar based directly on the accepted
grammar documented at the top of `src/dialects/il/parser.zig` — not on the
book's prose — so it should stay honest to what the compiler actually
parses. It intentionally does *not* attempt real error diagnostics (that's
a job for the compiler itself, not the editor); it's presentation only.

## Installing (WSL + VS Code)

Easiest method, works whether you're using VS Code natively or through the
Remote-WSL extension — it installs to whichever host is currently active:

1. Open the Extensions view (`Ctrl+Shift+X`).
2. Click the `...` menu in the top-right corner of the Extensions view.
3. Choose **Install from Location...**
4. Select this folder (`il-vscode/`).
5. Reload the window if prompted.

Alternative (manual copy), if "Install from Location" isn't available in
your VS Code version:

```bash
# If using VS Code's Remote-WSL extension (editing files inside WSL):
cp -r il-vscode ~/.vscode-server/extensions/matterscript-il-0.1.0

# If using VS Code natively on Windows:
cp -r il-vscode /mnt/c/Users/<you>/.vscode/extensions/matterscript-il-0.1.0
```

Then reload the VS Code window (`Ctrl+Shift+P` → "Developer: Reload Window").

## Verifying it worked

Open any `.ms.il` file (e.g. `examples/docs/TAG-130/example-12.1.ms.il`).
The status bar in the bottom-right should say **MatterScript IL** rather
than "Plain Text". Try deliberately mismatching a bracket to confirm
matching/highlighting is active.

## Extending it

The grammar lives in `syntaxes/il.tmLanguage.json` — it's plain JSON with
regex `match` patterns, no build step required. If the parser's accepted
grammar changes (comment at the top of `parser.zig`), this file should be
updated to match. Bracket pairs are declared separately in
`language-configuration.json` if those ever need to change.
