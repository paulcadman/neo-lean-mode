;;; leanmacs-render-test.el --- Tests for leanmacs-render and leanmacs-rpc  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Batch ERT tests for the pure parts of lean-emacs: TaggedText flattening,
;; goal rendering, and RPC wire-format detection.  No Lean server required.
;;
;; Run with:
;;   emacs -Q --batch -L . -l test/leanmacs-render-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'leanmacs-render)
(require 'leanmacs-rpc)

;;;; TaggedText flattening

(ert-deftest leanmacs-render-tagged-text-leaf ()
  (should (equal (leanmacs-render-tagged-text '(:text "hello")) "hello")))

(ert-deftest leanmacs-render-tagged-text-nil ()
  (should (equal (leanmacs-render-tagged-text nil) "")))

(ert-deftest leanmacs-render-tagged-text-append ()
  ;; arrays come back from the JSON parser as vectors
  (should (equal (leanmacs-render-tagged-text
                  (list :append (vector '(:text "a") '(:text "b") '(:text "c"))))
                 "abc")))

(ert-deftest leanmacs-render-tagged-text-tag-ignores-payload ()
  ;; (:tag [PAYLOAD INNER]) -- payload dropped, inner rendered.
  (should (equal (leanmacs-render-tagged-text
                  (list :tag (vector '(:info "ignored") '(:text "Nat"))))
                 "Nat")))

(ert-deftest leanmacs-render-tagged-text-nested ()
  (let ((tt (list :append
                  (vector
                   '(:text "f ")
                   (list :tag (vector '(:info "x") '(:text "x")))
                   '(:text " ")
                   (list :append (vector '(:text "(") '(:text "y") '(:text ")")))))))
    (should (equal (leanmacs-render-tagged-text tt) "f x (y)"))))

;;;; Goal rendering

(ert-deftest leanmacs-render-goal-simple ()
  (let ((goal (list :hyps (vector (list :names (vector "a" "b")
                                        :type '(:text "Nat")))
                    :type '(:text "a = b"))))
    (should (equal (leanmacs-render-goal goal)
                   "a b : Nat\n⊢ a = b"))))

(ert-deftest leanmacs-render-goal-case-and-let ()
  (let ((goal (list :userName "succ"
                    :goalPrefix "⊢ "
                    :hyps (vector (list :names (vector "n")
                                        :type '(:text "Nat")
                                        :val '(:text "0")))
                    :type '(:text "P n"))))
    (should (equal (leanmacs-render-goal goal)
                   "case succ\nn : Nat := 0\n⊢ P n"))))

(ert-deftest leanmacs-render-goals-empty ()
  (should (equal (leanmacs-render-goals (vector)) "No goals."))
  (should (equal (leanmacs-render-goals nil) "No goals.")))

(ert-deftest leanmacs-render-goals-multiple ()
  (let ((goals (vector (list :hyps (vector) :type '(:text "A"))
                       (list :hyps (vector) :type '(:text "B")))))
    (should (equal (leanmacs-render-goals goals) "⊢ A\n\n⊢ B"))))

;;;; Term goal / combined state

(ert-deftest leanmacs-render-term-goal-nil ()
  (should (null (leanmacs-render-term-goal nil))))

(ert-deftest leanmacs-render-term-goal-simple ()
  (let ((term (list :hyps (vector (list :names (vector "n")
                                        :type '(:text "Nat")))
                    :type '(:text "Nat"))))
    (should (equal (leanmacs-render-term-goal term)
                   "Expected type:\nn : Nat\n⊢ Nat"))))

(ert-deftest leanmacs-render-state-goals-only ()
  (let ((goals (vector (list :hyps (vector) :type '(:text "A")))))
    (should (equal (leanmacs-render-state goals nil) "⊢ A"))))

(ert-deftest leanmacs-render-state-term-only ()
  ;; In term mode there are no tactic goals; only the expected type shows.
  (let ((term (list :hyps (vector) :type '(:text "Nat"))))
    (should (equal (leanmacs-render-state (vector) term)
                   "Expected type:\n⊢ Nat"))))

(ert-deftest leanmacs-render-state-both ()
  (let ((goals (vector (list :hyps (vector) :type '(:text "A"))))
        (term (list :hyps (vector) :type '(:text "Nat"))))
    (should (equal (leanmacs-render-state goals term)
                   "⊢ A\n\nExpected type:\n⊢ Nat"))))

(ert-deftest leanmacs-render-state-empty ()
  (should (equal (leanmacs-render-state (vector) nil) "No goals."))
  (should (equal (leanmacs-render-state nil nil) "No goals.")))

;;;; RPC wire-format / dead-code detection

(ert-deftest leanmacs-rpc-dead-code-p ()
  (should (leanmacs-rpc--dead-code-p -32900))
  (should (leanmacs-rpc--dead-code-p -32801))
  (should (leanmacs-rpc--dead-code-p -32901))
  (should (leanmacs-rpc--dead-code-p -32902))
  (should-not (leanmacs-rpc--dead-code-p -32602))
  (should-not (leanmacs-rpc--dead-code-p nil)))

;; `leanmacs-rpc--ref-key' reads from an eglot connection's capabilities.  We
;; fake that accessor to test the wire-format mapping in isolation.
(ert-deftest leanmacs-rpc-ref-key-v1 ()
  (cl-letf (((symbol-function 'eglot--capabilities)
             (lambda (_) '(:experimental (:rpcProvider (:rpcWireFormat "v1"))))))
    (should (equal (leanmacs-rpc--ref-key 'fake) "__rpcref"))))

(ert-deftest leanmacs-rpc-ref-key-v0-default ()
  (cl-letf (((symbol-function 'eglot--capabilities)
             (lambda (_) '(:experimental (:rpcProvider (:rpcWireFormat "v0"))))))
    (should (equal (leanmacs-rpc--ref-key 'fake) "p")))
  (cl-letf (((symbol-function 'eglot--capabilities)
             (lambda (_) '())))
    (should (equal (leanmacs-rpc--ref-key 'fake) "p"))))

(provide 'leanmacs-render-test)
;;; leanmacs-render-test.el ends here
