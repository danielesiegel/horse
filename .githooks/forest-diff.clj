#!/usr/bin/env bb
;; forest-diff.clj — semantic diff driver for forester trees
;; Shows typed operations instead of raw text hunks
;;
;; Install: git config diff.forest.command ".githooks/forest-diff.clj"
;;          echo '*.tree diff=forest' >> .gitattributes
;;
;; Usage: called by git diff with 7 args:
;;   path old-file old-hex old-mode new-file new-hex new-mode

(require '[clojure.string :as str]
         '[clojure.java.io :as io])

;; --- Tree parsing ---

(defn parse-tree-content [content]
  (let [strip-verb (str/replace content #"\\startverb[\s\S]*?\\stopverb" "")]
    {:refs (into #{} (map second (re-seq #"\\ref\{([^}]+)\}" strip-verb)))
     :trit (some->> (re-find #"\\meta\{trit\}\{(-?\d+)\}" content) second parse-long)
     :taxon (second (re-find #"\\taxon\{(\w+)\}" content))
     :tags (into #{} (map second (re-seq #"\\tag\{([^}]+)\}" content)))
     :title (second (re-find #"\\title\{([^}]+)\}" content))
     :meta (into {} (map (fn [[_ k v]] [k v]) (re-seq #"\\meta\{(\w+)\}\{([^}]+)\}" content)))
     :subtrees (mapv second (re-seq #"\\subtree\{\\title\{([^}]+)\}" content))}))

(defn classify-ref [source-id target-id source-tags]
  (cond
    ;; Same prefix = sibling
    (and (re-find #"^scan-" source-id) (re-find #"^scan-" target-id)
         (not= target-id "scan-0000"))
    :Sibling

    ;; Points to index
    (= target-id "scan-0000")
    :IndexEntry

    ;; Points to bcf-0043 or bcf-0044 from a scan
    (and (re-find #"^scan-" source-id) (#{"bcf-0043" "bcf-0044"} target-id))
    :StationContext

    ;; Points to bcf-* from scan (structural)
    (and (re-find #"^scan-" source-id) (re-find #"^bcf-" target-id))
    :StructuralLink

    ;; Default
    :else :Ref))

;; --- Diff computation ---

(defn compute-ops [old-tree new-tree id]
  (let [ops (atom [])]
    ;; New refs
    (doseq [r (clojure.set/difference (:refs new-tree) (:refs old-tree))]
      (swap! ops conj {:op :AddRef :source id :target r
                       :kind (classify-ref id r (:tags new-tree))}))
    ;; Removed refs
    (doseq [r (clojure.set/difference (:refs old-tree) (:refs new-tree))]
      (swap! ops conj {:op :DelRef :source id :target r
                       :kind (classify-ref id r (:tags old-tree))}))
    ;; Trit change
    (when (and (:trit old-tree) (:trit new-tree) (not= (:trit old-tree) (:trit new-tree)))
      (swap! ops conj {:op :SetMeta :tree id :key "trit"
                       :old (:trit old-tree) :new (:trit new-tree)
                       :warning (str "GF(3) value changed: " (:trit old-tree) " → " (:trit new-tree))}))
    ;; Taxon change
    (when (and (:taxon old-tree) (:taxon new-tree) (not= (:taxon old-tree) (:taxon new-tree)))
      (swap! ops conj {:op :SetTaxon :tree id :old (:taxon old-tree) :new (:taxon new-tree)}))
    ;; New tags
    (doseq [t (clojure.set/difference (:tags new-tree) (:tags old-tree))]
      (swap! ops conj {:op :AddTag :tree id :tag t}))
    ;; Removed tags
    (doseq [t (clojure.set/difference (:tags old-tree) (:tags new-tree))]
      (swap! ops conj {:op :DelTag :tree id :tag t}))
    ;; New subtrees
    (doseq [s (remove (set (:subtrees old-tree)) (:subtrees new-tree))]
      (swap! ops conj {:op :AddSubtree :tree id :title s}))
    ;; Meta changes
    (doseq [[k v] (:meta new-tree)]
      (when (not= v (get (:meta old-tree) k))
        (swap! ops conj {:op :SetMeta :tree id :key k :old (get (:meta old-tree) k) :new v})))
    @ops))

;; --- Formatting ---

(def ansi-green "\033[32m")
(def ansi-red "\033[31m")
(def ansi-yellow "\033[33m")
(def ansi-cyan "\033[36m")
(def ansi-reset "\033[0m")

(defn format-op [{:keys [op] :as o}]
  (case op
    :AddRef    (str ansi-green "  +ref(" (:source o) " → " (:target o) ", " (name (:kind o)) ")" ansi-reset)
    :DelRef    (str ansi-red   "  -ref(" (:source o) " → " (:target o) ", " (name (:kind o)) ")" ansi-reset)
    :SetMeta   (str ansi-yellow "  Δmeta(" (:tree o) "." (:key o) ": " (:old o) " → " (:new o) ")"
                    (when (:warning o) (str " ⚠ " (:warning o))) ansi-reset)
    :SetTaxon  (str ansi-yellow "  Δtaxon(" (:tree o) ": " (:old o) " → " (:new o) ")" ansi-reset)
    :AddTag    (str ansi-green  "  +tag(" (:tree o) ", " (:tag o) ")" ansi-reset)
    :DelTag    (str ansi-red    "  -tag(" (:tree o) ", " (:tag o) ")" ansi-reset)
    :AddSubtree (str ansi-cyan  "  +subtree(" (:tree o) ", \"" (:title o) "\")" ansi-reset)
    (str "  ?" (pr-str o))))

(defn format-commutation [ops]
  ;; Check which ops commute with each other
  (when (> (count ops) 1)
    (let [ref-ops (filter #(#{:AddRef :DelRef} (:op %)) ops)
          meta-ops (filter #(#{:SetMeta :SetTaxon} (:op %)) ops)]
      (when (and (seq ref-ops) (seq meta-ops))
        (str ansi-cyan
             "\n  ⊗ Commutation: " (count ref-ops) " ref ops ⊗ " (count meta-ops) " meta ops"
             "\n    In pijul: these commute (independent graph regions)"
             "\n    In git: depends on line proximity (text topology)"
             ansi-reset)))))

;; --- Main ---

(let [args *command-line-args*]
  (if (< (count args) 5)
    ;; Standalone mode: diff two tree files
    (if (>= (count args) 2)
      (let [old-content (slurp (first args))
            new-content (slurp (second args))
            id (str/replace (.getName (io/file (second args))) #"\.tree$" "")
            old-tree (parse-tree-content old-content)
            new-tree (parse-tree-content new-content)
            ops (compute-ops old-tree new-tree id)]
        (println (str "forest-diff: " id))
        (if (seq ops)
          (do
            (doseq [o ops] (println (format-op o)))
            (when-let [comm (format-commutation ops)]
              (println comm)))
          (println "  (no semantic changes)")))
      (println "Usage: forest-diff.clj <old.tree> <new.tree>"))

    ;; Git diff driver mode: path old-file old-hex old-mode new-file new-hex new-mode
    (let [path (nth args 0)
          old-file (nth args 1)
          new-file (nth args 4)
          id (str/replace (.getName (io/file path)) #"\.tree$" "")
          old-content (try (slurp old-file) (catch Exception _ ""))
          new-content (try (slurp new-file) (catch Exception _ ""))
          old-tree (parse-tree-content old-content)
          new-tree (parse-tree-content new-content)
          ops (compute-ops old-tree new-tree id)]
      (println (str "forest-diff: " id " (" path ")"))
      (if (seq ops)
        (do
          (doseq [o ops] (println (format-op o)))
          (when-let [comm (format-commutation ops)]
            (println comm)))
        (println "  (no semantic changes)")))))
