;;; db-utils.el --- Utility Functions for Daniel's Emacs Configuration -*- lexical-binding: t -*-

;;; Commentary:
;;
;; Some functions used in my ~/.emacs.d/init.el.  Most of them are copied from
;; various sources around the internet.
;;

;;; Code:

(require 'dash)


;;; application shortcuts

(defun db/run-or-hide-ansi-term ()
  "Find `*ansi-term*' or run `ansi-term' with `explicit-shell-file-name'.
If already in `*ansi-term*' buffer, bury it."
  (interactive)
  (if (string= "term-mode" major-mode)
      (bury-buffer)
      (if (get-buffer "*ansi-term*")
          (switch-to-buffer "*ansi-term*")
          (ansi-term explicit-shell-file-name))))

(defun db/gnus ()
  "Switch to the `*Group*' buffer, starting `gnus' if not existent."
  (interactive)
  (require 'gnus)
  (if (get-buffer "*Group*")
      (switch-to-buffer "*Group*")
    (gnus)))

(defun db/org-agenda ()
  "Show the main `org-agenda'."
  (interactive)
  (org-agenda nil "A"))

(defun db/scratch ()
  "Switch to `*scratch*'."
  (interactive)
  (switch-to-buffer "*scratch*"))

(defun db/find-user-init-file ()
  "Edit `user-init-file'."
  (interactive)
  (find-file user-init-file))

(defun db/run-or-hide-eshell (arg)
  "Opens an eshell buffer if not already in one, and otherwise
  returns to where we have been before."
  ;; idea to split the current window is from
  ;; http://howardism.org/Technical/Emacs/eshell-fun.html
  (interactive "P")
  (if (string= "eshell-mode" major-mode)
      ;; bury buffer; reopen with current working directory if arg is given
      (progn
        (bury-buffer)
        (delete-window)
        (and arg (db/run-or-hide-eshell arg)))
    (if-let ((eshell-window (db/find-window-by-buffer-mode 'eshell-mode)))
        (select-window eshell-window)
      ;; open eshell
      (let ((current-dir (expand-file-name default-directory))
            (height      (/ (window-total-height) 3)))
        (split-window-vertically (- height))
        (other-window 1)
        (eshell 1)
        (when arg
          (end-of-line)
          (eshell-kill-input)
          (insert (format "cd '%s'" current-dir))
          (eshell-send-input))))))

(defun db/run-or-hide-shell ()
  "Opens an shell buffer if not already in one, and otherwise
  returns to where we have been before."
  (interactive "")
  (if (string= "shell-mode" major-mode)
      (progn
        (bury-buffer)
        (other-window -1))
    (shell)))


;;; general utilities

(defun db/get-url-from-link ()
  "Copy url of link under point into clipboard."
  (interactive)
  (let ((url (plist-get (text-properties-at (point)) 'help-echo)))
    (if url
        (kill-new url)
      (error "No link found."))))

(defun db/test-emacs ()
  ;; from oremacs
  "Test whether emacs' configuration is not throwing any errors."
  (interactive)
  (require 'async)
  (async-start
   (lambda () (shell-command-to-string
               "emacs --batch --eval \"
(condition-case e
    (progn
      (load \\\"~/.emacs.d/init.el\\\")
      (message \\\"-OK-\\\"))
  (error
   (message \\\"ERROR!\\\")
   (signal (car e) (cdr e))))\""))
   `(lambda (output)
      (if (string-match "-OK-" output)
          (when ,(called-interactively-p 'any)
            (message "All is well"))
        (switch-to-buffer-other-window "*startup error*")
        (delete-region (point-min) (point-max))
        (insert output)
        (search-backward "ERROR!")))))

(defun db/isearch-forward-symbol-with-prefix (p)
  ;; http://endlessparentheses.com/quickly-search-for-occurrences-of-the-symbol-at-point.html
  "Like `isearch-forward', unless prefix argument is provided.
With a prefix argument P, isearch for the symbol at point."
  (interactive "P")
  (let ((current-prefix-arg nil))
    (call-interactively
     (if p
         #'isearch-forward-symbol-at-point
         #'isearch-forward))))

(defun endless/fill-or-unfill ()
  "Like `fill-paragraph', but unfill if used twice."
  ;; http://endlessparentheses.com/fill-and-unfill-paragraphs-with-a-single-key.html
  (interactive)
  (let ((fill-column
         (if (eq last-command 'endless/fill-or-unfill)
             (progn (setq this-command nil)
                    (point-max))
           fill-column)))
    (call-interactively #'fill-paragraph)))

(defun db/delete-trailing-whitespace-maybe ()
  "Call `delete-trailing-whitespace', but not in `message-mode'."
  (unless (derived-mode-p 'message-mode)
    (delete-trailing-whitespace)))

(defun db/find-window-by-buffer-mode (mode)
  "Return first window in current frame displaying a buffer with
major mode MODE."
  (cl-find-if (lambda (window)
                (with-current-buffer (window-buffer window)
                  (eq major-mode mode)))
              (window-list-1)))

(defun db/show-current-org-task ()
  "Show title of currently clock in task in modeline."
  (interactive)
  (message org-clock-current-task))

(defun db/hex-to-ascii (hex-string)
  "Convert HEX-STRING to its ASCII equivalent."
  ;; https://stackoverflow.com/questions/12003231/how-do-i-convert-a-string-of-hex-into-ascii-using-elisp
  (interactive "sString (hex): ")
  (->> (string-to-list hex-string)
       (-partition 2)
       (--map (string-to-number (concat it) 16))
       concat
       message))

(defun db/ascii-to-hex (ascii-string)
  "Convert ASCII-STRING to its hexadecimal representation."
  (interactive "sString (ascii): ")
  (->> (--map (format "%2X" it) ascii-string)
       (apply #'concat)
       message))

(defun db/ntp-to-time (high low &optional format-string)
  "Format NTP time given by HIGH and LOW (both integer) to time as given by FORMAT-STRING.
If not given, FORMAT-STRING defaults to some ISO 8601-like format."
  (interactive
   (list (string-to-number (read-string "High (hex): ") 16)
         (string-to-number (read-string "Log (hex): ") 16)))
  (let* ((high-seconds (- high 2208992400)) ; subtract seconds between 1900-01-01 and the epoch
         (h (lsh high-seconds -16))
         (l (% high-seconds 65536))
         (u (floor (* (/ low 4294967296.0) 1e6)))
         (p (- low (floor (/ (* u 4294967296) 1e6)))))
    (message
     (format-time-string (or format-string "%Y-%m-%dT%H:%M:%S.%9NZ")
                         (list h l u p)))))

(defun conditionally-enable-lispy ()
  "Enable lispy-mode when in `eval-expression’ or in
`pp-eval-expression’.  lispy must have been loaded for this
first, i.e., this function will not automatically load
lispy."
  (when (and (featurep 'lispy)
             (or (eq this-command 'eval-expression)
                 (eq this-command 'pp-eval-expression)))
    (lispy-mode 1)))

(defun db/sort-nsm-permanent-settings ()
  "Sort values in `nsm-permanent-host-settings’."
  (setq nsm-permanent-host-settings
        (cl-sort nsm-permanent-host-settings
                 #'string<
                 :key #'second)))

(defun db/update-cert-file-directory (symbol new-value)
  "Set SYMBOL to NEW-VALUE and add all certificate in it to `gnutls-trustfiles’.

Assumes that NEW-VALUE points to a directory, and certificates
are assumed to be of the form *.crt."
  (set symbol new-value)
  (when (file-directory-p new-value)
    (dolist (cert-file (directory-files new-value t ".crt$"))
      (add-to-list 'gnutls-trustfiles cert-file))))

(defun endless/colorize-compilation ()
  "Colorize from `compilation-filter-start' to `point'."
  ;; http://endlessparentheses.com/ansi-colors-in-the-compilation-buffer-output.html
  (let ((inhibit-read-only t))
    (ansi-color-apply-on-region compilation-filter-start (point))))

(defun db/add-use-package-to-imenu ()
  "Add `use-package’ statements to `imenu-generic-expression."
  (add-to-list 'imenu-generic-expression
               '("Used Packages"
                 "\\(^\\s-*(use-package +\\)\\(\\_<.+\\_>\\)"
                 2)))

(defun db/turn-off-local-electric-pair-mode ()
  "Locally turn off electric pair mode."
  (interactive)
  (electric-pair-local-mode -1))

(defun db/pretty-print-xml ()
  "Stupid function to pretty print XML content in current buffer."
  ;; We assume that < and > only occur as XML tag delimiters, not in strings;
  ;; this function is not Unicode-safe
  (interactive)

  (unless (eq major-mode 'nxml-mode)
    (require 'nxml-mode)
    (nxml-mode))

  (save-mark-and-excursion

   ;; First make it all into one line
   (goto-char (point-min))
   (while (re-search-forward "\n[\t ]*" nil 'no-error)
     ;; In case there was a space, we have to keep at least one as a separator
     (if (save-match-data (looking-back "[\t ]"))
         (replace-match " ")
       (replace-match "")))

   ;; Next break between tags
   (goto-char (point-min))
   (while (re-search-forward ">[\t ]*<" nil 'no-error)
     (replace-match ">\n<"))

   ;; Move opening and closing tags to same line in case there’s nothing in
   ;; between
   (goto-char (point-min))
   (while (re-search-forward "<\\([^>]*\\)>\n</\\1>" nil 'no-error)
     (replace-match "<\\1></\\1>"))

   ;; Indent
   (indent-region (point-min) (point-max))))


;;; helm configuration

(defcustom db/helm-frequently-used-features
  '(("Mail"      . db/gnus)
    ("Agenda"    . db/org-agenda)
    ("Init File" . db/find-user-init-file)
    ("EMMS"      . emms)
    ("Shell"     . shell)
    ("EShell"    . eshell)
    ("scratch"   . db/scratch))
  "Helm shortcuts for frequently used features."
  :group 'personal-settings
  :type  '(alist :key-type string :value-type sexp))

(defvar db/helm-source-frequently-used-features
  '((name . "Frequently Used")
    (candidates . db/helm-frequently-used-features)
    (action . (("Open" . funcall)))
    (filtered-candidate-transformer . helm-adaptive-sort))
  "Helm source for `db/helm-frequently-used-features’.")

(defvar db/helm-source-frequently-visited-locations
  '((name . "Locations")
    (candidates . db/helm-frequently-visited-locations)
    (action . (("Open" . (lambda (entry)
                           (if (consp entry)
                               (funcall (car entry) (cdr entry))
                             (find-file entry))))))
    (filtered-candidate-transformer . helm-adaptive-sort)))

(defcustom db/important-documents-path "~/Documents/library/"
  "Path of important documents."
  :group 'personal-settings
  :type 'string)

(defun db/important-documents ()
  "Recursively return paths of all files found in `db/important-documents-path’.
The result will be a list of cons cells, where the car is the
path relative to `db/important-documents’ and the cdr is the full
path."
  ;; code adapted from `directory-files-recursively’
  (let ((db/important-documents-path (expand-file-name db/important-documents-path)))
    (cl-labels ((all-files-in-dir (dir)
                 (let ((result nil)
                       (files nil))
                   (dolist (file (sort (file-name-all-completions "" dir)
                                       'string<))
                     (unless (eq ?. (aref file 0)) ; omit hidden files
                       (if (directory-name-p file)
                           (let* ((leaf (substring file 0 (1- (length file))))
                                  (full-file (expand-file-name leaf dir)))
                             ;; Don't follow symlinks to other directories.
                             (unless (file-symlink-p full-file)
                               (setq result
                                     (nconc result (all-files-in-dir full-file)))))
                           (push (cons
                                  (string-remove-prefix db/important-documents-path
                                                        (expand-file-name file dir))
                                  (expand-file-name file dir))
                                 files))))
                   (nconc result (nreverse files)))))
      (when (file-directory-p db/important-documents-path)
        (all-files-in-dir db/important-documents-path)))))

(defun db/system-open (path)
  "Open PATH with default program as defined by the underlying system."
  (cond
   ((eq system-type 'windows-nt)
    (w32-shell-execute "open" path))
   ((eq system-type 'cygwin)
    (start-process "" nil "cygstart" path))
   (t
    (start-process "" nil "xdg-open" path))))

(defvar db/helm-source-important-documents
  '((name . "Important files")
    (candidates . db/important-documents)
    (action . (("Open externally" . db/system-open)
               ("Find file" . find-file))))
  "Helm source for important documents.")

(defun db/helm-shortcuts (arg)
  "Open helm completion on common locations."
  (interactive "p")
  (require 'helm-files)
  (require 'helm-bookmark)
  (helm :sources `(db/helm-source-frequently-used-features
                   ,(when (and (= arg 4)
                               (file-directory-p db/important-documents-path))
                      'db/helm-source-important-documents)
                   helm-source-bookmarks
                   helm-source-bookmark-set)))


;;; Org Utilities

(defun db/org-cleanup-continuous-clocks ()
  "Join continuous clock lines in the current buffer."
  (interactive)
  (let* ((inactive-timestamp (org-re-timestamp 'inactive))
         (clock-line (concat "\\(^ *\\)CLOCK: " inactive-timestamp "--" inactive-timestamp " => .*"
                             "\n"
                             " *CLOCK: " inactive-timestamp "--\\[\\2\\] => .*$")))
    (save-excursion
      (goto-char (point-min))
      (while (search-forward-regexp clock-line nil t)
       (replace-match "\\1CLOCK: [\\4]--[\\3]")
       (org-clock-update-time-maybe)))))


;;; Calendar

(defun db/export-diary ()
  "Export diary.org as ics file to the current value of `org-icalendar-combined-agenda-file’.
This is done only if the value of this variable is not null."
  (interactive)
  (require 'ox-icalendar)
  (cond
   ((null org-icalendar-combined-agenda-file)
    (message "`org-icalendar-combined-agenda-file’ not set, not exporting diary."))
   ((not (file-name-absolute-p org-icalendar-combined-agenda-file))
    (user-error "`org-icalendar-combined-agenda-file’ not an absolute path, aborting."))
   (t
    (progn
      (org-save-all-org-buffers)
      (let ((org-agenda-files (cl-remove-if #'string-empty-p
                                            (list db/org-default-home-file
                                                  db/org-default-work-file)))
            (org-agenda-new-buffers nil))
        ;; check whether we need to do something
        (when (cl-some (lambda (org-file)
                         (file-newer-than-file-p org-file
                                                 org-icalendar-combined-agenda-file))
                       org-agenda-files)
          (message "Exporting diary ...")
          ;; open files manually to avoid polluting `org-agenda-new-buffers’; we
          ;; don’t want these buffers to be closed after exporting
          (mapc #'find-file-noselect org-agenda-files)
          ;; actual export; calls `org-release-buffers’ and may thus close
          ;; buffers we want to keep around … which is why we set
          ;; `org-agenda-new-buffers’ to nil
          (when (file-exists-p org-icalendar-combined-agenda-file)
            (delete-file org-icalendar-combined-agenda-file)
            (sit-for 3))
          (org-icalendar-combine-agenda-files)
          (message "Exporting diary ... done.")))))))


;;; Extend Input Methods

(defun db/add-symbols-to-TeX-input-method ()
  "Add some new symbols to TeX input method."
  (when (string= current-input-method "TeX")
    (let ((quail-current-package (assoc "TeX" quail-package-alist)))
      (quail-define-rules
       ((append . t))
       ("\\land" ?∧)
       ("\\lor" ?∨)
       ("\\lnot" ?¬)
       ("\\implies" ?⇒)
       ("\\powerset" ?𝔓)
       ("\\mathbbK" ?𝕂)
       ("\\mathbbR" ?ℝ)
       ("\\mathbbN" ?ℕ)
       ("\\mathbbZ" ?ℤ)
       ("\\mathbbP" ?ℙ)
       ("\\mathcalA" ?𝒜)
       ("\\mathcalB" ?ℬ)
       ("\\mathcalC" ?𝒞)
       ("\\mathcalD" ?𝒟)
       ("\\mathcalE" ?ℰ)
       ("\\mathcalH" ?ℋ)
       ("\\mathcalI" ?ℐ)
       ("\\mathcalJ" ?𝒥)
       ("\\mathcalK" ?𝒦)
       ("\\mathcalL" ?ℒ)
       ("\\mathcalM" ?ℳ)
       ("\\mathcalR" ?ℛ)
       ("\\mathcalQ" ?𝒬)
       ("\\mathcalS" ?𝒮)
       ("\\mathfrakP" ?𝔓)))))


;;; Hydras

(defhydra hydra-ispell (:color blue)
  "ispell"
  ("g" (lambda ()
         (interactive)
         (setq ispell-dictionary "de_DE")
         (ispell-change-dictionary "de_DE"))
   "german")
  ("e" (lambda ()
         (interactive)
         (setq ispell-dictionary "en_US")
         (ispell-change-dictionary "en_US"))
   "english"))

(defhydra hydra-toggle (:color blue)
  "toggle"
  ("c" column-number-mode "column")
  ("d" toggle-debug-on-error "debug-on-error")
  ("e" toggle-debug-on-error "debug-on-error")
  ("f" auto-fill-mode "auto-fill")
  ("l" toggle-truncate-lines "truncate lines")
  ("q" toggle-debug-on-quit "debug-on-quit")
  ("r" read-only-mode "read-only"))

;; zooming with single keystrokes (from oremacs)
(defhydra hydra-zoom (:color red)
  "zoom"
  ("g" text-scale-increase "increase")
  ("l" text-scale-decrease "decrease"))

(defhydra hydra-rectangle (:body-pre (rectangle-mark-mode 1)
                                     :color pink
                                     :post (deactivate-mark))
  "
  ^_k_^     _d_elete    _s_tring
_h_   _l_   _o_k        _y_ank
  ^_j_^     _n_ew-copy  _r_eset
^^^^        _e_xchange  _u_ndo
^^^^        ^ ^         _p_aste
"
  ("h" backward-char nil)
  ("l" forward-char nil)
  ("k" previous-line nil)
  ("j" next-line nil)
  ("n" copy-rectangle-as-kill nil)
  ("d" delete-rectangle nil)
  ("r" (if (region-active-p)
           (deactivate-mark)
         (rectangle-mark-mode 1))
   nil)
  ("y" yank-rectangle nil)
  ("u" undo nil)
  ("s" string-rectangle nil)
  ("p" kill-rectangle nil)
  ("e" rectangle-exchange-point-and-mark nil)
  ("o" nil nil))


;;; Wrappers for external applications

(defun db/two-monitors-xrandr ()
  "Activate second monitor using xrandr."
  (call-process "xrandr" nil nil nil
                "--output" "HDMI-3" "--primary" "--right-of" "LVDS-1" "--auto"))

(defun db/one-monitor-xrandr ()
  "Deactivate all additional monitors."
  (call-process "xrandr" nil nil nil
                "--output" "HDMI-3" "--off"))


;;; Bookmarks

(defun db/bookmark-add-with-handler (name location handler)
  "Add NAME as bookmark to LOCATION and use HANDLER to open it.
HANDLER is a function receiving a single argument, namely
LOCATION.  If a bookmark named NAME is already present, replace
it."
  (when (assoc name bookmark-alist)
    (setq bookmark-alist
          (cl-delete-if #'(lambda (bmk) (equal (car bmk) name))
                        bookmark-alist)))
  (push `(,name
          (filename . ,location)
          (handler . ,#'(lambda (arg)
                          (funcall handler (cdr (assoc 'filename arg))))))
        bookmark-alist)
  (setq bookmark-alist (cl-sort bookmark-alist #'string-lessp :key #'car)))

(defun db/bookmark-add-external (location name)
  "Add NAME as bookmark to LOCATION that is opened by the operating system."
  (interactive "sLocation: \nsName: ")
  (db/bookmark-add-with-handler name location #'db/system-open))

(defun db/bookmark-add-url (url name)
  "Add NAME as bookmark to URL that is opened by `browse-url’."
  (interactive "sURL: \nsName: ")
  (db/bookmark-add-with-handler name url #'browse-url))


;;; End

(provide 'db-utils)

;;; db-utils.el ends here
