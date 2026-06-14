# leanmacs

An Emacs plugin for the [Lean 4](https://lean-lang.org) theorem prover, working
toward feature parity with [lean.nvim](https://github.com/Julian/lean.nvim).

Built on built-in **Eglot** + `jsonrpc.el`, it speaks Lean's *interactive RPC*
protocol (`$/lean/rpc/connect`, `getInteractiveGoals`) — the layer behind a real
infoview, not just plaintext LSP hovers. The major mode is `leanmacs-mode`,
named distinctly so it is never confused with `lean-mode` / `lean4-mode`.

> ⚠️ **Vibe-coded.** This project is written largely by prompting an AI coding
> agent. Expect rough edges; review before relying on it.

## Status

Early. The current milestone is the RPC keystone: connect to the server and show
the live goal.

| Command         | Binding   | Description                         |
|-----------------|-----------|-------------------------------------|
| `leanmacs-goal` | `C-c C-g` | Show the interactive goal at point. |

## Requirements

- Emacs 29.1+ (developed on 30.2).
- A Lean 4 toolchain (`lake`, `lean`) on `PATH`, e.g. via
  [elan](https://github.com/leanprover/elan).

## Usage

```elisp
(add-to-list 'load-path "/path/to/lean-emacs")
(require 'leanmacs-mode)
```

Open a `.lean` file in a Lake project, start the server with `eglot`, then run
`leanmacs-goal` inside a proof. The goal buffer then follows the cursor.

## Keybindings

The only built-in binding is `leanmacs-goal` on `C-c C-g` in `leanmacs-mode-map`.

### Vim / Evil

`leanmacs-mode` is a normal major mode, so Evil works out of the box. The
`C-c C-g` binding is awkward from normal state, so bind `leanmacs-goal` under
the local-leader instead.

**Doom Emacs** (`SPC m g` runs `leanmacs-goal`):

```elisp
(map! :map leanmacs-mode-map
      :localleader
      "g" #'leanmacs-goal)
```

**Vanilla Evil** (`<localleader> g` runs `leanmacs-goal`):

```elisp
(with-eval-after-load 'leanmacs-mode
  (evil-define-key 'normal leanmacs-mode-map
    (kbd "<localleader>g") #'leanmacs-goal))
```

## License and credits

MIT (see `LICENSE`). Behavior and the RPC handling are ported from the MIT
`lean.nvim` by Julian Berman; `data/abbreviations.json` is vendored from it.
`nael` and `lean4-mode` were design references only (no code copied).
