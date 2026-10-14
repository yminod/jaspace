;;; jaspace-tests.el --- JaSpace behavior tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'jaspace)

;; The upstream implementation needs this removed API even on Emacs 31.
;; Keep the shim in the test harness only, so the original can be characterized.
(defmacro jaspace-test-with-buffer (&rest body)
  (declare (indent 0) (debug t))
  `(let ((jaspace-modes nil)
         (jaspace-follow-font-lock nil)
         (jaspace-alternate-jaspace-string "□")
         (jaspace-alternate-eol-string nil)
         (jaspace-highlight-tabs nil)
         (jaspace-disable-on-read-only-buffers nil)
         (jaspace-mode-hook nil)
         (jaspace-mode-off-hook nil))
     (cl-letf (((symbol-function 'make-local-hook)
                (if (fboundp 'make-local-hook)
                    (symbol-function 'make-local-hook)
                  (lambda (_hook) nil))))
       (with-temp-buffer
         (unwind-protect
             (progn ,@body)
           (when jaspace-mode (jaspace-mode-off)))))))

(ert-deftest jaspace-space-display-and-restoration ()
  (jaspace-test-with-buffer
    (let ((original buffer-display-table))
      (jaspace-mode-on)
      (should jaspace-mode)
      (should (equal (aref buffer-display-table #x3000) [#x25a1]))
      (jaspace-mode-off)
      (should-not jaspace-mode)
      (should (equal buffer-display-table original)))))

(ert-deftest jaspace-empty-alternates-are-disabled ()
  (jaspace-test-with-buffer
    (setq jaspace-alternate-jaspace-string ""
          jaspace-alternate-eol-string "")
    (jaspace-mode-on)
    (should-not buffer-display-table)))

(ert-deftest jaspace-face-only-mode ()
  (jaspace-test-with-buffer
    (setq jaspace-alternate-jaspace-string nil)
    (insert "a　b")
    (jaspace-mode-on)
    (font-lock-ensure)
    (should-not buffer-display-table)
    (should (memq 'jaspace-highlight-jaspace-face
                  (ensure-list (get-text-property 2 'face))))
    (jaspace-mode-off)
    (font-lock-ensure)
    (should-not (get-text-property 2 'face))))

(ert-deftest jaspace-eol-display ()
  (jaspace-test-with-buffer
    (setq jaspace-alternate-eol-string "«\n")
    (jaspace-mode-on)
    (should (equal (aref buffer-display-table ?\n) [#xab ?\n]))))

(ert-deftest jaspace-toggle-and-prefix ()
  (jaspace-test-with-buffer
    (jaspace-mode)
    (should jaspace-mode)
    (jaspace-mode)
    (should-not jaspace-mode)
    (jaspace-mode '(4))
    (should jaspace-mode)
    (jaspace-mode 0)
    (should-not jaspace-mode)))

(ert-deftest jaspace-hooks-and-idempotence ()
  (jaspace-test-with-buffer
    (let ((on 0) (off 0))
      (add-hook 'jaspace-mode-hook (lambda () (setq on (1+ on))) nil t)
      (add-hook 'jaspace-mode-off-hook (lambda () (setq off (1+ off))) nil t)
      (jaspace-mode-on)
      (jaspace-mode-on)
      (should (= on 1))
      (jaspace-mode-off)
      (jaspace-mode-off)
      (should (= off 1)))))

(ert-deftest jaspace-preserves-content-modification-and-undo ()
  (jaspace-test-with-buffer
    (insert "　\t\n")
    (buffer-enable-undo)
    (set-buffer-modified-p nil)
    (let ((text (buffer-string)) (undo buffer-undo-list))
      (jaspace-mode-on)
      (jaspace-mode-off)
      (should (equal (buffer-string) text))
      (should-not (buffer-modified-p))
      (should (eq buffer-undo-list undo)))))

(ert-deftest jaspace-major-mode-change-cleans-up ()
  (jaspace-test-with-buffer
    (jaspace-mode-on)
    (text-mode)
    (should-not jaspace-mode)
    (should-not buffer-display-table)))

(ert-deftest jaspace-update-auto-enables-selected-mode ()
  (jaspace-test-with-buffer
    (setq jaspace-modes '(fundamental-mode))
    (jaspace-update)
    (should jaspace-mode)))

(ert-deftest jaspace-manual-off-survives-update ()
  (jaspace-test-with-buffer
    (setq jaspace-modes '(fundamental-mode))
    (jaspace-update)
    (jaspace-mode-off)
    (jaspace-update)
    (should-not jaspace-mode)))

(ert-deftest jaspace-update-read-only-policy ()
  (jaspace-test-with-buffer
    (jaspace-mode-on)
    (setq jaspace-disable-on-read-only-buffers t buffer-read-only t)
    (jaspace-update)
    (should-not jaspace-mode)
    (setq buffer-read-only nil)
    (jaspace-update)
    (should jaspace-mode)))

(ert-deftest jaspace-manual-enabling-in-read-only-buffer ()
  (jaspace-test-with-buffer
    (setq buffer-read-only t)
    (jaspace-mode-on)
    (should jaspace-mode)
    (jaspace-mode-off)
    (should-not jaspace-mode)))

(ert-deftest jaspace-update-follows-font-lock ()
  (jaspace-test-with-buffer
    (setq jaspace-follow-font-lock t)
    (jaspace-mode-on)
    ;; Font Lock deliberately declines interactive activation in batch mode.
    ;; Bind its state here to exercise the policy independently of redisplay.
    (setq font-lock-mode nil)
    (jaspace-update)
    (should-not jaspace-mode)
    (setq font-lock-mode t)
    (jaspace-update)
    (should jaspace-mode)))

(ert-deftest jaspace-tab-highlight-keywords ()
  (jaspace-test-with-buffer
    (setq jaspace-highlight-tabs t)
    (insert "a\tb\n")
    (jaspace-mode-on)
    (font-lock-ensure)
    (should (memq 'jaspace-highlight-tab-face
                  (ensure-list (get-text-property 2 'face))))))

(ert-deftest jaspace-tab-marker-and-cleanup ()
  (jaspace-test-with-buffer
    (setq jaspace-highlight-tabs ?^ tab-width 4)
    (insert "a\tb\n")
    (jaspace-mode-on)
    (font-lock-ensure)
    (should (equal (get-char-property 2 'display) "^  "))
    (jaspace-mode-off)
    (should-not (get-char-property 2 'display))
    (should-not (get-char-property 2 'jaspace-alt))))

(provide 'jaspace-tests)
;;; jaspace-tests.el ends here
