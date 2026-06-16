;;; neo-lean.el --- Emacs support for the Lean 4 theorem prover  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; Package-Requires: ((emacs "29.1"))
;; URL: https://github.com/janmasrovira/neo-lean-mode
;; Version: 0.0.1
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Umbrella entry point for neo-lean, an Emacs plugin for Lean 4.  Loading
;; this pulls in the major mode and its interactive-RPC goal display; see
;; `neo-lean-mode'.
;;
;; The package is deliberately named `neo-lean' (mode `neo-lean-mode') so it
;; is never confused with `lean-mode' or `lean4-mode'.

;;; Code:

(require 'neo-lean-mode)

(provide 'neo-lean)
;;; neo-lean.el ends here
