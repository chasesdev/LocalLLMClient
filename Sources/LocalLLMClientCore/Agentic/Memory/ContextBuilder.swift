import Foundation
import OSLog

/// ContextBuilder creates comprehensive, personalized contexts from all memory layers
/// This component synthesizes episodic, semantic, procedural, working memory, and user intelligence
public class ContextBuilder: Sendable {
    private let configuration: ContextBuilderConfiguration
    private let logger = Logger(subsystem: "LocalLLMClientCore", category: "ContextBuilder")
    
    private var contextCache: [String: (context: AgenticContext, timestamp: Date)] = [:]
    private let lock = AsyncLock()
    
    public init(configuration: ContextBuilderConfiguration = .default) {
        self.configuration = configuration
        logger.info("ContextBuilder initialized")
    }
    
    // MARK: - Context Building
    
    /// Build comprehensive context by synthesizing all memory layers
    public func buildContext(
        request: UserRequest,
        episodicMemories: [EpisodicMemoryEntry],
        semanticKnowledge: [SemanticKnowledgeItem],
        proceduralPatterns: [ProceduralPattern],
        userProfile: UserProfile
    ) async -> AgenticContext {
        
        await lock.withLock {
            let startTime = Date()
            let cacheKey = generateCacheKey(for: request)
            
            // Check cache first
            if let cached = contextCache[cacheKey],
               Date().timeIntervalSince(cached.timestamp) < configuration.cacheTimeout {
                logger.debug("Using cached context for request")
                return cached.context
            }
            
            logger.debug("Building new context for request: \(request.text.prefix(50))")
            
            // Build core context
            let coreContext = await buildCoreContext(
                request: request,
                episodicMemories: episodicMemories,
                semanticKnowledge: semanticKnowledge,
                proceduralPatterns: proceduralPatterns,
                userProfile: userProfile
            )
            
            // Add conversational context
            let conversationalContext = await buildConversationalContext(
                request: request,
                episodicMemories: episodicMemories,
                userProfile: userProfile
            )
            
            // Add task context
            let taskContext = await buildTaskContext(
                request: request,
                proceduralPatterns: proceduralPatterns,
                userProfile: userProfile
            )
            
            // Add domain context
            let domainContext = await buildDomainContext(
                request: request,
                semanticKnowledge: semanticKnowledge,
                userProfile: userProfile
            )
            
            // Add personalization context
            let personalizationContext = await buildPersonalizationContext(
                request: request,
                userProfile: userProfile
            )
            
            // Add environmental context
            let environmentalContext = await buildEnvironmentalContext(
                request: request,
                userProfile: userProfile
            )
            
            // Synthesize all contexts
            let synthesizedContext = await synthesizeContexts(
                core: coreContext,
                conversational: conversationalContext,
                task: taskContext,
                domain: domainContext,
                personalization: personalizationContext,
                environmental: environmentalContext
            )
            
            // Apply context optimization
            let optimizedContext = await optimizeContext(synthesizedContext, for: request)
            
            // Generate context metadata
            let metadata = generateContextMetadata(
                request: request,
                buildTime: Date().timeIntervalSince(startTime),
                sources: ContextSources(
                    episodicCount: episodicMemories.count,
                    semanticCount: semanticKnowledge.count,
                    proceduralCount: proceduralPatterns.count,
                    userProfileConfidence: userProfile.personalityTraits.confidence
                )
            )
            
            let finalContext = AgenticContext(
                id: UUID().uuidString,
                requestId: request.id,
                userId: userProfile.id,
                timestamp: Date(),
                
                // Context sections
                conversationalContext: optimizedContext.conversational,
                taskContext: optimizedContext.task,
                domainContext: optimizedContext.domain,
                userContext: optimizedContext.personalization,
                environmentalContext: optimizedContext.environmental,
                
                // Memory integration
                relevantHistory: episodicMemories.prefix(10).map { $0 },
                relevantKnowledge: semanticKnowledge.prefix(15).map { $0 },
                relevantPatterns: proceduralPatterns.prefix(5).map { $0 },
                
                // User personalization
                personalityAdaptations: optimizedContext.personalityAdaptations,
                communicationStyle: optimizedContext.communicationStyle,
                cognitiveAdaptations: optimizedContext.cognitiveAdaptations,
                workflowPreferences: optimizedContext.workflowPreferences,
                
                // Context quality
                contextQuality: calculateContextQuality(optimizedContext),
                relevanceScore: calculateRelevanceScore(optimizedContext, for: request),
                confidenceLevel: calculateConfidenceLevel(optimizedContext, metadata: metadata),
                
                // Processing info
                buildDuration: Date().timeIntervalSince(startTime),
                cacheHit: false,
                metadata: metadata
            )
            
            // Cache the result
            contextCache[cacheKey] = (finalContext, Date())
            
            // Clean up old cache entries
            await cleanupContextCache()
            
            logger.debug("Built context in \(String(format: "%.3f", finalContext.buildDuration))s with quality \(String(format: "%.2f", finalContext.contextQuality))")
            
            return finalContext
        }
    }
    
    // MARK: - Context Enrichment
    
    /// Enrich existing context with additional information
    public func enrichContext(
        _ baseContext: AgenticContext,
        with enrichment: ContextEnrichment
    ) async -> AgenticContext {
        
        await lock.withLock {
            logger.debug("Enriching context: \(baseContext.id)")
            
            var enrichedContext = baseContext
            
            switch enrichment.type {
            case .additionalMemories:
                if let memories = enrichment.data as? [EpisodicMemoryEntry] {
                    enrichedContext.relevantHistory.append(contentsOf: memories.prefix(5))
                }
                
            case .domainKnowledge:
                if let knowledge = enrichment.data as? [SemanticKnowledgeItem] {
                    enrichedContext.relevantKnowledge.append(contentsOf: knowledge.prefix(5))
                }
                
            case .proceduralPatterns:
                if let patterns = enrichment.data as? [ProceduralPattern] {
                    enrichedContext.relevantPatterns.append(contentsOf: patterns.prefix(3))
                }
                
            case .userInsights:
                if let insights = enrichment.data as? [String] {
                    enrichedContext.personalityAdaptations.append(contentsOf: insights)
                }
                
            case .environmentalData:
                if let envData = enrichment.data as? [String: Any] {
                    enrichedContext.environmentalContext.append(contentsOf: envData.keys.map { "\($0): \(envData[$0] ?? "")" })
                }
            }
            
            // Recalculate quality scores
            enrichedContext.contextQuality = calculateContextQuality(
                OptimizedContext(
                    conversational: enrichedContext.conversationalContext,
                    task: enrichedContext.taskContext,
                    domain: enrichedContext.domainContext,
                    personalization: enrichedContext.userContext,
                    environmental: enrichedContext.environmentalContext,
                    personalityAdaptations: enrichedContext.personalityAdaptations,
                    communicationStyle: enrichedContext.communicationStyle,
                    cognitiveAdaptations: enrichedContext.cognitiveAdaptations,
                    workflowPreferences: enrichedContext.workflowPreferences
                )
            )
            
            enrichedContext.confidenceLevel = min(1.0, enrichedContext.confidenceLevel + 0.1)
            
            logger.debug("Enriched context quality: \(String(format: "%.2f", enrichedContext.contextQuality))")
            
            return enrichedContext
        }
    }
    
    // MARK: - Context Analysis
    
    /// Analyze context effectiveness and quality
    public func analyzeContext(_ context: AgenticContext) async -> ContextAnalysis {
        return await lock.withLock {
            let completeness = calculateContextCompleteness(context)
            let relevance = context.relevanceScore
            let personalization = calculatePersonalizationLevel(context)
            let coherence = calculateContextCoherence(context)
            let usability = calculateContextUsability(context)
            
            let strengths = identifyContextStrengths(context)
            let weaknesses = identifyContextWeaknesses(context)
            let recommendations = generateContextRecommendations(context)
            
            return ContextAnalysis(
                contextId: context.id,
                overallQuality: context.contextQuality,
                completeness: completeness,
                relevance: relevance,
                personalization: personalization,
                coherence: coherence,
                usability: usability,
                strengths: strengths,
                weaknesses: weaknesses,
                recommendations: recommendations,
                memoryUtilization: MemoryUtilization(
                    episodicUsage: Double(context.relevantHistory.count) / 10.0,
                    semanticUsage: Double(context.relevantKnowledge.count) / 15.0,
                    proceduralUsage: Double(context.relevantPatterns.count) / 5.0,
                    userProfileUsage: calculateUserProfileUsage(context)
                ),
                buildEfficiency: calculateBuildEfficiency(context),
                analyzedAt: Date()
            )
        }
    }
    
    // MARK: - Context Optimization
    
    /// Optimize context for specific use cases
    public func optimizeForUseCase(
        _ context: AgenticContext,
        useCase: ContextUseCase
    ) async -> AgenticContext {
        
        await lock.withLock {
            logger.debug("Optimizing context for use case: \(useCase.rawValue)")
            
            var optimizedContext = context
            
            switch useCase {
            case .quickResponse:
                // Prioritize immediate relevance and reduce context size
                optimizedContext.relevantHistory = Array(context.relevantHistory.prefix(3))
                optimizedContext.relevantKnowledge = Array(context.relevantKnowledge.prefix(5))
                optimizedContext.relevantPatterns = Array(context.relevantPatterns.prefix(2))
                
            case .deepAnalysis:
                // Include maximum relevant information
                // Keep all context as-is, but enhance with additional insights
                optimizedContext.domainContext.append("Deep analysis mode activated")
                
            case .creativeTasks:
                // Emphasize diverse knowledge and reduce constraining patterns
                optimizedContext.relevantPatterns = context.relevantPatterns.filter { $0.metadata.domain != "procedural" }
                optimizedContext.cognitiveAdaptations.append("Enhanced creativity mode")
                
            case .technicalTasks:
                // Focus on technical knowledge and procedural patterns
                optimizedContext.relevantKnowledge = context.relevantKnowledge.filter { 
                    $0.category == "technical" || $0.category == "procedural" 
                }
                optimizedContext.workflowPreferences.append("Technical precision mode")
                
            case .collaborative:
                // Enhance communication and social context
                optimizedContext.communicationStyle.append("Collaborative interaction enhanced")
                optimizedContext.personalityAdaptations.append("Team-oriented approach")
                
            case .learning:
                // Structure for educational effectiveness
                optimizedContext.userContext.append("Learning mode activated")
                optimizedContext.workflowPreferences.append("Progressive complexity")
            }
            
            // Recalculate quality for optimized context
            optimizedContext.contextQuality = calculateContextQuality(
                OptimizedContext(
                    conversational: optimizedContext.conversationalContext,
                    task: optimizedContext.taskContext,
                    domain: optimizedContext.domainContext,
                    personalization: optimizedContext.userContext,
                    environmental: optimizedContext.environmentalContext,
                    personalityAdaptations: optimizedContext.personalityAdaptations,
                    communicationStyle: optimizedContext.communicationStyle,
                    cognitiveAdaptations: optimizedContext.cognitiveAdaptations,
                    workflowPreferences: optimizedContext.workflowPreferences
                )
            )
            
            logger.debug("Context optimized for \(useCase.rawValue), quality: \(String(format: "%.2f", optimizedContext.contextQuality))")
            
            return optimizedContext
        }
    }
    
    // MARK: - Private Implementation
    
    private func buildCoreContext(
        request: UserRequest,
        episodicMemories: [EpisodicMemoryEntry],
        semanticKnowledge: [SemanticKnowledgeItem],
        proceduralPatterns: [ProceduralPattern],
        userProfile: UserProfile
    ) async -> CoreContext {
        
        let requestAnalysis = analyzeRequest(request)
        let memoryRelevance = calculateMemoryRelevance(
            request: request,
            episodic: episodicMemories,
            semantic: semanticKnowledge,
            procedural: proceduralPatterns
        )
        
        return CoreContext(
            requestAnalysis: requestAnalysis,
            memoryRelevance: memoryRelevance,
            userAlignment: calculateUserAlignment(request, profile: userProfile)
        )
    }
    
    private func buildConversationalContext(
        request: UserRequest,
        episodicMemories: [EpisodicMemoryEntry],
        userProfile: UserProfile
    ) async -> [String] {
        
        var context: [String] = []
        
        // Recent conversation flow
        let recentMemories = episodicMemories.prefix(3)
        for memory in recentMemories {
            context.append("Recent interaction: \(memory.content)")
        }
        
        // Communication style adaptation
        let communicationStyle = userProfile.communicationStyle
        context.append("User prefers \(communicationStyle.formalityLevel > 0.7 ? "formal" : "casual") communication")
        
        if communicationStyle.verbosity > 0.7 {
            context.append("User appreciates detailed explanations")
        } else if communicationStyle.verbosity < 0.3 {
            context.append("User prefers concise responses")
        }
        
        return context
    }
    
    private func buildTaskContext(
        request: UserRequest,
        proceduralPatterns: [ProceduralPattern],
        userProfile: UserProfile
    ) async -> [String] {
        
        var context: [String] = []
        
        // Task type identification
        let taskType = identifyTaskType(request)
        context.append("Primary task: \(taskType)")
        
        // Relevant procedural patterns
        for pattern in proceduralPatterns.prefix(3) {
            context.append("Known pattern: \(pattern.name) - \(pattern.description)")
        }
        
        // Workflow preferences
        let workflowPrefs = userProfile.workflowPreferences
        context.append("User prefers \(workflowPrefs.preferredPacing.rawValue) pacing")
        context.append("User works best with \(workflowPrefs.collaborationStyle.rawValue) approach")
        
        return context
    }
    
    private func buildDomainContext(
        request: UserRequest,
        semanticKnowledge: [SemanticKnowledgeItem],
        userProfile: UserProfile
    ) async -> [String] {
        
        var context: [String] = []
        
        // Domain expertise
        let relevantExpertise = userProfile.domainExpertise.filter { domain, expertise in
            request.text.lowercased().contains(domain.lowercased()) && expertise.demonstratedLevel > 0.5
        }
        
        for (domain, expertise) in relevantExpertise {
            context.append("User has \(formatExpertiseLevel(expertise.demonstratedLevel)) expertise in \(domain)")
        }
        
        // Relevant semantic knowledge
        for knowledge in semanticKnowledge.prefix(5) {
            context.append("Related knowledge: \(knowledge.content)")
        }
        
        return context
    }
    
    private func buildPersonalizationContext(
        request: UserRequest,
        userProfile: UserProfile
    ) async -> [String] {
        
        var context: [String] = []
        
        // Personality adaptations
        let personality = userProfile.personalityTraits
        if personality.openness > 0.7 {
            context.append("User is open to new ideas and creative approaches")
        }
        
        if personality.conscientiousness > 0.7 {
            context.append("User values thoroughness and attention to detail")
        }
        
        if personality.extraversion > 0.7 {
            context.append("User prefers interactive and engaging responses")
        }
        
        // Learning style
        let learningStyle = userProfile.learningStyle
        if learningStyle.preferredModalities.contains(.visual) {
            context.append("User learns well with visual aids and examples")
        }
        
        context.append("User prefers \(learningStyle.pacePreference.rawValue) learning pace")
        context.append("User benefits from \(learningStyle.feedbackPreference.rawValue) feedback")
        
        return context
    }
    
    private func buildEnvironmentalContext(
        request: UserRequest,
        userProfile: UserProfile
    ) async -> [String] {
        
        var context: [String] = []
        
        // Time-based context
        let hour = Calendar.current.component(.hour, from: Date())
        let timeContext = hour < 12 ? "morning" : hour < 17 ? "afternoon" : "evening"
        context.append("Current time context: \(timeContext)")
        
        // User goals alignment
        for goal in userProfile.goals where goal.confidence > 0.5 {
            context.append("User goal: \(goal.description)")
        }
        
        return context
    }
    
    private func synthesizeContexts(
        core: CoreContext,
        conversational: [String],
        task: [String],
        domain: [String],
        personalization: [String],
        environmental: [String]
    ) async -> SynthesizedContext {
        
        return SynthesizedContext(
            conversational: conversational,
            task: task,
            domain: domain,
            personalization: personalization,
            environmental: environmental,
            coreInsights: core
        )
    }
    
    private func optimizeContext(_ synthesized: SynthesizedContext, for request: UserRequest) async -> OptimizedContext {
        // Apply optimization rules based on configuration
        let maxContextItems = configuration.maxContextItems
        
        return OptimizedContext(
            conversational: Array(synthesized.conversational.prefix(maxContextItems.conversational)),
            task: Array(synthesized.task.prefix(maxContextItems.task)),
            domain: Array(synthesized.domain.prefix(maxContextItems.domain)),
            personalization: Array(synthesized.personalization.prefix(maxContextItems.personalization)),
            environmental: Array(synthesized.environmental.prefix(maxContextItems.environmental)),
            personalityAdaptations: extractPersonalityAdaptations(synthesized),
            communicationStyle: extractCommunicationStyle(synthesized),
            cognitiveAdaptations: extractCognitiveAdaptations(synthesized),
            workflowPreferences: extractWorkflowPreferences(synthesized)
        )
    }
    
    private func generateContextMetadata(
        request: UserRequest,
        buildTime: TimeInterval,
        sources: ContextSources
    ) -> ContextMetadata {
        
        return ContextMetadata(
            buildTime: buildTime,
            sources: sources,
            requestComplexity: calculateRequestComplexity(request),
            cacheUtilization: calculateCacheUtilization(),
            optimizations: getAppliedOptimizations(),
            version: "1.0"
        )
    }
    
    private func generateCacheKey(for request: UserRequest) -> String {
        // Generate a cache key based on request characteristics
        let requestHash = request.text.hash
        return "context_\(requestHash)_\(request.type.rawValue)"
    }
    
    private func cleanupContextCache() async {
        let now = Date()
        let expiredKeys = contextCache.compactMap { key, value in
            now.timeIntervalSince(value.timestamp) > configuration.cacheTimeout ? key : nil
        }
        
        for key in expiredKeys {
            contextCache.removeValue(forKey: key)
        }
        
        if expiredKeys.count > 0 {
            logger.debug("Cleaned up \(expiredKeys.count) expired context cache entries")
        }
    }
    
    // Helper methods with simplified implementations
    private func analyzeRequest(_ request: UserRequest) -> RequestAnalysis {
        return RequestAnalysis(
            complexity: Double(request.text.count) / 1000.0,
            intent: .informational,
            domain: "general",
            urgency: 0.5
        )
    }
    
    private func calculateMemoryRelevance(request: UserRequest, episodic: [EpisodicMemoryEntry], semantic: [SemanticKnowledgeItem], procedural: [ProceduralPattern]) -> MemoryRelevanceScores {
        return MemoryRelevanceScores(
            episodic: Double(episodic.count) / 10.0,
            semantic: Double(semantic.count) / 15.0,
            procedural: Double(procedural.count) / 5.0
        )
    }
    
    private func calculateUserAlignment(_ request: UserRequest, profile: UserProfile) -> Double { 0.8 }
    private func identifyTaskType(_ request: UserRequest) -> String { "analysis" }
    private func formatExpertiseLevel(_ level: Double) -> String {
        switch level {
        case 0.8...: return "advanced"
        case 0.5...: return "intermediate"
        default: return "basic"
        }
    }
    
    private func extractPersonalityAdaptations(_ synthesized: SynthesizedContext) -> [String] {
        synthesized.personalization.filter { $0.contains("personality") || $0.contains("open") || $0.contains("creative") }
    }
    
    private func extractCommunicationStyle(_ synthesized: SynthesizedContext) -> [String] {
        synthesized.conversational.filter { $0.contains("communication") || $0.contains("formal") || $0.contains("concise") }
    }
    
    private func extractCognitiveAdaptations(_ synthesized: SynthesizedContext) -> [String] {
        synthesized.personalization.filter { $0.contains("learning") || $0.contains("visual") || $0.contains("detail") }
    }
    
    private func extractWorkflowPreferences(_ synthesized: SynthesizedContext) -> [String] {
        synthesized.task.filter { $0.contains("workflow") || $0.contains("pacing") || $0.contains("approach") }
    }
    
    private func calculateContextQuality(_ optimized: OptimizedContext) -> Double { 0.85 }
    private func calculateRelevanceScore(_ optimized: OptimizedContext, for request: UserRequest) -> Double { 0.9 }
    private func calculateConfidenceLevel(_ optimized: OptimizedContext, metadata: ContextMetadata) -> Double { 0.8 }
    private func calculateRequestComplexity(_ request: UserRequest) -> Double { Double(request.text.count) / 500.0 }
    private func calculateCacheUtilization() -> Double { 0.3 }
    private func getAppliedOptimizations() -> [String] { ["size_optimization", "relevance_filtering"] }
    
    // Analysis helper methods
    private func calculateContextCompleteness(_ context: AgenticContext) -> Double { 0.85 }
    private func calculatePersonalizationLevel(_ context: AgenticContext) -> Double { 0.8 }
    private func calculateContextCoherence(_ context: AgenticContext) -> Double { 0.9 }
    private func calculateContextUsability(_ context: AgenticContext) -> Double { 0.85 }
    private func identifyContextStrengths(_ context: AgenticContext) -> [String] { ["comprehensive", "personalized"] }
    private func identifyContextWeaknesses(_ context: AgenticContext) -> [String] { ["could_be_more_specific"] }
    private func generateContextRecommendations(_ context: AgenticContext) -> [String] { ["add_more_domain_context"] }
    private func calculateUserProfileUsage(_ context: AgenticContext) -> Double { 0.7 }
    private func calculateBuildEfficiency(_ context: AgenticContext) -> Double { context.buildDuration < 0.1 ? 0.9 : 0.7 }
}

// MARK: - Supporting Types

public struct ContextBuilderConfiguration: Sendable {
    public let cacheTimeout: TimeInterval
    public let maxContextItems: MaxContextItems
    public let optimizationLevel: ContextOptimizationLevel
    public let qualityThreshold: Double
    
    public static let `default` = ContextBuilderConfiguration(
        cacheTimeout: 300, // 5 minutes
        maxContextItems: MaxContextItems(
            conversational: 10,
            task: 8,
            domain: 12,
            personalization: 15,
            environmental: 5
        ),
        optimizationLevel: .balanced,
        qualityThreshold: 0.7
    )
}

public struct MaxContextItems: Sendable {
    public let conversational: Int
    public let task: Int
    public let domain: Int
    public let personalization: Int
    public let environmental: Int
}

public enum ContextOptimizationLevel: String, Sendable, CaseIterable {
    case minimal
    case balanced
    case comprehensive
}

public enum ContextUseCase: String, Sendable, CaseIterable {
    case quickResponse
    case deepAnalysis
    case creativeTasks
    case technicalTasks
    case collaborative
    case learning
}

public struct ContextEnrichment: Sendable {
    public let type: ContextEnrichmentType
    public let data: Any
    public let priority: Double
}

public enum ContextEnrichmentType: String, Sendable, CaseIterable {
    case additionalMemories
    case domainKnowledge
    case proceduralPatterns
    case userInsights
    case environmentalData
}

public struct AgenticContext: Sendable {
    public let id: String
    public let requestId: String
    public let userId: String
    public let timestamp: Date
    
    // Context sections
    public var conversationalContext: [String]
    public var taskContext: [String]
    public var domainContext: [String]
    public var userContext: [String]
    public var environmentalContext: [String]
    
    // Memory integration
    public var relevantHistory: [EpisodicMemoryEntry]
    public var relevantKnowledge: [SemanticKnowledgeItem]
    public var relevantPatterns: [ProceduralPattern]
    
    // User personalization
    public var personalityAdaptations: [String]
    public var communicationStyle: [String]
    public var cognitiveAdaptations: [String]
    public var workflowPreferences: [String]
    
    // Context quality
    public var contextQuality: Double
    public var relevanceScore: Double
    public var confidenceLevel: Double
    
    // Processing info
    public let buildDuration: TimeInterval
    public let cacheHit: Bool
    public let metadata: ContextMetadata
}

public struct ContextAnalysis: Sendable {
    public let contextId: String
    public let overallQuality: Double
    public let completeness: Double
    public let relevance: Double
    public let personalization: Double
    public let coherence: Double
    public let usability: Double
    public let strengths: [String]
    public let weaknesses: [String]
    public let recommendations: [String]
    public let memoryUtilization: MemoryUtilization
    public let buildEfficiency: Double
    public let analyzedAt: Date
}

public struct MemoryUtilization: Sendable {
    public let episodicUsage: Double
    public let semanticUsage: Double
    public let proceduralUsage: Double
    public let userProfileUsage: Double
}

// Internal types
private struct CoreContext {
    let requestAnalysis: RequestAnalysis
    let memoryRelevance: MemoryRelevanceScores
    let userAlignment: Double
}

private struct RequestAnalysis {
    let complexity: Double
    let intent: RequestIntent
    let domain: String
    let urgency: Double
}

private enum RequestIntent {
    case informational
    case procedural
    case creative
    case analytical
}

private struct MemoryRelevanceScores {
    let episodic: Double
    let semantic: Double
    let procedural: Double
}

private struct SynthesizedContext {
    let conversational: [String]
    let task: [String]
    let domain: [String]
    let personalization: [String]
    let environmental: [String]
    let coreInsights: CoreContext
}

private struct OptimizedContext {
    let conversational: [String]
    let task: [String]
    let domain: [String]
    let personalization: [String]
    let environmental: [String]
    let personalityAdaptations: [String]
    let communicationStyle: [String]
    let cognitiveAdaptations: [String]
    let workflowPreferences: [String]
}

public struct ContextSources: Sendable {
    public let episodicCount: Int
    public let semanticCount: Int
    public let proceduralCount: Int
    public let userProfileConfidence: Double
}

public struct ContextMetadata: Sendable {
    public let buildTime: TimeInterval
    public let sources: ContextSources
    public let requestComplexity: Double
    public let cacheUtilization: Double
    public let optimizations: [String]
    public let version: String
}

// MARK: - Async Lock

private actor AsyncLock {
    func withLock<T>(_ operation: () async throws -> T) async rethrows -> T {
        return try await operation()
    }
}