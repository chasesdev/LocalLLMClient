import Foundation
import LocalLLMClientUtility

/// Semantic memory system that builds and maintains knowledge graphs
/// Stores domain expertise, concept relationships, and factual knowledge
public final class SemanticMemory: Sendable {
    
    // MARK: - Knowledge Storage
    
    private let knowledgeGraph = Locked<[String: SemanticKnowledgeItem]>([:])
    private let domainIndex = Locked<[String: Set<String>]>([:])
    private let conceptIndex = ConceptIndex()
    private let relationshipGraph = RelationshipGraph()
    
    private let capacity: Int
    private let persistenceManager: SemanticPersistenceManager
    
    // MARK: - Knowledge Processing
    
    private let knowledgeExtractor = KnowledgeExtractor()
    private let conceptAnalyzer = ConceptAnalyzer()
    private let relationshipDetector = RelationshipDetector()
    private let factValidator = FactValidator()
    
    // MARK: - Statistics
    
    private var stats = Locked(SemanticMemoryStats())
    
    // MARK: - External Connections
    
    private var episodicValidator: ((SemanticKnowledgeItem) async -> Bool)?
    
    // MARK: - Initialization
    
    public init(capacity: Int = 50000) {
        self.capacity = capacity
        self.persistenceManager = SemanticPersistenceManager()
        
        print("🧠 Semantic Memory initialized with capacity: \(capacity)")
    }
    
    public func initialize() async throws {
        try await persistenceManager.initialize()
        await loadPersistedKnowledge()
        
        print("🚀 Semantic Memory loaded \(await getCount()) knowledge items from storage")
    }
    
    public func setEpisodicValidator(_ validator: @escaping (SemanticKnowledgeItem) async -> Bool) {
        self.episodicValidator = validator
    }
    
    // MARK: - Knowledge Storage
    
    /// Store a new knowledge item
    public func store(_ knowledge: SemanticKnowledgeItem) async {
        let startTime = Date()
        
        // Validate knowledge against episodic evidence if validator is available
        var validatedKnowledge = knowledge
        if let validator = episodicValidator {
            let isValid = await validator(knowledge)
            if !isValid {
                print("⚠️ Knowledge item rejected by episodic validation: \(knowledge.concept)")
                return
            }
        }
        
        // Check for existing knowledge and merge if necessary
        if let existing = await knowledgeGraph.withLock({ $0[knowledge.concept] }) {
            validatedKnowledge = await mergeKnowledge(existing: existing, new: knowledge)
        }
        
        // Store in knowledge graph
        await knowledgeGraph.withLock { graph in
            graph[validatedKnowledge.concept] = validatedKnowledge
        }
        
        // Update domain index
        await domainIndex.withLock { index in
            if index[validatedKnowledge.domain] == nil {
                index[validatedKnowledge.domain] = Set<String>()
            }
            index[validatedKnowledge.domain]?.insert(validatedKnowledge.concept)
        }
        
        // Update concept index for fast searching
        await conceptIndex.addConcept(validatedKnowledge)
        
        // Update relationship graph
        await relationshipGraph.updateRelationships(for: validatedKnowledge)
        
        // Persist to storage
        try? await persistenceManager.store(validatedKnowledge)
        
        let storageTime = Date().timeIntervalSince(startTime)
        await updateStats { stats in
            stats.totalItems += 1
            stats.averageStorageTime = (stats.averageStorageTime + storageTime) / 2
        }
        
        // Enforce capacity limits
        await enforceCapacity()
        
        print("🧠 Stored semantic knowledge: \(validatedKnowledge.concept)")
    }
    
    // MARK: - Knowledge Retrieval
    
    /// Get relevant knowledge for a user request
    public func getRelevantKnowledge(
        for request: UserRequest,
        limit: Int = 20
    ) async -> [SemanticKnowledgeItem] {
        let startTime = Date()
        
        // Multi-strategy retrieval for comprehensive results
        var candidates: [ScoredKnowledge] = []
        
        // 1. Direct concept search
        let directMatches = await conceptIndex.findConcepts(matching: request.text, limit: limit * 2)
        for match in directMatches {
            if let knowledge = await knowledgeGraph.withLock({ $0[match.concept] }) {
                candidates.append(ScoredKnowledge(
                    knowledge: knowledge,
                    relevanceScore: match.similarity,
                    confidenceScore: knowledge.confidence,
                    freshnessScore: calculateFreshnessScore(knowledge.lastUpdated)
                ))
            }
        }
        
        // 2. Domain-based search
        let domains = await inferDomains(from: request.text)
        for domain in domains.prefix(3) {
            let domainKnowledge = await getKnowledgeInDomain(domain, limit: 10)
            for knowledge in domainKnowledge {
                if !candidates.contains(where: { $0.knowledge.id == knowledge.id }) {
                    let relevance = await calculateRelevance(knowledge: knowledge, request: request)
                    candidates.append(ScoredKnowledge(
                        knowledge: knowledge,
                        relevanceScore: relevance,
                        confidenceScore: knowledge.confidence,
                        freshnessScore: calculateFreshnessScore(knowledge.lastUpdated)
                    ))
                }
            }
        }
        
        // 3. Relationship-based expansion
        let expandedConcepts = await relationshipGraph.expandConcepts(
            from: extractConcepts(from: request.text),
            depth: 2
        )
        
        for concept in expandedConcepts {
            if let knowledge = await knowledgeGraph.withLock({ $0[concept] }),
               !candidates.contains(where: { $0.knowledge.id == knowledge.id }) {
                let relevance = await calculateRelevance(knowledge: knowledge, request: request)
                candidates.append(ScoredKnowledge(
                    knowledge: knowledge,
                    relevanceScore: relevance,
                    confidenceScore: knowledge.confidence,
                    freshnessScore: calculateFreshnessScore(knowledge.lastUpdated)
                ))
            }
        }
        
        // Score and rank candidates
        let rankedResults = candidates.map { candidate in
            let combinedScore = calculateCombinedKnowledgeScore(
                relevance: candidate.relevanceScore,
                confidence: candidate.confidenceScore,
                freshness: candidate.freshnessScore
            )
            
            return ScoredKnowledge(
                knowledge: candidate.knowledge,
                relevanceScore: candidate.relevanceScore,
                confidenceScore: candidate.confidenceScore,
                freshnessScore: candidate.freshnessScore,
                combinedScore: combinedScore
            )
        }.sorted { $0.combinedScore > $1.combinedScore }
        
        let results = Array(rankedResults.prefix(limit)).map { $0.knowledge }
        
        let retrievalTime = Date().timeIntervalSince(startTime)
        await updateStats { stats in
            stats.totalSearches += 1
            stats.averageSearchTime = (stats.averageSearchTime + retrievalTime) / 2
            stats.averageResultCount = (stats.averageResultCount + Double(results.count)) / 2
        }
        
        return results
    }
    
    /// Search semantic knowledge with query
    public func search(
        query: String,
        domain: String? = nil,
        limit: Int = 10
    ) async -> [SemanticKnowledgeItem] {
        let startTime = Date()
        
        var candidates: [SemanticKnowledgeItem] = []
        
        if let domain = domain {
            // Search within specific domain
            candidates = await getKnowledgeInDomain(domain, limit: limit * 2)
        } else {
            // Search all knowledge
            candidates = await knowledgeGraph.withLock { Array($0.values) }
        }
        
        // Score candidates based on query relevance
        let scoredResults = await withTaskGroup(of: ScoredKnowledge?.self) { group in
            for candidate in candidates {
                group.addTask {
                    let similarity = await self.calculateTextSimilarity(
                        text1: query,
                        text2: candidate.concept + " " + candidate.description
                    )
                    
                    guard similarity > 0.2 else { return nil } // Minimum relevance threshold
                    
                    return ScoredKnowledge(
                        knowledge: candidate,
                        relevanceScore: similarity,
                        confidenceScore: candidate.confidence,
                        freshnessScore: self.calculateFreshnessScore(candidate.lastUpdated),
                        combinedScore: similarity * 0.6 + candidate.confidence * 0.3 + self.calculateFreshnessScore(candidate.lastUpdated) * 0.1
                    )
                }
            }
            
            var results: [ScoredKnowledge] = []
            for await result in group {
                if let scored = result {
                    results.append(scored)
                }
            }
            return results
        }
        
        let finalResults = scoredResults
            .sorted { $0.combinedScore > $1.combinedScore }
            .prefix(limit)
            .map { $0.knowledge }
        
        let searchTime = Date().timeIntervalSince(startTime)
        await updateStats { stats in
            stats.totalSearches += 1
            stats.averageSearchTime = (stats.averageSearchTime + searchTime) / 2
        }
        
        return Array(finalResults)
    }
    
    /// Get recent knowledge items
    public func getRecentKnowledge(limit: Int = 10) async -> [SemanticKnowledgeItem] {
        let knowledge = await knowledgeGraph.withLock { Array($0.values) }
        
        return knowledge
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Knowledge Extraction
    
    /// Extract knowledge from an episodic memory
    public func extractKnowledge(from episode: EpisodicMemoryEntry) async -> [SemanticKnowledgeItem] {
        let extractedItems = await knowledgeExtractor.extract(from: episode)
        
        // Validate and enhance extracted knowledge
        var validatedItems: [SemanticKnowledgeItem] = []
        
        for item in extractedItems {
            // Analyze concepts and relationships
            let enhancedItem = await conceptAnalyzer.enhance(item)
            
            // Detect relationships with existing knowledge
            let relationships = await relationshipDetector.detect(for: enhancedItem, in: knowledgeGraph)
            
            let finalItem = SemanticKnowledgeItem(
                id: enhancedItem.id,
                concept: enhancedItem.concept,
                description: enhancedItem.description,
                domain: enhancedItem.domain,
                relationships: relationships,
                confidence: enhancedItem.confidence,
                sources: enhancedItem.sources + [episode.id],
                lastUpdated: Date()
            )
            
            validatedItems.append(finalItem)
        }
        
        return validatedItems
    }
    
    // MARK: - Knowledge Graph Operations
    
    /// Get knowledge in a specific domain
    public func getKnowledgeInDomain(_ domain: String, limit: Int = 20) async -> [SemanticKnowledgeItem] {
        let conceptIds = await domainIndex.withLock { $0[domain] ?? Set() }
        
        let knowledge = await knowledgeGraph.withLock { graph in
            conceptIds.compactMap { conceptId in
                graph[conceptId]
            }
        }
        
        return Array(knowledge.prefix(limit))
    }
    
    /// Find related concepts through relationships
    public func findRelatedConcepts(
        to concept: String,
        relationshipTypes: [RelationshipType] = [],
        depth: Int = 2
    ) async -> [SemanticKnowledgeItem] {
        
        return await relationshipGraph.findRelated(
            to: concept,
            types: relationshipTypes.isEmpty ? RelationshipType.allCases : relationshipTypes,
            depth: depth,
            knowledgeGraph: knowledgeGraph
        )
    }
    
    // MARK: - Knowledge Maintenance
    
    /// Optimize knowledge graph structure
    public func optimizeKnowledgeGraph() async -> Int {
        var optimizationCount = 0
        
        // 1. Merge similar concepts
        let mergedCount = await mergeSimilarConcepts()
        optimizationCount += mergedCount
        
        // 2. Update relationship strengths
        let updatedRelationships = await updateRelationshipStrengths()
        optimizationCount += updatedRelationships
        
        // 3. Remove low-confidence knowledge
        let removedCount = await removeLowConfidenceKnowledge()
        optimizationCount += removedCount
        
        // 4. Consolidate redundant information
        let consolidatedCount = await consolidateRedundantKnowledge()
        optimizationCount += consolidatedCount
        
        // Rebuild indices after optimization
        await rebuildIndices()
        
        print("🔧 Optimized knowledge graph: \(optimizationCount) items processed")
        return optimizationCount
    }
    
    // MARK: - Statistics and Analytics
    
    public var count: Int {
        get async {
            await knowledgeGraph.withLock { $0.count }
        }
    }
    
    public func getStatistics() async -> SemanticMemoryStats {
        return await stats.withLock { $0 }
    }
    
    public func getDomainDistribution() async -> [String: Int] {
        return await domainIndex.withLock { index in
            index.mapValues { $0.count }
        }
    }
    
    // MARK: - Private Implementation
    
    private func loadPersistedKnowledge() async {
        do {
            let persistedKnowledge = try await persistenceManager.loadAll()
            
            await knowledgeGraph.withLock { graph in
                for knowledge in persistedKnowledge {
                    graph[knowledge.concept] = knowledge
                }
            }
            
            await rebuildIndices()
            
        } catch {
            print("⚠️ Failed to load persisted knowledge: \(error)")
        }
    }
    
    private func rebuildIndices() async {
        let allKnowledge = await knowledgeGraph.withLock { Array($0.values) }
        
        // Rebuild domain index
        await domainIndex.withLock { index in
            index.removeAll()
            for knowledge in allKnowledge {
                if index[knowledge.domain] == nil {
                    index[knowledge.domain] = Set<String>()
                }
                index[knowledge.domain]?.insert(knowledge.concept)
            }
        }
        
        // Rebuild concept index
        await conceptIndex.rebuild(with: allKnowledge)
        
        // Rebuild relationship graph
        await relationshipGraph.rebuild(with: allKnowledge)
    }
    
    private func mergeKnowledge(
        existing: SemanticKnowledgeItem,
        new: SemanticKnowledgeItem
    ) async -> SemanticKnowledgeItem {
        // Merge descriptions
        let mergedDescription = existing.description.count > new.description.count 
            ? existing.description 
            : new.description
        
        // Merge relationships
        var mergedRelationships = existing.relationships
        for newRelationship in new.relationships {
            if !mergedRelationships.contains(where: { $0.relatedConcept == newRelationship.relatedConcept }) {
                mergedRelationships.append(newRelationship)
            } else {
                // Update relationship strength
                if let index = mergedRelationships.firstIndex(where: { $0.relatedConcept == newRelationship.relatedConcept }) {
                    let updated = ConceptRelationship(
                        relatedConcept: newRelationship.relatedConcept,
                        relationshipType: newRelationship.relationshipType,
                        strength: max(mergedRelationships[index].strength, newRelationship.strength)
                    )
                    mergedRelationships[index] = updated
                }
            }
        }
        
        // Merge sources
        let mergedSources = Array(Set(existing.sources + new.sources))
        
        // Update confidence (weighted average based on source count)
        let totalSources = existing.sources.count + new.sources.count
        let mergedConfidence = (existing.confidence * Double(existing.sources.count) + 
                               new.confidence * Double(new.sources.count)) / Double(totalSources)
        
        return SemanticKnowledgeItem(
            id: existing.id,
            concept: existing.concept,
            description: mergedDescription,
            domain: existing.domain,
            relationships: mergedRelationships,
            confidence: mergedConfidence,
            sources: mergedSources,
            lastUpdated: Date()
        )
    }
    
    private func enforceCapacity() async {
        let currentCount = await getCount()
        
        if currentCount > capacity {
            let excessCount = currentCount - capacity
            
            // Remove lowest confidence knowledge items
            let allKnowledge = await knowledgeGraph.withLock { Array($0.values) }
            let lowestConfidence = allKnowledge
                .sorted { $0.confidence < $1.confidence }
                .prefix(excessCount)
                .map { $0.concept }
            
            await knowledgeGraph.withLock { graph in
                for concept in lowestConfidence {
                    graph.removeValue(forKey: concept)
                }
            }
            
            await rebuildIndices()
            
            print("🗑️ Removed \(excessCount) lowest confidence knowledge items")
        }
    }
    
    private func inferDomains(from text: String) async -> [String] {
        // Simple domain inference - would use ML in production
        let domainKeywords = [
            "code": ["programming", "code", "function", "algorithm", "software"],
            "science": ["research", "study", "experiment", "data", "analysis"],
            "technology": ["tech", "computer", "system", "network", "digital"],
            "business": ["business", "market", "strategy", "company", "profit"],
            "general": []
        ]
        
        let lowercaseText = text.lowercased()
        var domainScores: [String: Int] = [:]
        
        for (domain, keywords) in domainKeywords {
            let score = keywords.reduce(0) { count, keyword in
                count + (lowercaseText.contains(keyword) ? 1 : 0)
            }
            domainScores[domain] = score
        }
        
        return domainScores
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }
    
    private func extractConcepts(from text: String) -> [String] {
        // Simple concept extraction - would use NLP in production
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 }
            .map { $0.lowercased() }
    }
    
    private func calculateRelevance(
        knowledge: SemanticKnowledgeItem,
        request: UserRequest
    ) async -> Double {
        return await calculateTextSimilarity(
            text1: request.text,
            text2: knowledge.concept + " " + knowledge.description
        )
    }
    
    private func calculateTextSimilarity(text1: String, text2: String) async -> Double {
        // Simple similarity calculation - would use embeddings in production
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        guard !union.isEmpty else { return 0 }
        return Double(intersection.count) / Double(union.count)
    }
    
    private func calculateFreshnessScore(_ lastUpdated: Date) -> Double {
        let ageInDays = Date().timeIntervalSince(lastUpdated) / (24 * 60 * 60)
        return max(0, 1 - (ageInDays / 365)) // Decay over one year
    }
    
    private func calculateCombinedKnowledgeScore(
        relevance: Double,
        confidence: Double,
        freshness: Double
    ) -> Double {
        return relevance * 0.5 + confidence * 0.3 + freshness * 0.2
    }
    
    private func getCount() async -> Int {
        await knowledgeGraph.withLock { $0.count }
    }
    
    // MARK: - Optimization Methods
    
    private func mergeSimilarConcepts() async -> Int {
        // Implementation for merging similar concepts
        return 0 // Placeholder
    }
    
    private func updateRelationshipStrengths() async -> Int {
        // Implementation for updating relationship strengths
        return 0 // Placeholder
    }
    
    private func removeLowConfidenceKnowledge() async -> Int {
        let threshold = 0.3
        var removedCount = 0
        
        await knowledgeGraph.withLock { graph in
            let lowConfidenceItems = graph.values.filter { $0.confidence < threshold }
            for item in lowConfidenceItems {
                graph.removeValue(forKey: item.concept)
                removedCount += 1
            }
        }
        
        return removedCount
    }
    
    private func consolidateRedundantKnowledge() async -> Int {
        // Implementation for consolidating redundant knowledge
        return 0 // Placeholder
    }
    
    private func updateStats(_ update: (inout SemanticMemoryStats) -> Void) async {
        await stats.withLock { update(&$0) }
    }
}

// MARK: - Supporting Types

private struct ScoredKnowledge {
    let knowledge: SemanticKnowledgeItem
    let relevanceScore: Double
    let confidenceScore: Double
    let freshnessScore: Double
    var combinedScore: Double = 0
    
    init(
        knowledge: SemanticKnowledgeItem,
        relevanceScore: Double,
        confidenceScore: Double,
        freshnessScore: Double,
        combinedScore: Double = 0
    ) {
        self.knowledge = knowledge
        self.relevanceScore = relevanceScore
        self.confidenceScore = confidenceScore
        self.freshnessScore = freshnessScore
        self.combinedScore = combinedScore
    }
}

public struct SemanticMemoryStats: Sendable {
    public var totalItems: Int = 0
    public var totalSearches: Int = 0
    public var averageSearchTime: TimeInterval = 0
    public var averageStorageTime: TimeInterval = 0
    public var averageResultCount: Double = 0
    public var optimizationRuns: Int = 0
    public var lastOptimization: Date?
}

// MARK: - Component Stubs (to be implemented)

private final class ConceptIndex: Sendable {
    private let index = Locked<[String: ConceptIndexEntry]>([:])
    
    func addConcept(_ knowledge: SemanticKnowledgeItem) async {
        let entry = ConceptIndexEntry(
            concept: knowledge.concept,
            keywords: extractKeywords(from: knowledge.description),
            domain: knowledge.domain
        )
        
        await index.withLock { $0[knowledge.concept] = entry }
    }
    
    func findConcepts(matching query: String, limit: Int) async -> [ConceptMatch] {
        let queryKeywords = extractKeywords(from: query)
        
        let matches = await index.withLock { index in
            index.values.compactMap { entry in
                let similarity = calculateKeywordSimilarity(queryKeywords, entry.keywords)
                guard similarity > 0.2 else { return nil }
                
                return ConceptMatch(concept: entry.concept, similarity: similarity)
            }
        }
        
        return matches
            .sorted { $0.similarity > $1.similarity }
            .prefix(limit)
            .map { $0 }
    }
    
    func rebuild(with knowledge: [SemanticKnowledgeItem]) async {
        await index.withLock { $0.removeAll() }
        
        for item in knowledge {
            await addConcept(item)
        }
    }
    
    private func extractKeywords(from text: String) -> [String] {
        return text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 2 }
    }
    
    private func calculateKeywordSimilarity(_ keywords1: [String], _ keywords2: [String]) -> Double {
        let set1 = Set(keywords1)
        let set2 = Set(keywords2)
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        guard !union.isEmpty else { return 0 }
        return Double(intersection.count) / Double(union.count)
    }
}

private struct ConceptIndexEntry: Sendable {
    let concept: String
    let keywords: [String]
    let domain: String
}

private struct ConceptMatch: Sendable {
    let concept: String
    let similarity: Double
}

private final class RelationshipGraph: Sendable {
    private let relationships = Locked<[String: [ConceptRelationship]]>([:])
    
    func updateRelationships(for knowledge: SemanticKnowledgeItem) async {
        await relationships.withLock { graph in
            graph[knowledge.concept] = knowledge.relationships
        }
    }
    
    func expandConcepts(from concepts: [String], depth: Int) async -> [String] {
        var expanded = Set(concepts)
        var currentDepth = 0
        
        while currentDepth < depth {
            let currentConcepts = Array(expanded)
            
            for concept in currentConcepts {
                let related = await relationships.withLock { graph in
                    graph[concept]?.map { $0.relatedConcept } ?? []
                }
                expanded.formUnion(related)
            }
            
            currentDepth += 1
        }
        
        return Array(expanded)
    }
    
    func findRelated(
        to concept: String,
        types: [RelationshipType],
        depth: Int,
        knowledgeGraph: Locked<[String: SemanticKnowledgeItem]>
    ) async -> [SemanticKnowledgeItem] {
        
        let relatedConcepts = await relationships.withLock { graph in
            graph[concept]?
                .filter { types.contains($0.relationshipType) }
                .map { $0.relatedConcept } ?? []
        }
        
        let knowledge = await knowledgeGraph.withLock { graph in
            relatedConcepts.compactMap { graph[$0] }
        }
        
        return knowledge
    }
    
    func rebuild(with knowledge: [SemanticKnowledgeItem]) async {
        await relationships.withLock { graph in
            graph.removeAll()
            for item in knowledge {
                graph[item.concept] = item.relationships
            }
        }
    }
}

private final class KnowledgeExtractor: Sendable {
    func extract(from episode: EpisodicMemoryEntry) async -> [SemanticKnowledgeItem] {
        // Extract semantic knowledge from episode
        // This would use NLP and ML techniques in production
        return []
    }
}

private final class ConceptAnalyzer: Sendable {
    func enhance(_ knowledge: SemanticKnowledgeItem) async -> SemanticKnowledgeItem {
        // Enhance knowledge with concept analysis
        return knowledge
    }
}

private final class RelationshipDetector: Sendable {
    func detect(
        for knowledge: SemanticKnowledgeItem,
        in graph: Locked<[String: SemanticKnowledgeItem]>
    ) async -> [ConceptRelationship] {
        // Detect relationships with existing knowledge
        return []
    }
}

private final class FactValidator: Sendable {
    // Fact validation utilities
}

private final class SemanticPersistenceManager: Sendable {
    func initialize() async throws {
        // Initialize storage
    }
    
    func store(_ knowledge: SemanticKnowledgeItem) async throws {
        // Store to persistent storage
    }
    
    func loadAll() async throws -> [SemanticKnowledgeItem] {
        // Load from persistent storage
        return []
    }
}