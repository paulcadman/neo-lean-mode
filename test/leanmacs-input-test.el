;;; leanmacs-input-test.el --- Tests for leanmacs-input  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Batch ERT tests for the Unicode input method.  Covers the pure
;; translation helper (including `$CURSOR' handling) and a smoke test that
;; the Quail method builds from the vendored data file.  No Lean server
;; required.
;;
;; Run with:
;;   emacs -Q --batch -L . -l test/leanmacs-input-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'quail)
(require 'leanmacs-input)

;;;; Pure translation helper

(ert-deftest leanmacs-input-translation-plain ()
  "A marker-free expansion is returned unchanged and unpropertized."
  (let ((s (leanmacs-input--translation "α")))
    (should (equal s "α"))
    (should-not (get-text-property 0 'advice s))))

(ert-deftest leanmacs-input-translation-cursor-strips-marker ()
  "The $CURSOR marker is removed from the inserted text."
  (should (equal (substring-no-properties
                  (leanmacs-input--translation "⟨$CURSOR⟩"))
                 "⟨⟩")))

(ert-deftest leanmacs-input-translation-cursor-advice-moves-point ()
  "The advice closure leaves point where $CURSOR was."
  (let ((s (leanmacs-input--translation "⟨$CURSOR⟩")))
    (with-temp-buffer
      (insert s)
      (funcall (get-text-property 0 'advice s) s)
      (should (equal (buffer-substring-no-properties (point-min) (point)) "⟨"))
      (should (equal (buffer-substring-no-properties (point) (point-max)) "⟩")))))

(ert-deftest leanmacs-input-translation-cursor-multichar-suffix ()
  "Offset counts characters, so multi-char suffixes land point correctly."
  (let ((s (leanmacs-input--translation "‖$CURSOR‖₊")))
    (should (equal (substring-no-properties s) "‖‖₊"))
    (with-temp-buffer
      (insert s)
      (funcall (get-text-property 0 'advice s) s)
      ;; point sits between the two bars, before the trailing "‖₊".
      (should (equal (buffer-substring-no-properties (point-min) (point)) "‖"))
      (should (equal (buffer-substring-no-properties (point) (point-max)) "‖₊")))))

(ert-deftest leanmacs-input-translation-trailing-marker ()
  "A $CURSOR at the very end yields no advice (offset 0)."
  (let ((s (leanmacs-input--translation "foo$CURSOR")))
    (should (equal s "foo"))
    (should-not (get-text-property 0 'advice s))))

;;;; Building the method from real data

(ert-deftest leanmacs-input-setup-builds-package ()
  "`leanmacs-input-setup' registers the package and known rules."
  (leanmacs-input-setup)
  (should (assoc leanmacs-input-method-name quail-package-alist))
  (let ((quail-current-package
         (assoc leanmacs-input-method-name quail-package-alist)))
    ;; \to -> → (single char, stored directly as the char).
    (should (eq (quail-map-definition (quail-lookup-key "\\to" 3)) ?→))
    ;; \alpha -> α.
    (should (eq (quail-map-definition (quail-lookup-key "\\alpha" 6)) ?α))
    ;; \\ -> \ (escaped leader).
    (should (eq (quail-map-definition (quail-lookup-key "\\\\" 2)) ?\\))
    ;; \<> -> ⟨⟩ with a cursor-placing advice.
    (let* ((def (quail-map-definition (quail-lookup-key "\\<>" 3)))
           (str (aref (cdr def) 0)))
      (should (equal (substring-no-properties str) "⟨⟩"))
      (should (functionp (get-text-property 0 'advice str))))))

(provide 'leanmacs-input-test)
;;; leanmacs-input-test.el ends here
