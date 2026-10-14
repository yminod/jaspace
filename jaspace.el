;;; jaspace.el --- Make Japanese whitespaces visible -*- lexical-binding: t; -*-

;; Author: Satomi I.
;; Version: 1.2.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: convenience, faces
;; URL: https://github.com/yminod/jaspace
;; SPDX-License-Identifier: GPL-2.0-or-later

;; Copyright (C) 2002-2004, Satomi I.
;; (satomi atmark ring period gr period jp)
;; Maintenance changes are recorded separately in the repository history.

;; This program is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the
;; Free Software Foundation; either version 2 of the License, or any later
;; version.
;;
;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;;; Commentary:

;; JaSpace displays U+3000 IDEOGRAPHIC SPACE using a display table and
;; Font Lock faces.  It can also display newline and tab markers.
;;
;; Add this directory to `load-path', then (require 'jaspace).
;; Buffers in `jaspace-modes' are enabled automatically, following Font
;; Lock by default.  Use M-x jaspace-mode, jaspace-mode-on, or
;; jaspace-mode-off to override the selection for the current buffer.
;;
;; Customize `jaspace-alternate-jaspace-string',
;; `jaspace-alternate-eol-string', and `jaspace-highlight-tabs' to select
;; markers.  Empty alternate strings are treated as nil.  Newline
;; markers must end with a newline character.
;;
;; The upstream 1.1 source is preserved at the upstream/1.1 tag.
;; This maintained version targets GNU Emacs 27.1 and later.

;;; Code:

(require 'font-lock)
(require 'disp-table)
(require 'nadvice)

(defgroup jaspace nil
  "Make Japanese whitespaces visible."
  :group 'convenience)

(defcustom jaspace-alternate-jaspace-string "\N{WHITE SQUARE}"
  "Alternate string for U+3000 IDEOGRAPHIC SPACE.
Nil or an empty string enables highlighting without a display mapping.
Changes take effect when the mode is enabled again."
  :type '(choice (const nil) string)
  :group 'jaspace)

(defcustom jaspace-alternate-eol-string nil
  "Alternate end-of-line marker, ending with a newline character.
Nil or an empty string disables the marker.
Changes take effect when the mode is enabled again."
  :type '(choice (const nil) string)
  :group 'jaspace)

(defcustom jaspace-highlight-tabs nil
  "Non-nil highlights tabs with Font Lock.
A character also displays a marker followed by padding to the next
tab stop.  Changes take effect when the mode is enabled again."
  :type '(choice (const nil) (const t) (character :value ?^))
  :group 'jaspace)

(defface jaspace-highlight-jaspace-face
  (if (null jaspace-alternate-jaspace-string)
      '((t (:background "rosybrown")))
    '((((class color) (background light)) (:foreground "azure3"))
      (((class color) (background dark)) (:foreground "pink4"))))
  "Face for Japanese whitespaces."
  :group 'jaspace)

(defface jaspace-highlight-eol-face
  '((((class color) (background light)) (:foreground "darkseagreen"))
    (((class color) (background dark)) (:foreground "darkcyan")))
  "Face for end-of-line markers."
  :group 'jaspace)

(defface jaspace-highlight-tab-face
  (if (characterp jaspace-highlight-tabs)
      '((((class color) (background light)) (:foreground "gray70"))
        (((class color) (background dark)) (:foreground "gray30")))
    '((((class color) (background light))
       (:strike-through t :foreground "gray80"))
      (((class color) (background dark))
       (:strike-through t :foreground "gray20"))))
  "Face for tabs."
  :group 'jaspace)

(defcustom jaspace-mode-string " JaSp"
  "Mode-line indicator for JaSpace."
  :type 'string
  :group 'jaspace)

(defcustom jaspace-follow-font-lock t
  "Non-nil suspends JaSpace while Font Lock is disabled."
  :type 'boolean
  :group 'jaspace)

(defcustom jaspace-disable-on-read-only-buffers nil
  "Non-nil suspends JaSpace while the buffer is read-only."
  :type 'boolean
  :group 'jaspace)

(defcustom jaspace-idle-delay 1
  "Retained for compatibility; JaSpace no longer uses an idle timer."
  :type 'number
  :group 'jaspace)

(defcustom jaspace-mode-hook nil
  "Hook run once when JaSpace is activated."
  :type 'hook
  :group 'jaspace)

(defcustom jaspace-mode-off-hook nil
  "Hook run once when JaSpace is deactivated."
  :type 'hook
  :group 'jaspace)

(defcustom jaspace-modes
  '(asm-mode awk-mode autoconf-mode c-mode c++-mode cc-mode change-log-mode
    cperl-mode emacs-lisp-mode java-mode html-mode lisp-mode
    lisp-interaction-mode m4-mode makefile-mode objc-mode pascal-mode
    perl-mode sh-mode shell-script-mode sgml-mode xml-mode)
  "Major modes in which JaSpace is enabled automatically.
The list uses exact major mode symbols, as in upstream 1.1.
Manual activation or deactivation overrides it until the major mode
changes.  Changes to this list are checked after the next command."
  :type '(repeat (symbol :tag "Major Mode"))
  :group 'jaspace)

(defvar-local jaspace-mode nil
  "Non-nil when JaSpace is enabled; use the mode commands to change it.")
(defvar-local jaspace-base-mode nil
  "Buffer's explicit activation preference, if locally bound.")
(defvar-local jaspace-original-display-table nil
  "Display table present before JaSpace was enabled.")
(defvar-local jaspace-font-lock-keywords nil
  "Font Lock keywords installed in this buffer by JaSpace.")
(defvar-local jaspace-tab-width nil
  "Tab width used for character markers, or nil.")
(defvar jaspace-idle-timer nil
  "Legacy timer, retained only so it can be canceled on upgrade.")
(defvar jaspace-inhibit-update nil
  "Non-nil inhibits recursive activation updates.")

(defvar-local jaspace--display-table nil)
(defvar-local jaspace--display-base nil)
(defvar-local jaspace--display-was-local nil)
(defvar-local jaspace--display-entries nil)
(defvar-local jaspace--tab-marker nil)

;; Optional mmm-mode integration; loading JaSpace does not load mmm-mode.
(defvar mmm-mode)
(declare-function mmm-regions-alist "mmm-region" (beg end))
(declare-function mmm-update-mode-info "mmm-mode" (mode &optional force))
(declare-function mmm-refontify-maybe "mmm-mode" ())
;; whitespace-mode keeps a copy of the table it will later restore.
(defvar whitespace-display-table)

(defun jaspace--nonempty-string (value)
  "Return VALUE if it is a nonempty string."
  (and (stringp value) (> (length value) 0) value))

(defun jaspace--install-display-table ()
  "Install buffer-private mappings, remembering their ownership."
  (let ((space (jaspace--nonempty-string jaspace-alternate-jaspace-string))
        (eol (jaspace--nonempty-string jaspace-alternate-eol-string)))
    (when (or space eol)
      (setq jaspace-original-display-table buffer-display-table
            jaspace--display-was-local (local-variable-p 'buffer-display-table)
            jaspace--display-base
            (copy-sequence (or buffer-display-table standard-display-table
                               (make-display-table)))
            jaspace--display-table (copy-sequence jaspace--display-base)
            buffer-display-table jaspace--display-table)
      (optimize-char-table jaspace--display-base)
      (dolist (mapping `((#x3000 . ,space) (?\n . ,eol)))
        (when (cdr mapping)
          (let* ((char (car mapping))
                 (original (aref jaspace--display-table char))
                 (installed (vconcat (cdr mapping))))
            (push (list char original installed) jaspace--display-entries)
            (aset jaspace--display-table char installed)))))))

(defun jaspace--clean-display-table (table)
  "Remove mappings owned by JaSpace from TABLE, preserving other edits."
  (when (char-table-p table)
    (dolist (entry jaspace--display-entries)
      (when (eq (aref table (car entry)) (nth 2 entry))
        (aset table (car entry) (nth 1 entry))))))

(defun jaspace--restore-display-table ()
  "Restore owned entries, including copies retained by `whitespace-mode'."
  (when jaspace--display-table
    (jaspace--clean-display-table jaspace--display-table)
    (jaspace--clean-display-table buffer-display-table)
    (when (boundp 'whitespace-display-table)
      (jaspace--clean-display-table whitespace-display-table))
    ;; Setting an entry and resetting it can leave expanded sub-tables.
    ;; Compare canonical copies so representation changes are not mistaken
    ;; for mappings installed by another package.
    (optimize-char-table jaspace--display-table)
    (when (and (eq buffer-display-table jaspace--display-table)
               (equal buffer-display-table jaspace--display-base))
      (if jaspace--display-was-local
          (setq buffer-display-table jaspace-original-display-table)
        (kill-local-variable 'buffer-display-table)))
    (setq jaspace--display-table nil
          jaspace--display-base nil
          jaspace--display-entries nil
          jaspace-original-display-table nil)))

(defun jaspace--clear-tab-overlays (beg end)
  "Remove only JaSpace's tab overlays between BEG and END."
  (remove-overlays beg end 'jaspace-alt t))

(defun jaspace--prepare-tabs (limit)
  "Clear old tab markers before Font Lock scans up to LIMIT."
  (jaspace--clear-tab-overlays (point) limit)
  nil)

(defun jaspace--match-tab (limit)
  "Find a tab up to LIMIT and install its marker overlay."
  (when (re-search-forward "\t" limit t)
    (let* ((beg (match-beginning 0))
           (end (match-end 0))
           (width (save-excursion
                    (goto-char beg)
                    (- tab-width (% (current-column) tab-width))))
           (overlay (make-overlay beg end nil t nil)))
      (overlay-put overlay 'jaspace-alt t)
      (overlay-put overlay 'evaporate t)
      (overlay-put overlay 'display
                   (concat (char-to-string jaspace--tab-marker)
                           (make-string (1- width) ?\s))))
    t))

(defun jaspace-font-lock-keywords ()
  "Return JaSpace's Font Lock keywords for the current configuration."
  (append
   '(("\N{IDEOGRAPHIC SPACE}" (0 'jaspace-highlight-jaspace-face prepend)))
   (when (jaspace--nonempty-string jaspace-alternate-eol-string)
     '(("\n" (0 'jaspace-highlight-eol-face prepend))))
   (when jaspace-highlight-tabs
     (append
      (if jaspace--tab-marker
          '((jaspace--prepare-tabs)
            (jaspace--match-tab (0 'jaspace-highlight-tab-face prepend)))
        '(("\t" (0 'jaspace-highlight-tab-face prepend))))
      '(("[\t ]+$" (0 (if show-trailing-whitespace
                            'trailing-whitespace 'default) append)))))))

(defun jaspace-fontify-buffer ()
  "Invalidate JaSpace's highlighting for redisplay."
  (save-restriction
    (widen)
    (font-lock-flush)))

(defun jaspace-font-lock-remove-keywords ()
  "Remove the keywords installed in this buffer."
  (when jaspace-font-lock-keywords
    (font-lock-remove-keywords nil jaspace-font-lock-keywords)))

(defun jaspace-active-count ()
  "Return the number of buffers with JaSpace enabled."
  (let ((count 0))
    (dolist (buffer (buffer-list) count)
      (when (buffer-local-value 'jaspace-mode buffer)
        (setq count (1+ count))))))

(defun jaspace--width-advice (function &rest arguments)
  "Call FUNCTION with ARGUMENTS using the original display table.
Current Emacs still consults display mappings in `char-width' and
`string-width'.  Preserve upstream's logical text widths in JaSpace
buffers, without altering calls in other buffers."
  (if (and jaspace-mode jaspace--display-table)
      (let ((buffer-display-table jaspace-original-display-table))
        (apply function arguments))
    (apply function arguments)))

(defun jaspace--update-width-advice ()
  "Keep width advice installed only while a JaSpace buffer is active."
  (dolist (function '(char-width string-width))
    (if (> (jaspace-active-count) 0)
        (unless (advice-member-p #'jaspace--width-advice function)
          (advice-add function :around #'jaspace--width-advice))
      (advice-remove function #'jaspace--width-advice))))

(defun jaspace--after-change (beg end _old-length)
  "Discard tab markers on lines affected by a change between BEG and END."
  (when jaspace--tab-marker
    (save-restriction
      (widen)
      (save-excursion
        (goto-char beg)
        (let ((start (line-beginning-position)))
          (goto-char end)
          (jaspace--clear-tab-overlays start (line-end-position)))))))

;; An internal define-minor-mode supplies standard mode registration and
;; buffer-local state.  Public wrappers preserve the original toggle behavior
;; and activation-only jaspace-mode-hook (standard mode hooks run on both).
(define-minor-mode jaspace--local-mode
  "Internal state transition for JaSpace; use `jaspace-mode' instead."
  :variable jaspace-mode
  :lighter jaspace-mode-string
  :group 'jaspace
  (let ((jaspace-inhibit-update t))
    (if jaspace-mode
        (progn
          (jaspace--install-display-table)
          (jaspace--update-width-advice)
          (setq jaspace--tab-marker
                (and (characterp jaspace-highlight-tabs) jaspace-highlight-tabs)
                jaspace-tab-width (and jaspace--tab-marker tab-width)
                jaspace-font-lock-keywords (jaspace-font-lock-keywords))
          (font-lock-add-keywords nil jaspace-font-lock-keywords 'append)
          (add-hook 'change-major-mode-hook #'jaspace-mode-quit nil t)
          (add-hook 'kill-buffer-hook #'jaspace-mode-quit nil t)
          (add-hook 'after-change-functions #'jaspace--after-change nil t)
          (jaspace-fontify-buffer)
          (run-hooks 'jaspace-mode-hook))
      (remove-hook 'change-major-mode-hook #'jaspace-mode-quit t)
      (remove-hook 'kill-buffer-hook #'jaspace-mode-quit t)
      (remove-hook 'after-change-functions #'jaspace--after-change t)
      (jaspace--restore-display-table)
      (jaspace--update-width-advice)
      (save-restriction
        (widen)
        (jaspace--clear-tab-overlays (point-min) (point-max)))
      (jaspace-font-lock-remove-keywords)
      (setq jaspace-font-lock-keywords nil jaspace-tab-width nil
            jaspace--tab-marker nil)
      (jaspace-fontify-buffer)
      (run-hooks 'jaspace-mode-off-hook))))

(defun jaspace-mode-enter ()
  "Activate JaSpace without changing the buffer's activation preference."
  (unless jaspace-mode (jaspace--local-mode 1)))

(defun jaspace-mode-quit ()
  "Deactivate JaSpace without changing the buffer's activation preference."
  (when jaspace-mode (jaspace--local-mode -1)))

;;;###autoload
(defun jaspace-mode (&optional arg)
  "Toggle JaSpace in the current buffer.
With prefix ARG, enable if positive, otherwise disable.
Unlike a standard minor mode, a Lisp call without ARG toggles the mode,
preserving the original public interface."
  (interactive "P")
  (if (if arg (> (prefix-numeric-value arg) 0) (not jaspace-mode))
      (jaspace-mode-on)
    (jaspace-mode-off)))

;;;###autoload
(defun jaspace-mode-on ()
  "Enable JaSpace and remember a manual activation preference."
  (interactive)
  (setq-local jaspace-base-mode t)
  (jaspace-mode-enter))

;;;###autoload
(defun jaspace-mode-off ()
  "Disable JaSpace and remember a manual deactivation preference."
  (interactive)
  (setq-local jaspace-base-mode nil)
  (jaspace-mode-quit))

(defun jaspace-update ()
  "Update the current buffer after mode, Font Lock, or policy changes.
Automatic decisions use hooks.  Changes made directly with `setq' are
also checked after the next command in the current buffer."
  (unless jaspace-inhibit-update
    (let* ((jaspace-inhibit-update t)
           (selected (if (local-variable-p 'jaspace-base-mode)
                         jaspace-base-mode
                       (memq major-mode jaspace-modes)))
           (active (and selected
                        (or (not jaspace-follow-font-lock) font-lock-mode)
                        (not (and jaspace-disable-on-read-only-buffers
                                  buffer-read-only)))))
      (if active (jaspace-mode-enter) (jaspace-mode-quit))
      (when (and jaspace-mode jaspace--tab-marker
                 (not (eql jaspace-tab-width tab-width)))
        (setq jaspace-tab-width tab-width)
        (save-restriction
          (widen)
          (jaspace--clear-tab-overlays (point-min) (point-max)))
        (jaspace-fontify-buffer)))))

(defun jaspace-set-idle-timer ()
  "Cancel a legacy JaSpace timer; retained for configuration compatibility."
  (when (timerp jaspace-idle-timer) (cancel-timer jaspace-idle-timer))
  (setq jaspace-idle-timer nil))

(defun jaspace--font-lock-changed ()
  "Update activation and discard tab markers when Font Lock stops."
  (unless font-lock-mode
    (save-restriction
      (widen)
      (jaspace--clear-tab-overlays (point-min) (point-max))))
  (jaspace-update))

(defun jaspace-synch-mmm-maybe ()
  "Synchronize JaSpace keywords with mmm-mode when it is active."
  (when (bound-and-true-p mmm-mode)
    (let ((font-lock-keywords-alist font-lock-keywords-alist))
      (dolist (region (mmm-regions-alist (point-min) (point-max)))
        (let ((mode (or (car region) major-mode)))
          (when jaspace-mode
            (font-lock-add-keywords mode jaspace-font-lock-keywords 'append))
          (mmm-update-mode-info mode t))))
    (mmm-refontify-maybe)))

(defun jaspace-mmm-mode-hook ()
  "Install JaSpace synchronization hooks for an mmm-mode buffer."
  (jaspace-synch-mmm-maybe)
  (add-hook 'jaspace-mode-hook #'jaspace-synch-mmm-maybe nil t)
  (add-hook 'jaspace-mode-off-hook #'jaspace-synch-mmm-maybe nil t))

(define-key mode-line-mode-menu [jaspace-mode]
            '(menu-item "Japanese Whitespaces" jaspace-mode
                        :button (:toggle . jaspace-mode)))

(jaspace-set-idle-timer)
(add-hook 'after-change-major-mode-hook #'jaspace-update)
(add-hook 'font-lock-mode-hook #'jaspace--font-lock-changed)
(add-hook 'read-only-mode-hook #'jaspace-update)
(add-hook 'find-file-hook #'jaspace-update)
(add-hook 'post-command-hook #'jaspace-update)

(defun jaspace-unload-function ()
  "Clean up JaSpace buffers, hooks, advice, and the legacy timer."
  (let ((jaspace-inhibit-update t))
    (dolist (buffer (buffer-list))
      (with-current-buffer buffer (jaspace-mode-quit))))
  (dolist (hook '(after-change-major-mode-hook read-only-mode-hook
                 find-file-hook post-command-hook))
    (remove-hook hook #'jaspace-update))
  (remove-hook 'font-lock-mode-hook #'jaspace--font-lock-changed)
  (jaspace--update-width-advice)
  (jaspace-set-idle-timer)
  nil)

(provide 'jaspace)
;;; jaspace.el ends here
