;;; leanmacs-render.el --- Render interactive goals to text  -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Jan Mas Rovira

;; Author: Jan Mas Rovira <janmasrovira@gmail.com>
;; Keywords: languages, lean
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Pure rendering of Lean's interactive goal data structures to plain text.
;; These functions take the plists/vectors that Eglot's JSON parser produces
;; (objects -> keyword plists, arrays -> vectors) and have no side effects, so
;; they are unit-testable without a running server.
;;
;; In this milestone the `tag' payloads of `TaggedText'/`CodeWithInfos' (which
;; carry subexpression info for clickable goals) are dropped -- only the text
;; leaves are concatenated.  A later milestone will turn those tags into Emacs
;; text properties for an interactive infoview.

;;; Code:

(require 'seq)

(defconst leanmacs-render-default-goal-prefix "⊢ "
  "Symbol shown before a goal's target type when none is provided.")

(defun leanmacs-render-tagged-text (tt)
  "Flatten a `TaggedText' (or `CodeWithInfos') TT to a string.
TT is one of: (:text STRING), (:append [TT...]) or (:tag [PAYLOAD TT]).
Tag payloads are ignored for now; only text leaves are kept."
  (cond
   ((null tt) "")
   ((stringp tt) tt)
   ((plist-member tt :text)
    (or (plist-get tt :text) ""))
   ((plist-member tt :append)
    (mapconcat #'leanmacs-render-tagged-text (plist-get tt :append) ""))
   ((plist-member tt :tag)
    ;; (:tag [PAYLOAD INNER]) -- render only the inner TaggedText.
    (leanmacs-render-tagged-text (seq-elt (plist-get tt :tag) 1)))
   (t "")))

(defun leanmacs-render--hypothesis (hyp)
  "Render one `InteractiveHypothesisBundle' HYP to a string.
Bundled names share a type, e.g. \"a b : Nat\"; let-binders also show
their value after \":=\"."
  (let* ((names (string-join (append (plist-get hyp :names) nil) " "))
         (type (leanmacs-render-tagged-text (plist-get hyp :type)))
         (val (plist-get hyp :val))
         (base (format "%s : %s" names type)))
    (if val
        (format "%s := %s" base (leanmacs-render-tagged-text val))
      base)))

(defun leanmacs-render-goal (goal)
  "Render one interactive GOAL to a string.
Shows an optional case name, the hypotheses, and the target type prefixed
by the goal's `goalPrefix' (default `leanmacs-render-default-goal-prefix')."
  (let ((lines '())
        (user-name (plist-get goal :userName))
        (prefix (or (plist-get goal :goalPrefix) leanmacs-render-default-goal-prefix)))
    (when (and user-name (not (string-empty-p user-name)))
      (push (format "case %s" user-name) lines))
    (seq-doseq (hyp (plist-get goal :hyps))
      (push (leanmacs-render--hypothesis hyp) lines))
    (push (concat prefix (leanmacs-render-tagged-text (plist-get goal :type))) lines)
    (string-join (nreverse lines) "\n")))

(defun leanmacs-render-goals (goals)
  "Render the vector of interactive GOALS to a string.
Returns \"No goals.\" when GOALS is empty."
  (if (seq-empty-p goals)
      "No goals."
    (mapconcat #'leanmacs-render-goal goals "\n\n")))

(provide 'leanmacs-render)
;;; leanmacs-render.el ends here
