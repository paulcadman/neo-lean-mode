;;; leanmacs-mode.el --- Major mode for Lean 4  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; Package-Requires: ((emacs "29.1"))
;; URL: https://github.com/janmasrovira/lean-emacs
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; A major mode for editing Lean 4 source, working toward feature parity
;; with lean.nvim.  This file defines `leanmacs-mode' and configures Eglot to
;; talk to the Lean language server (`lake serve').
;;
;; This milestone keeps the mode itself minimal -- just enough for Eglot
;; to attach.  Full font-lock, indentation and imenu come later.  The point
;; of the current milestone is the interactive RPC layer (see `leanmacs-rpc.el')
;; and the goal display (`leanmacs-goal').

;;; Code:

(require 'eglot)
(require 'leanmacs-input)

(defgroup leanmacs nil
  "Major mode for the Lean 4 theorem prover."
  :group 'languages
  :prefix "leanmacs-")

(defcustom leanmacs-server-command '("lake" "serve")
  "Command used to start the Lean language server.
A list whose first element is the program and the rest are arguments.
Eglot launches this within the current project."
  :type '(repeat string)
  :group 'leanmacs)

;;;; Syntax

(defvar leanmacs-mode-syntax-table
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
  "Syntax table for `leanmacs-mode'.")

;;;; Keymap

(defvar-keymap leanmacs-mode-map
  :doc "Keymap for `leanmacs-mode'."
  "C-c C-g" #'leanmacs-goal)

;;;; Eglot integration

;; Register the Lean server.  `lake serve' prints nothing on startup, so we
;; tell Eglot not to wait synchronously for output (see
;; `leanmacs--eglot-managed-setup').
(add-to-list 'eglot-server-programs
             (cons 'leanmacs-mode
                   (lambda (&optional _interactive _project)
                     leanmacs-server-command)))

(defun leanmacs--eglot-managed-setup ()
  "Buffer-local Eglot tweaks for Lean, run from `eglot-managed-mode-hook'."
  (when (derived-mode-p 'leanmacs-mode)
    ;; `lake serve' is silent on startup; don't block waiting for a banner.
    (setq-local eglot-sync-connect nil)))

(add-hook 'eglot-managed-mode-hook #'leanmacs--eglot-managed-setup)

;;;; Mode

;;;###autoload
(define-derived-mode leanmacs-mode prog-mode "Leanmacs"
  "Major mode for editing Lean 4 files.

\\{leanmacs-mode-map}"
  :syntax-table leanmacs-mode-syntax-table
  (setq-local comment-start "-- ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "[ \t]*\\(?://+\\|--+\\)[ \t]*")
  (setq-local comment-use-syntax t)
  (setq-local tab-width 2)
  ;; Suggest `lake build' when compiling.
  (setq-local compile-command "lake build")
  ;; Unicode abbreviation input (\alpha -> α, \<> -> ⟨⟩, ...).
  (when leanmacs-input-enable
    (activate-input-method leanmacs-input-method-name)))

;; Only claim `.lean' if nothing else already has (e.g. lean4-mode), so the
;; two can coexist and the user's chosen default wins.  Standalone installs
;; still get `leanmacs-mode' automatically.
;;;###autoload
(unless (assoc "\\.lean\\'" auto-mode-alist)
  (add-to-list 'auto-mode-alist '("\\.lean\\'" . leanmacs-mode)))

(require 'leanmacs-goal)
(require 'leanmacs-progress)

(provide 'leanmacs-mode)
;;; leanmacs-mode.el ends here
