;;; leanmacs-goal.el --- Show and track the interactive goal  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Fetch the interactive goals at point over the Lean RPC session and show
;; them in the goal buffer.  `leanmacs-goal' opens the buffer on demand; while
;; it is visible it follows the cursor, refreshing after a short debounce
;; (like lean.nvim's `update_cooldown').
;;
;; Cursor-follow is gated on the goal buffer being visible -- so moving around
;; with the infoview closed costs nothing -- and each request carries a
;; monotonic id so a slow response cannot overwrite a newer one.

;;; Code:

(require 'cl-lib)
(require 'leanmacs-rpc)
(require 'leanmacs-render)
(require 'leanmacs-infoview)

(defcustom leanmacs-goal-auto-update t
  "When non-nil, refresh the goal buffer as the cursor moves.
Tracking only happens while the goal buffer is visible; open it with
`leanmacs-goal'."
  :type 'boolean
  :group 'leanmacs)

(defcustom leanmacs-goal-update-delay 0.05
  "Seconds to wait after the cursor stops before refreshing the goal.
Coalesces rapid movement into a single request."
  :type 'number
  :group 'leanmacs)

(defvar-local leanmacs--goal-timer nil
  "Pending debounce timer for the goal refresh in this buffer.")
(defvar-local leanmacs--goal-request-id 0
  "Monotonic id of the latest goal request; guards against stale responses.")
(defvar-local leanmacs--goal-last-point nil
  "Buffer position of the last scheduled refresh.")

(defun leanmacs--goal-update (&optional display)
  "Fetch the proof state at point and render it into the infoview.
Requests the interactive tactic goals and the term goal (the expected
type) and shows both.  With DISPLAY non-nil, pop up the infoview window
once they arrive; otherwise refresh its contents in place."
  (when (eglot-current-server)
    (let* ((id (cl-incf leanmacs--goal-request-id))
           (src (current-buffer))
           (subsession (leanmacs-rpc-open (leanmacs-rpc-position-params))))
      (cl-flet ((fresh-p ()
                  (and (buffer-live-p src)
                       (= id (buffer-local-value 'leanmacs--goal-request-id src))))
                (show (goals term-goal)
                  (let ((text (leanmacs-render-state goals term-goal)))
                    (if display
                        (leanmacs-infoview-display text)
                      (leanmacs-infoview-update text)))))
        (leanmacs-rpc-get-interactive-goals
         subsession
         (lambda (result)
           (when (fresh-p)
             ;; Chain the term goal so both render together; a missing or
             ;; failed term goal just leaves the tactic goals showing.
             (let ((goals (plist-get result :goals)))
               (leanmacs-rpc-get-interactive-term-goal
                subsession
                (lambda (term-goal) (when (fresh-p) (show goals term-goal)))
                (lambda (_err) (when (fresh-p) (show goals nil)))))))
         (lambda (err)
           ;; Ignore transient errors during movement; only report on an
           ;; explicit request.
           (when (and (fresh-p) display)
             (message "leanmacs-goal: %s"
                      (or (and (listp err) (plist-get err :message)) err)))))))))

;;;###autoload
(defun leanmacs-goal ()
  "Display the interactive tactic state at point in the goal buffer.
Opens the goal buffer; while it stays visible it follows the cursor (see
`leanmacs-goal-auto-update').  Requires an active Eglot connection to the
Lean server in this buffer."
  (interactive)
  (unless (eglot-current-server)
    (user-error "No Lean language server connected (try `eglot')"))
  (leanmacs--goal-update t))

(defun leanmacs--goal-post-command ()
  "Schedule a goal refresh after cursor movement, while the infoview is visible."
  (when (and leanmacs-goal-auto-update
             (eglot-current-server)
             (leanmacs-infoview-visible-p)
             (not (eql (point) leanmacs--goal-last-point)))
    (setq leanmacs--goal-last-point (point))
    (when (timerp leanmacs--goal-timer)
      (cancel-timer leanmacs--goal-timer))
    (let ((buf (current-buffer)))
      (setq leanmacs--goal-timer
            (run-with-timer
             leanmacs-goal-update-delay nil
             (lambda ()
               (when (buffer-live-p buf)
                 (with-current-buffer buf
                   (setq leanmacs--goal-timer nil)
                   (leanmacs--goal-update nil)))))))))

(defun leanmacs--goal-setup ()
  "Install buffer-local cursor-follow tracking for the goal buffer."
  (add-hook 'post-command-hook #'leanmacs--goal-post-command nil t))

(add-hook 'leanmacs-mode-hook #'leanmacs--goal-setup)

(provide 'leanmacs-goal)
;;; leanmacs-goal.el ends here
