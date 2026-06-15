;;; leanmacs-progress.el --- File-processing progress bars  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Lean elaborates files line by line and that can be slow, so the server
;; streams `$/lean/fileProgress' notifications telling us which line ranges
;; are still being processed.  This module shows that as an unobtrusive bar
;; in the left fringe (a `|' in the margin on terminals) on every line Lean
;; is still working on, clearing it as ranges finish.
;;
;; The notification is handled globally (it is not tied to the current
;; buffer); we resolve its URI to the visiting buffer and draw there, after
;; a short debounce so a burst of updates coalesces into one redraw.

;;; Code:

(require 'cl-lib)
(require 'eglot)

;; `eglot-uri-to-path' is the public name on Emacs 30+ (eglot 1.16); on 29.x
;; only the internal `eglot--uri-to-path' exists.  Pick whichever is present.
(defalias 'leanmacs-progress--uri-to-path
  (if (fboundp 'eglot-uri-to-path) 'eglot-uri-to-path 'eglot--uri-to-path)
  "Convert an LSP document URI to a local file path.")

;;;; Customization

(defcustom leanmacs-progress-enable t
  "When non-nil, show file-processing progress bars from the Lean server."
  :type 'boolean
  :group 'leanmacs)

(defcustom leanmacs-progress-character "|"
  "Character drawn in the left margin to mark a processing line.
Only used on terminals; graphical frames use a fringe bitmap instead."
  :type 'string
  :group 'leanmacs)

(defcustom leanmacs-progress-update-delay 0.1
  "Seconds to wait after a progress notification before redrawing.
Coalesces a burst of `$/lean/fileProgress' updates into a single redraw."
  :type 'number
  :group 'leanmacs)

(defface leanmacs-progress
  '((((background dark))  :foreground "orange")
    (((background light)) :foreground "dark orange")
    (t :foreground "orange"))
  "Face for the file-processing progress bar in the fringe or margin."
  :group 'leanmacs)

(when (fboundp 'define-fringe-bitmap)
  (define-fringe-bitmap 'leanmacs-progress-bitmap
    [#b00111000] nil nil '(center t)))

;;;; State (buffer-local)

(defvar-local leanmacs-progress--ranges nil
  "Latest `processing' ranges reported for this buffer, as a list of plists.")
(defvar-local leanmacs-progress--overlays nil
  "Overlays currently drawing the progress bar in this buffer.")
(defvar-local leanmacs-progress--timer nil
  "Pending debounce timer for a progress redraw in this buffer.")
(defvar-local leanmacs-progress--margin-added nil
  "Non-nil if we widened the left margin (terminal fallback) and must restore it.")

;;;; Pure logic

(defun leanmacs-progress--lines (ranges max-line)
  "Return the 0-based line numbers covered by RANGES, clamped to MAX-LINE.
RANGES is a list of plists as found in a `$/lean/fileProgress'
notification, each shaped (:range (:start (:line L ...) :end (:line L ...))
...).  The result is sorted and de-duplicated, marking every line from a
range's start through its end inclusive."
  (let ((lines '()))
    (dolist (info ranges)
      (let* ((range (plist-get info :range))
             (start (plist-get (plist-get range :start) :line))
             (end   (plist-get (plist-get range :end) :line)))
        (when (and (integerp start) (integerp end))
          (let ((line start)
                (last (min end max-line)))
            (while (<= line last)
              (push line lines)
              (setq line (1+ line)))))))
    (sort (delete-dups lines) #'<)))

;;;; Drawing

(defun leanmacs-progress--before-string ()
  "Return the overlay `before-string' that renders one progress mark."
  (if (display-graphic-p)
      (propertize " " 'display
                  '(left-fringe leanmacs-progress-bitmap leanmacs-progress))
    (propertize " " 'display
                `((margin left-margin)
                  ,(propertize leanmacs-progress-character
                               'face 'leanmacs-progress)))))

(defun leanmacs-progress--clear-overlays ()
  "Delete the progress overlays in the current buffer."
  (mapc #'delete-overlay leanmacs-progress--overlays)
  (setq leanmacs-progress--overlays nil))

(defun leanmacs-progress--ensure-margin ()
  "On a terminal, widen the left margin so the mark has somewhere to go."
  (unless (display-graphic-p)
    (when (< (or left-margin-width 0) 1)
      (setq leanmacs-progress--margin-added t
            left-margin-width 1)
      (dolist (win (get-buffer-window-list (current-buffer) nil t))
        (set-window-margins win left-margin-width right-margin-width)))))

(defun leanmacs-progress--redraw ()
  "Redraw the progress bar in the current buffer from `leanmacs-progress--ranges'."
  (leanmacs-progress--clear-overlays)
  (when leanmacs-progress-enable
    (let* ((max-line (1- (line-number-at-pos (point-max))))
           (lines (leanmacs-progress--lines leanmacs-progress--ranges max-line)))
      (when lines
        (leanmacs-progress--ensure-margin)
        (let ((before (leanmacs-progress--before-string)))
          (save-excursion
            (goto-char (point-min))
            (let ((cur 0))
              (dolist (line lines)
                (forward-line (- line cur))
                (setq cur line)
                (let ((ov (make-overlay (point) (point))))
                  (overlay-put ov 'leanmacs-progress t)
                  (overlay-put ov 'before-string before)
                  (push ov leanmacs-progress--overlays))))))))))

(defun leanmacs-progress--schedule ()
  "Schedule a debounced redraw of the current buffer's progress bar."
  (unless (timerp leanmacs-progress--timer)
    (let ((buf (current-buffer)))
      (setq leanmacs-progress--timer
            (run-with-timer
             leanmacs-progress-update-delay nil
             (lambda ()
               (when (buffer-live-p buf)
                 (with-current-buffer buf
                   (setq leanmacs-progress--timer nil)
                   (leanmacs-progress--redraw)))))))))

;;;; Public entry points

(defun leanmacs-progress-clear ()
  "Remove all progress bars from the current buffer and reset its state."
  (interactive)
  (when (timerp leanmacs-progress--timer)
    (cancel-timer leanmacs-progress--timer))
  (setq leanmacs-progress--timer nil
        leanmacs-progress--ranges nil)
  (leanmacs-progress--clear-overlays)
  (when leanmacs-progress--margin-added
    (setq leanmacs-progress--margin-added nil
          left-margin-width 0)
    (dolist (win (get-buffer-window-list (current-buffer) nil t))
      (set-window-margins win left-margin-width right-margin-width))))

(defun leanmacs-progress--buffer-for-uri (uri)
  "Return the live buffer visiting URI, or nil."
  (when (stringp uri)
    (let ((path (ignore-errors (leanmacs-progress--uri-to-path uri))))
      (and path (find-buffer-visiting path)))))

(defun leanmacs-progress--handle (uri processing)
  "Record PROCESSING ranges for URI's buffer and schedule a redraw."
  (when leanmacs-progress-enable
    (let ((buffer (leanmacs-progress--buffer-for-uri uri)))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          ;; Eglot delivers JSON arrays as vectors; normalise to a list.
          (setq leanmacs-progress--ranges (append processing nil))
          (leanmacs-progress--schedule))))))

;; Server-pushed progress.  Handled globally and routed to the visiting
;; buffer by URI -- the notification is not tied to the current buffer.
(cl-defmethod eglot-handle-notification
  (_server (_method (eql $/lean/fileProgress))
           &key textDocument processing &allow-other-keys)
  (leanmacs-progress--handle (plist-get textDocument :uri) processing))

;; Tear down when the server disconnects from a Lean buffer.
(defun leanmacs-progress--managed-hook ()
  "Clear progress bars when Eglot stops managing a Lean buffer."
  (when (and (derived-mode-p 'leanmacs-mode)
             (not (bound-and-true-p eglot-managed-mode)))
    (leanmacs-progress-clear)))

(add-hook 'eglot-managed-mode-hook #'leanmacs-progress--managed-hook)

(provide 'leanmacs-progress)
;;; leanmacs-progress.el ends here
