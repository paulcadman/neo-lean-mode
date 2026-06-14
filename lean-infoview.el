;;; lean-infoview.el --- Display buffer for Lean goals  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; A minimal display target for rendered Lean goals.  This is intentionally
;; small: a single shared `*Lean Goal*' buffer shown in a side window.  The
;; full infoview (multiple windows, pins, diff pins, diagnostics, widget
;; toggles) is a later milestone.

;;; Code:

(defcustom lean-infoview-buffer-name "*Lean Goal*"
  "Name of the buffer used to display Lean goals."
  :type 'string
  :group 'lean)

(defvar lean-infoview-display-action
  '((display-buffer-in-side-window)
    (side . right)
    (window-width . 0.4)
    (slot . 0))
  "`display-buffer' ACTION used to show the goal buffer.")

(define-derived-mode lean-infoview-mode special-mode "Lean Goal"
  "Major mode for the Lean goal display buffer."
  (setq-local truncate-lines nil)
  (setq-local cursor-type nil))

(defun lean-infoview--buffer ()
  "Return the shared goal buffer, creating it if necessary."
  (or (get-buffer lean-infoview-buffer-name)
      (with-current-buffer (get-buffer-create lean-infoview-buffer-name)
        (lean-infoview-mode)
        (current-buffer))))

(defun lean-infoview-display (string)
  "Show STRING in the goal buffer and pop it up in a side window."
  (let ((buffer (lean-infoview--buffer)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert string)
        (goto-char (point-min))))
    (display-buffer buffer lean-infoview-display-action)
    buffer))

(provide 'lean-infoview)
;;; lean-infoview.el ends here
