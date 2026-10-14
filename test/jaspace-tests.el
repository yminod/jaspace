;;; jaspace-tests.el --- JaSpace behavior tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'jaspace)
(require 'whitespace)

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
     (with-temp-buffer
       (unwind-protect
           (progn ,@body)
         (when jaspace-mode (jaspace-mode-off))))))

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

(ert-deftest jaspace-shared-display-table-is-not-mutated ()
  (jaspace-test-with-buffer
    (let ((shared (make-display-table)))
      (aset shared #x3000 [?.])
      (setq buffer-display-table shared)
      (jaspace-mode-on)
      (should-not (eq buffer-display-table shared))
      (should (equal (aref shared #x3000) [?.]))
      (jaspace-mode-off)
      (should (eq buffer-display-table shared)))))

(ert-deftest jaspace-standard-display-table-is-inherited ()
  (jaspace-test-with-buffer
    (let ((standard-display-table (make-display-table)))
      (aset standard-display-table ?x [?y])
      (jaspace-mode-on)
      (should (equal (aref buffer-display-table ?x) [?y]))
      (should-not (aref standard-display-table #x3000))
      (jaspace-mode-off)
      (should-not (local-variable-p 'buffer-display-table)))))

(ert-deftest jaspace-foreign-display-table-edits-survive ()
  (jaspace-test-with-buffer
    (jaspace-mode-on)
    (aset buffer-display-table ?x [?y])
    (jaspace-mode-off)
    (should (equal (aref buffer-display-table ?x) [?y]))
    (should-not (aref buffer-display-table #x3000))))

(ert-deftest jaspace-replacement-mapping-survives ()
  (jaspace-test-with-buffer
    (jaspace-mode-on)
    (aset buffer-display-table #x3000 [?z])
    (jaspace-mode-off)
    (should (equal (aref buffer-display-table #x3000) [?z]))))

(ert-deftest jaspace-independent-buffers-and-kill-cleanup ()
  (jaspace-test-with-buffer
    (let ((other (generate-new-buffer " *jaspace-other*"))
          (before (jaspace-active-count)))
      (unwind-protect
          (progn
            (jaspace-mode-on)
            (with-current-buffer other
              (setq-local jaspace-alternate-jaspace-string "_")
              (jaspace-mode-on)
              (should (equal (aref buffer-display-table #x3000) [?_])))
            (should (= (jaspace-active-count) (+ before 2)))
            (should (equal (aref buffer-display-table #x3000) [#x25a1]))
            (kill-buffer other)
            (should (= (jaspace-active-count) (1+ before))))
        (when (buffer-live-p other) (kill-buffer other))))))

(ert-deftest jaspace-narrowed-buffer-cleans-all-tab-markers ()
  (jaspace-test-with-buffer
    (setq jaspace-highlight-tabs ?^)
    (insert "\ta\n\tb\n")
    (jaspace-mode-on)
    (font-lock-ensure)
    (should (get-char-property 1 'jaspace-alt))
    (narrow-to-region 4 7)
    (jaspace-mode-off)
    (widen)
    (should-not (get-char-property 1 'jaspace-alt))
    (should-not (get-char-property 4 'jaspace-alt))))

(ert-deftest jaspace-tab-marker-preserves-foreign-display-properties ()
  (jaspace-test-with-buffer
    (setq jaspace-highlight-tabs ?^)
    (insert "a\tb\n")
    (put-text-property 2 3 'display "FOREIGN")
    (let ((foreign (make-overlay 3 4)))
      (overlay-put foreign 'display "OTHER")
      (jaspace-mode-on)
      (font-lock-ensure)
      (jaspace-mode-off)
      (should (equal (get-text-property 2 'display) "FOREIGN"))
      (should (equal (overlay-get foreign 'display) "OTHER")))))

(ert-deftest jaspace-read-only-tab-cleanup-keeps-buffer-state ()
  (jaspace-test-with-buffer
    (setq jaspace-highlight-tabs ?^)
    (insert "a\tb\n")
    (buffer-enable-undo)
    (set-buffer-modified-p nil)
    (setq buffer-read-only t)
    (let ((undo buffer-undo-list))
      (jaspace-mode-on)
      (font-lock-ensure)
      (should (get-char-property 2 'jaspace-alt))
      (jaspace-mode-off)
      (should-not (get-char-property 2 'jaspace-alt))
      (should (eq undo buffer-undo-list))
      (should-not (buffer-modified-p)))))

(ert-deftest jaspace-tab-marker-refreshes-after-edit ()
  (jaspace-test-with-buffer
    (setq jaspace-highlight-tabs ?^ tab-width 4)
    (insert "a\tb\n")
    (jaspace-mode-on)
    (font-lock-ensure)
    (goto-char 1)
    (insert "x")
    (font-lock-ensure)
    (should (equal (get-char-property 3 'display) "^ "))
    (goto-char 3)
    (delete-char 1)
    (font-lock-ensure)
    (should-not (get-char-property 3 'jaspace-alt))))

(ert-deftest jaspace-tab-width-refreshes-after-command ()
  (jaspace-test-with-buffer
    (setq jaspace-highlight-tabs ?^ tab-width 4)
    (insert "a\tb\n")
    (jaspace-mode-on)
    (font-lock-ensure)
    (setq tab-width 8)
    (run-hooks 'post-command-hook)
    (font-lock-ensure)
    (should (equal (get-char-property 2 'display) "^      "))))

(ert-deftest jaspace-read-only-mode-hook-updates-policy ()
  (jaspace-test-with-buffer
    (setq jaspace-disable-on-read-only-buffers t)
    (jaspace-mode-on)
    (read-only-mode 1)
    (should-not jaspace-mode)
    (read-only-mode -1)
    (should jaspace-mode)))

(ert-deftest jaspace-major-mode-hook-updates-selection ()
  (jaspace-test-with-buffer
    (setq jaspace-modes '(emacs-lisp-mode))
    (emacs-lisp-mode)
    (should jaspace-mode)
    (text-mode)
    (should-not jaspace-mode)))

(ert-deftest jaspace-font-lock-hook-updates-policy ()
  (jaspace-test-with-buffer
    (setq jaspace-follow-font-lock t)
    (jaspace-mode-on)
    (setq font-lock-mode nil)
    (run-hooks 'font-lock-mode-hook)
    (should-not jaspace-mode)
    (setq font-lock-mode t)
    (run-hooks 'font-lock-mode-hook)
    (should jaspace-mode)))

(ert-deftest jaspace-real-font-lock-toggle-resumes-manual-mode ()
  (jaspace-test-with-buffer
    (let ((noninteractive nil))
      (rename-buffer (generate-new-buffer-name "jaspace-font-lock-test"))
      (emacs-lisp-mode)
      (setq jaspace-follow-font-lock t jaspace-highlight-tabs ?^)
      (insert "; a\tb\n")
      (font-lock-mode 1)
      (jaspace-mode-on)
      (font-lock-ensure)
      (should (get-char-property 4 'jaspace-alt))
      (font-lock-mode -1)
      (should-not jaspace-mode)
      (should-not (get-char-property 4 'jaspace-alt))
      (font-lock-mode 1)
      (should jaspace-mode)
      (font-lock-ensure)
      (should (get-char-property 4 'jaspace-alt)))))

(ert-deftest jaspace-font-lock-off-clears-tabs-with-follow-disabled ()
  (jaspace-test-with-buffer
    (let ((noninteractive nil))
      (rename-buffer (generate-new-buffer-name "jaspace-font-lock-test"))
      (emacs-lisp-mode)
      (setq jaspace-highlight-tabs ?^)
      (insert "; a\tb\n")
      (font-lock-mode 1)
      (jaspace-mode-on)
      (font-lock-ensure)
      (font-lock-mode -1)
      (should jaspace-mode)
      (should-not (get-char-property 4 'jaspace-alt)))))

(ert-deftest jaspace-preserves-font-lock-defaults-and-other-keywords ()
  (jaspace-test-with-buffer
    (emacs-lisp-mode)
    (let ((defaults font-lock-defaults)
          (foreign '(("FOREIGN" (0 'bold)))))
      (insert "FOREIGN　")
      (font-lock-add-keywords nil foreign 'append)
      (jaspace-mode-on)
      (font-lock-ensure)
      (jaspace-mode-off)
      (font-lock-ensure)
      (should (eq defaults font-lock-defaults))
      (should (eq (get-text-property 1 'face) 'bold))
      (should-not (get-text-property 8 'face)))))

(ert-deftest jaspace-width-advice-lifetime-and-no-idle-timer ()
  (jaspace-test-with-buffer
    (jaspace-mode-on)
    (should-not jaspace-idle-timer)
    (should (subrp (symbol-function 'vertical-motion)))
    (should (advice-member-p #'jaspace--width-advice 'char-width))
    (jaspace-mode-off)
    (should-not (advice-member-p #'jaspace--width-advice 'char-width))
    (should-not (advice-member-p #'jaspace--width-advice 'string-width))))

(ert-deftest jaspace-marker-does-not-change-text-width-apis ()
  (jaspace-test-with-buffer
    (setq jaspace-alternate-jaspace-string "LONG"
          jaspace-alternate-eol-string "«\n")
    (let ((width (char-width #x3000))
          (string (string-width "a　b")))
      (jaspace-mode-on)
      (should (= width (char-width #x3000)))
      (should (= string (string-width "a　b"))))))

(ert-deftest jaspace-eol-vertical-motion-preserves-empty-lines ()
  (jaspace-test-with-buffer
    (setq jaspace-alternate-eol-string "«\n")
    (insert "a\n\nb\n")
    (let ((window (selected-window))
          (old (window-buffer (selected-window))))
      (unwind-protect
          (progn
            (set-window-buffer window (current-buffer))
            (jaspace-mode-on)
            (goto-char 1)
            (should (= (vertical-motion 1 window) 1))
            (should (= (point) 3))
            (should (= (vertical-motion 1 window) 1))
            (should (= (point) 4)))
        (set-window-buffer window old)))))

(ert-deftest jaspace-whitespace-mode-toggle-orders ()
  (dolist (jaspace-first '(nil t))
    (dolist (jaspace-off-first '(nil t))
      (jaspace-test-with-buffer
        ;; whitespace-mode explicitly refuses to enable in a batch job.
        ;; Exercise its interactive code path without opening a GUI.
        (let ((noninteractive nil)
              (whitespace-style '(face tabs tab-mark newline-mark))
              (whitespace-display-mappings '((tab-mark 9 [?> ?\t])
                                            (newline-mark 10 [?$ ?\n]))))
          (rename-buffer (generate-new-buffer-name "jaspace-whitespace-test"))
          (emacs-lisp-mode)
          (font-lock-mode 1)
          (setq jaspace-alternate-eol-string "«\n")
          (insert "a　\t\n")
          (unwind-protect
              (progn
                (if jaspace-first
                    (progn (jaspace-mode-on) (whitespace-mode 1))
                  (whitespace-mode 1)
                  (jaspace-mode-on))
                (font-lock-ensure)
                (should (equal (aref buffer-display-table #x3000) [#x25a1]))
                (if jaspace-off-first
                    (progn
                      (jaspace-mode-off)
                      (should whitespace-mode)
                      (should (aref buffer-display-table ?\t))
                      (whitespace-mode -1))
                  (whitespace-mode -1)
                  (jaspace-mode-off))
                (should-not (and buffer-display-table
                                 (aref buffer-display-table #x3000)))
                (should-not (and buffer-display-table
                                 (aref buffer-display-table ?\n)))
                (should-not (and buffer-display-table
                                 (aref buffer-display-table ?\t))))
            (when whitespace-mode (whitespace-mode -1))))))))

(provide 'jaspace-tests)
;;; jaspace-tests.el ends here
