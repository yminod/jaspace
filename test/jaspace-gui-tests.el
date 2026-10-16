;;; jaspace-gui-tests.el --- GUI layout checks -*- lexical-binding: t; -*-

(require 'jaspace-tests)
(require 'face-remap)

(defun jaspace-gui-test-layout ()
  "Return GUI pixel positions of visible characters in the current buffer."
  (font-lock-ensure)
  (redisplay t)
  (save-excursion
    (let (layout)
      (dotimes (offset (- (point-max) (point-min)))
        (let ((position (posn-at-point (+ (point-min) offset))))
          (should position)
          (push (posn-x-y position) layout)))
      (nreverse layout))))

(defun jaspace-gui-test-hit-map ()
  "Map GUI cell coordinates back to buffer positions after redisplay.
Use this with newline display mappings: `posn-at-point' can report the
preceding display string for the first replacement after a newline."
  (font-lock-ensure)
  (redisplay t)
  (let ((height (cdr (window-text-pixel-size))) positions)
    (cl-loop for y from 0 below height by (frame-char-height) do
             (cl-loop for x from 0 below (window-body-width nil t)
                      by (frame-char-width) do
                      (push (posn-point (posn-at-x-y x y)) positions)))
    (nreverse positions)))

(ert-deftest jaspace-gui-ascii-spaces-preserve-pixel-layout ()
  (should (display-graphic-p))
  (dolist (scale '(0 2))
    (dolist (marker '(?. ?-))
      (jaspace-test-with-buffer
        (setq jaspace-alternate-jaspace-string nil
              jaspace-highlight-spaces marker)
        (insert "a  b\tZ\n   leading and trailing   \n")
        (save-window-excursion
          (switch-to-buffer (current-buffer))
          (text-scale-set scale)
          (let ((layout (jaspace-gui-test-layout)))
            (jaspace-mode-on)
            (should (equal layout (jaspace-gui-test-layout)))
            (jaspace-mode-off)
            (should (equal layout (jaspace-gui-test-layout)))))))))

(ert-deftest jaspace-gui-ascii-spaces-preserve-wrapping-with-other-markers ()
  (should (display-graphic-p))
  (jaspace-test-with-buffer
    (setq jaspace-alternate-jaspace-string "[]"
          jaspace-alternate-eol-string "$\n"
          jaspace-highlight-tabs ?^ tab-width 4)
    (insert "a \t\N{IDEOGRAPHIC SPACE} b  \tZ\n")
    (insert (make-string 150 ?\s) "end\n")
    (save-window-excursion
      (switch-to-buffer (current-buffer))
      (setq truncate-lines nil)
      (jaspace-mode-on)
      (let ((layout (jaspace-gui-test-hit-map))
            (size (window-text-pixel-size)))
        (jaspace-mode-off)
        (setq jaspace-highlight-spaces ?.)
        (jaspace-mode-on)
        (should (equal layout (jaspace-gui-test-hit-map)))
        (should (equal size (window-text-pixel-size)))))))

(ert-deftest jaspace-gui-ascii-spaces-keep-logical-width-in-variable-font ()
  (skip-unless (member "Arial" (font-family-list)))
  (jaspace-test-with-buffer
    (setq jaspace-alternate-jaspace-string nil jaspace-highlight-spaces ?#)
    (insert "a b c d e f g h i j\n")
    (save-window-excursion
      (switch-to-buffer (current-buffer))
      (face-remap-add-relative 'default :family "Arial")
      (let ((columns (jaspace-test-columns))
            (size (window-text-pixel-size)))
        (jaspace-mode-on)
        (font-lock-ensure)
        (redisplay t)
        (should (equal columns (jaspace-test-columns)))
        (should (= (char-width ?\s) 1))
        (should (= (string-width "a b") 3))
        (should (equal (get-char-property 2 'display) "#"))
        (message "Arial # marker: pixels %S -> %S; logical columns preserved"
                 size (window-text-pixel-size))))))

(ert-deftest jaspace-gui-ascii-spaces-refresh-after-text-scale-change ()
  (jaspace-test-with-buffer
    (setq jaspace-alternate-jaspace-string nil jaspace-highlight-spaces ?.)
    (insert "a  b\n")
    (save-window-excursion
      (switch-to-buffer (current-buffer))
      (jaspace-mode-on)
      (font-lock-ensure)
      (text-scale-set 2)
      (let ((layout (jaspace-gui-test-layout)))
        (should (equal (get-char-property 2 'display) "."))
        (jaspace-mode-off)
        (should (equal layout (jaspace-gui-test-layout)))))))

(defun jaspace-gui-run-tests ()
  "Run GUI checks, write a report to JASPACE_GUI_REPORT, and exit."
  (let* ((stats (ert-run-tests-batch "^jaspace-gui-"))
         (failed (ert-stats-completed-unexpected stats)))
    (with-temp-file (getenv "JASPACE_GUI_REPORT")
      (insert (format "Emacs %s; font %s\n" emacs-version
                      (frame-parameter nil 'font)))
      (insert-buffer-substring (get-buffer "*Messages*"))
      (insert "\nJASPACE_GUI_TESTS_COMPLETE\n"))
    (kill-emacs (if (zerop failed) 0 1))))

(provide 'jaspace-gui-tests)
;;; jaspace-gui-tests.el ends here
