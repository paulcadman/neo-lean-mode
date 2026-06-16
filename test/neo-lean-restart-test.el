;;; neo-lean-restart-test.el --- Tests for stale-imports detection  -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Batch ERT tests for `neo-lean--imports-out-of-date-p', the pure predicate
;; that recognises Lean's "imports out of date" diagnostic.  No server needed.

;;; Code:

(require 'ert)
(require 'neo-lean-restart)

(defun neo-lean-restart-test--diag (&rest overrides)
  "A stale-imports `Diagnostic' plist, with OVERRIDES taking precedence.
OVERRIDES come first so `plist-get' returns them over the defaults."
  (append overrides
          (list :severity 1
                :message "Imports are out of date and must be rebuilt; \
use the \"Restart File\" command in your editor."
                :range '(:start (:line 0 :character 0)
                                :end (:line 0 :character 0)))))

(ert-deftest neo-lean-imports-out-of-date-p-matches ()
  (should (neo-lean--imports-out-of-date-p (neo-lean-restart-test--diag))))

(ert-deftest neo-lean-imports-out-of-date-p-wrong-severity ()
  ;; A warning (2), not an error (1), is not the stale-imports condition.
  (should-not (neo-lean--imports-out-of-date-p
               (neo-lean-restart-test--diag :severity 2))))

(ert-deftest neo-lean-imports-out-of-date-p-wrong-message ()
  (should-not (neo-lean--imports-out-of-date-p
               (neo-lean-restart-test--diag :message "unrelated error"))))

(ert-deftest neo-lean-imports-out-of-date-p-not-top-of-file ()
  ;; The diagnostic must sit at the very top of the file (line 0, char 0).
  (should-not (neo-lean--imports-out-of-date-p
               (neo-lean-restart-test--diag
                :range '(:start (:line 5 :character 0)
                                :end (:line 5 :character 3))))))

(provide 'neo-lean-restart-test)
;;; neo-lean-restart-test.el ends here
