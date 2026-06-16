;;; neo-lean-progress-test.el --- Tests for neo-lean-progress  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Batch ERT tests for the file-progress logic.  Covers the pure mapping
;; from `$/lean/fileProgress' ranges to the set of lines to mark, including
;; clamping, multiple/overlapping ranges, and malformed input.  The drawing
;; side (fringe/margin overlays) needs a live frame and is not tested here.
;;
;; Run with:
;;   emacs -Q --batch -L . -l test/neo-lean-progress-test.el \
;;         -f ert-run-tests-batch-and-exit

;;; Code:

(require 'ert)
(require 'neo-lean-progress)

(defun neo-lean-progress-test--range (start end &optional kind)
  "Build a processing-info plist spanning lines START..END (0-based)."
  (list :range (list :start (list :line start :character 0)
                     :end   (list :line end   :character 0))
        :kind (or kind 1)))

(ert-deftest neo-lean-progress-lines-single ()
  "A single range yields every line from start through end inclusive."
  (should (equal (neo-lean-progress--lines
                  (list (neo-lean-progress-test--range 2 4)) 100)
                 '(2 3 4))))

(ert-deftest neo-lean-progress-lines-clamped ()
  "Lines past the buffer's last line are dropped."
  (should (equal (neo-lean-progress--lines
                  (list (neo-lean-progress-test--range 8 20)) 10)
                 '(8 9 10))))

(ert-deftest neo-lean-progress-lines-merges-and-sorts ()
  "Multiple, out-of-order, overlapping ranges merge into one sorted set."
  (should (equal (neo-lean-progress--lines
                  (list (neo-lean-progress-test--range 5 6)
                        (neo-lean-progress-test--range 1 2)
                        (neo-lean-progress-test--range 2 3))
                  100)
                 '(1 2 3 5 6))))

(ert-deftest neo-lean-progress-lines-empty ()
  "No ranges means no lines."
  (should (equal (neo-lean-progress--lines nil 100) '())))

(ert-deftest neo-lean-progress-lines-ignores-malformed ()
  "Entries missing line numbers are skipped rather than erroring."
  (should (equal (neo-lean-progress--lines
                  (list '(:range (:start (:character 0) :end (:character 0)))
                        (neo-lean-progress-test--range 0 0))
                  100)
                 '(0))))

(provide 'neo-lean-progress-test)
;;; neo-lean-progress-test.el ends here
