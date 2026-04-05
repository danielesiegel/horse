/// BCIRoomScan — RoomPlan + ARKit LiDAR → point cloud for BCI station placement
///
/// Three scan modes matching the GF(3) station triad:
///   -1 (blue):  RoomPlan CapturedRoom → structured walls/furniture/openings
///    0 (horse): ARKit mesh → raw triangle mesh with classification
///   +1 (red):   LiDAR depth → dense point cloud (PLY export)
///
/// Usage on device:
///   1. Open app, scan room with LiDAR-equipped iPhone/iPad
///   2. RoomPlan identifies walls, doors, windows, furniture automatically
///   3. Export as USDZ (structured) + PLY (point cloud) + JSON (placement zones)
///   4. JSON marks candidate zones for chair(-1), screen(0), pegboard(+1)
///
/// This file is the data model + export logic. The SwiftUI scanning view
/// requires an actual iOS device with LiDAR (iPhone 12 Pro+, iPad Pro 2020+).

import Foundation

// MARK: - GF(3) Station Trit

enum StationTrit: Int, Codable {
    case blue = -1   // chair, afferent, sieve
    case horse = 0   // screen, crossover, shimmer
    case red = 1     // pegboard, efferent, cosieve

    var label: String {
        switch self {
        case .blue: return "chair"
        case .horse: return "screen"
        case .red: return "headset-station"
        }
    }

    var ikea: String {
        switch self {
        case .blue: return "ÖRFJÄLL"
        case .horse: return "LACK+SIGFINN"
        case .red: return "SKÅDIS"
        }
    }
}

// MARK: - Point Cloud

struct Point3D: Codable {
    let x: Float
    let y: Float
    let z: Float
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let classification: Classification

    enum Classification: String, Codable {
        case wall, floor, ceiling, door, window, furniture, unknown
    }
}

struct PointCloud {
    var points: [Point3D] = []
    var captureDate: Date = Date()

    /// Export as PLY (Polygon File Format) — universal point cloud interchange
    func exportPLY() -> Data {
        var ply = "ply\n"
        ply += "format ascii 1.0\n"
        ply += "element vertex \(points.count)\n"
        ply += "property float x\n"
        ply += "property float y\n"
        ply += "property float z\n"
        ply += "property uchar red\n"
        ply += "property uchar green\n"
        ply += "property uchar blue\n"
        ply += "comment classification per-vertex in separate JSON\n"
        ply += "comment BCI Factory station scan\n"
        ply += "comment date \(ISO8601DateFormatter().string(from: captureDate))\n"
        ply += "end_header\n"

        for p in points {
            ply += "\(p.x) \(p.y) \(p.z) \(p.r) \(p.g) \(p.b)\n"
        }

        return Data(ply.utf8)
    }
}

// MARK: - Placement Zone (candidate locations for station objects)

struct PlacementZone: Codable {
    let trit: StationTrit
    let center: [Float]      // [x, y, z] in room coordinates
    let normal: [Float]      // surface normal (wall-facing for screen/pegboard)
    let dimensions: [Float]  // [width, height, depth] in meters
    let score: Float         // 0-1 suitability score
    let reason: String

    /// BCI station placement heuristics:
    /// - Chair: needs floor area ≥ 0.6m², near wall but not blocking door
    /// - Screen: needs wall segment ≥ 0.5m wide, eye-height (1.1-1.4m), no window glare
    /// - Pegboard: needs wall segment ≥ 0.4m wide, within arm reach of chair (≤0.8m)
    static func scoreForChair(floorArea: Float, distToWall: Float, distToDoor: Float) -> Float {
        var s: Float = 0
        if floorArea >= 0.6 { s += 0.3 }
        if distToWall < 0.5 { s += 0.3 }     // back near wall
        if distToDoor > 1.0 { s += 0.2 }     // not blocking egress
        if floorArea < 2.0 { s += 0.2 }      // cozy, not cavernous
        return min(s, 1.0)
    }

    static func scoreForScreen(wallWidth: Float, height: Float, hasWindow: Bool) -> Float {
        var s: Float = 0
        if wallWidth >= 0.5 { s += 0.3 }
        if height >= 1.1 && height <= 1.4 { s += 0.3 }  // eye height seated
        if !hasWindow { s += 0.2 }                        // no glare
        s += 0.2                                           // base score for any wall
        return min(s, 1.0)
    }

    static func scoreForPegboard(wallWidth: Float, distToChair: Float) -> Float {
        var s: Float = 0
        if wallWidth >= 0.4 { s += 0.3 }
        if distToChair <= 0.8 { s += 0.4 }   // arm's reach
        if distToChair >= 0.3 { s += 0.1 }   // not overlapping
        s += 0.2
        return min(s, 1.0)
    }
}

// MARK: - Room Scan Result

struct RoomScanResult: Codable {
    let scanDate: String
    let roomDimensions: [Float]  // [width, depth, height] meters
    let wallCount: Int
    let doorCount: Int
    let windowCount: Int
    let floorArea: Float         // m²
    let placementZones: [PlacementZone]
    let tritConserved: Bool      // zones sum to 0 mod 3 (always true if all 3 placed)

    /// The canonical export: room scan → station placement JSON
    /// This feeds into:
    ///   1. zig-syrup spatial propagator (world:// protocol)
    ///   2. Emacs kiosk layout (ghostty-ix viewport)
    ///   3. bcf-0043 BOM validation (does furniture fit?)
    func exportJSON() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }
}

// MARK: - HomeKit Room Metadata

/// Bridge to HomeKit: if the scanned room is already a HomeKit room,
/// pull its accessories (lights, sensors, plugs) as context for the BCI station.
/// A smart plug on the Cyton PSU = remote power cycle.
/// A Hue light = ambient color feedback (mirror the color:// URI as room lighting).
struct HomeKitContext: Codable {
    let roomName: String?
    let accessories: [HomeKitAccessory]

    struct HomeKitAccessory: Codable {
        let name: String
        let category: String      // "light", "plug", "sensor", "thermostat"
        let reachable: Bool
        let bciRole: BCIRole?

        enum BCIRole: String, Codable {
            case ambientColor       // Hue/LIFX → mirror color:// as room color
            case powerSwitch        // smart plug → Cyton PSU power cycle
            case environmentSensor  // temp/humidity → session metadata
            case occupancy          // motion sensor → auto-wake kiosk
        }
    }
}

// MARK: - DuckDB Export

/// Point cloud as DuckDB-ingestible CSV for spatial queries
/// Each point: x,y,z,r,g,b,classification,trit_zone
///
/// ```sql
/// CREATE TABLE room_scan AS
/// SELECT * FROM read_csv('scan.csv',
///   columns={'x':'FLOAT','y':'FLOAT','z':'FLOAT',
///            'r':'UTINYINT','g':'UTINYINT','b':'UTINYINT',
///            'classification':'VARCHAR','trit_zone':'TINYINT'});
///
/// -- Find wall segments suitable for screen placement
/// SELECT avg(x), avg(y), avg(z), count(*)
/// FROM room_scan
/// WHERE classification = 'wall' AND z BETWEEN 1.1 AND 1.4
/// GROUP BY round(x, 0.5), round(y, 0.5)
/// HAVING count(*) > 100;
/// ```
struct DuckDBExport {
    static func exportCSV(cloud: PointCloud, zones: [PlacementZone]) -> Data {
        var csv = "x,y,z,r,g,b,classification,trit_zone\n"
        for p in cloud.points {
            // Find which zone this point belongs to (nearest zone center)
            let zone = nearestZone(point: p, zones: zones)
            csv += "\(p.x),\(p.y),\(p.z),\(p.r),\(p.g),\(p.b),\(p.classification.rawValue),\(zone?.trit.rawValue ?? 99)\n"
        }
        return Data(csv.utf8)
    }

    static func nearestZone(point: Point3D, zones: [PlacementZone]) -> PlacementZone? {
        zones.min(by: { a, b in
            let da = pow(point.x - a.center[0], 2) + pow(point.y - a.center[1], 2) + pow(point.z - a.center[2], 2)
            let db = pow(point.x - b.center[0], 2) + pow(point.y - b.center[1], 2) + pow(point.z - b.center[2], 2)
            return da < db
        })
    }
}

// MARK: - Entrypoint (macOS CLI for testing with synthetic data)

@main
struct BCIRoomScanCLI {
    static func main() {
        print("BCIRoomScan — BCI Factory station placement from LiDAR point cloud")
        print("")
        print("Scan modes:")
        print("  -1 (blue):  RoomPlan CapturedRoom → structured geometry")
        print("   0 (horse): ARKit scene mesh → classified triangles")
        print("  +1 (red):   LiDAR depth map → dense PLY point cloud")
        print("")
        print("Requires LiDAR-equipped iOS device (iPhone 12 Pro+ / iPad Pro 2020+)")
        print("Export formats: PLY, USDZ, JSON (placement zones), CSV (DuckDB)")
        print("")

        // Synthetic room for testing: 3m × 4m × 2.7m
        let result = RoomScanResult(
            scanDate: ISO8601DateFormatter().string(from: Date()),
            roomDimensions: [3.0, 4.0, 2.7],
            wallCount: 4,
            doorCount: 1,
            windowCount: 1,
            floorArea: 12.0,
            placementZones: [
                PlacementZone(
                    trit: .blue,
                    center: [1.5, 3.0, 0.0],
                    normal: [0, -1, 0],
                    dimensions: [0.7, 0.5, 0.7],
                    score: PlacementZone.scoreForChair(floorArea: 0.49, distToWall: 0.3, distToDoor: 2.0),
                    reason: "Back wall, away from door, floor clear"
                ),
                PlacementZone(
                    trit: .horse,
                    center: [1.5, 3.5, 1.2],
                    normal: [0, -1, 0],
                    dimensions: [0.6, 0.4, 0.05],
                    score: PlacementZone.scoreForScreen(wallWidth: 2.0, height: 1.2, hasWindow: false),
                    reason: "Back wall at eye height, no window, wide segment"
                ),
                PlacementZone(
                    trit: .red,
                    center: [2.5, 3.5, 1.0],
                    normal: [0, -1, 0],
                    dimensions: [0.4, 0.6, 0.1],
                    score: PlacementZone.scoreForPegboard(wallWidth: 0.8, distToChair: 0.7),
                    reason: "Right of screen, within arm's reach of chair"
                ),
            ],
            tritConserved: true  // -1 + 0 + 1 = 0 ✓
        )

        let json = String(data: result.exportJSON(), encoding: .utf8)!
        print(json)
    }
}
