;;; neo-lean-mode.el --- Major mode for Lean 4  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; Package-Requires: ((emacs "29.1"))
;; URL: https://github.com/janmasrovira/neo-lean-mode
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; A major mode for editing Lean 4 source.  This file defines `neo-lean-mode'
;; and configures Eglot to talk to the Lean language server (`lake serve').
;;
;; This milestone keeps the mode itself minimal -- just enough for Eglot
;; to attach.  Full font-lock, indentation and imenu come later.  The point
;; of the current milestone is the interactive RPC layer (see `neo-lean-rpc.el')
;; and the goal display (`neo-lean-goal').

;;; Code:

(require 'eglot)
(require 'neo-lean-input)

(defgroup neo-lean nil
  "Major mode for the Lean 4 theorem prover."
  :group 'languages
  :prefix "neo-lean-")

(defcustom neo-lean-server-command '("lake" "serve")
  "Command used to start the Lean language server.
A list whose first element is the program and the rest are arguments.
Eglot launches this within the current project."
  :type '(repeat string)
  :group 'neo-lean)

;;;; Syntax

(defvar neo-lean-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; `--' line comments and `/- ... -/' (nestable) block comments.
    ;; In Emacs' two-character comment syntax, `-' and `/' share the
    ;; comment-start/-end slots: `--' opens a line comment, `/-' a block.
    (modify-syntax-entry ?/ ". 14n" table)
    (modify-syntax-entry ?- ". 123" table)
    (modify-syntax-entry ?\n ">" table)
    ;; Strings.
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\\ "\\" table)
    ;; Treat common identifier characters as symbol constituents so that
    ;; navigation and `symbol-at-point' behave sensibly on Lean names.
    (modify-syntax-entry ?_ "_" table)
    (modify-syntax-entry ?' "_" table)
    (modify-syntax-entry ?. "_" table)
    ;; Brackets.
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?{ "(}" table)
    (modify-syntax-entry ?} "){" table)
    table)
  "Syntax table for `neo-lean-mode'.")

;;;; Keymap

(defvar-keymap neo-lean-mode-map
  :doc "Keymap for `neo-lean-mode'."
  "C-c C-g" #'neo-lean-goal)

;;;; Eglot integration

;; Register the Lean server.  `lake serve' prints nothing on startup, so we
;; tell Eglot not to wait synchronously for output (see
;; `neo-lean--eglot-managed-setup').
(add-to-list 'eglot-server-programs
             (cons 'neo-lean-mode
                   (lambda (&optional _interactive _project)
                     neo-lean-server-command)))

(defun neo-lean--eglot-managed-setup ()
  "Buffer-local Eglot tweaks for Lean, run from `eglot-managed-mode-hook'."
  (when (derived-mode-p 'neo-lean-mode)
    ;; `lake serve' is silent on startup; don't block waiting for a banner.
    (setq-local eglot-sync-connect nil)))

(add-hook 'eglot-managed-mode-hook #'neo-lean--eglot-managed-setup)

;;;; Mode

;;;###autoload
(define-derived-mode neo-lean-mode prog-mode "Neo-Lean"
  "Major mode for editing Lean 4 files.

\\{neo-lean-mode-map}"
  :syntax-table neo-lean-mode-syntax-table
  (setq-local comment-start "-- ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "[ \t]*--+[ \t]*")
  (setq-local comment-use-syntax t)
  (setq-local tab-width 2)
  ;; Suggest `lake build' when compiling.
  (setq-local compile-command "lake build")
  ;; Unicode abbreviation input (\alpha -> α, \<> -> ⟨⟩, ...).
  (when neo-lean-input-enable
    (activate-input-method neo-lean-input-method-name)))

;; Only claim `.lean' if nothing else already has (e.g. lean4-mode), so the
;; two can coexist and the user's chosen default wins.  Standalone installs
;; still get `neo-lean-mode' automatically.
;;;###autoload
(unless (assoc "\\.lean\\'" auto-mode-alist)
  (add-to-list 'auto-mode-alist '("\\.lean\\'" . neo-lean-mode)))

(require 'neo-lean-goal)
(require 'neo-lean-progress)
;; Optional editor integrations; each self-disables when its host is absent.
(require 'neo-lean-doom)

(provide 'neo-lean-mode)
;;; neo-lean-mode.el ends here
