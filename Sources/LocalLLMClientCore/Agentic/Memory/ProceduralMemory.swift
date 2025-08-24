import Foundation
import CryptoKit
import OSLog

/// ProceduralMemory manages learned patterns, workflows, and behavioral templates
/// This component focuses on "how to do things" - procedural knowledge that improves over time
public class ProceduralMemory: Sendable {
    private let storage: ProceduralMemoryStorage
    private let logger = Logger(subsystem: "LocalLLMClientCore", category: "ProceduralMemory")
    private let lock = AsyncLock()
    
    private var patterns: [String: ProceduralPattern] = [:]
    private var workflows: [String: WorkflowTemplate] = [:]
    private var executionHistory: [String: [ExecutionRecord]] = [:]
    
    public init(configuration: ProceduralMemoryConfiguration = .default) async {
        self.storage = ProceduralMemoryStorage(configuration: configuration.storage)
        
        // Load existing patterns and workflows
        await loadFromStorage()
        
        logger.info("ProceduralMemory initialized with \(patterns.count) patterns and \(workflows.count) workflows")
    }
    
    // MARK: - Pattern Learning
    
    /// Learn a new procedural pattern from successful interactions
    public func learnPattern(from interaction: InteractionContext) async {
        await lock.withLock {
            let patternId = generatePatternId(from: interaction)
            
            if var existingPattern = patterns[patternId] {
                // Reinforce existing pattern
                existingPattern.reinforcement += 1
                existingPattern.lastUsed = Date()
                existingPattern.successRate = calculateSuccessRate(for: patternId)
                existingPattern.optimizations.append(contentsOf: extractOptimizations(from: interaction))
                patterns[patternId] = existingPattern
                
                logger.debug("Reinforced pattern: \(patternId)")
            } else {
                // Create new pattern
                let newPattern = ProceduralPattern(
                    id: patternId,
                    name: interaction.taskType,
                    description: generatePatternDescription(from: interaction),
                    steps: extractSteps(from: interaction),
                    conditions: extractConditions(from: interaction),
                    expectedOutcomes: extractOutcomes(from: interaction),
                    contextRequirements: extractContextRequirements(from: interaction),
                    toolsUsed: interaction.toolsUsed,
                    successMetrics: extractSuccessMetrics(from: interaction),
                    optimizations: extractOptimizations(from: interaction),
                    metadata: PatternMetadata(
                        createdAt: Date(),
                        lastUsed: Date(),
                        usageCount: 1,
                        reinforcement: 1,
                        successRate: 1.0,
                        complexity: calculateComplexity(from: interaction),
                        domain: extractDomain(from: interaction)
                    )
                )
                
                patterns[patternId] = newPattern
                logger.info("Learned new pattern: \(patternId)")
            }
            
            // Record execution
            recordExecution(patternId: patternId, interaction: interaction)
            
            // Persist to storage
            await storage.savePattern(patterns[patternId]!)
        }
    }
    
    /// Get relevant patterns for a given context
    public func getRelevantPatterns(for request: UserRequest, limit: Int = 5) async -> [ProceduralPattern] {
        return await lock.withLock {
            let requestVector = generateRequestVector(from: request)
            
            let scoredPatterns = patterns.values.compactMap { pattern -> (ProceduralPattern, Double)? in
                let relevanceScore = calculateRelevanceScore(pattern: pattern, requestVector: requestVector)
                return relevanceScore > 0.3 ? (pattern, relevanceScore) : nil
            }
            
            return scoredPatterns
                .sorted { $0.1 > $1.1 }
                .prefix(limit)
                .map { $0.0 }
        }
    }
    
    // MARK: - Workflow Management
    
    /// Learn a workflow template from successful multi-step interactions
    public func learnWorkflow(from interactions: [InteractionContext], name: String) async {
        await lock.withLock {
            let workflowId = generateWorkflowId(from: interactions, name: name)
            
            let workflow = WorkflowTemplate(
                id: workflowId,
                name: name,
                description: generateWorkflowDescription(from: interactions),
                steps: extractWorkflowSteps(from: interactions),
                dependencies: extractDependencies(from: interactions),
                parallelizable: analyzeParallelization(from: interactions),
                estimatedDuration: calculateEstimatedDuration(from: interactions),
                requiredTools: extractRequiredTools(from: interactions),
                contextFlow: analyzeContextFlow(from: interactions),
                errorHandling: extractErrorHandling(from: interactions),
                optimizationHints: extractWorkflowOptimizations(from: interactions),
                metadata: WorkflowMetadata(
                    createdAt: Date(),
                    lastUsed: Date(),
                    usageCount: 1,
                    successRate: 1.0,
                    averageDuration: calculateEstimatedDuration(from: interactions),
                    complexity: calculateWorkflowComplexity(from: interactions)
                )
            )
            
            workflows[workflowId] = workflow
            logger.info("Learned new workflow: \(name)")
            
            // Persist to storage
            await storage.saveWorkflow(workflow)
        }
    }
    
    /// Get relevant workflows for a given task
    public func getRelevantWorkflows(for task: TaskContext, limit: Int = 3) async -> [WorkflowTemplate] {
        return await lock.withLock {
            let taskVector = generateTaskVector(from: task)
            
            let scoredWorkflows = workflows.values.compactMap { workflow -> (WorkflowTemplate, Double)? in
                let relevanceScore = calculateWorkflowRelevance(workflow: workflow, taskVector: taskVector)
                return relevanceScore > 0.4 ? (workflow, relevanceScore) : nil
            }
            
            return scoredWorkflows
                .sorted { $0.1 > $1.1 }
                .prefix(limit)
                .map { $0.0 }
        }
    }
    
    // MARK: - Pattern Analysis
    
    /// Analyze patterns to identify optimization opportunities
    public func analyzePatterns() async -> PatternAnalysis {
        return await lock.withLock {
            let totalPatterns = patterns.count
            let totalWorkflows = workflows.count
            
            let highPerformingPatterns = patterns.values.filter { $0.metadata.successRate > 0.8 }
            let underperformingPatterns = patterns.values.filter { $0.metadata.successRate < 0.5 }
            
            let mostUsedPatterns = patterns.values
                .sorted { $0.metadata.usageCount > $1.metadata.usageCount }
                .prefix(10)
                .map { $0 }
            
            let recentPatterns = patterns.values
                .filter { Date().timeIntervalSince($0.metadata.createdAt) < 86400 * 7 } // Last 7 days
                .sorted { $0.metadata.createdAt > $1.metadata.createdAt }
            
            let domainDistribution = Dictionary(grouping: patterns.values) { $0.metadata.domain }
                .mapValues { $0.count }
            
            let optimizationOpportunities = identifyOptimizationOpportunities()
            
            return PatternAnalysis(
                totalPatterns: totalPatterns,
                totalWorkflows: totalWorkflows,
                averageSuccessRate: patterns.values.map { $0.metadata.successRate }.reduce(0, +) / Double(totalPatterns),
                highPerformingPatterns: Array(highPerformingPatterns),
                underperformingPatterns: Array(underperformingPatterns),
                mostUsedPatterns: Array(mostUsedPatterns),
                recentPatterns: Array(recentPatterns),
                domainDistribution: domainDistribution,
                optimizationOpportunities: optimizationOpportunities
            )
        }
    }
    
    // MARK: - Memory Consolidation
    
    /// Consolidate and optimize procedural memory
    public func consolidateMemory() async {
        await lock.withLock {
            logger.info("Starting procedural memory consolidation")
            
            // Remove rarely used patterns
            let cutoffDate = Date().addingTimeInterval(-86400 * 30) // 30 days ago
            let initialCount = patterns.count
            
            patterns = patterns.filter { _, pattern in
                pattern.metadata.lastUsed > cutoffDate || pattern.metadata.usageCount > 5
            }
            
            // Merge similar patterns
            await mergeSimilarPatterns()
            
            // Optimize workflow templates
            await optimizeWorkflows()
            
            // Clean up execution history
            await cleanupExecutionHistory()
            
            let finalCount = patterns.count
            logger.info("Consolidated procedural memory: \(initialCount) -> \(finalCount) patterns")
            
            // Persist changes
            await storage.saveAllPatterns(Array(patterns.values))
            await storage.saveAllWorkflows(Array(workflows.values))
        }
    }
    
    // MARK: - Private Implementation
    
    private func loadFromStorage() async {
        do {
            let loadedPatterns = await storage.loadAllPatterns()
            let loadedWorkflows = await storage.loadAllWorkflows()
            
            for pattern in loadedPatterns {
                patterns[pattern.id] = pattern
            }
            
            for workflow in loadedWorkflows {
                workflows[workflow.id] = workflow
            }
            
            logger.info("Loaded \(patterns.count) patterns and \(workflows.count) workflows from storage")
        } catch {
            logger.error("Failed to load from storage: \(error)")
        }
    }
    
    private func generatePatternId(from interaction: InteractionContext) -> String {
        let components = [
            interaction.taskType,
            interaction.toolsUsed.joined(separator: ","),
            String(interaction.steps.count)
        ].joined(separator: "_")
        
        return SHA256.hash(data: components.data(using: .utf8) ?? Data())
            .compactMap { String(format: "%02x", $0) }
            .joined()
            .prefix(16)
            .description
    }
    
    private func generateRequestVector(from request: UserRequest) -> [Double] {
        // Simplified vector generation - in production this would use embeddings
        let features: [Double] = [
            Double(request.text.count) / 1000.0,
            request.text.contains("analyze") ? 1.0 : 0.0,
            request.text.contains("create") ? 1.0 : 0.0,
            request.text.contains("fix") ? 1.0 : 0.0,
            request.text.contains("optimize") ? 1.0 : 0.0
        ]
        return features
    }
    
    private func calculateRelevanceScore(pattern: ProceduralPattern, requestVector: [Double]) -> Double {
        // Simplified relevance calculation
        let baseScore = pattern.metadata.successRate * 0.4
        let usageScore = min(Double(pattern.metadata.usageCount) / 100.0, 1.0) * 0.3
        let recencyScore = max(0.0, 1.0 - Date().timeIntervalSince(pattern.metadata.lastUsed) / 86400) * 0.3
        
        return baseScore + usageScore + recencyScore
    }
    
    private func generatePatternDescription(from interaction: InteractionContext) -> String {
        return "Pattern for \(interaction.taskType) involving \(interaction.steps.count) steps"
    }
    
    private func extractSteps(from interaction: InteractionContext) -> [PatternStep] {
        return interaction.steps.enumerated().map { index, step in
            PatternStep(
                order: index,
                action: step.action,
                description: step.description,
                toolRequired: step.toolRequired,
                expectedDuration: step.duration,
                criticalityLevel: step.criticalityLevel,
                errorRecovery: step.errorRecovery
            )
        }
    }
    
    private func extractConditions(from interaction: InteractionContext) -> [PatternCondition] {
        return interaction.conditions.map { condition in
            PatternCondition(
                type: condition.type,
                expression: condition.expression,
                description: condition.description,
                importance: condition.importance
            )
        }
    }
    
    private func extractOutcomes(from interaction: InteractionContext) -> [PatternOutcome] {
        return interaction.outcomes.map { outcome in
            PatternOutcome(
                type: outcome.type,
                description: outcome.description,
                probability: outcome.probability,
                measurable: outcome.measurable
            )
        }
    }
    
    private func extractContextRequirements(from interaction: InteractionContext) -> [String] {
        return interaction.contextRequirements
    }
    
    private func extractSuccessMetrics(from interaction: InteractionContext) -> [SuccessMetric] {
        return interaction.successMetrics.map { metric in
            SuccessMetric(
                name: metric.name,
                type: metric.type,
                target: metric.target,
                weight: metric.weight
            )
        }
    }
    
    private func extractOptimizations(from interaction: InteractionContext) -> [PatternOptimization] {
        return interaction.optimizations.map { opt in
            PatternOptimization(
                type: opt.type,
                description: opt.description,
                impact: opt.impact,
                difficulty: opt.difficulty
            )
        }
    }
    
    private func calculateComplexity(from interaction: InteractionContext) -> Double {
        let stepComplexity = Double(interaction.steps.count) / 20.0
        let toolComplexity = Double(interaction.toolsUsed.count) / 10.0
        let conditionComplexity = Double(interaction.conditions.count) / 5.0
        
        return min(1.0, (stepComplexity + toolComplexity + conditionComplexity) / 3.0)
    }
    
    private func extractDomain(from interaction: InteractionContext) -> String {
        // Simplified domain extraction
        if interaction.toolsUsed.contains(where: { $0.contains("code") || $0.contains("build") }) {
            return "development"
        } else if interaction.toolsUsed.contains(where: { $0.contains("analyze") || $0.contains("data") }) {
            return "analysis"
        } else if interaction.toolsUsed.contains(where: { $0.contains("write") || $0.contains("create") }) {
            return "creative"
        } else {
            return "general"
        }
    }
    
    private func recordExecution(patternId: String, interaction: InteractionContext) {
        let record = ExecutionRecord(
            timestamp: Date(),
            patternId: patternId,
            success: interaction.success,
            duration: interaction.duration,
            toolsUsed: interaction.toolsUsed,
            contextHash: interaction.contextHash
        )
        
        if executionHistory[patternId] == nil {
            executionHistory[patternId] = []
        }
        
        executionHistory[patternId]?.append(record)
        
        // Keep only recent records
        let cutoffDate = Date().addingTimeInterval(-86400 * 7) // 7 days
        executionHistory[patternId] = executionHistory[patternId]?.filter { $0.timestamp > cutoffDate }
    }
    
    private func calculateSuccessRate(for patternId: String) -> Double {
        guard let records = executionHistory[patternId], !records.isEmpty else { return 1.0 }
        
        let successCount = records.filter { $0.success }.count
        return Double(successCount) / Double(records.count)
    }
    
    private func mergeSimilarPatterns() async {
        // Implementation for merging similar patterns based on similarity threshold
        // This would analyze pattern similarity and merge highly similar ones
    }
    
    private func optimizeWorkflows() async {
        // Implementation for workflow optimization
        // This would analyze workflow performance and suggest improvements
    }
    
    private func cleanupExecutionHistory() async {
        let cutoffDate = Date().addingTimeInterval(-86400 * 14) // 14 days
        
        for (patternId, records) in executionHistory {
            let filteredRecords = records.filter { $0.timestamp > cutoffDate }
            
            if filteredRecords.isEmpty {
                executionHistory.removeValue(forKey: patternId)
            } else {
                executionHistory[patternId] = filteredRecords
            }
        }
    }
    
    private func identifyOptimizationOpportunities() -> [OptimizationOpportunity] {
        var opportunities: [OptimizationOpportunity] = []
        
        // Find underperforming patterns
        for pattern in patterns.values where pattern.metadata.successRate < 0.7 && pattern.metadata.usageCount > 5 {
            opportunities.append(OptimizationOpportunity(
                type: .patternOptimization,
                description: "Pattern '\(pattern.name)' has low success rate (\(String(format: "%.1f", pattern.metadata.successRate * 100))%)",
                impact: .high,
                difficulty: .medium,
                estimatedImprovement: 0.3
            ))
        }
        
        return opportunities
    }
    
    // Placeholder methods for workflow operations
    private func generateWorkflowId(from interactions: [InteractionContext], name: String) -> String {
        return UUID().uuidString
    }
    
    private func generateWorkflowDescription(from interactions: [InteractionContext]) -> String {
        return "Workflow with \(interactions.count) interactions"
    }
    
    private func extractWorkflowSteps(from interactions: [InteractionContext]) -> [WorkflowStep] {
        return interactions.enumerated().map { index, interaction in
            WorkflowStep(
                order: index,
                name: interaction.taskType,
                description: "Step \(index + 1): \(interaction.taskType)",
                estimatedDuration: interaction.duration,
                dependencies: [],
                parallelizable: false
            )
        }
    }
    
    private func extractDependencies(from interactions: [InteractionContext]) -> [WorkflowDependency] {
        return []
    }
    
    private func analyzeParallelization(from interactions: [InteractionContext]) -> [String] {
        return []
    }
    
    private func calculateEstimatedDuration(from interactions: [InteractionContext]) -> TimeInterval {
        return interactions.reduce(0) { $0 + $1.duration }
    }
    
    private func extractRequiredTools(from interactions: [InteractionContext]) -> Set<String> {
        return Set(interactions.flatMap { $0.toolsUsed })
    }
    
    private func analyzeContextFlow(from interactions: [InteractionContext]) -> [ContextTransition] {
        return []
    }
    
    private func extractErrorHandling(from interactions: [InteractionContext]) -> [ErrorHandler] {
        return []
    }
    
    private func extractWorkflowOptimizations(from interactions: [InteractionContext]) -> [WorkflowOptimization] {
        return []
    }
    
    private func calculateWorkflowComplexity(from interactions: [InteractionContext]) -> Double {
        return Double(interactions.count) / 10.0
    }
    
    private func generateTaskVector(from task: TaskContext) -> [Double] {
        return [1.0, 0.0, 0.0]
    }
    
    private func calculateWorkflowRelevance(workflow: WorkflowTemplate, taskVector: [Double]) -> Double {
        return workflow.metadata.successRate * 0.8
    }
}

// MARK: - Supporting Types

public struct ProceduralMemoryConfiguration: Sendable {
    public let storage: ProceduralMemoryStorageConfiguration
    public let consolidationInterval: TimeInterval
    public let maxPatterns: Int
    public let maxWorkflows: Int
    
    public static let `default` = ProceduralMemoryConfiguration(
        storage: .default,
        consolidationInterval: 3600, // 1 hour
        maxPatterns: 10000,
        maxWorkflows: 1000
    )
}

public struct ProceduralPattern: Sendable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let steps: [PatternStep]
    public let conditions: [PatternCondition]
    public let expectedOutcomes: [PatternOutcome]
    public let contextRequirements: [String]
    public let toolsUsed: [String]
    public let successMetrics: [SuccessMetric]
    public var optimizations: [PatternOptimization]
    public var metadata: PatternMetadata
}

public struct PatternStep: Sendable, Codable {
    public let order: Int
    public let action: String
    public let description: String
    public let toolRequired: String?
    public let expectedDuration: TimeInterval
    public let criticalityLevel: Double
    public let errorRecovery: String?
}

public struct PatternCondition: Sendable, Codable {
    public let type: String
    public let expression: String
    public let description: String
    public let importance: Double
}

public struct PatternOutcome: Sendable, Codable {
    public let type: String
    public let description: String
    public let probability: Double
    public let measurable: Bool
}

public struct SuccessMetric: Sendable, Codable {
    public let name: String
    public let type: String
    public let target: Double
    public let weight: Double
}

public struct PatternOptimization: Sendable, Codable {
    public let type: String
    public let description: String
    public let impact: OptimizationImpact
    public let difficulty: OptimizationDifficulty
}

public struct PatternMetadata: Sendable, Codable {
    public let createdAt: Date
    public var lastUsed: Date
    public var usageCount: Int
    public var reinforcement: Int
    public var successRate: Double
    public let complexity: Double
    public let domain: String
}

public struct WorkflowTemplate: Sendable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let steps: [WorkflowStep]
    public let dependencies: [WorkflowDependency]
    public let parallelizable: [String]
    public let estimatedDuration: TimeInterval
    public let requiredTools: Set<String>
    public let contextFlow: [ContextTransition]
    public let errorHandling: [ErrorHandler]
    public let optimizationHints: [WorkflowOptimization]
    public var metadata: WorkflowMetadata
}

public struct WorkflowStep: Sendable, Codable {
    public let order: Int
    public let name: String
    public let description: String
    public let estimatedDuration: TimeInterval
    public let dependencies: [String]
    public let parallelizable: Bool
}

public struct WorkflowDependency: Sendable, Codable {
    public let from: String
    public let to: String
    public let type: String
    public let required: Bool
}

public struct ContextTransition: Sendable, Codable {
    public let from: String
    public let to: String
    public let transformation: String
}

public struct ErrorHandler: Sendable, Codable {
    public let errorType: String
    public let recoveryStrategy: String
    public let rollbackSteps: [String]
}

public struct WorkflowOptimization: Sendable, Codable {
    public let type: String
    public let description: String
    public let estimatedImprovement: Double
}

public struct WorkflowMetadata: Sendable, Codable {
    public let createdAt: Date
    public var lastUsed: Date
    public var usageCount: Int
    public var successRate: Double
    public let averageDuration: TimeInterval
    public let complexity: Double
}

public struct PatternAnalysis: Sendable {
    public let totalPatterns: Int
    public let totalWorkflows: Int
    public let averageSuccessRate: Double
    public let highPerformingPatterns: [ProceduralPattern]
    public let underperformingPatterns: [ProceduralPattern]
    public let mostUsedPatterns: [ProceduralPattern]
    public let recentPatterns: [ProceduralPattern]
    public let domainDistribution: [String: Int]
    public let optimizationOpportunities: [OptimizationOpportunity]
}

public struct OptimizationOpportunity: Sendable {
    public let type: OptimizationType
    public let description: String
    public let impact: OptimizationImpact
    public let difficulty: OptimizationDifficulty
    public let estimatedImprovement: Double
}

public enum OptimizationType: String, Sendable, Codable {
    case patternOptimization
    case workflowOptimization
    case toolOptimization
    case contextOptimization
}

public enum OptimizationImpact: String, Sendable, Codable {
    case low
    case medium
    case high
}

public enum OptimizationDifficulty: String, Sendable, Codable {
    case low
    case medium
    case high
}

public struct ExecutionRecord: Sendable {
    public let timestamp: Date
    public let patternId: String
    public let success: Bool
    public let duration: TimeInterval
    public let toolsUsed: [String]
    public let contextHash: String
}

// Context types
public struct InteractionContext: Sendable {
    public let taskType: String
    public let steps: [InteractionStep]
    public let toolsUsed: [String]
    public let conditions: [InteractionCondition]
    public let outcomes: [InteractionOutcome]
    public let contextRequirements: [String]
    public let successMetrics: [InteractionMetric]
    public let optimizations: [InteractionOptimization]
    public let success: Bool
    public let duration: TimeInterval
    public let contextHash: String
}

public struct InteractionStep: Sendable {
    public let action: String
    public let description: String
    public let toolRequired: String?
    public let duration: TimeInterval
    public let criticalityLevel: Double
    public let errorRecovery: String?
}

public struct InteractionCondition: Sendable {
    public let type: String
    public let expression: String
    public let description: String
    public let importance: Double
}

public struct InteractionOutcome: Sendable {
    public let type: String
    public let description: String
    public let probability: Double
    public let measurable: Bool
}

public struct InteractionMetric: Sendable {
    public let name: String
    public let type: String
    public let target: Double
    public let weight: Double
}

public struct InteractionOptimization: Sendable {
    public let type: String
    public let description: String
    public let impact: OptimizationImpact
    public let difficulty: OptimizationDifficulty
}

public struct TaskContext: Sendable {
    public let description: String
    public let requirements: [String]
    public let constraints: [String]
    public let expectedOutcomes: [String]
}

// MARK: - Storage

public class ProceduralMemoryStorage: Sendable {
    private let configuration: ProceduralMemoryStorageConfiguration
    
    public init(configuration: ProceduralMemoryStorageConfiguration) {
        self.configuration = configuration
    }
    
    public func savePattern(_ pattern: ProceduralPattern) async {
        // Implementation for saving pattern to persistent storage
    }
    
    public func saveWorkflow(_ workflow: WorkflowTemplate) async {
        // Implementation for saving workflow to persistent storage
    }
    
    public func loadAllPatterns() async -> [ProceduralPattern] {
        // Implementation for loading patterns from persistent storage
        return []
    }
    
    public func loadAllWorkflows() async -> [WorkflowTemplate] {
        // Implementation for loading workflows from persistent storage
        return []
    }
    
    public func saveAllPatterns(_ patterns: [ProceduralPattern]) async {
        // Implementation for bulk saving patterns
    }
    
    public func saveAllWorkflows(_ workflows: [WorkflowTemplate]) async {
        // Implementation for bulk saving workflows
    }
}

public struct ProceduralMemoryStorageConfiguration: Sendable {
    public let persistToDisk: Bool
    public let storageDirectory: String
    public let compressionEnabled: Bool
    
    public static let `default` = ProceduralMemoryStorageConfiguration(
        persistToDisk: true,
        storageDirectory: ".toke/procedural_memory",
        compressionEnabled: true
    )
}

// MARK: - Async Lock

private actor AsyncLock {
    func withLock<T>(_ operation: () async throws -> T) async rethrows -> T {
        return try await operation()
    }
}