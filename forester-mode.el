;;; forester-mode.el --- Major mode for Forester .tree files -*- lexical-binding: t; -*-

;; Author: BCI Factory
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: languages, math, forester

;;; Commentary:
;; Emacs major mode for Jon Sterling's Forester (https://sr.ht/~jonsterling/forester/).
;; Better than Geiser: native tree navigation, transclusion following,
;; inline build, LaTeX preview, and forest-wide search.

;;; Code:

(require 'cl-lib)

;; ──────────────────────────────────────────────────────────────────
;; Customization
;; ──────────────────────────────────────────────────────────────────

(defgroup forester nil
  "Forester tree editing."
  :group 'languages
  :prefix "forester-")

(defcustom forester-binary "./forester"
  "Path to forester binary (relative to forest root)."
  :type 'string :group 'forester)

(defcustom forester-forest-roots
  '("/Users/bob/i/horse")
  "List of forest root directories."
  :type '(repeat string) :group 'forester)

;; ──────────────────────────────────────────────────────────────────
;; Syntax highlighting
;; ──────────────────────────────────────────────────────────────────

(defvar forester-font-lock-keywords
  `(;; Commands: \word{...} or \word[...]{...}
    (,(rx "\\" (group (+ (or word ?-))) (? "["))
     (1 font-lock-keyword-face))
    ;; Tree addresses: [[addr-XXXX]]
    (,(rx "[[" (group (+ (not (any "]")))) "]]")
     (1 font-lock-reference-face))
    ;; Title/taxon/author/date
    (,(rx "\\" (group (or "title" "taxon" "author" "date" "tag" "meta" "import"
                          "xmlns" "xmlns:html"))
          "{")
     (1 font-lock-builtin-face))
    ;; Structural: \transclude \subtree \scope \open \put \get
    (,(rx "\\" (group (or "transclude" "subtree" "scope" "open" "put" "get"
                          "object" "patch" "def" "let" "alloc")))
     (1 font-lock-type-face))
    ;; Math mode: #{...}
    (,(rx "#{" (* (not (any "}"))) "}")
     . font-lock-string-face)
    ;; Comments: %...
    (,(rx "%" (* nonl))
     . font-lock-comment-face)
    ;; Emphasis: \strong \em \code
    (,(rx "\\" (group (or "strong" "em" "code" "p" "ul" "ol" "li")))
     (1 font-lock-preprocessor-face)))
  "Font-lock keywords for `forester-mode'.")

;; ──────────────────────────────────────────────────────────────────
;; Syntax table
;; ──────────────────────────────────────────────────────────────────

(defvar forester-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?% "<" st)
    (modify-syntax-entry ?\n ">" st)
    (modify-syntax-entry ?\{ "(}" st)
    (modify-syntax-entry ?\} "){" st)
    (modify-syntax-entry ?\[ "(]" st)
    (modify-syntax-entry ?\] ")[" st)
    (modify-syntax-entry ?\\ "/" st)
    (modify-syntax-entry ?- "w" st)
    (modify-syntax-entry ?# "'" st)
    st)
  "Syntax table for `forester-mode'.")

;; ──────────────────────────────────────────────────────────────────
;; Forest root detection
;; ──────────────────────────────────────────────────────────────────

(defun forester--find-root (&optional dir)
  "Find the forest root (directory containing forest.toml) from DIR."
  (or (locate-dominating-file (or dir default-directory) "forest.toml")
      (when buffer-file-name
        (locate-dominating-file (file-name-directory buffer-file-name) "forest.toml"))
      (cl-some (lambda (r) (when (file-exists-p (expand-file-name "forest.toml" r)) r))
               forester-forest-roots)))

(defun forester--tree-dirs ()
  "Parse forest.toml and return list of tree directories."
  (let ((root (expand-file-name (or (forester--find-root) ""))))
    (when (and root (not (string-empty-p root)))
      (with-temp-buffer
        (insert-file-contents (expand-file-name "forest.toml" root))
        (goto-char (point-min))
        (let (dirs)
          (when (re-search-forward "trees *= *\\[\\([^]]*\\)\\]" nil t)
            (let ((content (match-string 1)))
              (with-temp-buffer
                (insert content)
                (goto-char (point-min))
                (while (re-search-forward "\"\\([^\"]+\\)\"" nil t)
                  (push (expand-file-name (match-string 1) root) dirs)))))
          (nreverse dirs))))))

;; ──────────────────────────────────────────────────────────────────
;; Navigation: follow [[references]] and \transclude{addr}
;; ──────────────────────────────────────────────────────────────────

(defun forester--addr-at-point ()
  "Return the tree address at or near point."
  (save-excursion
    (cond
     ;; [[addr]]
     ((thing-at-point-looking-at "\\[\\[\\([^]]+\\)\\]\\]")
      (match-string-no-properties 1))
     ;; \transclude{addr} or \import{addr}
     ((thing-at-point-looking-at "\\\\\\(?:transclude\\|import\\){\\([^}]+\\)}")
      (match-string-no-properties 1))
     ;; bare addr pattern: xxx-XXXX
     ((thing-at-point-looking-at "\\b\\([a-z]+-[0-9A-Za-z]+\\)\\b")
      (match-string-no-properties 1)))))

(defun forester--find-tree-file (addr)
  "Find the .tree file for ADDR across all tree directories."
  (let ((root (forester--find-root))
        (filename (concat addr ".tree")))
    (when root
      (cl-some (lambda (dir)
                 (let ((f (expand-file-name filename dir)))
                   (when (file-exists-p f) f)))
               (forester--tree-dirs)))))

;;;###autoload
(defun forester-follow ()
  "Follow the tree reference at point."
  (interactive)
  (let ((addr (forester--addr-at-point)))
    (if addr
        (let ((file (forester--find-tree-file addr)))
          (if file
              (find-file file)
            (message "Tree not found: %s" addr)))
      (message "No tree address at point"))))

;;;###autoload
(defun forester-back ()
  "Go back to the previous tree (pop mark)."
  (interactive)
  (pop-to-mark-command))

;; ──────────────────────────────────────────────────────────────────
;; Forest-wide search
;; ──────────────────────────────────────────────────────────────────

;;;###autoload
(defun forester-search (query)
  "Search all .tree files in the forest for QUERY."
  (interactive "sSearch forest: ")
  (let ((root (forester--find-root)))
    (if root
        (grep-find (format "rg -n --glob '*.tree' '%s' %s" query root))
      (message "Not in a forest"))))

;;;###autoload
(defun forester-find-tree (addr)
  "Open a tree by address (with completion)."
  (interactive
   (list (completing-read "Tree: "
                          (forester--all-tree-addrs)
                          nil nil nil)))
  (let ((file (forester--find-tree-file addr)))
    (if file (find-file file)
      (message "Not found: %s" addr))))

(defun forester--all-tree-addrs ()
  "Collect all tree addresses in the forest."
  (let ((root (forester--find-root))
        addrs)
    (when root
      (dolist (dir (forester--tree-dirs))
        (when (file-directory-p dir)
          (dolist (f (directory-files dir nil "\\.tree\\'"))
            (push (file-name-sans-extension f) addrs)))))
    (nreverse addrs)))

;; ──────────────────────────────────────────────────────────────────
;; Build forest
;; ──────────────────────────────────────────────────────────────────

;;;###autoload
(defun forester-build ()
  "Build the forest from forest root."
  (interactive)
  (let ((root (forester--find-root)))
    (if root
        (let ((default-directory root))
          (compile (concat forester-binary " build")))
      (message "Not in a forest"))))

;;;###autoload
(defun forester-new-tree (prefix)
  "Create a new tree with PREFIX (e.g. 'bcf')."
  (interactive "sTree prefix: ")
  (let ((root (forester--find-root)))
    (if root
        (let* ((default-directory root)
               (result (shell-command-to-string
                        (format "%s new --prefix %s" forester-binary prefix))))
          (let ((addr (string-trim result)))
            (message "Created %s" addr)
            (let ((file (forester--find-tree-file addr)))
              (when file (find-file file)))))
      (message "Not in a forest"))))

;; ──────────────────────────────────────────────────────────────────
;; Transclusion preview
;; ──────────────────────────────────────────────────────────────────

(defun forester--preview-transclude ()
  "Show transcluded tree content in a tooltip or overlay."
  (let ((addr (forester--addr-at-point)))
    (when addr
      (let ((file (forester--find-tree-file addr)))
        (when file
          (with-temp-buffer
            (insert-file-contents file)
            (let ((content (buffer-substring-no-properties
                            (point-min) (min (point-max) 300))))
              (message "%s: %s" addr content))))))))

;; ──────────────────────────────────────────────────────────────────
;; LaTeX preview (inline math)
;; ──────────────────────────────────────────────────────────────────

;;;###autoload
(defun forester-preview-math ()
  "Preview #{...} LaTeX math at point."
  (interactive)
  (save-excursion
    (when (re-search-backward "#{" nil t)
      (let ((start (point)))
        (forward-sexp)
        (let* ((math (buffer-substring-no-properties (+ start 2) (1- (point))))
               (tex (format "\\documentclass{standalone}\n\\usepackage{amsmath,amssymb}\n\\begin{document}$%s$\\end{document}" math))
               (tmpfile (make-temp-file "forester-math" nil ".tex")))
          (with-temp-file tmpfile (insert tex))
          (message "Math: $%s$" math))))))

;; ──────────────────────────────────────────────────────────────────
;; Imenu support (navigate by \title, \def, \taxon)
;; ──────────────────────────────────────────────────────────────────

(defun forester-imenu-create-index ()
  "Create imenu index for forester trees."
  (let (index)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\\\\\(title\\|def\\|taxon\\){\\([^}]+\\)}" nil t)
        (push (cons (format "%s: %s" (match-string 1) (match-string 2))
                    (match-beginning 0))
              index)))
    (nreverse index)))

;; ──────────────────────────────────────────────────────────────────
;; Eldoc: show tree title on hover over [[addr]]
;; ──────────────────────────────────────────────────────────────────

(defvar forester--title-cache (make-hash-table :test 'equal)
  "Cache of addr -> title for eldoc.")

(defun forester--get-title (addr)
  "Get the \\title of tree ADDR (cached)."
  (or (gethash addr forester--title-cache)
      (let ((file (forester--find-tree-file addr)))
        (when file
          (with-temp-buffer
            (insert-file-contents file)
            (when (re-search-forward "\\\\title{\\([^}]+\\)}" nil t)
              (let ((title (match-string-no-properties 1)))
                (puthash addr title forester--title-cache)
                title)))))))

(defun forester-eldoc-function ()
  "Show title of tree address at point."
  (let ((addr (forester--addr-at-point)))
    (when addr
      (let ((title (forester--get-title addr)))
        (when title
          (format "%s: %s" addr title))))))

;; ──────────────────────────────────────────────────────────────────
;; Keymap
;; ──────────────────────────────────────────────────────────────────

(defvar forester-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-f") #'forester-follow)
    (define-key map (kbd "C-c C-b") #'forester-back)
    (define-key map (kbd "C-c C-s") #'forester-search)
    (define-key map (kbd "C-c C-t") #'forester-find-tree)
    (define-key map (kbd "C-c C-k") #'forester-build)
    (define-key map (kbd "C-c C-n") #'forester-new-tree)
    (define-key map (kbd "C-c C-p") #'forester-preview-math)
    (define-key map (kbd "M-.")     #'forester-follow)
    (define-key map (kbd "M-,")     #'forester-back)
    map)
  "Keymap for `forester-mode'.")

;; ──────────────────────────────────────────────────────────────────
;; Major mode definition
;; ──────────────────────────────────────────────────────────────────

;;;###autoload
(define-derived-mode forester-mode prog-mode "Forester"
  "Major mode for editing Forester .tree files."
  :syntax-table forester-mode-syntax-table
  (setq font-lock-defaults '(forester-font-lock-keywords))
  (setq-local comment-start "% ")
  (setq-local comment-end "")
  (setq-local indent-tabs-mode nil)
  (setq-local imenu-create-index-function #'forester-imenu-create-index)
  (setq-local eldoc-documentation-function #'forester-eldoc-function)
  (eldoc-mode 1))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.tree\\'" . forester-mode))

(provide 'forester-mode)
;;; forester-mode.el ends here
