#!/usr/bin/env bb
;; ingest-scan.clj — add a 3D file to the horse forest
;; Usage: bb ingest-scan.clj <file.ply|obj|stl|usdz> [repo-name]
;;
;; Workflow:
;;   1. Parse file header → vertices, faces, format
;;   2. Assign next scan-NNNN ID
;;   3. Create trees/scan-NNNN.tree with full metadata
;;   4. Insert into DuckDB scan_inventory
;;   5. Run pre-commit hook to validate GF(3)

(require '[clojure.string :as str]
         '[clojure.java.io :as io])

(def duckdb "/Users/bob/Library/Python/3.9/bin/duckdb")
(def db "/Users/bob/i.duckdb")
(def tree-dir "trees")

;; --- Find next scan ID ---

(defn next-scan-id []
  (let [existing (->> (file-seq (io/file tree-dir))
                      (filter #(re-matches #"scan-\d+\.tree" (.getName %)))
                      (map #(-> (.getName %) (str/replace #"scan-(\d+)\.tree" "$1") parse-long))
                      sort
                      last)]
    (format "scan-%04d" (inc (or existing 0)))))

;; --- File parsers ---

(defn parse-ply-header [path]
  (with-open [rdr (io/reader path)]
    (let [lines (take 50 (line-seq rdr))
          header-lines (take-while #(not= % "end_header") lines)
          format-line (first (filter #(str/starts-with? % "format ") header-lines))
          vertex-line (first (filter #(str/starts-with? % "element vertex ") header-lines))
          face-line (first (filter #(str/starts-with? % "element face ") header-lines))
          has-splat (some #(str/includes? % "f_dc_0") header-lines)]
      {:vertices (some-> vertex-line (str/split #"\s+") last parse-long)
       :faces (or (some-> face-line (str/split #"\s+") last parse-long) 0)
       :format (str "PLY/"
                    (cond
                      has-splat "3dgs"
                      (and format-line (str/includes? format-line "binary_little_endian")) "binary_little_endian"
                      (and format-line (str/includes? format-line "binary_big_endian")) "binary_big_endian"
                      :else "ascii"))})))

(defn parse-obj [path]
  (with-open [rdr (io/reader path)]
    (let [lines (line-seq rdr)
          vertices (count (filter #(re-matches #"v\s+.*" %) lines))
          faces (count (filter #(re-matches #"f\s+.*" %) lines))]
      {:vertices vertices :faces faces :format "OBJ"})))

(defn parse-stl [path]
  (let [content (slurp path)
        ascii? (str/starts-with? content "solid")]
    (if ascii?
      (let [facets (count (re-seq #"facet normal" content))]
        {:vertices (* facets 3) :faces facets :format "STL/ascii"})
      ;; Binary STL: 80 byte header + 4 byte triangle count
      (let [bytes (with-open [is (io/input-stream path)]
                    (let [buf (byte-array 84)]
                      (.read is buf)
                      buf))
            n-triangles (bit-or (bit-and (aget bytes 80) 0xFF)
                                (bit-shift-left (bit-and (aget bytes 81) 0xFF) 8)
                                (bit-shift-left (bit-and (aget bytes 82) 0xFF) 16)
                                (bit-shift-left (bit-and (aget bytes 83) 0xFF) 24))]
        {:vertices (* n-triangles 3) :faces n-triangles :format "STL/binary"}))))

(defn parse-file [path]
  (let [ext (str/lower-case (last (str/split (.getName (io/file path)) #"\.")))
        base-info (case ext
                    "ply" (parse-ply-header path)
                    "obj" (parse-obj path)
                    "stl" (parse-stl path)
                    "usdz" {:vertices 0 :faces 0 :format "USDZ"}
                    (throw (ex-info (str "Unknown extension: " ext) {:ext ext})))]
    (assoc base-info
           :extension ext
           :filename (.getName (io/file path))
           :size-bytes (.length (io/file path)))))

;; --- Trit assignment ---

(defn format-trit [fmt]
  (cond
    (str/includes? fmt "PLY") -1
    (str/includes? fmt "OBJ") 0
    (or (str/includes? fmt "STL") (str/includes? fmt "USDZ")) 1
    :else 0))

(defn trit-tag [trit]
  (case (int trit)
    -1 "trit-minus"
    0  "trit-zero"
    1  "trit-plus"))

;; --- Tree generation ---

(defn generate-tree [scan-id info repo]
  (let [trit (format-trit (:format info))]
    (str "\\title{" (:filename info) "}\n"
         "\\date{2026-04-04}\n"
         "\\taxon{scan}\n"
         "\\author{barton-rhodes}\n"
         "\\tag{" (str/lower-case (:extension info)) "}\n"
         "\\tag{" (trit-tag trit) "}\n"
         "\\meta{trit}{" trit "}\n"
         "\\meta{vertices}{" (:vertices info) "}\n"
         "\\meta{faces}{" (:faces info) "}\n"
         "\\meta{format}{" (:format info) "}\n"
         "\\meta{source-path}{" repo "}\n"
         "\n"
         "\\import{macros}\n"
         "\n"
         "\\p{" (case (int trit) -1 "−" 0 "○" 1 "+") " "
         (:filename info)
         " (" (:vertices info) " vertices, " (:format info) ")"
         " from " repo ".}\n"
         "\n"
         "\\subtree{\\title{Station context}\n"
         "\\p{Indexed in \\ref{scan-0000}. Station placement via \\ref{bcf-0043}.}\n"
         "}\n")))

;; --- DuckDB insert ---

(defn insert-duckdb [scan-id info repo]
  (let [sql (format "INSERT INTO scan_inventory VALUES ('%s', '%s', '%s', %d, %d, %d, '%s', '%s');"
                    (:filename info) (:extension info) (:format info)
                    (:vertices info) (:faces info) (:size-bytes info)
                    repo (:filename info))
        r (clojure.java.shell/sh duckdb db "-c" sql)]
    (when (not= 0 (:exit r))
      (println "DuckDB warning:" (:err r)))))

;; --- Main ---

(let [args *command-line-args*]
  (when (< (count args) 1)
    (println "Usage: bb ingest-scan.clj <file> [repo-name]")
    (System/exit 1))

  (let [path (first args)
        repo (or (second args) "local")
        _ (when-not (.exists (io/file path))
            (println "File not found:" path)
            (System/exit 1))
        info (parse-file path)
        scan-id (next-scan-id)
        tree-content (generate-tree scan-id info repo)
        tree-path (str tree-dir "/" scan-id ".tree")]

    (println (str "Ingesting: " (:filename info)))
    (println (str "  Format: " (:format info) " | Vertices: " (:vertices info) " | Faces: " (:faces info)))
    (println (str "  Trit: " (format-trit (:format info)) " (" (trit-tag (format-trit (:format info))) ")"))
    (println (str "  → " tree-path))

    ;; Write tree file
    (spit tree-path tree-content)
    (println (str "  ✓ Tree created"))

    ;; Insert into DuckDB
    (insert-duckdb scan-id info repo)
    (println (str "  ✓ DuckDB updated"))

    ;; Validate
    (let [hook (clojure.java.shell/sh "bb" ".githooks/pre-commit" :dir ".")]
      (print (:out hook))
      (when (not= 0 (:exit hook))
        (println "\n⚠ GF(3) violation — may need a balancing scan")))))
