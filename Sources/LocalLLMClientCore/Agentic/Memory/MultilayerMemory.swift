import Foundation
import LocalLLMClientUtility
import OSLog

/// Advanced multi-layer memory system that provides comprehensive context and learning
/// This is the "brain" that enables true AI intelligence, personalization, and continuity
public final class MultilayerMemory: ObservableObject, Sendable {
    
    // MARK: - Memory Layers
    
    /// Episodic memory - detailed conversation history and interactions
    public let episodicMemory: EpisodicMemory
    
    /// Semantic memory - knowledge graphs and domain expertise
    public let semanticMemory: SemanticMemory
    
    /// Procedural memory - learned patterns and workflows
    public let proceduralMemory: ProceduralMemory
    
    /// Working memory - active context and attention management
    public let workingMemory: WorkingMemory
    
    /// User profiler - deep user understanding and personalization
    public let userProfiler: UserProfiler
    
    /// Context builder - intelligent context assembly
    public let contextBuilder: ContextBuilder
    
    // MARK: - Configuration
    
    private let episodicCapacity: Int
    private let semanticCapacity: Int
    private let workingMemorySize: Int
    private let autoConsolidation: Bool
    
    // MARK: - State Management
    
    @Published public private(set) var memoryStats = MemorySystemStats()
    @Published public private(set) var consolidationStatus: ConsolidationStatus = .idle
    
    private let consolidationQueue = DispatchQueue(label: "memory.consolidation", qos: .background)
    private var consolidationTimer: Timer?
    
    // MARK: - Initialization
    
    public init(
        episodicCapacity: Int = 10000,
        semanticCapacity: Int = 50000,
        workingMemorySize: Int = 100,
        autoConsolidation: Bool = true,
        userId: String = "default_user"
    ) async {
        self.episodicCapacity = episodicCapacity
        self.semanticCapacity = semanticCapacity  
        self.workingMemorySize = workingMemorySize
        self.autoConsolidation = autoConsolidation
        
        // Initialize memory layers
        self.episodicMemory = EpisodicMemory(capacity: episodicCapacity)
        self.semanticMemory = SemanticMemory(capacity: semanticCapacity)
        self.proceduralMemory = ProceduralMemory()
        self.workingMemory = WorkingMemory(size: workingMemorySize)
        self.userProfiler = UserProfiler()
        self.contextBuilder = ContextBuilder()
        
        print("🧠 Multi-Layer Memory System initialized")
        print("   Episodic capacity: \(episodicCapacity)")
        print("   Semantic capacity: \(semanticCapacity)")
        print("   Working memory: \(workingMemorySize)")
        print("   Auto consolidation: \(autoConsolidation)")
    }
    
    public func initialize() async throws {
        // Initialize all memory layers
        try await episodicMemory.initialize()
        try await semanticMemory.initialize()
        try await proceduralMemory.initialize()
        try await workingMemory.initialize()
        try await userProfiler.initialize()
        try await contextBuilder.initialize()
        
        // Connect memory layers
        await setupMemoryConnections()
        
        // Start automatic consolidation if enabled
        if autoConsolidation {
            startMemoryConsolidation()
        }
        
        print("🚀 Multi-Layer Memory System ready for intelligent operations")
    }
    
    // MARK: - Core Memory Operations
    
    /// Build comprehensive context for a user request
    public func buildContext(for request: UserRequest) async -> AgenticContext {
        let startTime = Date()
        
        // Get relevant memories from all layers
        let episodicContext = await episodicMemory.getRelevantHistory(for: request, limit: 10)
        let semanticContext = await semanticMemory.getRelevantKnowledge(for: request, limit: 20)
        let proceduralContext = await proceduralMemory.getRelevantPatterns(for: request, limit: 5)
        let userContext = await userProfiler.getUserProfile()
        
        // Build comprehensive context
        let context = await contextBuilder.buildContext(
            request: request,
            episodicMemories: episodicContext,
            semanticKnowledge: semanticContext,
            proceduralPatterns: proceduralContext,
            userProfile: userContext
        )
        
        // Update working memory with active context
        await workingMemory.updateActiveContext(context)
        
        let buildTime = Date().timeIntervalSince(startTime)
        await updateStats(contextBuildTime: buildTime)
        
        return context
    }
    
    /// Store a new episodic memory from user interaction
    public func storeEpisode(
        request: UserRequest,
        response: AgenticResponse,
        context: AgenticContext,
        timestamp: Date
    ) async {
        // Create episodic memory entry
        let episode = EpisodicMemoryEntry(
            id: UUID().uuidString,
            request: request,
            response: response,
            context: context,
            timestamp: timestamp,
            importance: calculateImportance(request: request, response: response),
            emotions: extractEmotions(from: request, response: response),
            outcomes: extractOutcomes(from: response)
        )
        
        // Store in episodic memory
        await episodicMemory.storeEntry(episode)
        
        // Extract semantic knowledge for long-term storage
        let semanticItems = await extractSemanticKnowledge(from: episode, response: response)
        for item in semanticItems {
            await semanticMemory.addKnowledge(item)
        }
        
        // Update procedural memory with patterns
        let interactionContext = InteractionContext(
            taskType: request.type.rawValue,
            steps: [], // Would be extracted in real implementation
            toolsUsed: [], // Would be tracked during execution
            conditions: [], // Would be analyzed from context
            outcomes: [], // Would be determined from response
            contextRequirements: [],
            successMetrics: [],
            optimizations: [],
            success: true,
            duration: 0.0,
            contextHash: context.id
        )
        await proceduralMemory.learnPattern(from: interactionContext)
        
        // Update user profile based on interaction
        let interaction = UserInteraction(
            id: UUID().uuidString,
            userId: context.userId,
            timestamp: timestamp,
            type: mapRequestTypeToInteraction(request.type),
            content: request.text,
            duration: 0.0, // Would be calculated in real implementation
            success: true, // Would be determined from response quality
            context: .work, // Would be inferred from context
            tools: [], // Would be extracted from actual tools used
            outcome: .satisfied, // Would be inferred from response
            trigger: nil,
            metadata: [:]
        )
        await userProfiler.processInteraction(interaction)
        
        await updateStats(episodeStored: true)
    }
    
    /// Update user model based on interaction patterns
    public func updateUserModel(from request: UserRequest, response: String) async {
        let interaction = UserInteraction(
            id: UUID().uuidString,
            userId: "default_user", // Would be passed in real implementation
            timestamp: Date(),
            type: mapRequestTypeToInteraction(request.type),
            content: request.text,
            duration: 0.0,
            success: true,
            context: .work,
            tools: [],
            outcome: .satisfied,
            trigger: nil,
            metadata: [:]
        )
        await userProfiler.processInteraction(interaction)
    }
    
    /// Query memory system with semantic search
    public func query(_ query: MemoryQuery) async throws -> AgenticResponse {
        let startTime = Date()
        
        switch query.type {
        case .episodic:
            let results = await episodicMemory.getRelevantHistory(
                for: UserRequest(id: UUID().uuidString, text: query.parameters["query"] ?? "", type: .question),
                limit: query.resultLimit
            )
            
            let responseText = formatEpisodicResults(results)
            let queryTime = Date().timeIntervalSince(startTime)
            
            await updateStats(queryTime: queryTime, resultCount: results.count)
            
            return AgenticResponse(
                text: responseText,
                confidence: calculateConfidence(from: results),
                processingTime: queryTime,
                metadata: ["query_type": "episodic", "result_count": "\(results.count)"]
            )
            
        case .semantic:
            let results = await semanticMemory.getRelevantKnowledge(
                for: UserRequest(id: UUID().uuidString, text: query.parameters["query"] ?? "", type: .question),
                limit: query.resultLimit
            )
            
            let responseText = formatSemanticResults(results)
            let queryTime = Date().timeIntervalSince(startTime)
            
            await updateStats(queryTime: queryTime, resultCount: results.count)
            
            return AgenticResponse(
                text: responseText,
                confidence: calculateConfidence(from: results),
                processingTime: queryTime,
                metadata: ["query_type": "semantic", "result_count": "\(results.count)"]
            )
            
        case .procedural:
            let patterns = await proceduralMemory.getRelevantPatterns(
                for: UserRequest(id: UUID().uuidString, text: query.parameters["pattern"] ?? "", type: .task),
                limit: query.resultLimit
            )
            
            let responseText = formatProceduralResults(patterns)
            let queryTime = Date().timeIntervalSince(startTime)
            
            return AgenticResponse(
                text: responseText,
                confidence: calculateConfidence(from: patterns),
                processingTime: queryTime,
                metadata: ["query_type": "procedural", "pattern_count": "\(patterns.count)"]
            )
            
        case .contextual:
            let context = await buildContextualResponse(query)
            let queryTime = Date().timeIntervalSince(startTime)
            
            return AgenticResponse(
                text: context.description,
                confidence: 0.9,
                processingTime: queryTime,
                metadata: ["query_type": "contextual"]
            )
        }
    }
    
    // MARK: - User Intelligence
    
    /// Get comprehensive user profile
    public func getUserProfile() async -> UserProfile {
        return await userProfiler.getUserProfile()
    }
    
    /// Get user behavior patterns
    public func getUserPatterns() async -> [UserPattern] {
        return await proceduralMemory.getUserPatterns()
    }
    
    /// Get personalized recommendations
    public func getPersonalizedRecommendations(for context: AgenticContext) async -> [PersonalizedRecommendation] {
        let userProfile = await getUserProfile()
        let userPatterns = await getUserPatterns()
        let recentHistory = await episodicMemory.getRecentHistory(limit: 20)
        
        return await contextBuilder.generateRecommendations(
            userProfile: userProfile,
            patterns: userPatterns,
            recentHistory: recentHistory,
            currentContext: context
        )
    }
    
    // MARK: - Memory Analytics
    
    /// Get memory utilization statistics
    public func getUtilization() -> Double {
        let episodicUtil = Double(episodicMemory.count) / Double(episodicCapacity)
        let semanticUtil = Double(semanticMemory.count) / Double(semanticCapacity)
        let workingUtil = Double(workingMemory.activeItems) / Double(workingMemorySize)
        
        return (episodicUtil + semanticUtil + workingUtil) / 3.0
    }
    
    /// Get comprehensive memory analytics
    public func getMemoryAnalytics() async -> MemoryAnalytics {
        let episodicStats = await episodicMemory.getStatistics()
        let semanticStats = await semanticMemory.getStatistics()
        let proceduralStats = await proceduralMemory.getStatistics()
        let userStats = await userProfiler.getStatistics()
        
        return MemoryAnalytics(
            episodicMemories: episodicStats.totalEntries,
            semanticKnowledge: semanticStats.totalItems,
            proceduralPatterns: proceduralStats.totalPatterns,
            userInsights: userStats.totalInsights,
            averageQueryTime: memoryStats.averageQueryTime,
            memoryUtilization: getUtilization(),
            consolidationEfficiency: memoryStats.consolidationEfficiency
        )
    }
    
    // MARK: - Memory Consolidation
    
    private func startMemoryConsolidation() {
        consolidationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task { [weak self] in
                await self?.performMemoryConsolidation()
            }
        }
    }
    
    private func performMemoryConsolidation() async {
        await MainActor.run {
            consolidationStatus = .active
        }
        
        let startTime = Date()
        
        do {
            // Consolidate episodic memories
            let episodicConsolidated = await episodicMemory.consolidateOldMemories()
            
            // Optimize semantic knowledge
            let semanticOptimized = await semanticMemory.optimizeKnowledgeGraph()
            
            // Refine procedural patterns
            let proceduralRefined = await proceduralMemory.refinePatterns()
            
            // Update user profile insights
            await userProfiler.consolidateInsights()
            
            let consolidationTime = Date().timeIntervalSince(startTime)
            
            await updateConsolidationStats(
                episodicConsolidated: episodicConsolidated,
                semanticOptimized: semanticOptimized,
                proceduralRefined: proceduralRefined,
                consolidationTime: consolidationTime
            )
            
            print("🧠 Memory consolidation completed in \(String(format: "%.2f", consolidationTime))s")
            
        } catch {
            print("⚠️ Memory consolidation error: \(error)")
        }
        
        await MainActor.run {
            consolidationStatus = .idle
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupMemoryConnections() async {
        // Connect episodic memory to semantic extraction
        episodicMemory.setSemanticExtractor { episode in
            await self.extractSemanticKnowledge(from: episode)
        }
        
        // Connect semantic memory to episodic validation
        semanticMemory.setEpisodicValidator { knowledge in
            await self.validateWithEpisodic(knowledge)
        }
        
        // Connect procedural memory to all other layers
        proceduralMemory.setMemoryLayers(
            episodic: episodicMemory,
            semantic: semanticMemory
        )
        
        // Memory layers are now connected through the buildContext method
    }
    
    private func calculateImportance(request: UserRequest, response: String) -> Double {
        var importance = 0.5 // Base importance
        
        // Increase importance based on request priority
        if request.priority > 0.8 {
            importance += 0.4
        } else if request.priority > 0.6 {
            importance += 0.3
        } else if request.priority > 0.4 {
            importance += 0.1
        }
        
        // Increase importance based on response complexity
        if response.count > 500 {
            importance += 0.2
        }
        
        // Increase importance based on question complexity
        if request.text.count > 100 {
            importance += 0.1
        }
        
        return min(1.0, importance)
    }
    
    private func extractTags(from request: UserRequest, response: String) -> [String] {
        // Simple emotion extraction - would use NLP in production
        var emotions: [String] = []
        
        let emotionKeywords = [
            "urgent": "urgency",
            "please": "politeness",
            "help": "seeking_assistance",
            "thank": "gratitude",
            "sorry": "apologetic"
        ]
        
        let text = (request.text + " " + response).lowercased()
        
        for (keyword, emotion) in emotionKeywords {
            if text.contains(keyword) {
                emotions.append(emotion)
            }
        }
        
        return emotions
    }
    
    private func generateEmbedding(for text: String) async -> [Float] {
        // In a real implementation, this would use a proper embedding model
        // For now, return a simple hash-based embedding
        let hash = text.hash
        var embedding: [Float] = []
        for i in 0..<128 {
            embedding.append(Float(hash ^ (i * 31)) / Float(Int.max))
        }
        return embedding
    }
    
    private func extractSemanticKnowledge(from episode: EpisodicMemoryEntry, response: String) async -> [SemanticKnowledgeItem] {
        // Extract semantic knowledge from episode
        // In a real implementation, this would use NLP to extract concepts
        var items: [SemanticKnowledgeItem] = []
        
        // Simple keyword extraction
        let keywords = extractKeywords(from: response)
        
        for keyword in keywords {
            let item = SemanticKnowledgeItem(
                id: UUID().uuidString,
                concept: keyword,
                content: "Concept mentioned in interaction: \(keyword)",
                category: "extracted",
                domain: "general",
                confidence: 0.5,
                embedding: await generateEmbedding(for: keyword),
                relationships: [],
                metadata: ["source": "episodic_extraction"],
                lastAccessed: Date(),
                accessCount: 1
            )
            items.append(item)
        }
        
        return items
    }
    
    private func extractKeywords(from text: String) -> [String] {
        // Simple keyword extraction
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let stopWords = Set(["the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "a", "an", "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does", "did", "will", "would", "could", "should", "may", "might", "must", "can", "this", "that", "these", "those"])
        
        return words.filter { word in
            word.count > 3 && !stopWords.contains(word) && word.allSatisfy { $0.isLetter }
        }.prefix(5).map { $0 }
    }
    
    private func mapRequestTypeToInteraction(_ type: RequestType) -> InteractionType {
        switch type {
        case .question: return .question
        case .task: return .task
        case .analysis: return .conversation
        case .creation: return .task
        case .optimization: return .task
        case .learning: return .learning
        case .exploration: return .exploration
        }
    }
    
    private func validateWithEpisodic(_ knowledge: SemanticKnowledgeItem) async -> Bool {
        // In a real implementation, this would validate against episodic memories
        return knowledge.confidence > 0.3
    }
    
    private func formatEpisodicResults(_ results: [EpisodicMemoryEntry]) -> String {
        guard !results.isEmpty else { return "No relevant memories found." }
        
        let formatted = results.prefix(5).map { entry in
            "[\(entry.timestamp.formatted(.dateTime.hour().minute()))] \(entry.content.prefix(100))..."
        }.joined(separator: "\n")
        
        return "Found \(results.count) relevant memories:\n\n\(formatted)"
    }
    
    private func formatSemanticResults(_ results: [SemanticKnowledgeItem]) -> String {
        guard !results.isEmpty else { return "No relevant knowledge found." }
        
        let formatted = results.prefix(5).map { item in
            "• \(item.concept): \(item.content.prefix(100))..."
        }.joined(separator: "\n")
        
        return "Found \(results.count) relevant knowledge items:\n\n\(formatted)"
    }
    
    private func formatProceduralResults(_ results: [ProceduralPattern]) -> String {
        guard !results.isEmpty else { return "No relevant patterns found." }
        
        let formatted = results.prefix(5).map { pattern in
            "• \(pattern.name): \(pattern.description) (Success: \(String(format: "%.1f", pattern.metadata.successRate * 100))%)"
        }.joined(separator: "\n")
        
        return "Found \(results.count) relevant patterns:\n\n\(formatted)"
    }
    
    private func calculateConfidence<T>(from results: [T]) -> Double {
        guard !results.isEmpty else { return 0.0 }
        return min(1.0, Double(results.count) / 5.0) // Simple confidence based on result count
    }
    
    private func formatSemanticResults(_ results: [SemanticKnowledgeItem]) -> String {
        guard !results.isEmpty else { return "No relevant knowledge found." }
        
        let formatted = results.prefix(5).map { item in
            "• \(item.concept): \(item.description)"
        }.joined(separator: "\n")
        
        return "Found \(results.count) relevant knowledge items:\n\n\(formatted)"
    }
    
    private func formatProceduralResults(_ results: [ProceduralPattern]) -> String {
        guard !results.isEmpty else { return "No relevant patterns found." }
        
        let formatted = results.prefix(3).map { pattern in
            "• \(pattern.name): \(pattern.description) (confidence: \(String(format: "%.1f", pattern.confidence * 100))%)"
        }.joined(separator: "\n")
        
        return "Found \(results.count) relevant patterns:\n\n\(formatted)"
    }
    
    private func calculateConfidence<T>(from results: [T]) -> Double {
        guard !results.isEmpty else { return 0.0 }
        return min(1.0, Double(results.count) / 10.0) // Scale based on result count
    }
    
    private func buildContextualResponse(_ query: MemoryQuery) async -> AgenticContext {
        let userProfile = await getUserProfile()
        let recentHistory = await episodicMemory.getRecentHistory(limit: 5)
        let relevantKnowledge = await semanticMemory.getRecentKnowledge(limit: 10)
        
        return AgenticContext(
            userProfile: userProfile,
            conversationContext: ConversationContext(
                recentTopics: recentHistory.compactMap { $0.request.metadata["topic"] },
                unfinishedTasks: recentHistory.compactMap { $0.request.metadata["task"] }
            )
        )
    }
    
    // MARK: - Statistics Updates
    
    private func updateStats(
        contextBuildTime: TimeInterval? = nil,
        episodeStored: Bool = false,
        queryTime: TimeInterval? = nil,
        resultCount: Int? = nil
    ) async {
        await MainActor.run {
            if let buildTime = contextBuildTime {
                memoryStats.averageContextBuildTime = 
                    (memoryStats.averageContextBuildTime + buildTime) / 2
            }
            
            if episodeStored {
                memoryStats.totalEpisodesStored += 1
            }
            
            if let qTime = queryTime {
                memoryStats.averageQueryTime = (memoryStats.averageQueryTime + qTime) / 2
                memoryStats.totalQueries += 1
            }
            
            if let count = resultCount {
                memoryStats.averageResultCount = 
                    (memoryStats.averageResultCount + Double(count)) / 2
            }
        }
    }
    
    private func updateConsolidationStats(
        episodicConsolidated: Int,
        semanticOptimized: Int,
        proceduralRefined: Int,
        consolidationTime: TimeInterval
    ) async {
        await MainActor.run {
            memoryStats.consolidationRuns += 1
            memoryStats.averageConsolidationTime = 
                (memoryStats.averageConsolidationTime + consolidationTime) / 2
            memoryStats.lastConsolidation = Date()
            
            // Calculate efficiency based on items processed
            let totalProcessed = episodicConsolidated + semanticOptimized + proceduralRefined
            memoryStats.consolidationEfficiency = 
                consolidationTime > 0 ? Double(totalProcessed) / consolidationTime : 0
        }
    }
    
    deinit {
        consolidationTimer?.invalidate()
    }
}

// MARK: - Supporting Types

public struct MemorySystemStats: Sendable {
    public var totalEpisodesStored: Int = 0
    public var totalQueries: Int = 0
    public var averageQueryTime: TimeInterval = 0
    public var averageResultCount: Double = 0
    public var averageContextBuildTime: TimeInterval = 0
    public var consolidationRuns: Int = 0
    public var averageConsolidationTime: TimeInterval = 0
    public var consolidationEfficiency: Double = 0
    public var lastConsolidation: Date?
}

public enum ConsolidationStatus: String, CaseIterable {
    case idle = "idle"
    case active = "active"
    case optimizing = "optimizing"
    case finalizing = "finalizing"
}

public struct MemoryAnalytics: Sendable {
    public let episodicMemories: Int
    public let semanticKnowledge: Int
    public let proceduralPatterns: Int
    public let userInsights: Int
    public let averageQueryTime: TimeInterval
    public let memoryUtilization: Double
    public let consolidationEfficiency: Double
}

public struct PersonalizedRecommendation: Sendable {
    public let title: String
    public let description: String
    public let confidence: Double
    public let category: RecommendationCategory
    public let reasoning: String
    public let actionable: Bool
}

public enum RecommendationCategory: String, CaseIterable {
    case tool = "tool"
    case workflow = "workflow"
    case learning = "learning"
    case optimization = "optimization"
    case habit = "habit"
}

// MARK: - Memory Entry Types

public struct EpisodicMemoryEntry: Sendable, Identifiable, Codable {
    public let id: String
    public let request: UserRequest
    public let response: AgenticResponse
    public let context: AgenticContext
    public let timestamp: Date
    public let importance: Double
    public let emotions: [String]
    public let outcomes: [String]
    
    public init(
        id: String,
        request: UserRequest,
        response: AgenticResponse,
        context: AgenticContext,
        timestamp: Date,
        importance: Double,
        emotions: [String],
        outcomes: [String]
    ) {
        self.id = id
        self.request = request
        self.response = response
        self.context = context
        self.timestamp = timestamp
        self.importance = importance
        self.emotions = emotions
        self.outcomes = outcomes
    }
}

public struct SemanticKnowledgeItem: Sendable, Identifiable, Codable {
    public let id: String
    public let concept: String
    public let description: String
    public let domain: String
    public let relationships: [ConceptRelationship]
    public let confidence: Double
    public let sources: [String]
    public let lastUpdated: Date
    
    public init(
        id: String = UUID().uuidString,
        concept: String,
        description: String,
        domain: String,
        relationships: [ConceptRelationship] = [],
        confidence: Double,
        sources: [String],
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.concept = concept
        self.description = description
        self.domain = domain
        self.relationships = relationships
        self.confidence = confidence
        self.sources = sources
        self.lastUpdated = lastUpdated
    }
}

public struct ConceptRelationship: Sendable, Codable {
    public let relatedConcept: String
    public let relationshipType: RelationshipType
    public let strength: Double
    
    public init(relatedConcept: String, relationshipType: RelationshipType, strength: Double) {
        self.relatedConcept = relatedConcept
        self.relationshipType = relationshipType
        self.strength = strength
    }
}

public enum RelationshipType: String, Codable, CaseIterable {
    case isA = "is_a"
    case partOf = "part_of"
    case relatedTo = "related_to"
    case causedBy = "caused_by"
    case enables = "enables"
    case requires = "requires"
}

public struct ProceduralPattern: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let trigger: String
    public let steps: [String]
    public let success_rate: Double
    public let confidence: Double
    public let lastUsed: Date
    public let usageCount: Int
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        trigger: String,
        steps: [String],
        success_rate: Double,
        confidence: Double,
        lastUsed: Date = Date(),
        usageCount: Int
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.trigger = trigger
        self.steps = steps
        self.success_rate = success_rate
        self.confidence = confidence
        self.lastUsed = lastUsed
        self.usageCount = usageCount
    }
}