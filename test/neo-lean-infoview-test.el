;;; neo-lean-infoview-test.el --- Infoview tests  -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'neo-lean-goal)

(ert-deftest neo-lean-infoview-hide-hides-visible-goal-window ()
  (let ((neo-lean-infoview-buffer-name " *neo-lean-test-goal*"))
    (unwind-protect
        (progn
          (neo-lean-infoview-display "hello")
          (should (neo-lean-infoview-visible-p))
          (should (neo-lean-infoview-hide))
          (should-not (neo-lean-infoview-visible-p)))
      (when-let* ((buffer (get-buffer neo-lean-infoview-buffer-name)))
        (kill-buffer buffer)))))

(ert-deftest neo-lean-infoview-toggle-hides-visible-goal-window ()
  (let ((neo-lean-infoview-buffer-name " *neo-lean-test-goal*"))
    (unwind-protect
        (progn
          (neo-lean-infoview-display "hello")
          (should (neo-lean-infoview-visible-p))
          (neo-lean-infoview-toggle)
          (should-not (neo-lean-infoview-visible-p)))
      (when-let* ((buffer (get-buffer neo-lean-infoview-buffer-name)))
        (kill-buffer buffer)))))

(ert-deftest neo-lean-infoview-toggle-opens-via-goal-command-when-hidden ()
  (let ((called nil)
        (neo-lean-infoview-buffer-name " *neo-lean-test-goal*"))
    (cl-letf (((symbol-function 'neo-lean-goal)
               (lambda ()
                 (setq called t))))
      (neo-lean-infoview-toggle))
    (should called)))

;;; neo-lean-infoview-test.el ends here
