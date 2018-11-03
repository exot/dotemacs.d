;;; org.el -- Daniel's org mode configuration -*- lexical-binding: t -*-

;;; Commentary:

;; Everything in here influences the standard commands coming with org-mode,
;; either by setting variables, adding hooks, or by overriding.

;;; Code:


;;; Agenda Customization

;; For customization of default org agenda files
(defun db/update-org-agenda-files (symbol value)
  "Set SYMBOL to VALUE and update `org-agenda-files’ afterwards."
  (set-default symbol value)
  (setq org-agenda-files (cl-remove-duplicates
                          (cl-remove-if #'string-empty-p
                                        (mapcar (lambda (symbol)
                                                  (when (boundp symbol)
                                                    (symbol-value symbol)))
                                                '(db/org-default-home-file
                                                  db/org-default-work-file
                                                  db/org-default-refile-file
                                                  db/org-default-notes-file)))
                          :test #'cl-equalp)))

(defun db/org-agenda-list-deadlines (&optional match)
  ;; XXX org-agenda-later does not work, fix this
  "Prepare agenda view that only lists upcoming deadlines.

Ignores MATCH."
  (interactive "P")
  (catch 'exit
    (org-agenda-prepare "Deadlines")
    (org-compile-prefix-format 'agenda)
    (org-set-sorting-strategy 'agenda)

    (let* ((today (org-today))
	   (thefiles (org-agenda-files nil 'ifmode))
	   (inhibit-redisplay (not debug-on-error))
	   s rtn rtnall file files date start-pos)

      ;; headline
      (unless org-agenda-compact-blocks
        (setq s (point))
        (if org-agenda-overriding-header
            (insert (org-add-props (copy-sequence org-agenda-overriding-header)
                        nil 'face 'org-agenda-structure) "\n"))
	(org-agenda-mark-header-line s))

      ;; actual content
      (setq date (calendar-gregorian-from-absolute today)
            s (point)
            start-pos (point)
            files thefiles
            rtnall nil)
      (while (setq file (pop files))
        (catch 'nextfile
          (org-check-agenda-file file)
          (setq rtn (apply 'org-agenda-get-day-entries
                           file date
                           '(:deadline)))
          (setq rtnall (append rtnall rtn)))) ;; all entries
      (when rtnall
        (insert (org-agenda-finalize-entries rtnall 'agenda)
                "\n"))

      ;; finalize
      (goto-char (point-min))
      (or org-agenda-multi (org-agenda-fit-window-to-buffer))
      (unless (and (pos-visible-in-window-p (point-min))
		   (pos-visible-in-window-p (point-max)))
	(goto-char (1- (point-max)))
	(recenter -1)
	(if (not (pos-visible-in-window-p (or start-pos 1)))
	    (progn
	      (goto-char (or start-pos 1))
	      (recenter 1))))
      (goto-char (or start-pos 1))
      (add-text-properties
       (point-min) (point-max)
       `(org-agenda-type agenda
                         org-redo-cmd
                         (db/org-agenda-list-deadlines ,match)))
      (org-agenda-finalize)
      (setq buffer-read-only t)
      (message ""))))

(defun db/org-agenda-skip-tag (tag &optional others)
  ;; https://stackoverflow.com/questions/10074016/org-mode-filter-on-tag-in-agenda-view
  "Skip all entries that correspond to TAG.

If OTHERS is true, skip all entries that do not correspond to TAG."
  (let* ((next-headline    (save-mark-and-excursion
                             (or (outline-next-heading) (point-max))))
         (current-headline (or (and (org-at-heading-p)
                                    (point))
                               (save-mark-and-excursion
                                 ;; remember to also consider invisible headings
                                 (org-back-to-heading t))))
         (has-tag          (member tag (org-get-tags-at current-headline))))
    (if (or (and others (not has-tag))
            (and (not others) has-tag))
        next-headline
      nil)))

(defun db/cmp-date-property (prop)
  ;; https://emacs.stackexchange.com/questions/26351/custom-sorting-for-agenda
  "Compare two `org-mode' agenda entries, `A' and `B', by some date property.

If a is before b, return -1. If a is after b, return 1. If they
are equal return nil."
  (lexical-let ((prop prop))
    #'(lambda (a b)
        (let* ((a-pos (get-text-property 0 'org-marker a))
               (b-pos (get-text-property 0 'org-marker b))
               (a-date (or (org-entry-get a-pos prop)
                           (format "<%s>" (org-read-date t nil "now"))))
               (b-date (or (org-entry-get b-pos prop)
                           (format "<%s>" (org-read-date t nil "now"))))
               (cmp (compare-strings a-date nil nil b-date nil nil)))
          (if (eq cmp t) nil (cl-signum cmp))))))

;; A Hydra for changing agenda appearance
;; http://oremacs.com/2016/04/04/hydra-doc-syntax/

(defun db/org-agenda-span ()
  "Return the display span of the current shown agenda."
  (let ((args (get-text-property
               (min (1- (point-max)) (point))
               'org-last-args)))
    (nth 2 args)))

(defhydra hydra-org-agenda-view (:hint none)
  "
_d_: ?d? day        _g_: time grid=?g? _a_: arch-trees
_w_: ?w? week       _[_: inactive      _A_: arch-files
_t_: ?t? fortnight  _F_: follow=?F?    _r_: report=?r?
_m_: ?m? month      _e_: entry =?e?    _D_: diary=?D?
_y_: ?y? year       _q_: quit          _L__l__c_: ?l?

"
  ("SPC" org-agenda-reset-view)
  ("d" org-agenda-day-view
       (if (eq 'day (db/org-agenda-span))
           "[x]" "[ ]"))
  ("w" org-agenda-week-view
       (if (eq 'week (db/org-agenda-span))
           "[x]" "[ ]"))
  ("t" org-agenda-fortnight-view
       (if (eq 'fortnight (db/org-agenda-span))
           "[x]" "[ ]"))
  ("m" org-agenda-month-view
       (if (eq 'month (db/org-agenda-span)) "[x]" "[ ]"))
  ("y" org-agenda-year-view
       (if (eq 'year (db/org-agenda-span)) "[x]" "[ ]"))
  ("l" org-agenda-log-mode
       (format "% -3S" org-agenda-show-log))
  ("L" (org-agenda-log-mode '(4)))
  ("c" (org-agenda-log-mode 'clockcheck))
  ("F" org-agenda-follow-mode
       (format "% -3S" org-agenda-follow-mode))
  ("a" org-agenda-archives-mode)
  ("A" (org-agenda-archives-mode 'files))
  ("r" org-agenda-clockreport-mode
       (format "% -3S" org-agenda-clockreport-mode))
  ("e" org-agenda-entry-text-mode
       (format "% -3S" org-agenda-entry-text-mode))
  ("g" org-agenda-toggle-time-grid
       (format "% -3S" org-agenda-use-time-grid))
  ("D" org-agenda-toggle-diary
       (format "% -3S" org-agenda-include-diary))
  ("!" org-agenda-toggle-deadlines)
  ("["
   (let ((org-agenda-include-inactive-timestamps t))
     (org-agenda-check-type t 'timeline 'agenda)
     (org-agenda-redo)))
  ("q" (message "Abort") :exit t))


;;; Capturing

;; disable usage of helm for `org-capture'
(with-eval-after-load 'helm-mode
  (defvar helm-completing-read-handlers-alist) ; for the byte compiler
  (add-to-list 'helm-completing-read-handlers-alist
               '(org-capture . nil)))

(setq org-capture-use-agenda-date nil)

(setq org-capture-templates
      `(("t" "Todo"
             entry
             (file db/org-default-refile-file)
             ,(concat "* TODO %^{What}\n"
                      "SCHEDULED: %(org-insert-time-stamp (org-read-date nil t \"+0d\"))\n"
                      ":PROPERTIES:\n:CREATED: %U\n:END:\n"
                      "%?"))
        ("n" "Note"
             entry
             (file db/org-default-refile-file)
             "* %^{About} :NOTE:\n:PROPERTIES:\n:CREATED: %U\n:END:\n\n%?"
             :clock-in t :clock-resume t)
        ("d" "Date"
             entry
             (file db/org-default-refile-file)
             "* GOTO %^{What} :DATE:\n%^{When}t\n%a%?")
        ("i" "Interruptions")
        ("in" "Interruption now"
              entry
              (file db/org-default-refile-file)
              "* DONE %^{What}\n\n%?"
              :clock-in t :clock-resume t)
        ("ip" "Interruption previously" ; bad English vs mnemonics
              entry
              (file db/org-default-refile-file)
              ,(concat "* DONE %^{What}\n"
                       ":LOGBOOK:\n"
                       "%(db/read-clockline)\n" ; evaluated before above prompt?
                       ":END:\n"
                       "%?"))
        ("j" "journal entry"
             plain
             (file+datetree db/org-default-pensieve-file)
             "\n%i%U\n\n%?\n")
        ("r" "respond"
             entry
             (file db/org-default-refile-file)
             ,(concat "* TODO E-Mail: %:subject (%:from) :EMAIL:\n"
                      "SCHEDULED: %^{Reply when?}t\n"
                      ":PROPERTIES:\n:CREATED: %U\n:END:\n"
                      "\n%a")
             :immediate-finish t)
        ("R" "read"
             entry
             (file db/org-default-refile-file)
             ,(concat "* READ %:subject :READ:\n"
                      ;; "DEADLINE: <%(org-read-date nil nil \"+1m\")>\n"
                      ":PROPERTIES:\n:CREATED: %U\n:END:\n"
                      "\n%a"))
        ("U" "Read current content of clipboard"
             entry
             (file db/org-default-refile-file)
             ,(concat "* READ %^{Description} :READ:\n"
                      ":PROPERTIES:\n:CREATED: %U\n:END:\n"
                      "\n%(current-kill 0)"))
        ("m" "Meeting"
             entry
             (file db/org-default-refile-file)
             ,(concat "* MEETING %^{What} :MEETING:\n"
                      ":PROPERTIES:\n:CREATED: %U\n:END:\n"
                      "\n%?")
             :clock-in t :clock-resume t)
        ("p" "Phone call"
             entry
             (file db/org-default-refile-file)
             ,(concat "* PHONE %^{Calling} :PHONE:\n"
                      ":PROPERTIES:\n:CREATED: %U\n:END:\n"
                      "\n%?")
             :clock-in t :clock-resume t)
        ("w" "Weekly Summary"
             entry
             (file+datetree db/org-default-pensieve-file)
             "* Weekly Review\n\n%?")
        ("b" "Bookmark"
             entry
             (file+headline db/org-default-notes-file "Bookmarks")
             ,(concat "* [[%^{Link}][%^{Caption}]]\n"
                      ":PROPERTIES:\n:CREATED: %U\n:END:\n\n")
             :immediate-finish t)))

(defun db/org-timestamp-difference (stamp-1 stamp-2)
  "Returns time difference between two given org-mode timestamps."
  ;; Things copied from `org-clock-update-time-maybe’
  (let* ((s (-
             (float-time
              (apply #'encode-time (org-parse-time-string stamp-2 t)))
             (float-time
              (apply #'encode-time (org-parse-time-string stamp-1 t)))))
         (neg (< s 0))
         (s (abs s))
         (h (floor (/ s 3600)))
         (m (floor (/ (- s (* 3600 h)) 60))))
    (format (if neg "-%d:%02d" "%2d:%02d") h m)))

(defun db/read-clockline ()
  "Read starting and ending time from user and return org mode
  clock line."
  (let* ((now      (format-time-string "%H:%M"))
         (starting (format "[%s]" (org-read-date t nil nil "Started: "
                                                 (current-time)
                                                 now)))
         (ending   (format "[%s]" (org-read-date t nil nil "Ended: "
                                                 (current-time)
                                                 now)))
         (difference (db/org-timestamp-difference starting ending)))
    (format "CLOCK: %s--%s => %s" starting ending difference)))

;; Capture Code Snippets
;; from http://ul.io/nb/2018/04/30/better-code-snippets-with-org-capture/

(defun db/org-capture-code-snippet (filename)
  "Format Org mode entry for capturing code in active region in
the buffer visiting FILENAME."
  (with-current-buffer (find-buffer-visiting filename)
    (let ((code-snippet (buffer-substring-no-properties (mark) (- (point) 1)))
          (func-name (which-function))
          (file-name (buffer-file-name))
          (line-number (line-number-at-pos (region-beginning)))
          (org-src-mode (let ((mm (intern (replace-regexp-in-string
                                           "-mode" "" (format "%s" major-mode)))))
                          (or (car (rassoc mm org-src-lang-modes))
                              (format "%s" mm)))))
      (format
       "file:%s::%s
In ~%s~:
#+BEGIN_SRC %s
%s
#+END_SRC"
       file-name
       line-number
       func-name
       org-src-mode
       code-snippet))))

(add-to-list 'org-capture-templates
             '("s" "Code Snippet" entry (file db/org-default-refile-file)
               "* %?\n%(db/org-capture-code-snippet \"%F\")")
             t)


;;; Refiling

;; Exclude DONE state tasks from refile targets (from bh)
(defun db/verify-refile-target ()
  "Exclude todo keywords with a done state from refile targets"
  (not (member (nth 2 (org-heading-components))
               org-done-keywords)))


;;; Reset checklists

;; from `org-checklist’ by James TD Smith (@ ahktenzero (. mohorovi cc)),
;; version: 1.0

(defun org-reset-checkbox-state-maybe ()
  "Reset all checkboxes in an entry if the `RESET_CHECK_BOXES' property is set"
  (interactive "*")
  (if (org-entry-get (point) "RESET_CHECK_BOXES")
      (org-reset-checkbox-state-subtree)))


;; Helper Functions for Clocking

(defun db/find-parent-task ()
  ;; http://doc.norang.ca/org-mode.html#Clocking
  "Return point of the nearest parent task, and NIL if no such task exists."
  (save-mark-and-excursion
   (save-restriction
     (widen)
     (let ((parent-task nil))
       (or (org-at-heading-p)
           (org-back-to-heading t))
       (while (and (not parent-task)
                   (org-up-heading-safe))
         (let ((tags (nth 5 (org-heading-components))))
           (unless (and tags (member "NOP" (split-string tags ":" t)))
             (setq parent-task (point)))))
       parent-task))))

(defun db/ensure-running-clock ()
  "Clocks in into the parent task, if it exists, or the default task."
  (when (and (not org-clock-clocking-in)
             (not org-clock-resolving-clocks-due-to-idleness))
    (let ((parent-task (db/find-parent-task)))
      (save-mark-and-excursion
       (cond
        (parent-task
         ;; found parent task
         (org-with-point-at parent-task
           (org-clock-in)))
        ((and (markerp org-clock-default-task)
              (marker-buffer org-clock-default-task))
         ;; default task is set
         (org-with-point-at org-clock-default-task
           (org-clock-in)))
        (t
         (org-clock-in '(4))))))))

(defun db/save-current-org-task-to-file ()
  "Format currently clocked task and write it to
`db/org-clock-current-task-file'."
  (with-temp-file db/org-clock-current-task-file
    (let ((clock-buffer (marker-buffer org-clock-marker)))
      (if (null clock-buffer)
          (insert "No running clock")
        (insert org-clock-heading)))))


;;; Fixes

(defun endless/org-ispell ()
  "Configure `ispell-skip-region-alist' for `org-mode'."
  (make-local-variable 'ispell-skip-region-alist)
  (add-to-list 'ispell-skip-region-alist '(org-property-drawer-re))
  (add-to-list 'ispell-skip-region-alist '("~" "~"))
  (add-to-list 'ispell-skip-region-alist '("=" "="))
  (add-to-list 'ispell-skip-region-alist '("^#\\+BEGIN_SRC" . "^#\\+END_SRC")))


;;; Hydra

(defun db/clock-in-task-by-id (task-id)
  "Clock in org mode task as given by TASK-ID."
  (org-with-point-at (org-id-find task-id 'marker)
    (org-clock-in))
  (org-save-all-org-buffers))

(defun db/clock-out-task-by-id (task-id)
  "Clock out org mode task as given by TASK-ID."
  (org-with-point-at (org-id-find task-id 'marker)
    (org-clock-out))
  (org-save-all-org-buffers))

(defun db/org-clock-in-last-task (&optional arg)
  ;; from doc.norang.ca, originally bh/clock-in-last-task
  "Clock in the interrupted task if there is one.

Skip the default task and get the next one.  If ARG is given,
forces clocking in of the default task."
  (interactive "p")
  (let ((clock-in-to-task
         (cond
          ((eq arg 4) org-clock-default-task)
          ((and (org-clock-is-active)
                (equal org-clock-default-task (cadr org-clock-history)))
           (caddr org-clock-history))
          ((org-clock-is-active) (cadr org-clock-history))
          ((equal org-clock-default-task (car org-clock-history))
           (cadr org-clock-history))
          (t (car org-clock-history)))))
    (widen)
    (org-with-point-at clock-in-to-task
      (org-clock-in nil))))

(defun db/org-clock-current-task ()
  "Return currently clocked in task."
  (require 'org-clock)
  org-clock-current-task)

(defhydra hydra-org-clock (:color blue)
  "
Current Task: %s(db/org-clock-current-task); "
  ("w" (lambda ()
         (interactive)
         (db/clock-in-task-by-id org-working-task-id)))
  ("h" (lambda ()
         (interactive)
         (db/clock-in-task-by-id org-home-task-id)))
  ("b" (lambda ()
         (interactive)
         (db/clock-in-task-by-id org-break-task-id)))
  ("i" (lambda ()
         (interactive)
         (org-clock-in '(4))))
  ("a" counsel-org-goto-all)
  ("o" org-clock-out)
  ("l" db/org-clock-in-last-task)
  ("p" db/play-playlist)
  ("d" (lambda ()
         (interactive)
         (when (org-clock-is-active)
           (save-window-excursion
             (org-clock-goto)
             (let ((org-inhibit-logging 'note))
               (org-todo 'done)
               (org-save-all-org-buffers)))))))


;;; Babel

(defun org-babel-execute:hy (body params)
  ;; http://kitchingroup.cheme.cmu.edu/blog/2016/03/30/OMG-A-Lisp-that-runs-python/
  "Execute hy code BODY with parameters PARAMS."
  (ignore params)
  (let* ((temporary-file-directory ".")
         (tempfile (make-temp-file "hy-")))
    (with-temp-file tempfile
      (insert body))
    (unwind-protect
        (shell-command-to-string
         (format "hy %s" tempfile))
      (delete-file tempfile))))


;;; End

(provide 'db-org)

;;; db-org.el ends here
