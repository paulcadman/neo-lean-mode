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

(defvar-local leanmacs-infoview--source-buffer nil
  "The Lean source buffer whose goal is currently displayed here.")
(defvar-local leanmacs-infoview--source-pos nil
  "The text-document-position the displayed goal was fetched at.
Used to open an RPC session for interactive commands (e.g. go-to-definition)
issued from this buffer.")

(define-derived-mode leanmacs-infoview-mode special-mode "Leanmacs Goal"
  "Major mode for the Lean goal display buffer."
  (setq-local truncate-lines nil)
  (setq-local cursor-type nil))

(defun leanmacs-infoview-set-source (buffer pos)
  "Record BUFFER and POS as the source of the currently displayed goal.
POS is an LSP text-document-position plist.  Interactive commands in the
goal buffer use these to talk to the Lean server about the source document."
  (with-current-buffer (leanmacs-infoview--buffer)
    (setq leanmacs-infoview--source-buffer buffer
          leanmacs-infoview--source-pos pos)))

(defun leanmacs-infoview--buffer ()
  "Return the shared goal buffer, creating it if necessary."
  (or (get-buffer leanmacs-infoview-buffer-name)
      (with-current-buffer (get-buffer-create leanmacs-infoview-buffer-name)
        (leanmacs-infoview-mode)
        (current-buffer))))

(defun leanmacs-infoview-update (string)
  "Set the goal buffer contents to STRING and return the buffer.
Does not display the buffer.  No-ops when STRING is already shown, so
unchanged refreshes neither flicker nor reset the goal buffer's point."
  (let ((buffer (leanmacs-infoview--buffer)))
    (with-current-buffer buffer
      (unless (string= string (buffer-string))
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert string)
          (goto-char (point-min)))))
    buffer))

(defun leanmacs-infoview-display (string)
  "Set the goal buffer to STRING and pop it up in a side window."
  (display-buffer (leanmacs-infoview-update string)
                  leanmacs-infoview-display-action))

(defun leanmacs-infoview-visible-p ()
  "Return non-nil if the goal buffer is shown in some window."
  (when-let* ((buffer (get-buffer leanmacs-infoview-buffer-name)))
    (get-buffer-window buffer t)))

(provide 'leanmacs-infoview)
;;; leanmacs-infoview.el ends here
