;;; jaspace-tests.el --- JaSpace behavior tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'jaspace)
(require 'whitespace)

(defmacro jaspace-test-with-buffer (&rest body)
  (declare (indent 0) (debug t))
  `(let ((jaspace-follow-font-lock nil)
         (jaspace-alternate-jaspace-string "□")
         (jaspace-alternate-eol-string nil)
         (jaspace-highlight-tabs nil)
         (jaspace-disable-on-read-only-buffers nil)
         (jaspace-mode-hook nil)
         (jaspace-mode-off-hook nil))
     (with-temp-buffer
       (unwind-protect
           (progn ,@body)
         (jaspace-mode-off)))))

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
    (insert "a\N{IDEOGRAPHIC SPACE}b")
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
    (insert "\N{IDEOGRAPHIC SPACE}\t\n")
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

(ert-deftest jaspace-update-does-not-enable-inactive-buffer ()
  (jaspace-test-with-buffer
    (let ((noninteractive nil))
      (rename-buffer (generate-new-buffer-name "jaspace-inactive-test"))
      (emacs-lisp-mode)
      (font-lock-mode 1))
    (run-hooks 'post-command-hook)
    (jaspace-update)
    (should-not jaspace-mode)
    (should-not buffer-display-table)))

(ert-deftest jaspace-manual-off-survives-update ()
  (jaspace-test-with-buffer
    (jaspace-mode-on)
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

(ert-deftest jaspace-cloned-buffers-disable-independently ()
  (dolist (clone-function '(clone-buffer clone-indirect-buffer))
    (dolist (clone-off-first '(nil t))
      (jaspace-test-with-buffer
        (setq jaspace-alternate-eol-string
              "\N{LEFT-POINTING DOUBLE ANGLE QUOTATION MARK}\n")
        (jaspace-mode-on)
        (let* ((base (current-buffer))
               (clone (funcall clone-function " *jaspace-clone*" nil))
               (disabled (if clone-off-first clone base))
               (active (if clone-off-first base clone)))
          (unwind-protect
              (progn
                (with-current-buffer disabled
                  (jaspace-mode-off)
                  (should-not (and buffer-display-table
                                   (aref buffer-display-table #x3000)))
                  (should-not (and buffer-display-table
                                   (aref buffer-display-table ?\n))))
                (with-current-buffer active
                  (should jaspace-mode)
                  (should (equal (aref buffer-display-table #x3000) [#x25a1]))
                  (should (equal (aref buffer-display-table ?\n) [#xab ?\n]))))
            (kill-buffer clone)))))))

(ert-deftest jaspace-indirect-buffer-kill-preserves-base-mappings ()
  (jaspace-test-with-buffer
    (jaspace-mode-on)
    (let ((clone (clone-indirect-buffer " *jaspace-clone*" nil)))
      (unwind-protect
          (progn
            (kill-buffer clone)
            (should jaspace-mode)
            (should (equal (aref buffer-display-table #x3000) [#x25a1])))
        (when (buffer-live-p clone) (kill-buffer clone))))))

(ert-deftest jaspace-indirect-major-mode-change-preserves-base-mappings ()
  (jaspace-test-with-buffer
    (jaspace-mode-on)
    (let ((clone (clone-indirect-buffer " *jaspace-clone*" nil)))
      (unwind-protect
          (progn
            (with-current-buffer clone
              (text-mode)
              (should-not jaspace-mode))
            (should jaspace-mode)
            (should (equal (aref buffer-display-table #x3000) [#x25a1])))
        (kill-buffer clone)))))

(ert-deftest jaspace-cleanup-preserves-retained-table-and-foreign-edits ()
  (jaspace-test-with-buffer
    (jaspace-mode-on)
    (let ((retained buffer-display-table))
      (aset buffer-display-table ?x [?y])
      (jaspace-mode-off)
      (should (equal (aref buffer-display-table ?x) [?y]))
      (should-not (aref buffer-display-table #x3000))
      ;; A client retaining the active table still sees its original mappings.
      (should (equal (aref retained #x3000) [#x25a1]))
      (should (equal (aref retained ?x) [?y])))))

(ert-deftest jaspace-indirect-whitespace-cleanup-preserves-base-mappings ()
  (dolist (jaspace-first '(nil t))
    (dolist (jaspace-off-first '(nil t))
      (jaspace-test-with-buffer
        (let ((noninteractive nil)
              (whitespace-style '(space-mark tab-mark))
              (whitespace-display-mappings '((tab-mark ?\t [?> ?\t])))
              clone)
          (rename-buffer (generate-new-buffer-name "jaspace-whitespace-base"))
          (emacs-lisp-mode)
          (font-lock-mode 1)
          (unwind-protect
              (progn
                (if jaspace-first
                    (progn (jaspace-mode-on) (whitespace-mode 1))
                  (whitespace-mode 1)
                  (jaspace-mode-on))
                (setq clone (clone-indirect-buffer "jaspace-whitespace-clone" nil))
                (with-current-buffer clone
                  (if jaspace-off-first
                      (progn (jaspace-mode-off) (whitespace-mode -1))
                    (whitespace-mode -1)
                    (jaspace-mode-off))
                  (should-not (and buffer-display-table
                                   (aref buffer-display-table #x3000))))
                (should jaspace-mode)
                (should whitespace-mode)
                (should (equal (aref buffer-display-table #x3000) [#x25a1]))
                (should (equal (aref buffer-display-table ?\t) [?> ?\t]))
                ;; Whitespace restores its own pre-activation snapshot.
                (whitespace-mode -1)
                (if jaspace-first
                    (should (equal (aref buffer-display-table #x3000) [#x25a1]))
                  (should-not buffer-display-table)))
            (when (buffer-live-p clone) (kill-buffer clone))
            (when whitespace-mode (whitespace-mode -1))))))))

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

(ert-deftest jaspace-command-loop-refreshes-direct-state-changes ()
  (jaspace-test-with-buffer
    (let ((step 0))
      (setq jaspace-highlight-tabs ?^ tab-width 4
            jaspace-disable-on-read-only-buffers t)
      (insert "a\tb\n")
      (use-local-map (make-sparse-keymap))
      (local-set-key [f13]
                     (lambda ()
                       (interactive)
                       (setq step (1+ step))
                       (pcase step
                         (1 (setq tab-width 8))
                         (2 (setq buffer-read-only t))
                         (3 (setq buffer-read-only nil))
                         (4 (jaspace-mode-off)))))
      (jaspace-mode-on)
      (font-lock-ensure)
      (should (equal (get-char-property 2 'display) "^  "))
      ;; A keyboard macro enters the command loop and runs post-command-hook.
      ;; Calling the command function alone would not exercise that path.
      (save-window-excursion
        (switch-to-buffer (current-buffer))
        (execute-kbd-macro [f13])
        (font-lock-ensure)
        (should (equal (get-char-property 2 'display) "^      "))
        (execute-kbd-macro [f13])
        (should-not jaspace-mode)
        (should-not (get-char-property 2 'jaspace-alt))
        (execute-kbd-macro [f13])
        (should jaspace-mode)
        (font-lock-ensure)
        (should (equal (get-char-property 2 'display) "^      "))
        (execute-kbd-macro [f13])
        (execute-kbd-macro [f13])
        (should-not jaspace-mode)))))

(ert-deftest jaspace-background-tab-width-waits-for-target-update ()
  (jaspace-test-with-buffer
    (setq jaspace-highlight-tabs ?^ tab-width 4)
    (insert "a\tb\n")
    (jaspace-mode-on)
    (font-lock-ensure)
    (let ((target (current-buffer)))
      (with-temp-buffer
        (with-current-buffer target (setq tab-width 8))
        (run-hooks 'post-command-hook)
        (with-current-buffer target
          ;; Neither changing the variable nor another buffer's command
          ;; refreshes this buffer's marker.
          (should (equal (get-char-property 2 'display) "^  "))
          (jaspace-update)
          (font-lock-ensure)
          (should (equal (get-char-property 2 'display) "^      ")))))))

(ert-deftest jaspace-background-policy-waits-for-target-command ()
  (jaspace-test-with-buffer
    (setq jaspace-disable-on-read-only-buffers t)
    (jaspace-mode-on)
    (let ((target (current-buffer)))
      (with-temp-buffer
        (with-current-buffer target (setq buffer-read-only t))
        (run-hooks 'post-command-hook)
        (should (buffer-local-value 'jaspace-mode target)))
      (run-hooks 'post-command-hook)
      (should-not jaspace-mode)
      (setq buffer-read-only nil)
      (run-hooks 'post-command-hook)
      (should jaspace-mode))))

(ert-deftest jaspace-combined-policies-resume-only-when-both-allow ()
  (jaspace-test-with-buffer
    (let ((noninteractive nil)
          (on 0) (off 0))
      (rename-buffer (generate-new-buffer-name "jaspace-policy-test"))
      (emacs-lisp-mode)
      (setq jaspace-follow-font-lock t
            jaspace-disable-on-read-only-buffers t
            jaspace-highlight-tabs ?^)
      (insert "; a\tb\n")
      (font-lock-mode 1)
      (add-hook 'jaspace-mode-hook (lambda () (setq on (1+ on))) nil t)
      (add-hook 'jaspace-mode-off-hook (lambda () (setq off (1+ off))) nil t)
      (jaspace-mode-on)
      (dotimes (_ 3)
        (font-lock-ensure)
        (should (= (cl-count-if (lambda (overlay)
                                 (overlay-get overlay 'jaspace-alt))
                               (overlays-at 4)) 1))
        (read-only-mode 1)
        (font-lock-mode -1)
        (read-only-mode -1)
        (run-hooks 'post-command-hook)
        (should-not jaspace-mode)
        (should-not (get-char-property 4 'jaspace-alt))
        (font-lock-mode 1)
        (should jaspace-mode)
        (run-hooks 'post-command-hook))
      (should (= on 4))
      (should (= off 3)))))

(ert-deftest jaspace-read-only-mode-hook-updates-policy ()
  (jaspace-test-with-buffer
    (setq jaspace-disable-on-read-only-buffers t)
    (jaspace-mode-on)
    (read-only-mode 1)
    (should-not jaspace-mode)
    (read-only-mode -1)
    (should jaspace-mode)))

(ert-deftest jaspace-user-hook-enables-mode ()
  (jaspace-test-with-buffer
    (let ((prog-mode-hook (list (lambda () (jaspace-mode 1)))))
      (emacs-lisp-mode))
    (should jaspace-mode)
    (text-mode)
    (should-not jaspace-mode)))

(ert-deftest jaspace-update-hooks-affect-only-user-enabled-buffer ()
  (jaspace-test-with-buffer
    (let ((other (generate-new-buffer " *jaspace-inactive*")))
      (unwind-protect
          (progn
            (jaspace-mode-on)
            (should (local-variable-p 'post-command-hook))
            (with-current-buffer other
              (emacs-lisp-mode)
              (run-hooks 'post-command-hook)
              (run-hooks 'font-lock-mode-hook)
              (should-not jaspace-mode)
              (should-not buffer-display-table))
            (jaspace-mode-off)
            (should-not (memq 'jaspace-update post-command-hook))
            (should-not (memq 'jaspace--font-lock-changed font-lock-mode-hook)))
        (kill-buffer other)))))

(ert-deftest jaspace-manual-off-while-suspended-stays-off ()
  (jaspace-test-with-buffer
    (setq jaspace-follow-font-lock t font-lock-mode t)
    (jaspace-mode-on)
    (setq font-lock-mode nil)
    (run-hooks 'font-lock-mode-hook)
    (should-not jaspace-mode)
    (jaspace-mode-off)
    (setq font-lock-mode t)
    (run-hooks 'font-lock-mode-hook)
    (run-hooks 'post-command-hook)
    (jaspace-update)
    (should-not jaspace-mode)))

(ert-deftest jaspace-suspended-major-mode-change-cleans-hooks ()
  (jaspace-test-with-buffer
    (setq jaspace-disable-on-read-only-buffers t)
    (jaspace-mode-on)
    (read-only-mode 1)
    (should-not jaspace-mode)
    (text-mode)
    (read-only-mode -1)
    (run-hooks 'post-command-hook)
    (should-not jaspace-mode)
    (should-not (memq 'jaspace-update post-command-hook))
    (should-not (memq 'jaspace--font-lock-changed font-lock-mode-hook))))

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
      (insert "FOREIGN\N{IDEOGRAPHIC SPACE}")
      (font-lock-add-keywords nil foreign 'append)
      (jaspace-mode-on)
      (font-lock-ensure)
      (jaspace-mode-off)
      (font-lock-ensure)
      (should (eq defaults font-lock-defaults))
      (should (eq (get-text-property 1 'face) 'bold))
      (should-not (get-text-property 8 'face)))))

(ert-deftest jaspace-width-advice-lifetime ()
  (jaspace-test-with-buffer
    (jaspace-mode-on)
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
          (string (string-width "a\N{IDEOGRAPHIC SPACE}b")))
      (jaspace-mode-on)
      (should (= width (char-width #x3000)))
      (should (= string (string-width "a\N{IDEOGRAPHIC SPACE}b"))))))

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
          (insert "a\N{IDEOGRAPHIC SPACE}\t\n")
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
