import Foundation
import SQLite3
import OSLog
import CryptoKit

/// MemoryPersistence provides comprehensive storage for all memory layers
/// This component handles SQLite database operations, encryption, and data lifecycle management
public class MemoryPersistence: Sendable {
    private let configuration: MemoryPersistenceConfiguration
    private let logger = Logger(subsystem: "LocalLLMClientCore", category: "MemoryPersistence")
    
    private var database: OpaquePointer?
    private let databaseQueue = DispatchQueue(label: "memory.persistence", qos: .userInitiated)
    private let encryptionKey: SymmetricKey?
    
    public init(configuration: MemoryPersistenceConfiguration = .default) async throws {
        self.configuration = configuration
        
        // Initialize encryption if enabled
        if configuration.encryptionEnabled {
            self.encryptionKey = SymmetricKey(size: .bits256)
        } else {
            self.encryptionKey = nil
        }
        
        // Ensure storage directory exists
        try await createStorageDirectory()
        
        // Initialize database
        try await initializeDatabase()
        
        logger.info("MemoryPersistence initialized with database at: \(configuration.databasePath)")
    }
    
    deinit {
        if let db = database {
            sqlite3_close(db)
        }
    }
    
    // MARK: - Episodic Memory Persistence
    
    /// Save episodic memory entry
    public func saveEpisodicMemory(_ entry: EpisodicMemoryEntry) async throws {
        let data = try await serializeEntry(entry)
        
        try await withDatabase { db in
            let sql = """
                INSERT OR REPLACE INTO episodic_memory 
                (id, user_id, timestamp, content, context, embedding, tags, importance, encrypted_data, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MemoryPersistenceError.sqliteError("Failed to prepare episodic insert statement")
            }
            defer { sqlite3_finalize(statement) }
            
            let now = Date()
            
            sqlite3_bind_text(statement, 1, entry.id, -1, nil)
            sqlite3_bind_text(statement, 2, entry.userId, -1, nil)
            sqlite3_bind_int64(statement, 3, Int64(entry.timestamp.timeIntervalSince1970))
            sqlite3_bind_text(statement, 4, entry.content, -1, nil)
            sqlite3_bind_text(statement, 5, entry.context, -1, nil)
            sqlite3_bind_blob(statement, 6, entry.embedding, Int32(entry.embedding.count * MemoryLayout<Float>.size), nil)
            sqlite3_bind_text(statement, 7, entry.tags.joined(separator: ","), -1, nil)
            sqlite3_bind_double(statement, 8, entry.importance)
            sqlite3_bind_blob(statement, 9, data, Int32(data.count), nil)
            sqlite3_bind_int64(statement, 10, Int64(now.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 11, Int64(now.timeIntervalSince1970))
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw MemoryPersistenceError.sqliteError("Failed to insert episodic memory")
            }
        }
        
        logger.debug("Saved episodic memory: \(entry.id)")
    }
    
    /// Load episodic memories by user ID
    public func loadEpisodicMemories(userId: String, limit: Int = 100) async throws -> [EpisodicMemoryEntry] {
        return try await withDatabase { db in
            let sql = """
                SELECT id, user_id, timestamp, content, context, embedding, tags, importance, encrypted_data
                FROM episodic_memory 
                WHERE user_id = ? 
                ORDER BY timestamp DESC 
                LIMIT ?
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MemoryPersistenceError.sqliteError("Failed to prepare episodic select statement")
            }
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, userId, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(limit))
            
            var entries: [EpisodicMemoryEntry] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let entry = try parseEpisodicMemoryRow(statement)
                entries.append(entry)
            }
            
            return entries
        }
    }
    
    /// Search episodic memories by similarity
    public func searchEpisodicMemories(
        userId: String,
        queryEmbedding: [Float],
        limit: Int = 10,
        similarityThreshold: Float = 0.7
    ) async throws -> [EpisodicMemoryEntry] {
        
        return try await withDatabase { db in
            let sql = """
                SELECT id, user_id, timestamp, content, context, embedding, tags, importance, encrypted_data
                FROM episodic_memory 
                WHERE user_id = ?
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MemoryPersistenceError.sqliteError("Failed to prepare episodic search statement")
            }
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, userId, -1, nil)
            
            var candidates: [(EpisodicMemoryEntry, Float)] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let entry = try parseEpisodicMemoryRow(statement)
                let similarity = calculateCosineSimilarity(queryEmbedding, entry.embedding)
                
                if similarity >= similarityThreshold {
                    candidates.append((entry, similarity))
                }
            }
            
            // Sort by similarity and return top results
            return candidates
                .sorted { $0.1 > $1.1 }
                .prefix(limit)
                .map { $0.0 }
        }
    }
    
    // MARK: - Semantic Memory Persistence
    
    /// Save semantic knowledge item
    public func saveSemanticKnowledge(_ item: SemanticKnowledgeItem) async throws {
        let data = try await serializeKnowledgeItem(item)
        
        try await withDatabase { db in
            let sql = """
                INSERT OR REPLACE INTO semantic_memory 
                (id, concept, content, category, domain, confidence, embedding, relationships, metadata, encrypted_data, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MemoryPersistenceError.sqliteError("Failed to prepare semantic insert statement")
            }
            defer { sqlite3_finalize(statement) }
            
            let now = Date()
            let relationshipsJson = try JSONEncoder().encode(item.relationships)
            let metadataJson = try JSONSerialization.data(withJSONObject: item.metadata)
            
            sqlite3_bind_text(statement, 1, item.id, -1, nil)
            sqlite3_bind_text(statement, 2, item.concept, -1, nil)
            sqlite3_bind_text(statement, 3, item.content, -1, nil)
            sqlite3_bind_text(statement, 4, item.category, -1, nil)
            sqlite3_bind_text(statement, 5, item.domain, -1, nil)
            sqlite3_bind_double(statement, 6, item.confidence)
            sqlite3_bind_blob(statement, 7, item.embedding, Int32(item.embedding.count * MemoryLayout<Float>.size), nil)
            sqlite3_bind_blob(statement, 8, relationshipsJson, Int32(relationshipsJson.count), nil)
            sqlite3_bind_blob(statement, 9, metadataJson, Int32(metadataJson.count), nil)
            sqlite3_bind_blob(statement, 10, data, Int32(data.count), nil)
            sqlite3_bind_int64(statement, 11, Int64(now.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 12, Int64(now.timeIntervalSince1970))
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw MemoryPersistenceError.sqliteError("Failed to insert semantic knowledge")
            }
        }
        
        logger.debug("Saved semantic knowledge: \(item.concept)")
    }
    
    /// Load semantic knowledge by domain
    public func loadSemanticKnowledge(domain: String? = nil, limit: Int = 100) async throws -> [SemanticKnowledgeItem] {
        return try await withDatabase { db in
            let sql = domain != nil ? """
                SELECT id, concept, content, category, domain, confidence, embedding, relationships, metadata, encrypted_data
                FROM semantic_memory 
                WHERE domain = ?
                ORDER BY confidence DESC 
                LIMIT ?
            """ : """
                SELECT id, concept, content, category, domain, confidence, embedding, relationships, metadata, encrypted_data
                FROM semantic_memory 
                ORDER BY confidence DESC 
                LIMIT ?
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MemoryPersistenceError.sqliteError("Failed to prepare semantic select statement")
            }
            defer { sqlite3_finalize(statement) }
            
            if let domain = domain {
                sqlite3_bind_text(statement, 1, domain, -1, nil)
                sqlite3_bind_int(statement, 2, Int32(limit))
            } else {
                sqlite3_bind_int(statement, 1, Int32(limit))
            }
            
            var items: [SemanticKnowledgeItem] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let item = try parseSemanticKnowledgeRow(statement)
                items.append(item)
            }
            
            return items
        }
    }
    
    // MARK: - Procedural Memory Persistence
    
    /// Save procedural pattern
    public func saveProceduralPattern(_ pattern: ProceduralPattern) async throws {
        let data = try await serializePattern(pattern)
        
        try await withDatabase { db in
            let sql = """
                INSERT OR REPLACE INTO procedural_memory 
                (id, name, description, domain, success_rate, usage_count, complexity, encrypted_data, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MemoryPersistenceError.sqliteError("Failed to prepare procedural insert statement")
            }
            defer { sqlite3_finalize(statement) }
            
            let now = Date()
            
            sqlite3_bind_text(statement, 1, pattern.id, -1, nil)
            sqlite3_bind_text(statement, 2, pattern.name, -1, nil)
            sqlite3_bind_text(statement, 3, pattern.description, -1, nil)
            sqlite3_bind_text(statement, 4, pattern.metadata.domain, -1, nil)
            sqlite3_bind_double(statement, 5, pattern.metadata.successRate)
            sqlite3_bind_int(statement, 6, Int32(pattern.metadata.usageCount))
            sqlite3_bind_double(statement, 7, pattern.metadata.complexity)
            sqlite3_bind_blob(statement, 8, data, Int32(data.count), nil)
            sqlite3_bind_int64(statement, 9, Int64(pattern.metadata.createdAt.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 10, Int64(now.timeIntervalSince1970))
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw MemoryPersistenceError.sqliteError("Failed to insert procedural pattern")
            }
        }
        
        logger.debug("Saved procedural pattern: \(pattern.name)")
    }
    
    /// Load procedural patterns by domain
    public func loadProceduralPatterns(domain: String? = nil, limit: Int = 50) async throws -> [ProceduralPattern] {
        return try await withDatabase { db in
            let sql = domain != nil ? """
                SELECT encrypted_data
                FROM procedural_memory 
                WHERE domain = ?
                ORDER BY success_rate DESC, usage_count DESC
                LIMIT ?
            """ : """
                SELECT encrypted_data
                FROM procedural_memory 
                ORDER BY success_rate DESC, usage_count DESC
                LIMIT ?
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MemoryPersistenceError.sqliteError("Failed to prepare procedural select statement")
            }
            defer { sqlite3_finalize(statement) }
            
            if let domain = domain {
                sqlite3_bind_text(statement, 1, domain, -1, nil)
                sqlite3_bind_int(statement, 2, Int32(limit))
            } else {
                sqlite3_bind_int(statement, 1, Int32(limit))
            }
            
            var patterns: [ProceduralPattern] = []
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let dataPtr = sqlite3_column_blob(statement, 0)
                let dataSize = sqlite3_column_bytes(statement, 0)
                let data = Data(bytes: dataPtr!, count: Int(dataSize))
                
                let pattern = try await deserializePattern(data)
                patterns.append(pattern)
            }
            
            return patterns
        }
    }
    
    // MARK: - User Profile Persistence
    
    /// Save user profile
    public func saveUserProfile(_ profile: UserProfile) async throws {
        let data = try await serializeUserProfile(profile)
        
        try await withDatabase { db in
            let sql = """
                INSERT OR REPLACE INTO user_profiles 
                (user_id, interaction_count, confidence_level, encrypted_data, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?)
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MemoryPersistenceError.sqliteError("Failed to prepare user profile insert statement")
            }
            defer { sqlite3_finalize(statement) }
            
            let now = Date()
            
            sqlite3_bind_text(statement, 1, profile.id, -1, nil)
            sqlite3_bind_int(statement, 2, Int32(profile.interactionCount))
            sqlite3_bind_double(statement, 3, profile.personalityTraits.confidence)
            sqlite3_bind_blob(statement, 4, data, Int32(data.count), nil)
            sqlite3_bind_int64(statement, 5, Int64(profile.createdAt.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 6, Int64(now.timeIntervalSince1970))
            
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw MemoryPersistenceError.sqliteError("Failed to insert user profile")
            }
        }
        
        logger.debug("Saved user profile: \(profile.id)")
    }
    
    /// Load user profile
    public func loadUserProfile(userId: String) async throws -> UserProfile? {
        return try await withDatabase { db in
            let sql = """
                SELECT encrypted_data
                FROM user_profiles 
                WHERE user_id = ?
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MemoryPersistenceError.sqliteError("Failed to prepare user profile select statement")
            }
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_text(statement, 1, userId, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let dataPtr = sqlite3_column_blob(statement, 0)
                let dataSize = sqlite3_column_bytes(statement, 0)
                let data = Data(bytes: dataPtr!, count: Int(dataSize))
                
                return try await deserializeUserProfile(data)
            }
            
            return nil
        }
    }
    
    // MARK: - Memory Analytics
    
    /// Get comprehensive memory statistics
    public func getMemoryStatistics() async throws -> MemoryStatistics {
        return try await withDatabase { db in
            // Count records in each table
            let episodicCount = try getTableCount(db, tableName: "episodic_memory")
            let semanticCount = try getTableCount(db, tableName: "semantic_memory")
            let proceduralCount = try getTableCount(db, tableName: "procedural_memory")
            let profileCount = try getTableCount(db, tableName: "user_profiles")
            
            // Get database size
            let databaseSize = try getDatabaseSize()
            
            // Calculate storage efficiency
            let storageEfficiency = calculateStorageEfficiency(
                episodicCount: episodicCount,
                semanticCount: semanticCount,
                proceduralCount: proceduralCount,
                databaseSize: databaseSize
            )
            
            return MemoryStatistics(
                episodicMemoryCount: episodicCount,
                semanticKnowledgeCount: semanticCount,
                proceduralPatternCount: proceduralCount,
                userProfileCount: profileCount,
                totalMemoryItems: episodicCount + semanticCount + proceduralCount,
                databaseSizeMB: Double(databaseSize) / 1024 / 1024,
                storageEfficiency: storageEfficiency,
                lastUpdated: Date()
            )
        }
    }
    
    // MARK: - Memory Maintenance
    
    /// Clean up old memories based on configuration
    public func performMaintenance() async throws {
        logger.info("Starting memory maintenance")
        
        try await withDatabase { db in
            let now = Date()
            let retentionPeriod = configuration.memoryRetentionDays * 24 * 3600 // Convert to seconds
            let cutoffTime = now.timeIntervalSince1970 - Double(retentionPeriod)
            
            // Clean up old episodic memories
            let episodicSQL = "DELETE FROM episodic_memory WHERE timestamp < ?"
            try executeMaintenanceQuery(db, sql: episodicSQL, cutoffTime: cutoffTime)
            
            // Clean up low-confidence semantic knowledge
            let semanticSQL = "DELETE FROM semantic_memory WHERE confidence < ? AND updated_at < ?"
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, semanticSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_double(statement, 1, 0.3) // Low confidence threshold
                sqlite3_bind_int64(statement, 2, Int64(cutoffTime))
                sqlite3_step(statement)
                sqlite3_finalize(statement)
            }
            
            // Clean up unused procedural patterns
            let proceduralSQL = "DELETE FROM procedural_memory WHERE usage_count < 2 AND updated_at < ?"
            try executeMaintenanceQuery(db, sql: proceduralSQL, cutoffTime: cutoffTime)
            
            // Vacuum database to reclaim space
            let vacuumSQL = "VACUUM"
            if sqlite3_exec(db, vacuumSQL, nil, nil, nil) == SQLITE_OK {
                logger.info("Database vacuum completed")
            }
        }
        
        logger.info("Memory maintenance completed")
    }
    
    /// Create backup of memory database
    public func createBackup() async throws -> URL {
        let backupFileName = "memory_backup_\(Int(Date().timeIntervalSince1970)).db"
        let backupURL = configuration.storageDirectory.appendingPathComponent("backups").appendingPathComponent(backupFileName)
        
        // Ensure backup directory exists
        try FileManager.default.createDirectory(
            at: backupURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // Copy database file
        let sourceURL = URL(fileURLWithPath: configuration.databasePath)
        try FileManager.default.copyItem(at: sourceURL, to: backupURL)
        
        logger.info("Created backup: \(backupURL.path)")
        return backupURL
    }
    
    // MARK: - Private Implementation
    
    private func createStorageDirectory() async throws {
        try FileManager.default.createDirectory(
            at: configuration.storageDirectory,
            withIntermediateDirectories: true
        )
    }
    
    private func initializeDatabase() async throws {
        let path = configuration.databasePath
        
        guard sqlite3_open(path, &database) == SQLITE_OK else {
            throw MemoryPersistenceError.sqliteError("Unable to open database at: \(path)")
        }
        
        // Enable foreign keys and WAL mode
        sqlite3_exec(database, "PRAGMA foreign_keys = ON", nil, nil, nil)
        sqlite3_exec(database, "PRAGMA journal_mode = WAL", nil, nil, nil)
        sqlite3_exec(database, "PRAGMA synchronous = NORMAL", nil, nil, nil)
        
        // Create tables
        try await createTables()
        
        logger.info("Database initialized successfully")
    }
    
    private func createTables() async throws {
        let tables = [
            createEpisodicMemoryTable(),
            createSemanticMemoryTable(),
            createProceduralMemoryTable(),
            createUserProfilesTable(),
            createIndices()
        ]
        
        for tableSQL in tables {
            guard sqlite3_exec(database, tableSQL, nil, nil, nil) == SQLITE_OK else {
                throw MemoryPersistenceError.sqliteError("Failed to create table")
            }
        }
    }
    
    private func createEpisodicMemoryTable() -> String {
        return """
        CREATE TABLE IF NOT EXISTS episodic_memory (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            content TEXT NOT NULL,
            context TEXT,
            embedding BLOB,
            tags TEXT,
            importance REAL DEFAULT 0.5,
            encrypted_data BLOB,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
        """
    }
    
    private func createSemanticMemoryTable() -> String {
        return """
        CREATE TABLE IF NOT EXISTS semantic_memory (
            id TEXT PRIMARY KEY,
            concept TEXT NOT NULL,
            content TEXT NOT NULL,
            category TEXT,
            domain TEXT,
            confidence REAL DEFAULT 0.5,
            embedding BLOB,
            relationships BLOB,
            metadata BLOB,
            encrypted_data BLOB,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
        """
    }
    
    private func createProceduralMemoryTable() -> String {
        return """
        CREATE TABLE IF NOT EXISTS procedural_memory (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            domain TEXT,
            success_rate REAL DEFAULT 0.5,
            usage_count INTEGER DEFAULT 0,
            complexity REAL DEFAULT 0.5,
            encrypted_data BLOB,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
        """
    }
    
    private func createUserProfilesTable() -> String {
        return """
        CREATE TABLE IF NOT EXISTS user_profiles (
            user_id TEXT PRIMARY KEY,
            interaction_count INTEGER DEFAULT 0,
            confidence_level REAL DEFAULT 0.3,
            encrypted_data BLOB,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
        """
    }
    
    private func createIndices() -> String {
        return """
        CREATE INDEX IF NOT EXISTS idx_episodic_user_timestamp ON episodic_memory(user_id, timestamp);
        CREATE INDEX IF NOT EXISTS idx_semantic_domain ON semantic_memory(domain);
        CREATE INDEX IF NOT EXISTS idx_semantic_category ON semantic_memory(category);
        CREATE INDEX IF NOT EXISTS idx_procedural_domain ON procedural_memory(domain);
        CREATE INDEX IF NOT EXISTS idx_procedural_success_rate ON procedural_memory(success_rate);
        """
    }
    
    private func withDatabase<T>(_ operation: (OpaquePointer) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            databaseQueue.async {
                do {
                    guard let db = self.database else {
                        throw MemoryPersistenceError.databaseNotInitialized
                    }
                    let result = try operation(db)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Serialization methods
    private func serializeEntry(_ entry: EpisodicMemoryEntry) async throws -> Data {
        let data = try JSONEncoder().encode(entry)
        
        if let key = encryptionKey {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined!
        } else {
            return data
        }
    }
    
    private func deserializeEntry(_ data: Data) async throws -> EpisodicMemoryEntry {
        let decryptedData: Data
        
        if let key = encryptionKey {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            decryptedData = try AES.GCM.open(sealedBox, using: key)
        } else {
            decryptedData = data
        }
        
        return try JSONDecoder().decode(EpisodicMemoryEntry.self, from: decryptedData)
    }
    
    private func serializeKnowledgeItem(_ item: SemanticKnowledgeItem) async throws -> Data {
        let data = try JSONEncoder().encode(item)
        
        if let key = encryptionKey {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined!
        } else {
            return data
        }
    }
    
    private func deserializeKnowledgeItem(_ data: Data) async throws -> SemanticKnowledgeItem {
        let decryptedData: Data
        
        if let key = encryptionKey {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            decryptedData = try AES.GCM.open(sealedBox, using: key)
        } else {
            decryptedData = data
        }
        
        return try JSONDecoder().decode(SemanticKnowledgeItem.self, from: decryptedData)
    }
    
    private func serializePattern(_ pattern: ProceduralPattern) async throws -> Data {
        let data = try JSONEncoder().encode(pattern)
        
        if let key = encryptionKey {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined!
        } else {
            return data
        }
    }
    
    private func deserializePattern(_ data: Data) async throws -> ProceduralPattern {
        let decryptedData: Data
        
        if let key = encryptionKey {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            decryptedData = try AES.GCM.open(sealedBox, using: key)
        } else {
            decryptedData = data
        }
        
        return try JSONDecoder().decode(ProceduralPattern.self, from: decryptedData)
    }
    
    private func serializeUserProfile(_ profile: UserProfile) async throws -> Data {
        let data = try JSONEncoder().encode(profile)
        
        if let key = encryptionKey {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined!
        } else {
            return data
        }
    }
    
    private func deserializeUserProfile(_ data: Data) async throws -> UserProfile {
        let decryptedData: Data
        
        if let key = encryptionKey {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            decryptedData = try AES.GCM.open(sealedBox, using: key)
        } else {
            decryptedData = data
        }
        
        return try JSONDecoder().decode(UserProfile.self, from: decryptedData)
    }
    
    // Row parsing methods
    private func parseEpisodicMemoryRow(_ statement: OpaquePointer?) throws -> EpisodicMemoryEntry {
        let id = String(cString: sqlite3_column_text(statement, 0))
        let userId = String(cString: sqlite3_column_text(statement, 1))
        let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
        let content = String(cString: sqlite3_column_text(statement, 3))
        let context = String(cString: sqlite3_column_text(statement, 4))
        
        // Parse embedding
        let embeddingPtr = sqlite3_column_blob(statement, 5)
        let embeddingSize = sqlite3_column_bytes(statement, 5)
        let embeddingData = Data(bytes: embeddingPtr!, count: Int(embeddingSize))
        let embedding = embeddingData.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float.self))
        }
        
        let tagsString = String(cString: sqlite3_column_text(statement, 6))
        let tags = tagsString.split(separator: ",").map(String.init)
        let importance = sqlite3_column_double(statement, 7)
        
        return EpisodicMemoryEntry(
            id: id,
            userId: userId,
            timestamp: timestamp,
            content: content,
            context: context,
            embedding: embedding,
            tags: tags,
            importance: importance,
            metadata: [:] // Could be expanded
        )
    }
    
    private func parseSemanticKnowledgeRow(_ statement: OpaquePointer?) throws -> SemanticKnowledgeItem {
        let id = String(cString: sqlite3_column_text(statement, 0))
        let concept = String(cString: sqlite3_column_text(statement, 1))
        let content = String(cString: sqlite3_column_text(statement, 2))
        let category = String(cString: sqlite3_column_text(statement, 3))
        let domain = String(cString: sqlite3_column_text(statement, 4))
        let confidence = sqlite3_column_double(statement, 5)
        
        // Parse embedding
        let embeddingPtr = sqlite3_column_blob(statement, 6)
        let embeddingSize = sqlite3_column_bytes(statement, 6)
        let embeddingData = Data(bytes: embeddingPtr!, count: Int(embeddingSize))
        let embedding = embeddingData.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float.self))
        }
        
        // Parse relationships
        let relationshipsPtr = sqlite3_column_blob(statement, 7)
        let relationshipsSize = sqlite3_column_bytes(statement, 7)
        let relationshipsData = Data(bytes: relationshipsPtr!, count: Int(relationshipsSize))
        let relationships = try JSONDecoder().decode([ConceptRelationship].self, from: relationshipsData)
        
        // Parse metadata
        let metadataPtr = sqlite3_column_blob(statement, 8)
        let metadataSize = sqlite3_column_bytes(statement, 8)
        let metadataData = Data(bytes: metadataPtr!, count: Int(metadataSize))
        let metadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any] ?? [:]
        
        return SemanticKnowledgeItem(
            id: id,
            concept: concept,
            content: content,
            category: category,
            domain: domain,
            confidence: confidence,
            embedding: embedding,
            relationships: relationships,
            metadata: metadata,
            lastAccessed: Date(),
            accessCount: 1
        )
    }
    
    // Utility methods
    private func calculateCosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }
        
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let normA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let normB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard normA > 0 && normB > 0 else { return 0.0 }
        
        return dotProduct / (normA * normB)
    }
    
    private func getTableCount(_ db: OpaquePointer, tableName: String) throws -> Int {
        let sql = "SELECT COUNT(*) FROM \(tableName)"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryPersistenceError.sqliteError("Failed to prepare count query")
        }
        defer { sqlite3_finalize(statement) }
        
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw MemoryPersistenceError.sqliteError("Failed to execute count query")
        }
        
        return Int(sqlite3_column_int(statement, 0))
    }
    
    private func getDatabaseSize() throws -> Int64 {
        let fileURL = URL(fileURLWithPath: configuration.databasePath)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func calculateStorageEfficiency(
        episodicCount: Int,
        semanticCount: Int,
        proceduralCount: Int,
        databaseSize: Int64
    ) -> Double {
        let totalItems = episodicCount + semanticCount + proceduralCount
        guard totalItems > 0, databaseSize > 0 else { return 0.0 }
        
        let averageBytesPerItem = Double(databaseSize) / Double(totalItems)
        let theoreticalOptimal = 1000.0 // Assume 1KB per item is optimal
        
        return min(1.0, theoreticalOptimal / averageBytesPerItem)
    }
    
    private func executeMaintenanceQuery(_ db: OpaquePointer, sql: String, cutoffTime: Double) throws {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, Int64(cutoffTime))
            sqlite3_step(statement)
            sqlite3_finalize(statement)
        }
    }
}

// MARK: - Configuration and Types

public struct MemoryPersistenceConfiguration: Sendable {
    public let storageDirectory: URL
    public let databasePath: String
    public let encryptionEnabled: Bool
    public let memoryRetentionDays: Int
    public let maxDatabaseSizeMB: Int
    public let enableBackups: Bool
    public let backupIntervalHours: Int
    
    public static let `default`: MemoryPersistenceConfiguration = {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let tokeDirectory = homeDirectory.appendingPathComponent(".toke/memory")
        
        return MemoryPersistenceConfiguration(
            storageDirectory: tokeDirectory,
            databasePath: tokeDirectory.appendingPathComponent("memory.db").path,
            encryptionEnabled: true,
            memoryRetentionDays: 90,
            maxDatabaseSizeMB: 500,
            enableBackups: true,
            backupIntervalHours: 24
        )
    }()
    
    public init(
        storageDirectory: URL,
        databasePath: String,
        encryptionEnabled: Bool,
        memoryRetentionDays: Int,
        maxDatabaseSizeMB: Int,
        enableBackups: Bool,
        backupIntervalHours: Int
    ) {
        self.storageDirectory = storageDirectory
        self.databasePath = databasePath
        self.encryptionEnabled = encryptionEnabled
        self.memoryRetentionDays = memoryRetentionDays
        self.maxDatabaseSizeMB = maxDatabaseSizeMB
        self.enableBackups = enableBackups
        self.backupIntervalHours = backupIntervalHours
    }
}

public struct MemoryStatistics: Sendable {
    public let episodicMemoryCount: Int
    public let semanticKnowledgeCount: Int
    public let proceduralPatternCount: Int
    public let userProfileCount: Int
    public let totalMemoryItems: Int
    public let databaseSizeMB: Double
    public let storageEfficiency: Double
    public let lastUpdated: Date
}

public enum MemoryPersistenceError: Error, Sendable {
    case sqliteError(String)
    case databaseNotInitialized
    case encryptionError(String)
    case serializationError(String)
    case storageError(String)
}