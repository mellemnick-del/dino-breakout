import Foundation

struct Cell: Hashable {
    let col: Int
    let row: Int
}

/// The park map. Tracks which cells are built on and keeps a distance field
/// to the helipad, so every dino always knows its shortest way out. Rebuilding
/// the field after each placement is what makes dinos reroute around your maze.
final class Grid {
    static let unreachable = Int.max

    let cols: Int
    let rows: Int
    /// Paddock gate, where dinos break out.
    let spawn: Cell
    /// Evac helipad, what you're defending.
    let exit: Cell
    /// Boulders and water: always blocked, never buildable.
    let terrain: Set<Cell>
    /// River squares. Swimmers can cross them; nothing else can.
    let water: Set<Cell>
    private(set) var blocked: Set<Cell> = []
    private var field: [Int] = []
    /// The same distance map, but with the river open.
    private var swimField: [Int] = []

    init(cols: Int, rows: Int, spawn: Cell, exit: Cell, terrain: Set<Cell> = [], water: Set<Cell> = []) {
        self.cols = cols
        self.rows = rows
        self.spawn = spawn
        self.exit = exit
        self.terrain = terrain
        self.water = water
        blocked = terrain
        field = buildField(blocked: blocked)
        swimField = buildField(blocked: blocked.subtracting(water))
    }

    convenience init(level: Level) {
        self.init(
            cols: Level.cols, rows: Level.rows, spawn: level.spawn, exit: level.exit,
            terrain: level.terrain, water: Set(level.water)
        )
    }

    func contains(_ cell: Cell) -> Bool {
        cell.col >= 0 && cell.col < cols && cell.row >= 0 && cell.row < rows
    }

    /// Steps from this cell to the helipad.
    func distance(at cell: Cell, swims: Bool = false) -> Int {
        guard contains(cell) else { return Grid.unreachable }
        return swims ? swimField[index(cell)] : field[index(cell)]
    }

    /// The neighbor one step closer to the helipad, or nil when already there.
    func nextStep(from cell: Cell, swims: Bool = false) -> Cell? {
        let here = distance(at: cell, swims: swims)
        guard here != Grid.unreachable, here > 0 else { return nil }
        return neighbors(of: cell).min { distance(at: $0, swims: swims) < distance(at: $1, swims: swims) }
    }

    /// Builds on a cell unless that would seal off the paddock gate or any cell
    /// in `mustStayOpen` (where dinos are standing or heading). Returns false and
    /// changes nothing if the build isn't allowed.
    func block(_ cell: Cell, keeping mustStayOpen: [Cell], keepingSwimmers swimmers: [Cell] = []) -> Bool {
        guard contains(cell), cell != spawn, cell != exit, !blocked.contains(cell) else { return false }
        var trial = blocked
        trial.insert(cell)
        let trialField = buildField(blocked: trial)
        for open in [spawn] + mustStayOpen where trialField[index(open)] == Grid.unreachable {
            return false
        }
        let trialSwim = buildField(blocked: trial.subtracting(water))
        for open in swimmers where trialSwim[index(open)] == Grid.unreachable {
            return false
        }
        blocked = trial
        field = trialField
        swimField = trialSwim
        return true
    }

    func unblock(_ cell: Cell) {
        guard !terrain.contains(cell), blocked.remove(cell) != nil else { return }
        field = buildField(blocked: blocked)
        swimField = buildField(blocked: blocked.subtracting(water))
    }

    // MARK: - Private

    private func index(_ cell: Cell) -> Int {
        cell.row * cols + cell.col
    }

    private func neighbors(of cell: Cell) -> [Cell] {
        [
            Cell(col: cell.col, row: cell.row - 1),
            Cell(col: cell.col - 1, row: cell.row),
            Cell(col: cell.col + 1, row: cell.row),
            Cell(col: cell.col, row: cell.row + 1)
        ].filter { contains($0) }
    }

    /// Breadth-first search outward from the helipad.
    private func buildField(blocked: Set<Cell>) -> [Int] {
        var result = Array(repeating: Grid.unreachable, count: cols * rows)
        result[index(exit)] = 0
        var queue = [exit]
        var head = 0
        while head < queue.count {
            let cell = queue[head]
            head += 1
            let next = result[index(cell)] + 1
            for neighbor in neighbors(of: cell)
            where !blocked.contains(neighbor) && result[index(neighbor)] == Grid.unreachable {
                result[index(neighbor)] = next
                queue.append(neighbor)
            }
        }
        return result
    }
}
