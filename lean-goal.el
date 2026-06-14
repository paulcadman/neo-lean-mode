;;; lean-goal.el --- Show the interactive goal at point  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; The `lean-goal' command: fetch the interactive goals at point over the
;; Lean RPC session and show them in the goal buffer.  This is the
;; user-facing payoff of the RPC keystone -- it exercises the full path
;; connect -> getInteractiveGoals -> render -> display.

;;; Code:

(require 'lean-rpc)
(require 'lean-render)
(require 'lean-infoview)

;;;###autoload
(defun lean-goal ()
  "Display the interactive tactic state at point in the goal buffer.
Requires an active Eglot connection to the Lean server in this buffer."
  (interactive)
  (unless (eglot-current-server)
    (user-error "No Lean language server connected (try `M-x eglot')"))
  (let ((subsession (lean-rpc-open (lean-rpc-position-params))))
    (lean-rpc-get-interactive-goals
     subsession
     (lambda (result)
       (lean-infoview-display (lean-render-goals (plist-get result :goals))))
     (lambda (err)
       (message "lean-goal: %s"
                (or (and (listp err) (plist-get err :message))
                    err))))))

(provide 'lean-goal)
;;; lean-goal.el ends here
