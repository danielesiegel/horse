;;; forester-transient.el --- Magit-like transient UI for plurigrid/causal forests -*- lexical-binding: t; -*-

;; Requires: transient, forester-mode

;;; Code:

(require 'transient)
(require 'cl-lib)

;; ──────────────────────────────────────────────────────────────────
;; World data
;; ──────────────────────────────────────────────────────────────────

(defvar pluri-worlds-root "/Users/bob/worlds/"
  "Root directory of the 26 worlds.")

(defvar pluri-horse-root "/Users/bob/i/horse/"
  "Root of the bci.horse forest.")

(defvar pluri-world-letters
  '("a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m"
    "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z")
  "The 26 world letters.")

(defun pluri--world-role (letter)
  "Extract role from world LETTER's causal_link.hy."
  (let ((file (expand-file-name (format "%s/causal_link.hy" letter) pluri-worlds-root)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (when (re-search-forward "\\*WORLD-.-ROLE\\*[\" ]+\\([^\"]+\\)" nil t)
          (match-string-no-properties 1))))))

(defun pluri--world-syndrome (letter)
  "Extract syndrome from world LETTER's causal_link.hy."
  (let ((file (expand-file-name (format "%s/causal_link.hy" letter) pluri-worlds-root)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (when (re-search-forward "syndrome \"\\(.\\)\"" nil t)
          (let ((l (match-string 1)))
            (forward-line 1)
            (when (re-search-forward "(syndrome \"" nil t)
              nil) ;; already have letter
            l))))))

(defun pluri--world-trit (letter)
  "Get trit from world LETTER's world.toml."
  (let ((file (expand-file-name (format "%s/world.toml" letter) pluri-worlds-root)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (when (re-search-forward "trit *= *\\(-?[0-9]+\\)" nil t)
          (string-to-number (match-string 1)))))))

(defun pluri--world-color (letter)
  "Get hex color from world LETTER's world.toml."
  (let ((file (expand-file-name (format "%s/world.toml" letter) pluri-worlds-root)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (when (re-search-forward "color *= *\"\\(#[0-9A-Fa-f]+\\)\"" nil t)
          (match-string-no-properties 1))))))

;; ──────────────────────────────────────────────────────────────────
;; Parallel buffer views
;; ──────────────────────────────────────────────────────────────────

(defun pluri--horse-file-p (file)
  "Return non-nil if FILE is a bci.horse tree (horse-/bci-/bcf- prefix)."
  (let ((name (file-name-nondirectory file)))
    (and (string-prefix-p (expand-file-name "trees/" pluri-horse-root)
                          (expand-file-name (file-name-directory file)))
         (or (string-prefix-p "horse-" name)
             (string-prefix-p "bci-" name)
             (string-prefix-p "bcf-" name)))))

(defun pluri--set-text-scale (buf file)
  "Set text scale on BUF: 3/4 size for non-horse FILE, normal for horse."
  (with-current-buffer buf
    (if (pluri--horse-file-p file)
        (text-scale-mode -1)
      (setq text-scale-mode-amount -1)
      (text-scale-mode 1))))

(defun pluri-parallel-view (files)
  "Open FILES in maximally parallel split windows.
Non-horse files display at 3/4 text scale."
  (delete-other-windows)
  (let* ((bufs (mapcar #'find-file-noselect files))
         (n (length files)))
    (cond
     ((= n 1)
      (switch-to-buffer (car bufs))
      (pluri--set-text-scale (car bufs) (car files)))
     ((= n 2)
      (switch-to-buffer (car bufs))
      (pluri--set-text-scale (car bufs) (car files))
      (split-window-right)
      (other-window 1)
      (switch-to-buffer (cadr bufs))
      (pluri--set-text-scale (cadr bufs) (cadr files)))
     ((= n 3)
      (switch-to-buffer (car bufs))
      (pluri--set-text-scale (car bufs) (car files))
      (split-window-right)
      (other-window 1)
      (switch-to-buffer (cadr bufs))
      (pluri--set-text-scale (cadr bufs) (cadr files))
      (split-window-below)
      (other-window 1)
      (switch-to-buffer (caddr bufs))
      (pluri--set-text-scale (caddr bufs) (caddr files)))
     ((>= n 4)
      (switch-to-buffer (car bufs))
      (pluri--set-text-scale (car bufs) (car files))
      (split-window-right)
      (other-window 1)
      (switch-to-buffer (cadr bufs))
      (pluri--set-text-scale (cadr bufs) (cadr files))
      (other-window -1)
      (split-window-below)
      (other-window 1)
      (switch-to-buffer (caddr bufs))
      (pluri--set-text-scale (caddr bufs) (caddr files))
      (other-window 1)
      (split-window-below)
      (other-window 1)
      (switch-to-buffer (cadddr bufs))
      (pluri--set-text-scale (cadddr bufs) (cadddr files))))
    (other-window (- (1- n)))))

;; ──────────────────────────────────────────────────────────────────
;; World status buffer (magit-style)
;; ──────────────────────────────────────────────────────────────────

(defun pluri-world-status ()
  "Show all 26 worlds in a magit-style status buffer."
  (interactive)
  (let ((buf (get-buffer-create "*plurigrid*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize "Plurigrid World Status\n" 'face '(:weight bold :height 1.3)))
        (insert (propertize (format "Root: %s\n\n" pluri-worlds-root) 'face 'font-lock-comment-face))
        (insert (propertize "Letter  Trit  Color    Role\n" 'face '(:weight bold :underline t)))
        (dolist (l pluri-world-letters)
          (let* ((trit (pluri--world-trit l))
                 (color (pluri--world-color l))
                 (role (pluri--world-role l))
                 (trit-str (if trit (format "%+2d" trit) " ?"))
                 (trit-face (cond ((and trit (> trit 0)) '(:foreground "#FF0000"))
                                  ((and trit (< trit 0)) '(:foreground "#0000FF"))
                                  (t '(:foreground "#00CC00"))))
                 (color-swatch (if color
                                   (propertize "██" 'face `(:foreground ,color))
                                 "  ")))
            (insert (format "  %s     " (propertize l 'face '(:weight bold))))
            (insert (propertize trit-str 'face trit-face))
            (insert (format "   %s " color-swatch))
            (insert (or color "       "))
            (insert (format "  %s\n" (or role "")))))
        (insert (propertize "\n[RET] open world  [t] transient  [f] forest  [c] causal  [p] parallel\n"
                            'face 'font-lock-comment-face)))
      (goto-char (point-min))
      (special-mode)
      (local-set-key (kbd "t") #'pluri-dispatch)
      (local-set-key (kbd "f") #'pluri-forest-dispatch)
      (local-set-key (kbd "q") #'quit-window)
      (local-set-key (kbd "RET") #'pluri-open-world-at-point))
    (switch-to-buffer buf)))

(defun pluri--letter-at-point ()
  "Get the world letter on the current line."
  (save-excursion
    (beginning-of-line)
    (when (looking-at "  \\([a-z]\\) ")
      (match-string-no-properties 1))))

(defun pluri-open-world-at-point ()
  "Open the world directory at point."
  (interactive)
  (let ((letter (pluri--letter-at-point)))
    (when letter
      (let ((dir (expand-file-name letter pluri-worlds-root)))
        (find-file dir)))))

;; ──────────────────────────────────────────────────────────────────
;; Transient: main plurigrid dispatch
;; ──────────────────────────────────────────────────────────────────

(transient-define-prefix pluri-dispatch ()
  "Plurigrid dispatch — magit-like interface for 26 worlds."
  ["World"
   ("s" "Status (all 26)"        pluri-world-status)
   ("w" "Open world..."          pluri-open-world)
   ("c" "Causal link..."         pluri-open-causal)]
  ["Forest (bci.horse)"
   ("f" "Forest dispatch"        pluri-forest-dispatch)
   ("b" "Build forest"           forester-build)
   ("t" "Find tree..."           forester-find-tree)]
  ["Parallel"
   ("3" "GF(3) triad view"       pluri-gf3-triad-view)
   ("p" "Parallel causal links"  pluri-parallel-causal)
   ("B" "BCI deranged (Olive|Jade/Sage|Cobalt)" pluri-bci-pipeline-view)
   ("L" "Locale quartet (3/4)"   pluri-locale-quartet)]
  ["Skill"
   ("S" "Skill URI browser"      pluri-skill-browser)
   ("N" "nanoclj REPL"           nanoclj-start-repl)])

;; ──────────────────────────────────────────────────────────────────
;; Transient: forest dispatch
;; ──────────────────────────────────────────────────────────────────

(transient-define-prefix pluri-forest-dispatch ()
  "Forest navigation — bci.horse tree operations."
  ["Navigate"
   ("f" "Follow [[ref]] at point"  forester-follow)
   ("b" "Back"                     forester-back)
   ("t" "Find tree..."            forester-find-tree)
   ("s" "Search forest..."        forester-search)]
  ["Build"
   ("k" "Build forest"            forester-build)
   ("n" "New tree..."             forester-new-tree)]
  ["BCI Trees"
   ("1" "bcf-0001 (root)"         pluri-open-bcf-root)
   ("m" "bci-0001 (math)"         pluri-open-bci-math)
   ("h" "horse-0001 (portal)"     pluri-open-horse-portal)
   ("p" "bcf-0023 (plurigrid)"    pluri-open-plurigrid)])

;; ──────────────────────────────────────────────────────────────────
;; Commands
;; ──────────────────────────────────────────────────────────────────

(defun pluri-open-world (letter)
  "Open world LETTER's directory."
  (interactive "sWorld letter (a-z): ")
  (let ((dir (expand-file-name letter pluri-worlds-root)))
    (if (file-directory-p dir)
        (find-file dir)
      (message "No world: %s" letter))))

(defun pluri-open-causal (letter)
  "Open world LETTER's causal_link.hy."
  (interactive "sWorld letter (a-z): ")
  (let ((file (expand-file-name (format "%s/causal_link.hy" letter) pluri-worlds-root)))
    (if (file-exists-p file)
        (find-file file)
      (message "No causal link for world %s" letter))))

(defun pluri-parallel-causal ()
  "Open 4 causal links in parallel split view."
  (interactive)
  (pluri-parallel-view
   (list (expand-file-name "p/causal_link.hy" pluri-worlds-root)
         (expand-file-name "b/causal_link.hy" pluri-worlds-root)
         (expand-file-name "e/causal_link.hy" pluri-worlds-root)
         (expand-file-name "t/causal_link.hy" pluri-worlds-root))))

(defun pluri-gf3-triad-view ()
  "Open a GF(3)-balanced triad: worlds with trit -1, 0, +1."
  (interactive)
  (let (minus zero plus)
    (dolist (l pluri-world-letters)
      (let ((trit (pluri--world-trit l)))
        (cond ((and trit (= trit -1) (not minus))
               (setq minus (expand-file-name (format "%s/world.toml" l) pluri-worlds-root)))
              ((and trit (= trit 0) (not zero))
               (setq zero (expand-file-name (format "%s/world.toml" l) pluri-worlds-root)))
              ((and trit (= trit 1) (not plus))
               (setq plus (expand-file-name (format "%s/world.toml" l) pluri-worlds-root))))))
    (when (and minus zero plus)
      (pluri-parallel-view (list minus zero plus)))))

;; BCI stage colors from seed 1069:
;;   Stage 0 (horse-0002) = Sage   #7D9C76  trit +1
;;   Stage 1 (horse-0003) = Olive  #61612F  trit +1
;;   Stage 2 (horse-0004) = Cobalt #3056FD  trit  0
;;   Stage 3 (horse-0005) = Jade   #2BB683  trit  0
;;
;; Derangement sigma = (1,3,0,2): no fixed points.
;;   Slot 0 -> Olive,  Slot 1 -> Jade,
;;   Slot 2 -> Sage,   Slot 3 -> Cobalt

(defvar pluri-bci-stages
  '(("Sage"   "#7D9C76" "horse-0002" +1 "Signal Acquisition (Sites)")
    ("Olive"  "#61612F" "horse-0003" +1 "Local Processing (Cohomology)")
    ("Cobalt" "#3056FD" "horse-0004"  0 "Global Assembly (Descent)")
    ("Jade"   "#2BB683" "horse-0005"  0 "Decode (Categorical Semantics)"))
  "BCI pipeline stages: (color-name hex tree-id trit description).")

(defvar pluri-bci-derangement '(1 3 0 2)
  "Derangement sigma of stage indices. No fixed points: 0->1, 1->3, 2->0, 3->2.")

(defun pluri-bci-pipeline-view ()
  "Open the 4-stage BCI pipeline trees in deranged order.
Derangement sigma = (1,3,0,2): each slot gets a stage
that is NOT its natural occupant."
  (interactive)
  (let* ((files (mapcar
                 (lambda (i)
                   (let ((stage (nth i pluri-bci-stages)))
                     (expand-file-name
                      (format "trees/%s.tree" (nth 2 stage))
                      pluri-horse-root)))
                 pluri-bci-derangement)))
    (pluri-parallel-view files)
    (message "BCI derangement: Olive | Jade / Sage | Cobalt  [sigma=(1,3,0,2)]")))

(defvar pluri-tree-search-dirs
  (list (expand-file-name "trees/" pluri-horse-root)
        (expand-file-name "stacks-trees/" pluri-horse-root)
        (expand-file-name "localcharts/forest/trees/" pluri-horse-root)
        (expand-file-name "bci/stages/" pluri-horse-root))
  "Directories to search for .tree files by ID.")

(defun pluri--find-tree-file (id)
  "Find tree file for ID across all known tree directories."
  (cl-loop for dir in pluri-tree-search-dirs
           for f = (expand-file-name (concat id ".tree") dir)
           when (file-exists-p f) return f
           finally return
           (car (directory-files-recursively
                 pluri-horse-root (concat "^" (regexp-quote id) "\\.tree$")))))

(defun pluri--extract-links (file)
  "Extract all tree IDs linked from FILE via \\transclude or [[ref]]."
  (when (and file (file-exists-p file))
    (with-temp-buffer
      (insert-file-contents file)
      (let (ids)
        (goto-char (point-min))
        (while (re-search-forward
                "\\\\transclude{\\([^}]+\\)}\\|\\[\\[\\([a-z]+-[0-9A-Za-z]+\\)\\]\\]"
                nil t)
          (let ((id (or (match-string 1) (match-string 2))))
            (unless (string= id "macros")
              (push id ids))))
        (delete-dups (nreverse ids))))))

(defun pluri--random-walk-3 (start-file &optional depth)
  "Random walk from START-FILE, collecting up to 3 verified non-horse trees.
Walks links up to DEPTH hops (default 3), checking each exists."
  (let ((depth (or depth 3))
        (visited (make-hash-table :test 'equal))
        (found '())
        (frontier (list start-file)))
    (puthash start-file t visited)
    (cl-loop for step from 0 below depth
             while (and frontier (< (length found) 3))
             do (let ((next-frontier '()))
                  (dolist (f frontier)
                    (dolist (id (pluri--extract-links f))
                      (let ((target (pluri--find-tree-file id)))
                        (when (and target
                                   (not (gethash target visited)))
                          (puthash target t visited)
                          (push target next-frontier)
                          (unless (pluri--horse-file-p target)
                            (when (< (length found) 3)
                              (push target found)))))))
                  (setq frontier (if (> (length next-frontier) 10)
                                     (cl-subseq (pluri--shuffle next-frontier) 0 10)
                                   (pluri--shuffle next-frontier)))))
    (nreverse found)))

(defun pluri--shuffle (list)
  "Return a shuffled copy of LIST."
  (let ((vec (vconcat list)))
    (cl-loop for i from (1- (length vec)) downto 1
             do (let* ((j (random (1+ i)))
                       (tmp (aref vec i)))
                  (aset vec i (aref vec j))
                  (aset vec j tmp)))
    (append vec nil)))

(defun pluri--random-horse-tree ()
  "Pick a random horse tree file."
  (let* ((trees (directory-files
                 (expand-file-name "trees/" pluri-horse-root)
                 t "^\\(horse\\|bci\\|bcf\\)-.*\\.tree$"))
         (choice (nth (random (length trees)) trees)))
    choice))

(defun pluri-locale-quartet ()
  "1 random horse tree + 3 transcluded non-horse trees via random walk.
Horse tree at full size, non-horse at 3/4. Each link verified."
  (interactive)
  (let* ((horse (pluri--random-horse-tree))
         (walked (pluri--random-walk-3 horse))
         (n-walked (length walked)))
    (when (< n-walked 3)
      (let* ((all-non (cl-remove-if
                       #'pluri--horse-file-p
                       (directory-files-recursively
                        pluri-horse-root "\\.tree$")))
             (shuffled (pluri--shuffle all-non)))
        (cl-loop for f in shuffled
                 while (< (length walked) 3)
                 unless (member f walked)
                 do (push f walked))))
    (let ((files (cons horse (cl-subseq walked 0 (min 3 (length walked))))))
      (pluri-parallel-view files)
      (message "Walk from %s -> %s"
               (file-name-nondirectory horse)
               (mapconcat #'file-name-nondirectory walked " | ")))))

(defun pluri-open-bcf-root ()
  "Open BCI Factory root tree."
  (interactive)
  (find-file (expand-file-name "trees/bcf-0001.tree" pluri-horse-root)))

(defun pluri-open-bci-math ()
  "Open BCI mathematics tree."
  (interactive)
  (find-file (expand-file-name "trees/bci-0001.tree" pluri-horse-root)))

(defun pluri-open-horse-portal ()
  "Open bci.horse portal tree."
  (interactive)
  (find-file (expand-file-name "trees/horse-0001.tree" pluri-horse-root)))

(defun pluri-open-plurigrid ()
  "Open plurigrid reference tree."
  (interactive)
  (find-file (expand-file-name "trees/bcf-0023.tree" pluri-horse-root)))

;; ──────────────────────────────────────────────────────────────────
;; Skill URI browser
;; ──────────────────────────────────────────────────────────────────

(defun pluri-skill-browser ()
  "Browse skill:// URIs from world.toml files."
  (interactive)
  (let ((buf (get-buffer-create "*skills*"))
        skills)
    (dolist (l pluri-world-letters)
      (let ((file (expand-file-name (format "%s/world.toml" l) pluri-worlds-root)))
        (when (file-exists-p file)
          (with-temp-buffer
            (insert-file-contents file)
            (while (re-search-forward "uri *= *\"\\(skill://[^\"]+\\)\"" nil t)
              (push (cons (match-string-no-properties 1) l) skills))))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize "Skill URIs across 26 worlds\n\n" 'face '(:weight bold :height 1.3)))
        (dolist (s (nreverse skills))
          (insert (format "  %s  [world %s]\n"
                          (propertize (car s) 'face 'font-lock-constant-face)
                          (propertize (cdr s) 'face '(:weight bold)))))
        (insert (format "\n%d skills found\n" (length skills))))
      (goto-char (point-min))
      (special-mode))
    (switch-to-buffer buf)))

;; ──────────────────────────────────────────────────────────────────
;; Global binding
;; ──────────────────────────────────────────────────────────────────

(global-set-key (kbd "C-c P") #'pluri-dispatch)

(provide 'forester-transient)
;;; forester-transient.el ends here
