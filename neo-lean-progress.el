;;; neo-lean-progress.el --- File-processing progress bars  -*- lexical-binding: t; -*-

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
(require 'neo-lean-rpc)

;;;; Customization

(defcustom neo-lean-progress-enable t
  "When non-nil, show file-processing progress bars from the Lean server."
  :type 'boolean
  :group 'neo-lean)

(defcustom neo-lean-progress-character "|"
  "Character drawn in the left margin to mark a processing line.
Only used on terminals; graphical frames use a fringe bitmap instead."
  :type 'string
  :group 'neo-lean)

(defcustom neo-lean-progress-update-delay 0.1
  "Seconds to wait after a progress notification before redrawing.
Coalesces a burst of `$/lean/fileProgress' updates into a single redraw."
  :type 'number
  :group 'neo-lean)

(defface neo-lean-progress
  '((((background dark))  :foreground "orange")
    (((background light)) :foreground "dark orange")
    (t :foreground "orange"))
  "Face for the file-processing progress bar in the fringe or margin."
  :group 'neo-lean)

(when (fboundp 'define-fringe-bitmap)
  (define-fringe-bitmap 'neo-lean-progress-bitmap
    [#b00111000] nil nil '(center t)))

;;;; State (buffer-local)

(defvar-local neo-lean-progress--ranges nil
  "Latest `processing' ranges reported for this buffer, as a list of plists.")
(defvar-local neo-lean-progress--overlays nil
  "Overlays currently drawing the progress bar in this buffer.")
(defvar-local neo-lean-progress--timer nil
  "Pending debounce timer for a progress redraw in this buffer.")
(defvar-local neo-lean-progress--margin-added nil
  "Non-nil if we widened the left margin (terminal fallback) and must restore it.")

;;;; Pure logic

(defun neo-lean-progress--lines (ranges max-line)
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

(defun neo-lean-progress--before-string ()
  "Return the overlay `before-string' that renders one progress mark."
  (if (display-graphic-p)
      (propertize " " 'display
                  '(left-fringe neo-lean-progress-bitmap neo-lean-progress))
    (propertize " " 'display
                `((margin left-margin)
                  ,(propertize neo-lean-progress-character
                               'face 'neo-lean-progress)))))

(defun neo-lean-progress--clear-overlays ()
  "Delete the progress overlays in the current buffer."
  (mapc #'delete-overlay neo-lean-progress--overlays)
  (setq neo-lean-progress--overlays nil))

(defun neo-lean-progress--ensure-margin ()
  "On a terminal, widen the left margin so the mark has somewhere to go."
  (unless (display-graphic-p)
    (when (< (or left-margin-width 0) 1)
      (setq neo-lean-progress--margin-added t
            left-margin-width 1)
      (dolist (win (get-buffer-window-list (current-buffer) nil t))
        (set-window-margins win left-margin-width right-margin-width)))))

(defun neo-lean-progress--redraw ()
  "Redraw the progress bar in the current buffer from `neo-lean-progress--ranges'."
  (neo-lean-progress--clear-overlays)
  (when neo-lean-progress-enable
    (let* ((max-line (1- (line-number-at-pos (point-max))))
           (lines (neo-lean-progress--lines neo-lean-progress--ranges max-line)))
      (when lines
        (neo-lean-progress--ensure-margin)
        (let ((before (neo-lean-progress--before-string)))
          (save-excursion
            (goto-char (point-min))
            (let ((cur 0))
              (dolist (line lines)
                (forward-line (- line cur))
                (setq cur line)
                (let ((ov (make-overlay (point) (point))))
                  (overlay-put ov 'neo-lean-progress t)
                  (overlay-put ov 'before-string before)
                  (push ov neo-lean-progress--overlays))))))))))

(defun neo-lean-progress--schedule ()
  "Schedule a debounced redraw of the current buffer's progress bar."
  (unless (timerp neo-lean-progress--timer)
    (let ((buf (current-buffer)))
      (setq neo-lean-progress--timer
            (run-with-timer
             neo-lean-progress-update-delay nil
             (lambda ()
               (when (buffer-live-p buf)
                 (with-current-buffer buf
                   (setq neo-lean-progress--timer nil)
                   (neo-lean-progress--redraw)))))))))

;;;; Public entry points

(defun neo-lean-progress-clear ()
  "Remove all progress bars from the current buffer and reset its state."
  (interactive)
  (when (timerp neo-lean-progress--timer)
    (cancel-timer neo-lean-progress--timer))
  (setq neo-lean-progress--timer nil
        neo-lean-progress--ranges nil)
  (neo-lean-progress--clear-overlays)
  (when neo-lean-progress--margin-added
    (setq neo-lean-progress--margin-added nil
          left-margin-width 0)
    (dolist (win (get-buffer-window-list (current-buffer) nil t))
      (set-window-margins win left-margin-width right-margin-width))))

(defun neo-lean-progress--buffer-for-uri (uri)
  "Return the live buffer visiting URI, or nil."
  (when (stringp uri)
    (let ((path (ignore-errors (neo-lean-uri-to-path uri))))
      (and path (find-buffer-visiting path)))))

(defun neo-lean-progress--handle (uri processing)
  "Record PROCESSING ranges for URI's buffer and schedule a redraw."
  (when neo-lean-progress-enable
    (let ((buffer (neo-lean-progress--buffer-for-uri uri)))
      (when (buffer-live-p buffer)
        (with-current-buffer buffer
          ;; Eglot delivers JSON arrays as vectors; normalise to a list.
          (setq neo-lean-progress--ranges (append processing nil))
          (neo-lean-progress--schedule))))))

;; Server-pushed progress.  Handled globally and routed to the visiting
;; buffer by URI -- the notification is not tied to the current buffer.
(cl-defmethod eglot-handle-notification
  (_server (_method (eql $/lean/fileProgress))
           &key textDocument processing &allow-other-keys)
  (neo-lean-progress--handle (plist-get textDocument :uri) processing))

;; Tear down when the server disconnects from a Lean buffer.
(defun neo-lean-progress--managed-hook ()
  "Clear progress bars when Eglot stops managing a Lean buffer."
  (when (and (derived-mode-p 'neo-lean-mode)
             (not (bound-and-true-p eglot-managed-mode)))
    (neo-lean-progress-clear)))

(add-hook 'eglot-managed-mode-hook #'neo-lean-progress--managed-hook)

(provide 'neo-lean-progress)
;;; neo-lean-progress.el ends here
