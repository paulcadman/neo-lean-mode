;;; lean-render-test.el --- Tests for lean-render and lean-rpc  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Batch ERT tests for the pure parts of lean-emacs: TaggedText flattening,
;; goal rendering, and RPC wire-format detection.  No Lean server required.
;;
;; Run with:
;;   emacs -Q --batch -L . -l test/lean-render-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'lean-render)
(require 'lean-rpc)

;;;; TaggedText flattening

(ert-deftest lean-render-tagged-text-leaf ()
  (should (equal (lean-render-tagged-text '(:text "hello")) "hello")))

(ert-deftest lean-render-tagged-text-nil ()
  (should (equal (lean-render-tagged-text nil) "")))

(ert-deftest lean-render-tagged-text-append ()
  ;; arrays come back from the JSON parser as vectors
  (should (equal (lean-render-tagged-text
                  (list :append (vector '(:text "a") '(:text "b") '(:text "c"))))
                 "abc")))

(ert-deftest lean-render-tagged-text-tag-ignores-payload ()
  ;; (:tag [PAYLOAD INNER]) -- payload dropped, inner rendered.
  (should (equal (lean-render-tagged-text
                  (list :tag (vector '(:info "ignored") '(:text "Nat"))))
                 "Nat")))

(ert-deftest lean-render-tagged-text-nested ()
  (let ((tt (list :append
                  (vector
                   '(:text "f ")
                   (list :tag (vector '(:info "x") '(:text "x")))
                   '(:text " ")
                   (list :append (vector '(:text "(") '(:text "y") '(:text ")")))))))
    (should (equal (lean-render-tagged-text tt) "f x (y)"))))

;;;; Goal rendering

(ert-deftest lean-render-goal-simple ()
  (let ((goal (list :hyps (vector (list :names (vector "a" "b")
                                        :type '(:text "Nat")))
                    :type '(:text "a = b"))))
    (should (equal (lean-render-goal goal)
                   "a b : Nat\n⊢ a = b"))))

(ert-deftest lean-render-goal-case-and-let ()
  (let ((goal (list :userName "succ"
                    :goalPrefix "⊢ "
                    :hyps (vector (list :names (vector "n")
                                        :type '(:text "Nat")
                                        :val '(:text "0")))
                    :type '(:text "P n"))))
    (should (equal (lean-render-goal goal)
                   "case succ\nn : Nat := 0\n⊢ P n"))))

(ert-deftest lean-render-goals-empty ()
  (should (equal (lean-render-goals (vector)) "No goals."))
  (should (equal (lean-render-goals nil) "No goals.")))

(ert-deftest lean-render-goals-multiple ()
  (let ((goals (vector (list :hyps (vector) :type '(:text "A"))
                       (list :hyps (vector) :type '(:text "B")))))
    (should (equal (lean-render-goals goals) "⊢ A\n\n⊢ B"))))

;;;; RPC wire-format / dead-code detection

(ert-deftest lean-rpc-dead-code-p ()
  (should (lean-rpc--dead-code-p -32900))
  (should (lean-rpc--dead-code-p -32801))
  (should (lean-rpc--dead-code-p -32901))
  (should (lean-rpc--dead-code-p -32902))
  (should-not (lean-rpc--dead-code-p -32602))
  (should-not (lean-rpc--dead-code-p nil)))

;; `lean-rpc--ref-key' reads from an eglot connection's capabilities.  We
;; fake that accessor to test the wire-format mapping in isolation.
(ert-deftest lean-rpc-ref-key-v1 ()
  (cl-letf (((symbol-function 'eglot--capabilities)
             (lambda (_) '(:experimental (:rpcProvider (:rpcWireFormat "v1"))))))
    (should (equal (lean-rpc--ref-key 'fake) "__rpcref"))))

(ert-deftest lean-rpc-ref-key-v0-default ()
  (cl-letf (((symbol-function 'eglot--capabilities)
             (lambda (_) '(:experimental (:rpcProvider (:rpcWireFormat "v0"))))))
    (should (equal (lean-rpc--ref-key 'fake) "p")))
  (cl-letf (((symbol-function 'eglot--capabilities)
             (lambda (_) '())))
    (should (equal (lean-rpc--ref-key 'fake) "p"))))

(provide 'lean-render-test)
;;; lean-render-test.el ends here
