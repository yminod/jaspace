;;; package-smoke.el --- Package load/unload smoke test -*- lexical-binding: t; -*-

(require 'package)
(require 'jaspace)

(with-temp-buffer
  (insert-file-contents "jaspace.el")
  (let ((package (package-buffer-info)))
    (unless (and (eq (package-desc-name package) 'jaspace)
                 (equal (package-desc-version package) '(1 2 0))
                 (equal (package-desc-reqs package) '((emacs (27 1)))))
      (error "Unexpected package metadata: %S" package))))

(let ((jaspace-modes nil)
      (jaspace-follow-font-lock nil)
      (jaspace-highlight-tabs ?^))
  (with-temp-buffer
    (insert "a\N{IDEOGRAPHIC SPACE}\tb\n")
    (jaspace-mode-on)
    (font-lock-ensure)
    (unless (get-char-property 3 'jaspace-alt)
      (error "Tab marker not installed"))
    (unload-feature 'jaspace t)
    (when buffer-display-table (error "Display table not restored on unload"))
    (when (get-char-property 3 'jaspace-alt)
      (error "Tab overlay left behind on unload"))
    (dolist (hook '(after-change-major-mode-hook read-only-mode-hook
                   find-file-hook post-command-hook))
      (when (memq 'jaspace-update (symbol-value hook))
        (error "Global hook left behind: %S" hook)))
    (when (memq 'jaspace--font-lock-changed font-lock-mode-hook)
      (error "Font Lock hook left behind"))
    (dolist (function '(char-width string-width))
      (when (advice-member-p 'jaspace--width-advice function)
        (error "Width advice left behind: %S" function)))))

(princ "Package metadata and unload checks passed.\n")
;;; package-smoke.el ends here
