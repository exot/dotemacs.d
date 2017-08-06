;;; db-eshell --- Configuration for eshell

;;; Commentary:

;;; Code:


;; Setup

(require 'em-prompt)
(require 'em-term)
(require 'em-cmpl)


;; Customization

(setq eshell-cmpl-cycle-completions nil
      eshell-scroll-to-bottom-on-input t
      eshell-prefer-lisp-functions nil)

(setenv "PAGER" "cat")

(defun eshell-clear-buffer ()
  "Clear terminal."
  (interactive)
  (let ((inhibit-read-only t))
    (erase-buffer)
    (eshell-send-input)))

;; eshell is a bit strange and sets up its mode map as a local map;
;; because of this we need to put key definitions into a hook
(add-hook 'eshell-mode-hook
          (lambda ()
            (bind-key "C-a" #'eshell-bol eshell-mode-map)
            (bind-key "C-l" #'eshell-clear-buffer eshell-mode-map)))

(add-to-list 'eshell-command-completions-alist
             '("gunzip" "gz\\'"))

(add-to-list 'eshell-command-completions-alist
             '("tar" "\\(\\.tar|\\.tgz\\|\\.tar\\.gz\\)\\'"))

(setq eshell-prompt-function
      (lambda ()
        (concat
         "[" (user-login-name)
         "@" (getenv "HOST")
         ":" (abbreviate-file-name (eshell/pwd))
         "]\n→ "))
      eshell-prompt-regexp
      "^→ ")

(add-hook 'eshell-mode-hook
          (lambda ()
            (add-hook 'eshell-output-filter-functions 'eshell-truncate-buffer)))


;; Git Completion
;; https://tsdh.wordpress.com/2013/05/31/eshell-completion-for-git-bzr-and-hg/

(require 'pcomplete)

(defun pcmpl-git-commands ()
  "Return the most common git commands by parsing the git output."
  (with-temp-buffer
    (call-process "git" nil (current-buffer) nil "help" "--all")
    (goto-char 0)
    (search-forward "available git commands in")
    (let (commands)
      (while (re-search-forward
              "^[[:blank:]]+\\([[:word:]-.]+\\)[[:blank:]]*\\([[:word:]-.]+\\)?"
              nil t)
        (push (match-string 1) commands)
        (when (match-string 2)
          (push (match-string 2) commands)))
      (sort commands #'string<))))

(defconst pcmpl-git-commands (pcmpl-git-commands)
  "List of `git' commands.")

(defvar pcmpl-git-ref-list-cmd "git for-each-ref refs/ --format='%(refname)'"
  "The `git' command to run to get a list of refs.")

(defun pcmpl-git-get-refs (type)
  "Return a list of `git' refs filtered by TYPE."
  (with-temp-buffer
    (insert (shell-command-to-string pcmpl-git-ref-list-cmd))
    (goto-char (point-min))
    (let (refs)
      (while (re-search-forward (concat "^refs/" type "/\\(.+\\)$") nil t)
        (push (match-string 1) refs))
      (nreverse refs))))

(defun pcmpl-git-remotes ()
  "Return a list of remote repositories."
  (split-string (shell-command-to-string "git remote")))

(defun pcomplete/git ()
  "Completion for `git'."
  ;; Completion for the command argument.
  (pcomplete-here* pcmpl-git-commands)
  (cond
    ((pcomplete-match "help" 1)
     (pcomplete-here* pcmpl-git-commands))
    ((pcomplete-match (regexp-opt '("pull" "push")) 1)
     (pcomplete-here (pcmpl-git-remotes)))
    ;; provide branch completion for the command `checkout'.
    ((pcomplete-match (regexp-opt '("checkout" "co")) 1)
     (pcomplete-here* (append (pcmpl-git-get-refs "heads")
                              (pcmpl-git-get-refs "tags"))))
    (t
     (while (pcomplete-here (pcomplete-entries))))))


;; End

(provide 'db-eshell)
;;; db-eshell ends here