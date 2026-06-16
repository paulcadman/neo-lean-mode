;;; neo-lean-input.el --- Unicode abbreviation input for Lean  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean, i18n
;; Package-Requires: ((emacs "29.1"))
;; URL: https://github.com/janmasrovira/neo-lean-mode
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; A Quail input method that lets you type the Unicode symbols common in
;; Lean 4 by entering a backslash followed by an abbreviation:
;;
;;   \alpha  -> α      \to   -> →       \and -> ∧
;;   \<>     -> ⟨⟩     \norm -> ‖‖      \\   -> \
;;
;; For bracket-style abbreviations the expansion leaves point between the
;; delimiters (shown above as the cursor sitting inside ⟨⟩ and ‖‖).
;;
;; The translation table is generated at load time from
;; `data/abbreviations.json', vendored from leanprover/vscode-lean4
;; (Apache-2.0; see the NOTICE file).  Entries whose expansion contains the
;; `$CURSOR' marker (mostly matching delimiter pairs) are registered so that
;; point lands where the marker was, via Quail's per-rule `advice' feature.
;;
;; The method is named "Neo-Lean".  `neo-lean-mode' activates it in each
;; buffer unless `neo-lean-input-enable' is nil; you can also turn it on
;; anywhere with `M-x set-input-method RET Neo-Lean'.

;;; Code:

(require 'quail)
(require 'subr-x)

;; Declared for the `json-read' fallback used on Emacs built without native
;; JSON support (`json-parse-buffer' is preferred when available).
(defvar json-object-type)
(defvar json-key-type)
(defvar json-array-type)
(declare-function json-read "json")

(defconst neo-lean-input-method-name "Neo-Lean"
  "Name of the Quail input method for Lean.")

(defconst neo-lean-input--cursor-marker "$CURSOR"
  "Marker in an expansion indicating where point should land after insertion.")

(defcustom neo-lean-input-enable t
  "When non-nil, `neo-lean-mode' activates the Neo-Lean input method.
Disable this if you prefer to manage the input method yourself, e.g. with
`set-input-method'."
  :type 'boolean
  :group 'neo-lean)

(defcustom neo-lean-input-data-file
  (expand-file-name
   "data/abbreviations.json"
   (file-name-directory (or load-file-name buffer-file-name default-directory)))
  "Path to the JSON file mapping abbreviations to their Unicode expansions.
Keys omit the leading backslash; an expansion may contain the `$CURSOR'
marker to request a specific point position after insertion.  After
changing this you must call `neo-lean-input-setup' to rebuild the method."
  :type 'file
  :group 'neo-lean)

(defun neo-lean-input--read-abbreviations ()
  "Read `neo-lean-input-data-file' into a hash table of KEY -> EXPANSION.
Both keys and values are strings; keys omit the leading backslash."
  (with-temp-buffer
    (insert-file-contents neo-lean-input-data-file)
    (goto-char (point-min))
    (if (fboundp 'json-parse-buffer)
        (json-parse-buffer :object-type 'hash-table
                           :array-type 'list
                           :null-object nil)
      (require 'json)
      (let ((json-object-type 'hash-table)
            (json-key-type 'string)
            (json-array-type 'list))
        (json-read)))))

(defun neo-lean-input--translation (expansion)
  "Return the Quail translation string for EXPANSION.
If EXPANSION contains `neo-lean-input--cursor-marker', the marker is
removed and the returned string carries an `advice' property that moves
point back to the marker's position once Quail has inserted it."
  (if (string-search neo-lean-input--cursor-marker expansion)
      (let* ((parts  (split-string expansion
                                   (regexp-quote neo-lean-input--cursor-marker)))
             (clean  (string-join parts))
             ;; Characters to the right of the marker = how far to back up.
             (offset (length (string-join (cdr parts)))))
        (if (> offset 0)
            (propertize clean 'advice (lambda (_s) (backward-char offset)))
          clean))
    expansion))

;;;###autoload
(defun neo-lean-input-setup ()
  "Define (or rebuild) the Neo-Lean Quail input method.
Reads `neo-lean-input-data-file' and registers a rule \"\\KEY\" for every
abbreviation KEY in it."
  (interactive)
  ;; (Re)create the package.  The trailing t enables `maximum-shortest', so
  ;; the longest matching abbreviation wins (e.g. \to vs \top).
  (with-temp-buffer
    (quail-define-package
     neo-lean-input-method-name "UTF-8" "λ" t
     "Neo-Lean input method for Lean 4.
Type a backslash followed by an abbreviation to insert a Unicode symbol,
for example \\alpha for α, \\to for →, or \\<> for ⟨⟩ (point lands between
the brackets).  Run `M-x quail-help' for the full table."
     nil nil nil nil nil nil nil t))
  (with-temp-buffer
    (maphash
     (lambda (key expansion)
       (when (and (stringp key) (not (string-empty-p key)) (stringp expansion))
         (quail-defrule (concat "\\" key)
                        (vector (neo-lean-input--translation expansion))
                        neo-lean-input-method-name t)))
     (neo-lean-input--read-abbreviations))))

;; Build the method when this file is loaded, mirroring how Quail packages
;; register themselves on load.
(neo-lean-input-setup)

;;;###autoload
(defun neo-lean-input-activate ()
  "Activate the Neo-Lean input method in the current buffer."
  (interactive)
  (activate-input-method neo-lean-input-method-name))

(provide 'neo-lean-input)
;;; neo-lean-input.el ends here
