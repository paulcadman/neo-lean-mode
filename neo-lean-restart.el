;;; neo-lean-restart.el --- Restart a Lean file to reload its imports  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; A Lean file worker loads its imports once, when the document is opened, and
;; keeps them for its lifetime.  When a dependency changes the worker goes on
;; using the old imports until the file is reopened; the server flags this with
;; an "Imports are out of date" error diagnostic at the top of the file.
;;
;; `neo-lean-restart-file' reopens the document on the server -- a
;; `textDocument/didClose' followed by a `textDocument/didOpen' carrying Lean's
;; `dependencyBuildMode' "once", so the dependencies are rebuilt once and the
;; imports reloaded.  Eglot's own didClose/didOpen are reused so its
;; document-version bookkeeping (`eglot--docver', pending changes) stays
;; consistent; we only decorate the opened item with the extra Lean field.
;;
;; When `neo-lean-prompt-on-stale-imports' is non-nil we watch incoming
;; diagnostics and offer to run the restart automatically, mirroring the
;; server's own "Restart File" hint.

;;; Code:

(require 'cl-lib)
(require 'seq)
(require 'eglot)
(require 'neo-lean-rpc)

(defcustom neo-lean-prompt-on-stale-imports t
  "When non-nil, offer to restart the file when the server reports stale imports.
Lean emits an error diagnostic when an open file's imports are out of date
\(a dependency changed and was rebuilt); enabling this prompts you to run
`neo-lean-restart-file'.  When nil the diagnostic still shows but no prompt
appears."
  :type 'boolean
  :group 'neo-lean)

(defvar-local neo-lean--imports-out-of-date nil
  "Non-nil once the server reported this buffer's imports are out of date.
Latched so the restart is offered only once until the condition clears.")

;;;###autoload
(defun neo-lean-restart-file ()
  "Restart the Lean file worker for this buffer, rebuilding and reloading imports.
Reopens the document on the Lean server (a `textDocument/didClose' then
`didOpen') with `dependencyBuildMode' \"once\", so the file's dependencies are
rebuilt once and its imports reloaded.  Use after a dependency changed and the
server reports its imports are out of date."
  (interactive)
  (unless (derived-mode-p 'neo-lean-mode)
    (user-error "Not in a Lean buffer"))
  (eglot--current-server-or-lose)
  ;; Let Eglot perform its own didClose/didOpen so its document-version counter
  ;; (`eglot--docver') and pending-change state stay consistent; only decorate
  ;; the opened `TextDocumentItem' with Lean's `dependencyBuildMode'.
  (eglot--signal-textDocument/didClose)
  (cl-letf* ((orig (symbol-function 'eglot--TextDocumentItem))
             ((symbol-function 'eglot--TextDocumentItem)
              (lambda (&rest args)
                (append (apply orig args) (list :dependencyBuildMode "once")))))
    (eglot--signal-textDocument/didOpen))
  (setq neo-lean--imports-out-of-date nil)
  (message "neo-lean: restarting file (rebuilding imports)..."))

;;;; Detect the server's "imports out of date" diagnostic and offer a restart

(defun neo-lean--imports-out-of-date-p (diagnostic)
  "Return non-nil if DIAGNOSTIC is Lean's \"imports out of date\" error.
DIAGNOSTIC is an LSP `Diagnostic' plist.  Matches an error at the very top of
the file whose message Lean uses for this condition."
  (let ((start (plist-get (plist-get diagnostic :range) :start))
        (msg (plist-get diagnostic :message)))
    (and (eql (plist-get diagnostic :severity) 1) ; DiagnosticSeverity.Error
         (stringp msg)
         (string-prefix-p "Imports are out of date and must be rebuilt" msg)
         (eql (plist-get start :line) 0)
         (eql (plist-get start :character) 0))))

(defconst neo-lean--imports-out-of-date-message
  "Imports are out of date and must be rebuilt.  \
Run M-x neo-lean-restart-file to reload them."
  "Diagnostic message shown when a file's imports are out of date.
Replaces the server's generic \"Restart File\" hint with the real command.")

(defun neo-lean--offer-restart (buffer)
  "Ask whether to restart BUFFER's Lean file to reload its imports."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (and neo-lean--imports-out-of-date
                 (y-or-n-p "Lean: imports are out of date; run neo-lean-restart-file now? "))
        (neo-lean-restart-file)))))

(cl-defmethod eglot-handle-notification :before
  (_server (_method (eql textDocument/publishDiagnostics))
           &key diagnostics &allow-other-keys)
  (seq-doseq (diag diagnostics)
    (when (neo-lean--imports-out-of-date-p diag)
      (plist-put diag :message neo-lean--imports-out-of-date-message))))

;; Watch diagnostics for the stale-imports report.  An `:after' method augments
;; Eglot's own publishDiagnostics handling without replacing it.  The prompt is
;; deferred off the notification handler (which runs in the connection's process
;; filter) with a zero-delay timer so it neither blocks nor reenters the server.
(cl-defmethod eglot-handle-notification :after
  (_server (_method (eql textDocument/publishDiagnostics))
           &key uri diagnostics &allow-other-keys)
  (when neo-lean-prompt-on-stale-imports
    (when-let* ((path (ignore-errors (neo-lean-uri-to-path uri)))
                (buffer (find-buffer-visiting path)))
      (with-current-buffer buffer
        (when (derived-mode-p 'neo-lean-mode)
          (let ((stale (seq-some #'neo-lean--imports-out-of-date-p diagnostics)))
            (cond
             ((and stale (not neo-lean--imports-out-of-date))
              (setq neo-lean--imports-out-of-date t)
              (run-with-timer 0 nil #'neo-lean--offer-restart buffer))
             ((not stale)
              (setq neo-lean--imports-out-of-date nil)))))))))

(provide 'neo-lean-restart)
;;; neo-lean-restart.el ends here
