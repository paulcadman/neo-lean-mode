;;; leanmacs-goal.el --- Show the interactive goal at point  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; The `leanmacs-goal' command: fetch the interactive goals at point over the
;; Lean RPC session and show them in the goal buffer.  This is the
;; user-facing payoff of the RPC keystone -- it exercises the full path
;; connect -> getInteractiveGoals -> render -> display.

;;; Code:

(require 'leanmacs-rpc)
(require 'leanmacs-render)
(require 'leanmacs-infoview)

;;;###autoload
(defun leanmacs-goal ()
  "Display the interactive tactic state at point in the goal buffer.
Requires an active Eglot connection to the Lean server in this buffer."
  (interactive)
  (unless (eglot-current-server)
    (user-error "No Lean language server connected (try `M-x eglot')"))
  (let ((subsession (leanmacs-rpc-open (leanmacs-rpc-position-params))))
    (leanmacs-rpc-get-interactive-goals
     subsession
     (lambda (result)
       (leanmacs-infoview-display (leanmacs-render-goals (plist-get result :goals))))
     (lambda (err)
       (message "leanmacs-goal: %s"
                (or (and (listp err) (plist-get err :message))
                    err))))))

(provide 'leanmacs-goal)
;;; leanmacs-goal.el ends here
