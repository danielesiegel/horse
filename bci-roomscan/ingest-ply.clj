#!/usr/bin/env bb
;; ingest-ply.clj — Watch for AirDropped PLY files, ingest into DuckDB, score placement
;;
;; Usage: bb ingest-ply.clj [path-to-ply]
;;   No arg: watches ~/Downloads and ~/Desktop for new .ply files
;;   With arg: ingests that specific file
;;
;; Pipeline:
;;   iPhone LiDAR scan → AirDrop → ~/Downloads/*.ply → DuckDB → placement zones

(require '[clojure.java.io :as io]
         '[clojure.string :as str])
(import '[java.nio ByteBuffer ByteOrder])

(def duck "/Users/bob/Library/Python/3.9/bin/duckdb")
(def db "/Users/bob/i.duckdb")

(defn parse-ply-header [path]
  (with-open [r (io/reader path)]
    (loop [lines (line-seq r)
           vertex-count 0
           format nil
           props []]
      (if-let [line (first lines)]
        (cond
          (str/starts-with? line "element vertex ")
          (recur (rest lines) (parse-long (subs line 15)) format props)

          (str/starts-with? line "format ")
          (recur (rest lines) vertex-count (second (str/split line #" ")) props)

          (str/starts-with? line "property ")
          (recur (rest lines) vertex-count format (conj props line))

          (= line "end_header")
          {:vertex-count vertex-count :format format :properties props}

          :else (recur (rest lines) vertex-count format props))
        {:vertex-count vertex-count :format format :properties props}))))

(defn is-gaussian-splat? [header]
  (some #(str/includes? % "f_dc_0") (:properties header)))

(defn ingest-binary-splat-ply
  "Extract binary 3DGS PLY → CSV → DuckDB"
  [path table-name]
  (let [ba (.readAllBytes (java.io.FileInputStream. (str path)))
        s (String. ba 0 (min 1000 (count ba)))
        idx (.indexOf s "end_header")
        header-end (+ idx (count "end_header\n"))
        n (:vertex-count (parse-ply-header path))
        stride (max 1 (quot n 50000)) ;; cap at ~50K points for DuckDB
        csv-path (str "/tmp/" table-name ".csv")
        C0 0.28209479
        buf (doto (ByteBuffer/wrap ba header-end (* n 56))
              (.order ByteOrder/LITTLE_ENDIAN))]
    (with-open [w (io/writer csv-path)]
      (.write w "x,y,z,r,g,b,opacity,scale_0,scale_1,scale_2\n")
      (dotimes [i n]
        (let [x (.getFloat buf) y (.getFloat buf) z (.getFloat buf)
              dc0 (.getFloat buf) dc1 (.getFloat buf) dc2 (.getFloat buf)
              op (.getFloat buf)
              s0 (.getFloat buf) s1 (.getFloat buf) s2 (.getFloat buf)
              _ (.getFloat buf) _ (.getFloat buf) _ (.getFloat buf) _ (.getFloat buf)]
          (when (zero? (mod i stride))
            (let [ri (min 255 (max 0 (int (* (+ 0.5 (* C0 dc0)) 255))))
                  gi (min 255 (max 0 (int (* (+ 0.5 (* C0 dc1)) 255))))
                  bi (min 255 (max 0 (int (* (+ 0.5 (* C0 dc2)) 255))))
                  alpha (/ 1.0 (+ 1.0 (Math/exp (- op))))]
              (when (and (Float/isFinite x) (> alpha 0.1))
                (.write w (format "%.4f,%.4f,%.4f,%d,%d,%d,%.4f,%.4f,%.4f,%.4f\n"
                                  x y z ri gi bi alpha s0 s1 s2))))))))
    csv-path))

(defn ingest-ascii-ply
  "Extract ASCII PLY → CSV → DuckDB"
  [path table-name]
  (let [csv-path (str "/tmp/" table-name ".csv")
        lines (str/split-lines (slurp path))
        header-idx (inc (.indexOf lines "end_header"))
        data-lines (drop header-idx lines)]
    (with-open [w (io/writer csv-path)]
      (.write w "x,y,z,r,g,b\n")
      (doseq [line data-lines]
        (let [parts (str/split (str/trim line) #"\s+")]
          (when (>= (count parts) 3)
            (let [xyz (take 3 parts)
                  rgb (if (>= (count parts) 6) (take 3 (drop 3 parts)) ["128" "128" "128"])]
              (.write w (str (str/join "," (concat xyz rgb)) "\n")))))))
    csv-path))

(defn load-into-duckdb [csv-path table-name]
  (let [r (clojure.java.shell/sh duck db "-c"
            (format "DROP TABLE IF EXISTS %s; CREATE TABLE %s AS SELECT * FROM read_csv('%s'); SELECT count(*) AS points FROM %s;"
                    table-name table-name csv-path table-name))]
    (println (:out r))
    (when (seq (:err r)) (println "  err:" (:err r)))))

(defn score-placement [table-name]
  (let [r (clojure.java.shell/sh duck db "-c"
            (format "
-- Bounding box
SELECT 'bounds' AS metric,
  round(max(x)-min(x),2) AS val_1,
  round(max(y)-min(y),2) AS val_2,
  round(max(z)-min(z),2) AS val_3
FROM %s
UNION ALL
-- Centroid
SELECT 'centroid', round(avg(x),2), round(avg(y),2), round(avg(z),2) FROM %s
UNION ALL
-- Wall density at eye height (z 1.1-1.4m for room-scale, scaled for larger scenes)
SELECT 'eye_height_points', count(*)::float, 0, 0
FROM %s WHERE z BETWEEN (SELECT percentile_cont(0.3) WITHIN GROUP (ORDER BY z) FROM %s)
                    AND (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY z) FROM %s);
" table-name table-name table-name table-name table-name))]
    (println "  Placement analysis:")
    (println (:out r))))

(defn ingest-file [path]
  (let [fname (.getName (io/file path))
        table-name (-> fname (str/replace #"\.ply$" "") (str/replace #"[^a-zA-Z0-9_]" "_"))
        table-name (str "pc_" table-name)
        header (parse-ply-header path)]
    (println (format "Ingesting %s (%d vertices, %s format, %s)"
                     fname (:vertex-count header) (:format header)
                     (if (is-gaussian-splat? header) "3DGS" "standard")))
    (let [csv-path (if (is-gaussian-splat? header)
                     (ingest-binary-splat-ply path table-name)
                     (ingest-ascii-ply path table-name))]
      (load-into-duckdb csv-path table-name)
      (score-placement table-name)
      (println (format "  Table '%s' ready in %s" table-name db)))))

;; --- main ---
(if-let [path (first *command-line-args*)]
  ;; Direct ingest
  (ingest-file path)
  ;; Watch mode
  (do
    (println "⬛ BCI Station Scanner — watching for PLY files...")
    (println "  AirDrop or save a .ply to ~/Downloads or ~/Desktop")
    (println "  Press Ctrl+C to stop")
    (println)
    (let [watch-dirs [(io/file (str (System/getProperty "user.home") "/Downloads"))
                      (io/file (str (System/getProperty "user.home") "/Desktop"))]
          seen (atom #{})]
      (loop []
        (doseq [dir watch-dirs]
          (doseq [f (.listFiles dir)]
            (when (and (str/ends-with? (.getName f) ".ply")
                       (not (@seen (.getAbsolutePath f)))
                       (> (.lastModified f) (- (System/currentTimeMillis) 60000)))
              (swap! seen conj (.getAbsolutePath f))
              (println (format "\n✦ New PLY detected: %s" (.getName f)))
              (ingest-file (.getAbsolutePath f)))))
        (Thread/sleep 2000)
        (recur)))))
