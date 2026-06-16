;;; neo-lean-doom.el --- Optional Doom Emacs integration  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Optional, self-disabling glue for Doom Emacs.  When Doom's `:tools lookup'
;; module is present (detected via `set-lookup-handlers!'), the interactive goal
;; buffer is wired into Doom's lookup system, so `+lookup/definition' and
;; `+lookup/type-definition' jump from the subexpression under point in the goal
;; buffer to its source.  (Doom's lookup has no `declaration' action, so
;; `neo-lean-goal-go-to-declaration' is left for manual binding.)
;;
;; Without Doom this file does nothing: the package stays editor-agnostic and
;; depends only on Eglot.  It is required unconditionally by `neo-lean-mode';
;; the integration only activates where Doom provides the seam.

;;; Code:

(require 'neo-lean-goal)

;; `set-lookup-handlers!' is a Doom macro.  Evaluate the registration at load
;; time only when it exists, via a quoted form, so we neither depend on Doom nor
;; expand the macro at byte-compile time.  The jumps round-trip to the Lean
;; server asynchronously, hence `:async'.
(when (fboundp 'set-lookup-handlers!)
  (eval '(set-lookup-handlers! 'neo-lean-infoview-mode
           :async t
           :definition #'neo-lean-goal-go-to-definition
           :type-definition #'neo-lean-goal-go-to-type)
        t))

(provide 'neo-lean-doom)
;;; neo-lean-doom.el ends here
