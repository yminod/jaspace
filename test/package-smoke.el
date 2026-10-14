;;; package-smoke.el --- Package load/unload smoke test -*- lexical-binding: t; -*-

(require 'package)

(with-temp-buffer
  (emacs-lisp-mode)
  (let* ((hooks '(after-change-major-mode-hook font-lock-mode-hook
                  read-only-mode-hook find-file-hook post-command-hook))
         (before (mapcar (lambda (hook)
                           (and (boundp hook) (copy-tree (default-value hook))))
                         hooks))
         (table buffer-display-table))
    (require 'jaspace)
    (unless (equal before
                   (mapcar (lambda (hook)
                             (and (boundp hook) (default-value hook)))
                           hooks))
      (error "Loading JaSpace changed global update hooks"))
    (run-hooks 'post-command-hook)
    (when (bound-and-true-p jaspace-mode)
      (error "Loading JaSpace enabled an existing buffer"))
    (unless (eq table buffer-display-table)
      (error "Loading JaSpace changed an existing buffer's display table"))))

(defun jaspace-smoke-check-hooks ()
  "Check that the current buffer has no JaSpace update or cleanup hooks."
  (dolist (hook '(after-change-major-mode-hook font-lock-mode-hook
                 read-only-mode-hook find-file-hook post-command-hook
                 change-major-mode-hook kill-buffer-hook after-change-functions))
    (dolist (function '(jaspace-update jaspace--font-lock-changed
                       jaspace-mode-off jaspace--after-change))
      (when (and (boundp hook) (memq function (symbol-value hook)))
        (error "JaSpace hook left behind: %S in %S" function hook)))))

(with-temp-buffer
  (insert-file-contents "jaspace.el")
  (let ((package (package-buffer-info)))
    (unless (and (eq (package-desc-name package) 'jaspace)
                 (equal (package-desc-version package) '(1 2 1))
                 (equal (package-desc-reqs package) '((emacs (27 1)))))
      (error "Unexpected package metadata: %S" package))))

(let ((jaspace-follow-font-lock nil)
      (jaspace-highlight-tabs ?^))
  (with-temp-buffer
    (insert "a\N{IDEOGRAPHIC SPACE}\tb\n")
    (jaspace-mode-on)
    (font-lock-ensure)
    (unless (get-char-property 3 'jaspace-alt)
      (error "Tab marker not installed"))
    (with-temp-buffer
      (setq-local jaspace-disable-on-read-only-buffers t)
      (jaspace-mode-on)
      (read-only-mode 1)
      (when jaspace-mode (error "Read-only buffer did not suspend JaSpace"))
      (unload-feature 'jaspace t)
      (jaspace-smoke-check-hooks))
    (when buffer-display-table (error "Display table not restored on unload"))
    (when (get-char-property 3 'jaspace-alt)
      (error "Tab overlay left behind on unload"))
    (jaspace-smoke-check-hooks)
    (dolist (function '(char-width string-width))
      (when (advice-member-p 'jaspace--width-advice function)
        (error "Width advice left behind: %S" function)))))

(princ "Package loading, metadata, and unload checks passed.\n")
;;; package-smoke.el ends here
