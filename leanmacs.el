;;; leanmacs.el --- Emacs support for the Lean 4 theorem prover  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; Package-Requires: ((emacs "29.1"))
;; URL: https://github.com/janmasrovira/lean-emacs
;; Version: 0.0.1
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Umbrella entry point for leanmacs, an Emacs plugin for Lean 4 working
;; toward feature parity with lean.nvim.  Loading this pulls in the major
;; mode and its interactive-RPC goal display; see `leanmacs-mode'.
;;
;; The package is deliberately named `leanmacs' (mode `leanmacs-mode') so it
;; is never confused with `lean-mode' or `lean4-mode'.

;;; Code:

(require 'leanmacs-mode)

(provide 'leanmacs)
;;; leanmacs.el ends here
