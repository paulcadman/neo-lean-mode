;;; neo-lean-infoview.el --- Display buffer for Lean goals  -*- lexical-binding: t; -*-

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

(defcustom neo-lean-infoview-buffer-name "*Neo-Lean Goal*"
  "Name of the buffer used to display Lean goals."
  :type 'string
  :group 'neo-lean)

(defvar neo-lean-infoview-display-action
  '((display-buffer-in-side-window)
    (side . right)
    (window-width . 0.4)
    (slot . 0))
  "`display-buffer' ACTION used to show the goal buffer.")

(defvar-local neo-lean-infoview--source-buffer nil
  "The Lean source buffer whose goal is currently displayed here.")
(defvar-local neo-lean-infoview--source-pos nil
  "The text-document-position the displayed goal was fetched at.
Used to open an RPC session for interactive commands (e.g. go-to-definition)
issued from this buffer.")
(defvar-local neo-lean-infoview--render-data nil
  "Latest structured infoview payload, used when rerendering folds.")
(defvar-local neo-lean-infoview--fold-state nil
  "Hash table of persistent fold state for the current infoview payload.")

(define-derived-mode neo-lean-infoview-mode special-mode "Neo-Lean Goal"
  "Major mode for the Lean goal display buffer."
  (setq-local truncate-lines nil)
  (setq-local cursor-type nil)
  (setq-local buffer-invisibility-spec '(neo-lean-fold)))

(defun neo-lean-infoview-set-source (buffer pos)
  "Record BUFFER and POS as the source of the currently displayed goal.
POS is an LSP text-document-position plist.  Interactive commands in the
goal buffer use these to talk to the Lean server about the source document."
  (with-current-buffer (neo-lean-infoview--buffer)
    (setq neo-lean-infoview--source-buffer buffer
          neo-lean-infoview--source-pos pos)))

(defun neo-lean-infoview--buffer ()
  "Return the shared goal buffer, creating it if necessary."
  (or (get-buffer neo-lean-infoview-buffer-name)
      (with-current-buffer (get-buffer-create neo-lean-infoview-buffer-name)
        (neo-lean-infoview-mode)
        (current-buffer))))

(defun neo-lean-infoview-update (string &optional preserve-point)
  "Set the goal buffer contents to STRING and return the buffer.
Does not display the buffer.  No-ops when STRING is already shown, so
unchanged refreshes neither flicker nor reset the goal buffer's point.
When PRESERVE-POINT is non-nil, keep point near its current position after
rewriting the buffer."
  (let ((buffer (neo-lean-infoview--buffer)))
    (with-current-buffer buffer
      (unless (equal-including-properties string (buffer-string))
        (let ((inhibit-read-only t)
              (pos (point)))
          (erase-buffer)
          (insert string)
          (goto-char (if preserve-point
                         (min pos (point-max))
                       (point-min))))))
    buffer))

(defun neo-lean-infoview-display (string)
  "Set the goal buffer to STRING and pop it up in a side window."
  (display-buffer (neo-lean-infoview-update string)
                  neo-lean-infoview-display-action))

(defun neo-lean-infoview-hide ()
  "Hide all visible goal buffer windows.
Return non-nil when at least one window was hidden."
  (when-let* ((buffer (get-buffer neo-lean-infoview-buffer-name))
              (windows (get-buffer-window-list buffer nil t)))
    (dolist (window windows)
      (quit-window nil window))
    windows))

(defun neo-lean-infoview-visible-p ()
  "Return non-nil if the goal buffer is shown in some window."
  (when-let* ((buffer (get-buffer neo-lean-infoview-buffer-name)))
    (get-buffer-window buffer t)))

(provide 'neo-lean-infoview)
;;; neo-lean-infoview.el ends here
