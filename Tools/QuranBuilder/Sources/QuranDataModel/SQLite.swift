// Minimal sqlite3 wrapper shared by the pipeline (writer) and the integrity tests (reader).

import Foundation
import SQLite3

public enum SQLiteError: Error, CustomStringConvertible {
    case open(String)
    case statement(sql: String, message: String)

    public var description: String {
        switch self {
        case .open(let message): "cannot open database: \(message)"
        case .statement(let sql, let message): "\(message) in: \(sql)"
        }
    }
}

public enum SQLiteValue: Sendable, ExpressibleByIntegerLiteral, ExpressibleByStringLiteral, ExpressibleByNilLiteral {
    case int(Int)
    case text(String)
    case null

    public init(integerLiteral value: Int) { self = .int(value) }
    public init(stringLiteral value: String) { self = .text(value) }
    public init(nilLiteral: ()) { self = .null }

    public init(_ value: Int?) { self = value.map(SQLiteValue.int) ?? .null }
    public init(_ value: String?) { self = value.map(SQLiteValue.text) ?? .null }
}

/// sqlite3 copies bound text immediately with this destructor.
private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class SQLiteDatabase {
    private let handle: OpaquePointer

    public init(path: String, readOnly: Bool) throws {
        var db: OpaquePointer?
        let flags = readOnly ? SQLITE_OPEN_READONLY : (SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? path
            sqlite3_close(db)
            throw SQLiteError.open("\(path): \(message)")
        }
        handle = db
    }

    deinit { sqlite3_close(handle) }

    public func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteError.statement(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    public func prepare(_ sql: String) throws -> SQLiteStatement {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SQLiteError.statement(sql: sql, message: String(cString: sqlite3_errmsg(handle)))
        }
        return SQLiteStatement(statement: statement, database: handle, sql: sql)
    }

    /// Runs `body` in one transaction; rolls back if it throws.
    public func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN")
        do {
            try body()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    /// Runs a query and calls `row` for each result row.
    public func query(_ sql: String, _ arguments: [SQLiteValue] = [], row: (SQLiteRow) throws -> Void) throws {
        let statement = try prepare(sql)
        try statement.bind(arguments)
        while try statement.step() {
            try row(SQLiteRow(statement: statement))
        }
    }

    /// First column of the first row.
    public func scalar(_ sql: String, _ arguments: [SQLiteValue] = []) throws -> SQLiteValue {
        var result = SQLiteValue.null
        try query(sql, arguments) { row in
            if case .null = result { result = row.value(0) }
        }
        return result
    }

    public func int(_ sql: String, _ arguments: [SQLiteValue] = []) throws -> Int? {
        if case .int(let value) = try scalar(sql, arguments) { return value }
        return nil
    }
}

public final class SQLiteStatement {
    fileprivate let statement: OpaquePointer
    private let database: OpaquePointer
    private let sql: String

    fileprivate init(statement: OpaquePointer, database: OpaquePointer, sql: String) {
        self.statement = statement
        self.database = database
        self.sql = sql
    }

    deinit { sqlite3_finalize(statement) }

    public func bind(_ values: [SQLiteValue]) throws {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
        for (index, value) in values.enumerated() {
            let position = Int32(index + 1)
            let status: Int32 = switch value {
            case .int(let int): sqlite3_bind_int64(statement, position, Int64(int))
            case .text(let text): sqlite3_bind_text(statement, position, text, -1, transient)
            case .null: sqlite3_bind_null(statement, position)
            }
            guard status == SQLITE_OK else { throw error() }
        }
    }

    /// Steps once; true while there is a row.
    @discardableResult
    public func step() throws -> Bool {
        switch sqlite3_step(statement) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw error()
        }
    }

    /// Binds, executes and resets an insert or update.
    public func run(_ values: [SQLiteValue]) throws {
        try bind(values)
        try step()
        sqlite3_reset(statement)
    }

    private func error() -> SQLiteError {
        .statement(sql: sql, message: String(cString: sqlite3_errmsg(database)))
    }
}

public struct SQLiteRow {
    fileprivate let statement: SQLiteStatement

    public func value(_ column: Int32) -> SQLiteValue {
        let handle = statement.statement
        switch sqlite3_column_type(handle, column) {
        case SQLITE_NULL: return .null
        case SQLITE_INTEGER: return .int(Int(sqlite3_column_int64(handle, column)))
        default: return .text(String(cString: sqlite3_column_text(handle, column)))
        }
    }

    public func int(_ column: Int32) -> Int? {
        if case .int(let value) = value(column) { return value }
        return nil
    }

    public func text(_ column: Int32) -> String? {
        if case .text(let value) = value(column) { return value }
        return nil
    }

    /// The bytes of a BLOB column (nil for any other type).
    public func blob(_ column: Int32) -> [UInt8]? {
        let handle = statement.statement
        guard sqlite3_column_type(handle, column) == SQLITE_BLOB else { return nil }
        let count = Int(sqlite3_column_bytes(handle, column))
        guard count > 0, let bytes = sqlite3_column_blob(handle, column) else { return [] }
        return Array(UnsafeRawBufferPointer(start: bytes, count: count).bindMemory(to: UInt8.self))
    }
}
