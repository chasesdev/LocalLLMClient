import Foundation
import LocalLLMClientUtility

/// Episodic memory system that stores detailed conversation history and interactions
/// Provides semantic search, temporal organization, and context reconstruction
public final class EpisodicMemory: Sendable {
    
    // MARK: - Storage
    
    private let memoryStorage = Locked<[String: EpisodicMemoryEntry]>([:])
    private let temporalIndex = Locked<[Date: Set<String>]>([:])
    private let semanticIndex = SemanticMemoryIndex()
    private let importanceIndex = Locked<[(String, Double)]>([])
    
    private let capacity: Int
    private let persistenceManager: EpisodicPersistenceManager
    
    // MARK: - Search and Indexing
    
    private let textProcessor = TextProcessor()
    private let similarityCalculator = SimilarityCalculator()
    private let contextReconstructor = ContextReconstructor()
    
    // MARK: - Statistics
    
    private var stats = Locked(EpisodicMemoryStats())
    
    // MARK: - External Connections
    
    private var semanticExtractor: ((EpisodicMemoryEntry) async -> [SemanticKnowledgeItem])?
    
    // MARK: - Initialization
    
    public init(capacity: Int = 10000) {
        self.capacity = capacity
        self.persistenceManager = EpisodicPersistenceManager()
        
        print("📚 Episodic Memory initialized with capacity: \(capacity)")
    }
    
    public func initialize() async throws {
        try await persistenceManager.initialize()
        await loadPersistedMemories()
        
        print("🚀 Episodic Memory loaded \(await getCount()) memories from storage")
    }
    
    public func setSemanticExtractor(_ extractor: @escaping (EpisodicMemoryEntry) async -> [SemanticKnowledgeItem]) {
        self.semanticExtractor = extractor
    }
    
    // MARK: - Memory Storage
    
    /// Store a new episodic memory
    public func store(_ episode: EpisodicMemoryEntry) async {
        let startTime = Date()
        
        // Add to main storage
        await memoryStorage.withLock { storage in
            storage[episode.id] = episode
        }
        
        // Add to temporal index
        await temporalIndex.withLock { index in
            let dateKey = Calendar.current.startOfDay(for: episode.timestamp)
            if index[dateKey] == nil {
                index[dateKey] = Set<String>()
            }
            index[dateKey]?.insert(episode.id)
        }
        
        // Add to semantic index
        await semanticIndex.addEpisode(episode)
        
        // Add to importance index (sorted by importance)
        await importanceIndex.withLock { index in
            index.append((episode.id, episode.importance))
            index.sort { $0.1 > $1.1 } // Sort by importance descending
            
            // Limit index size for performance
            if index.count > capacity * 2 {
                index = Array(index.prefix(capacity * 2))
            }
        }
        
        // Trigger semantic extraction in background
        if let extractor = semanticExtractor {
            Task.detached {
                _ = await extractor(episode)
            }
        }
        
        // Persist to storage
        try? await persistenceManager.store(episode)
        
        // Update statistics
        let storageTime = Date().timeIntervalSince(startTime)
        await updateStats { stats in
            stats.totalEntries += 1
            stats.averageStorageTime = (stats.averageStorageTime + storageTime) / 2
        }
        
        // Check capacity and evict if necessary
        await enforceCapacity()
        
        print("📝 Stored episodic memory: \(episode.request.text.prefix(50))...")
    }
    
    // MARK: - Memory Retrieval
    
    /// Get relevant conversation history for a request
    public func getRelevantHistory(
        for request: UserRequest,
        limit: Int = 10
    ) async -> [EpisodicMemoryEntry] {
        let startTime = Date()
        
        // Multi-stage retrieval for best results
        var candidates: [ScoredEpisode] = []
        
        // 1. Semantic similarity search
        let semanticMatches = await semanticIndex.findSimilar(
            to: request.text,
            limit: limit * 3
        )
        
        for match in semanticMatches {
            if let episode = await memoryStorage.withLock({ $0[match.episodeId] }) {
                candidates.append(ScoredEpisode(
                    episode: episode,
                    relevanceScore: match.similarity,
                    recencyScore: calculateRecencyScore(episode.timestamp),
                    importanceScore: episode.importance
                ))
            }
        }
        
        // 2. Temporal proximity (recent conversations)
        let recentEpisodes = await getRecentEpisodes(limit: limit)
        for episode in recentEpisodes {
            // Avoid duplicates
            if !candidates.contains(where: { $0.episode.id == episode.id }) {
                let similarity = await similarityCalculator.calculate(
                    text1: request.text,
                    text2: episode.request.text
                )
                
                candidates.append(ScoredEpisode(
                    episode: episode,
                    relevanceScore: similarity,
                    recencyScore: calculateRecencyScore(episode.timestamp),
                    importanceScore: episode.importance
                ))
            }
        }
        
        // 3. Context-based retrieval
        if let context = request.context {
            let contextMatches = await findContextualMatches(context: context, limit: limit)
            for episode in contextMatches {
                if !candidates.contains(where: { $0.episode.id == episode.id }) {
                    candidates.append(ScoredEpisode(
                        episode: episode,
                        relevanceScore: 0.7, // Moderate relevance for context matches
                        recencyScore: calculateRecencyScore(episode.timestamp),
                        importanceScore: episode.importance
                    ))
                }
            }
        }
        
        // Score and rank candidates
        let rankedCandidates = candidates.map { candidate in
            let combinedScore = calculateCombinedScore(
                relevance: candidate.relevanceScore,
                recency: candidate.recencyScore,
                importance: candidate.importanceScore
            )
            return ScoredEpisode(
                episode: candidate.episode,
                relevanceScore: candidate.relevanceScore,
                recencyScore: candidate.recencyScore,
                importanceScore: candidate.importanceScore,
                combinedScore: combinedScore
            )
        }.sorted { $0.combinedScore > $1.combinedScore }
        
        let results = Array(rankedCandidates.prefix(limit)).map { $0.episode }
        
        let retrievalTime = Date().timeIntervalSince(startTime)
        await updateStats { stats in
            stats.totalSearches += 1
            stats.averageSearchTime = (stats.averageSearchTime + retrievalTime) / 2
            stats.averageResultCount = (stats.averageResultCount + Double(results.count)) / 2
        }
        
        return results
    }
    
    /// Search episodic memory with text query
    public func search(
        query: String,
        timeRange: TimeRange? = nil,
        limit: Int = 10
    ) async -> [EpisodicMemoryEntry] {
        let startTime = Date()
        
        // Get all potential matches
        var candidates: [EpisodicMemoryEntry] = []
        
        if let timeRange = timeRange {
            // Search within time range
            candidates = await getMemoriesInTimeRange(timeRange)
        } else {
            // Search all memories
            candidates = await memoryStorage.withLock { Array($0.values) }
        }
        
        // Calculate similarity scores
        let scoredResults = await withTaskGroup(of: ScoredEpisode?.self) { group in
            for candidate in candidates {
                group.addTask { [similarityCalculator] in
                    let similarity = await similarityCalculator.calculate(
                        text1: query,
                        text2: candidate.request.text + " " + candidate.response.text
                    )
                    
                    guard similarity > 0.3 else { return nil } // Minimum similarity threshold
                    
                    return ScoredEpisode(
                        episode: candidate,
                        relevanceScore: similarity,
                        recencyScore: self.calculateRecencyScore(candidate.timestamp),
                        importanceScore: candidate.importance,
                        combinedScore: similarity * 0.6 + self.calculateRecencyScore(candidate.timestamp) * 0.2 + candidate.importance * 0.2
                    )
                }
            }
            
            var results: [ScoredEpisode] = []
            for await result in group {
                if let scored = result {
                    results.append(scored)
                }
            }
            return results
        }
        
        let sortedResults = scoredResults
            .sorted { $0.combinedScore > $1.combinedScore }
            .prefix(limit)
            .map { $0.episode }
        
        let searchTime = Date().timeIntervalSince(startTime)
        await updateStats { stats in
            stats.totalSearches += 1
            stats.averageSearchTime = (stats.averageSearchTime + searchTime) / 2
        }
        
        return Array(sortedResults)
    }
    
    /// Get recent conversation history
    public func getRecentHistory(limit: Int = 20) async -> [EpisodicMemoryEntry] {
        let memories = await memoryStorage.withLock { Array($0.values) }
        
        return memories
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Memory Analysis
    
    /// Validate semantic knowledge against episodic evidence
    public func validateKnowledge(_ knowledge: SemanticKnowledgeItem) async -> Bool {
        // Find episodes that support or contradict this knowledge
        let relevantEpisodes = await search(query: knowledge.concept, limit: 10)
        
        var supportingEvidence = 0
        var contradictingEvidence = 0
        
        for episode in relevantEpisodes {
            let episodeText = episode.request.text + " " + episode.response.text
            let similarity = await similarityCalculator.calculate(
                text1: knowledge.description,
                text2: episodeText
            )
            
            if similarity > 0.7 {
                supportingEvidence += 1
            } else if similarity < 0.3 {
                contradictingEvidence += 1
            }
        }
        
        // Validate based on evidence ratio
        let totalEvidence = supportingEvidence + contradictingEvidence
        guard totalEvidence > 0 else { return false }
        
        let supportRatio = Double(supportingEvidence) / Double(totalEvidence)
        return supportRatio > 0.6 // Require 60% supporting evidence
    }
    
    /// Find conversation patterns and themes
    public func findConversationPatterns() async -> [ConversationPattern] {
        let memories = await memoryStorage.withLock { Array($0.values) }
        let analyzer = ConversationPatternAnalyzer()
        
        return await analyzer.findPatterns(in: memories)
    }
    
    // MARK: - Memory Maintenance
    
    /// Consolidate old memories to optimize storage
    public func consolidateOldMemories() async -> Int {
        let consolidationThreshold = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days
        var consolidatedCount = 0
        
        await memoryStorage.withLock { storage in
            let oldMemories = storage.values.filter { $0.timestamp < consolidationThreshold }
            
            // Group similar old memories for consolidation
            let grouped = Dictionary(grouping: oldMemories) { memory in
                // Group by day and topic similarity
                let day = Calendar.current.startOfDay(for: memory.timestamp)
                let topic = extractMainTopic(from: memory.request.text)
                return "\(day)_\(topic)"
            }
            
            for (_, group) in grouped where group.count > 1 {
                // Keep the most important memory from each group
                let mostImportant = group.max { $0.importance < $1.importance }
                
                // Remove less important memories
                for memory in group where memory.id != mostImportant?.id {
                    storage.removeValue(forKey: memory.id)
                    consolidatedCount += 1
                }
            }
        }
        
        // Update indices after consolidation
        await rebuildIndices()
        
        print("🧹 Consolidated \(consolidatedCount) old episodic memories")
        return consolidatedCount
    }
    
    // MARK: - Statistics and Analytics
    
    public var count: Int {
        get async {
            await memoryStorage.withLock { $0.count }
        }
    }
    
    public func getStatistics() async -> EpisodicMemoryStats {
        return await stats.withLock { $0 }
    }
    
    private func getCount() async -> Int {
        await memoryStorage.withLock { $0.count }
    }
    
    // MARK: - Private Implementation
    
    private func loadPersistedMemories() async {
        do {
            let persistedMemories = try await persistenceManager.loadAll()
            
            await memoryStorage.withLock { storage in
                for memory in persistedMemories {
                    storage[memory.id] = memory
                }
            }
            
            await rebuildIndices()
            
        } catch {
            print("⚠️ Failed to load persisted memories: \(error)")
        }
    }
    
    private func rebuildIndices() async {
        let memories = await memoryStorage.withLock { Array($0.values) }
        
        // Rebuild temporal index
        await temporalIndex.withLock { index in
            index.removeAll()
            for memory in memories {
                let dateKey = Calendar.current.startOfDay(for: memory.timestamp)
                if index[dateKey] == nil {
                    index[dateKey] = Set<String>()
                }
                index[dateKey]?.insert(memory.id)
            }
        }
        
        // Rebuild importance index
        await importanceIndex.withLock { index in
            index = memories.map { ($0.id, $0.importance) }
                .sorted { $0.1 > $1.1 }
        }
        
        // Rebuild semantic index
        await semanticIndex.rebuild(with: memories)
    }
    
    private func enforceCapacity() async {
        let currentCount = await getCount()
        
        if currentCount > capacity {
            let excessCount = currentCount - capacity
            
            // Remove least important memories
            let leastImportant = await importanceIndex.withLock { index in
                Array(index.suffix(excessCount)).map { $0.0 }
            }
            
            await memoryStorage.withLock { storage in
                for id in leastImportant {
                    storage.removeValue(forKey: id)
                }
            }
            
            await rebuildIndices()
            
            print("🗑️ Removed \(excessCount) least important memories to maintain capacity")
        }
    }
    
    private func getRecentEpisodes(limit: Int) async -> [EpisodicMemoryEntry] {
        let memories = await memoryStorage.withLock { Array($0.values) }
        
        return memories
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }
    
    private func getMemoriesInTimeRange(_ timeRange: TimeRange) async -> [EpisodicMemoryEntry] {
        let memories = await memoryStorage.withLock { Array($0.values) }
        
        return memories.filter { memory in
            memory.timestamp >= timeRange.start && memory.timestamp <= timeRange.end
        }
    }
    
    private func findContextualMatches(
        context: RequestContext,
        limit: Int
    ) async -> [EpisodicMemoryEntry] {
        // Find memories that match conversational context
        let memories = await memoryStorage.withLock { Array($0.values) }
        
        var matches: [EpisodicMemoryEntry] = []
        
        for memory in memories {
            // Check for tool usage matches
            let memoryTools = Set(memory.response.toolCalls.map { $0.toolName })
            let contextTools = Set(context.activeTools)
            
            if !memoryTools.intersection(contextTools).isEmpty {
                matches.append(memory)
            }
            
            // Check for topic matches
            if let currentTopic = extractMainTopic(from: context.description),
               let memoryTopic = extractMainTopic(from: memory.request.text),
               currentTopic == memoryTopic {
                matches.append(memory)
            }
            
            if matches.count >= limit { break }
        }
        
        return Array(matches.prefix(limit))
    }
    
    private func calculateRecencyScore(_ timestamp: Date) -> Double {
        let now = Date()
        let ageInHours = now.timeIntervalSince(timestamp) / 3600
        
        // Exponential decay: recent memories score higher
        return exp(-ageInHours / 24.0) // Half-life of 24 hours
    }
    
    private func calculateCombinedScore(
        relevance: Double,
        recency: Double,
        importance: Double
    ) -> Double {
        // Weighted combination of scores
        return relevance * 0.5 + recency * 0.3 + importance * 0.2
    }
    
    private func extractMainTopic(from text: String) -> String {
        // Simple topic extraction - would use NLP in production
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 }
        
        return words.first ?? "general"
    }
    
    private func updateStats(_ update: (inout EpisodicMemoryStats) -> Void) async {
        await stats.withLock { update(&$0) }
    }
}

// MARK: - Supporting Types

private struct ScoredEpisode {
    let episode: EpisodicMemoryEntry
    let relevanceScore: Double
    let recencyScore: Double
    let importanceScore: Double
    var combinedScore: Double = 0
    
    init(
        episode: EpisodicMemoryEntry,
        relevanceScore: Double,
        recencyScore: Double,
        importanceScore: Double,
        combinedScore: Double = 0
    ) {
        self.episode = episode
        self.relevanceScore = relevanceScore
        self.recencyScore = recencyScore
        self.importanceScore = importanceScore
        self.combinedScore = combinedScore
    }
}

public struct EpisodicMemoryStats: Sendable {
    public var totalEntries: Int = 0
    public var totalSearches: Int = 0
    public var averageSearchTime: TimeInterval = 0
    public var averageStorageTime: TimeInterval = 0
    public var averageResultCount: Double = 0
    public var consolidationRuns: Int = 0
    public var lastConsolidation: Date?
}

public struct ConversationPattern: Sendable {
    public let pattern: String
    public let frequency: Double
    public let examples: [String]
    public let timePattern: String?
    public let confidence: Double
}

// MARK: - Component Stubs (to be implemented)

private final class SemanticMemoryIndex: Sendable {
    private let index = Locked<[String: SemanticIndexEntry]>([:])
    
    func addEpisode(_ episode: EpisodicMemoryEntry) async {
        // Add episode to semantic search index
        let keywords = extractKeywords(from: episode.request.text + " " + episode.response.text)
        let entry = SemanticIndexEntry(
            episodeId: episode.id,
            keywords: keywords,
            embedding: generateEmbedding(from: episode.request.text) // Placeholder
        )
        
        await index.withLock { $0[episode.id] = entry }
    }
    
    func findSimilar(to query: String, limit: Int) async -> [SimilarityMatch] {
        let queryEmbedding = generateEmbedding(from: query)
        let queryKeywords = extractKeywords(from: query)
        
        let matches = await index.withLock { index in
            index.values.compactMap { entry in
                let similarity = calculateSimilarity(queryEmbedding, entry.embedding)
                let keywordMatch = calculateKeywordOverlap(queryKeywords, entry.keywords)
                let combinedScore = similarity * 0.7 + keywordMatch * 0.3
                
                guard combinedScore > 0.3 else { return nil }
                
                return SimilarityMatch(
                    episodeId: entry.episodeId,
                    similarity: combinedScore
                )
            }
        }
        
        return matches
            .sorted { $0.similarity > $1.similarity }
            .prefix(limit)
            .map { $0 }
    }
    
    func rebuild(with episodes: [EpisodicMemoryEntry]) async {
        await index.withLock { $0.removeAll() }
        
        for episode in episodes {
            await addEpisode(episode)
        }
    }
    
    private func extractKeywords(from text: String) -> [String] {
        // Simple keyword extraction - would use NLP in production
        return text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 }
    }
    
    private func generateEmbedding(from text: String) -> [Double] {
        // Placeholder embedding generation - would use actual embeddings
        return Array(repeating: 0.5, count: 384)
    }
    
    private func calculateSimilarity(_ embedding1: [Double], _ embedding2: [Double]) -> Double {
        // Cosine similarity placeholder
        return 0.8
    }
    
    private func calculateKeywordOverlap(_ keywords1: [String], _ keywords2: [String]) -> Double {
        let set1 = Set(keywords1)
        let set2 = Set(keywords2)
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        guard !union.isEmpty else { return 0 }
        return Double(intersection.count) / Double(union.count)
    }
}

private struct SemanticIndexEntry: Sendable {
    let episodeId: String
    let keywords: [String]
    let embedding: [Double]
}

private struct SimilarityMatch: Sendable {
    let episodeId: String
    let similarity: Double
}

private final class TextProcessor: Sendable {
    // Text processing utilities
}

private final class SimilarityCalculator: Sendable {
    func calculate(text1: String, text2: String) async -> Double {
        // Simple similarity calculation - would use embeddings in production
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        guard !union.isEmpty else { return 0 }
        return Double(intersection.count) / Double(union.count)
    }
}

private final class ContextReconstructor: Sendable {
    // Context reconstruction utilities
}

private final class ConversationPatternAnalyzer: Sendable {
    func findPatterns(in memories: [EpisodicMemoryEntry]) async -> [ConversationPattern] {
        // Pattern analysis implementation
        return []
    }
}

private final class EpisodicPersistenceManager: Sendable {
    func initialize() async throws {
        // Initialize storage
    }
    
    func store(_ episode: EpisodicMemoryEntry) async throws {
        // Store to persistent storage
    }
    
    func loadAll() async throws -> [EpisodicMemoryEntry] {
        // Load from persistent storage
        return []
    }
}