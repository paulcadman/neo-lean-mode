# lean-emacs

An Emacs plugin for the [Lean 4](https://lean-lang.org) interactive theorem
prover, working toward feature parity with
[lean.nvim](https://github.com/Julian/lean.nvim).

It is a from-scratch implementation built on Emacs' built-in
[Eglot](https://www.gnu.org/software/emacs/manual/html_node/eglot/) LSP client
and `jsonrpc.el`. Unlike a plain LSP setup, it speaks Lean's **interactive RPC**
protocol (`$/lean/rpc/connect`, `getInteractiveGoals`, widgets) — the layer that
powers a real infoview with clickable goals.

## Status

Early. The current milestone is the **RPC keystone spike**: connect to the Lean
server's interactive RPC session and display the live tactic state.

| Command       | Binding   | Description                          |
|---------------|-----------|--------------------------------------|
| `lean-goal`   | `C-c C-g` | Show the interactive goal at point.  |

## Requirements

- Emacs 29.1+ (developed on 30.2).
- A Lean 4 toolchain (`lake`, `lean`) on `PATH`, typically via
  [elan](https://github.com/leanprover/elan).

## Usage

```elisp
(add-to-list 'load-path "/path/to/lean-emacs")
(require 'lean-mode)
```

Open a `.lean` file inside a Lake project, `M-x eglot` to start the server, then
`C-c C-g` inside a proof to see the goal.

## License and credits

MIT licensed (see `LICENSE`).

- Behavior and the RPC protocol handling are ported from
  [lean.nvim](https://github.com/Julian/lean.nvim) by Julian Berman, also MIT
  licensed.
- `data/abbreviations.json` is vendored from lean.nvim (originally from
  vscode-lean4), MIT licensed.
- Design inspiration from [nael](https://codeberg.org/mekeor/nael) and
  [lean4-mode](https://github.com/leanprover-community/lean4-mode); no code is
  copied from either (both are GPL/Apache licensed).
