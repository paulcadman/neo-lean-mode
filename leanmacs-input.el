;;; leanmacs-input.el --- Unicode abbreviation input for Lean  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean, i18n
;; Package-Requires: ((emacs "29.1"))
;; URL: https://github.com/janmasrovira/lean-emacs
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
;; The method is named "Leanmacs".  `leanmacs-mode' activates it in each
;; buffer unless `leanmacs-input-enable' is nil; you can also turn it on
;; anywhere with `M-x set-input-method RET Leanmacs'.

;;; Code:

(require 'quail)
(require 'subr-x)

;; Declared for the `json-read' fallback used on Emacs built without native
;; JSON support (`json-parse-buffer' is preferred when available).
(defvar json-object-type)
(defvar json-key-type)
(defvar json-array-type)
(declare-function json-read "json")

(defconst leanmacs-input-method-name "Leanmacs"
  "Name of the Quail input method for Lean.")

(defconst leanmacs-input--cursor-marker "$CURSOR"
  "Marker in an expansion indicating where point should land after insertion.")

(defcustom leanmacs-input-enable t
  "When non-nil, `leanmacs-mode' activates the Leanmacs input method.
Disable this if you prefer to manage the input method yourself, e.g. with
`set-input-method'."
  :type 'boolean
  :group 'leanmacs)

(defcustom leanmacs-input-data-file
  (expand-file-name
   "data/abbreviations.json"
   (file-name-directory (or load-file-name buffer-file-name default-directory)))
  "Path to the JSON file mapping abbreviations to their Unicode expansions.
Keys omit the leading backslash; an expansion may contain the `$CURSOR'
marker to request a specific point position after insertion.  After
changing this you must call `leanmacs-input-setup' to rebuild the method."
  :type 'file
  :group 'leanmacs)

(defun leanmacs-input--read-abbreviations ()
  "Read `leanmacs-input-data-file' into a hash table of KEY -> EXPANSION.
Both keys and values are strings; keys omit the leading backslash."
  (with-temp-buffer
    (insert-file-contents leanmacs-input-data-file)
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

(defun leanmacs-input--translation (expansion)
  "Return the Quail translation string for EXPANSION.
If EXPANSION contains `leanmacs-input--cursor-marker', the marker is
removed and the returned string carries an `advice' property that moves
point back to the marker's position once Quail has inserted it."
  (if (string-search leanmacs-input--cursor-marker expansion)
      (let* ((parts  (split-string expansion
                                   (regexp-quote leanmacs-input--cursor-marker)))
             (clean  (string-join parts))
             ;; Characters to the right of the marker = how far to back up.
             (offset (length (string-join (cdr parts)))))
        (if (> offset 0)
            (propertize clean 'advice (lambda (_s) (backward-char offset)))
          clean))
    expansion))

;;;###autoload
(defun leanmacs-input-setup ()
  "Define (or rebuild) the Leanmacs Quail input method.
Reads `leanmacs-input-data-file' and registers a rule \"\\KEY\" for every
abbreviation KEY in it."
  (interactive)
  ;; (Re)create the package.  The trailing t enables `maximum-shortest', so
  ;; the longest matching abbreviation wins (e.g. \to vs \top).
  (with-temp-buffer
    (quail-define-package
     leanmacs-input-method-name "UTF-8" "λ" t
     "Leanmacs input method for Lean 4.
Type a backslash followed by an abbreviation to insert a Unicode symbol,
for example \\alpha for α, \\to for →, or \\<> for ⟨⟩ (point lands between
the brackets).  Run `M-x quail-help' for the full table."
     nil nil nil nil nil nil nil t))
  (with-temp-buffer
    (maphash
     (lambda (key expansion)
       (when (and (stringp key) (not (string-empty-p key)) (stringp expansion))
         (quail-defrule (concat "\\" key)
                        (vector (leanmacs-input--translation expansion))
                        leanmacs-input-method-name t)))
     (leanmacs-input--read-abbreviations))))

;; Build the method when this file is loaded, mirroring how Quail packages
;; register themselves on load.
(leanmacs-input-setup)

;;;###autoload
(defun leanmacs-input-activate ()
  "Activate the Leanmacs input method in the current buffer."
  (interactive)
  (activate-input-method leanmacs-input-method-name))

(provide 'leanmacs-input)
;;; leanmacs-input.el ends here
