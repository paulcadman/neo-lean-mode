;;; leanmacs-infoview.el --- Display buffer for Lean goals  -*- lexical-binding: t; -*-

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

(defcustom leanmacs-infoview-buffer-name "*Leanmacs Goal*"
  "Name of the buffer used to display Lean goals."
  :type 'string
  :group 'leanmacs)

(defvar leanmacs-infoview-display-action
  '((display-buffer-in-side-window)
    (side . right)
    (window-width . 0.4)
    (slot . 0))
  "`display-buffer' ACTION used to show the goal buffer.")

(define-derived-mode leanmacs-infoview-mode special-mode "Leanmacs Goal"
  "Major mode for the Lean goal display buffer."
  (setq-local truncate-lines nil)
  (setq-local cursor-type nil))

(defun leanmacs-infoview--buffer ()
  "Return the shared goal buffer, creating it if necessary."
  (or (get-buffer leanmacs-infoview-buffer-name)
      (with-current-buffer (get-buffer-create leanmacs-infoview-buffer-name)
        (leanmacs-infoview-mode)
        (current-buffer))))

(defun leanmacs-infoview-display (string)
  "Show STRING in the goal buffer and pop it up in a side window."
  (let ((buffer (leanmacs-infoview--buffer)))
    (with-current-buffer buffer
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert string)
        (goto-char (point-min))))
    (display-buffer buffer leanmacs-infoview-display-action)
    buffer))

(provide 'leanmacs-infoview)
;;; leanmacs-infoview.el ends here
