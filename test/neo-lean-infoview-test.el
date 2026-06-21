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

(defun neo-lean-infoview-test--text-diagnostic (text)
  "Return a simple interactive diagnostic with message TEXT."
  (list :source "Lean 4"
        :severity 3
        :message (list :text text)))

(defun neo-lean-infoview-test--trace-diagnostic ()
  "Return a small interactive trace diagnostic for infoview tests."
  (let* ((child (list :tag
                      (vector
                       (list :trace
                             (list :indent 2
                                   :cls "Elab.step"
                                   :msg '(:text "child")
                                   :collapsed nil
                                   :children (list :strict (vector))))
                       '(:text ""))))
         (trace (list :indent 0
                      :cls "Elab.command"
                      :msg '(:text "parent")
                      :collapsed nil
                      :children (list :strict (vector child)))))
    (list :source "Lean 4"
          :severity 3
          :message (list :tag (vector (list :trace trace) '(:text ""))))))

(ert-deftest neo-lean-infoview-toggle-fold-collapses-trace-body ()
  (let ((neo-lean-infoview-buffer-name " *neo-lean-test-goal*"))
    (unwind-protect
        (with-current-buffer (neo-lean-infoview--buffer)
          (let ((data (list :goals nil
                            :term-goal nil
                            :messages (list (neo-lean-infoview-test--trace-diagnostic)))))
            (neo-lean--infoview-set-render-data data)
            (neo-lean-infoview-update (neo-lean--infoview-render-data data))
            (goto-char (point-min))
            (search-forward "Elab.command")
            (neo-lean-infoview-toggle-fold)
            (goto-char (point-min))
            (search-forward "Elab.command")
            (should (neo-lean--infoview-fold-property-at-line
                     'neo-lean-fold-collapsed))
            (goto-char (point-min))
            (search-forward "child")
            (should (eq (get-text-property (match-beginning 0) 'invisible)
                        'neo-lean-fold))))
      (when-let* ((buffer (get-buffer neo-lean-infoview-buffer-name)))
        (kill-buffer buffer)))))

(ert-deftest neo-lean-infoview-toggle-fold-keeps-point-on-header ()
  (let ((neo-lean-infoview-buffer-name " *neo-lean-test-goal*"))
    (unwind-protect
        (with-current-buffer (neo-lean-infoview--buffer)
          (let ((data (list :goals nil
                            :term-goal nil
                            :messages (list (neo-lean-infoview-test--trace-diagnostic)))))
            (neo-lean--infoview-set-render-data data)
            (neo-lean-infoview-update (neo-lean--infoview-render-data data))
            (goto-char (point-min))
            (search-forward "Elab.command")
            (let ((fold-id (neo-lean--infoview-fold-property-at-line
                            'neo-lean-fold-id)))
              (neo-lean-infoview-toggle-fold)
              (should (equal (neo-lean--infoview-fold-property-at-line
                              'neo-lean-fold-id)
                             fold-id))
              (should (looking-at-p ".*Elab\\.command")))))
      (when-let* ((buffer (get-buffer neo-lean-infoview-buffer-name)))
        (kill-buffer buffer)))))

(ert-deftest neo-lean-infoview-toggle-fold-keeps-window-start ()
  (let ((neo-lean-infoview-buffer-name " *neo-lean-test-goal*"))
    (save-window-excursion
      (unwind-protect
          (let* ((buffer (neo-lean-infoview--buffer))
                 (data (list :goals nil
                             :term-goal nil
                             :messages (append
                                        (cl-loop for i below 6
                                                 collect
                                                 (neo-lean-infoview-test--text-diagnostic
                                                  (format "filler %02d" i)))
                                        (list (neo-lean-infoview-test--trace-diagnostic))
                                        (cl-loop for i from 6 below 30
                                                 collect
                                                 (neo-lean-infoview-test--text-diagnostic
                                                  (format "filler %02d" i)))))))
            (with-current-buffer buffer
              (neo-lean--infoview-set-render-data data)
              (neo-lean-infoview-update (neo-lean--infoview-render-data data)))
            (switch-to-buffer buffer)
            (goto-char (point-min))
            (search-forward "filler 02")
            (let ((start (line-beginning-position)))
              (set-window-start (selected-window) start t)
              (goto-char (point-min))
              (search-forward "Elab.command")
              (neo-lean-infoview-toggle-fold)
              (should (= (window-start) start))))
        (when-let* ((buffer (get-buffer neo-lean-infoview-buffer-name)))
          (kill-buffer buffer))))))

(ert-deftest neo-lean-infoview-toggle-fold-collapses-top-level-diagnostic ()
  (let ((neo-lean-infoview-buffer-name " *neo-lean-test-goal*"))
    (unwind-protect
        (with-current-buffer (neo-lean-infoview--buffer)
          (let ((data (list :goals nil
                            :term-goal nil
                            :messages (list (neo-lean-infoview-test--trace-diagnostic)))))
            (neo-lean--infoview-set-render-data data)
            (neo-lean-infoview-update (neo-lean--infoview-render-data data))
            (goto-char (point-min))
            (search-forward "Lean 4 Information")
            (neo-lean-infoview-toggle-fold)
            (should (neo-lean--infoview-fold-property-at-line
                     'neo-lean-fold-collapsed))
            (goto-char (point-min))
            (search-forward "Elab.command")
            (should (eq (get-text-property (match-beginning 0) 'invisible)
                        'neo-lean-fold))))
      (when-let* ((buffer (get-buffer neo-lean-infoview-buffer-name)))
        (kill-buffer buffer)))))

(ert-deftest neo-lean-infoview-mode-map-handles-fold-clicks ()
  (let ((interactive-form (interactive-form #'neo-lean-infoview-toggle-fold)))
    (should (eq (car interactive-form) 'interactive))
    (should-not (cadr interactive-form)))
  (should (eq (lookup-key neo-lean-infoview-mode-map [mouse-1])
              #'neo-lean-infoview-mouse-toggle-fold))
  (should (eq (lookup-key neo-lean-infoview-mode-map [mouse-2])
              #'ignore)))

;;; neo-lean-infoview-test.el ends here
