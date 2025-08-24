import Foundation
import MLX
import LocalLLMClientUtility

/// The central coordination system for all agentic capabilities
/// This is the "brain" that orchestrates prompt caching, tool learning, memory, and autonomous actions
@MainActor
public final class AgenticCore: ObservableObject, Sendable {
    
    // MARK: - Core Systems
    
    /// Advanced prompt caching with MLX optimization
    public let promptCache: AdvancedPromptCache
    
    /// Dynamic tool ecosystem with learning capabilities
    public let toolEcosystem: DynamicToolEcosystem
    
    /// Multi-layer memory system for perfect recall
    public private(set) var memorySystem: MultilayerMemory!
    
    /// Multi-agent orchestration for complex tasks
    public let agentOrchestrator: MultiAgentSystem
    
    /// Proactive intelligence for autonomous actions
    public let proactiveEngine: AutonomousAgent
    
    /// Security sandbox for safe execution
    public let securitySandbox: ExecutionSandbox
    
    /// Performance telemetry and monitoring
    public let telemetry: AgenticTelemetrySystem
    
    // MARK: - State Management
    
    @Published public private(set) var isInitialized = false
    @Published public private(set) var performanceMetrics = AgenticPerformanceMetrics()
    @Published public private(set) var activeAgents: Set<AgentID> = []
    
    private let configuration: AgenticConfiguration
    private let dataLayer: AgenticDataLayer
    
    // MARK: - Initialization
    
    public init(configuration: AgenticConfiguration = .default) {
        self.configuration = configuration
        self.dataLayer = AgenticDataLayer(configuration: configuration)
        
        // Initialize core systems
        self.promptCache = AdvancedPromptCache(
            maxMemorySize: configuration.cacheConfiguration.maxMemorySize,
            persistencePath: configuration.cacheConfiguration.persistencePath
        )
        
        self.toolEcosystem = DynamicToolEcosystem(
            dataLayer: dataLayer,
            securityLevel: configuration.securityConfiguration.toolSecurityLevel
        )
        
        // Memory system will be initialized asynchronously in initialize() method
        
        self.agentOrchestrator = MultiAgentSystem(
            maxConcurrentAgents: configuration.agentConfiguration.maxConcurrentAgents,
            collaborationProtocols: configuration.agentConfiguration.protocols
        )
        
        self.proactiveEngine = AutonomousAgent(
            permissionLevel: configuration.autonomyConfiguration.permissionLevel,
            backgroundProcessingEnabled: configuration.autonomyConfiguration.backgroundProcessing
        )
        
        self.securitySandbox = ExecutionSandbox(
            isolationLevel: configuration.securityConfiguration.isolationLevel,
            resourceLimits: configuration.securityConfiguration.resourceLimits
        )
        
        self.telemetry = AgenticTelemetrySystem(
            enabledMetrics: configuration.telemetryConfiguration.enabledMetrics,
            reportingInterval: configuration.telemetryConfiguration.reportingInterval
        )
    }
    
    // MARK: - Core Operations
    
    /// Initialize all agentic systems
    public func initialize() async throws {
        let initStart = Date()
        
        do {
            // Initialize systems in dependency order
            try await dataLayer.initialize()
            try await promptCache.initialize()
            try await toolEcosystem.initialize()
            // Initialize memory system
            self.memorySystem = await MultilayerMemory(
                episodicCapacity: configuration.memoryConfiguration.episodicCapacity,
                semanticCapacity: configuration.memoryConfiguration.semanticCapacity,
                workingMemorySize: configuration.memoryConfiguration.workingMemorySize,
                autoConsolidation: true,
                userId: "default_user" // Would be passed from session context
            )
            try await memorySystem.initialize()
            try await agentOrchestrator.initialize()
            try await proactiveEngine.initialize()
            try await securitySandbox.initialize()
            try await telemetry.initialize()
            
            // Cross-system integration
            try await setupSystemIntegrations()
            
            isInitialized = true
            
            let initTime = Date().timeIntervalSince(initStart)
            telemetry.recordMetric(.initializationTime, value: initTime)
            
            print("🚀 Toke Agentic Core initialized in \(String(format: "%.2f", initTime))s")
            
        } catch {
            print("❌ Failed to initialize Agentic Core: \(error)")
            throw AgenticError.initializationFailed(error)
        }
    }
    
    /// Process a user request through the complete agentic pipeline
    public func processRequest(_ request: UserRequest) async throws -> AgenticResponse {
        guard isInitialized else {
            throw AgenticError.notInitialized
        }
        
        let processStart = Date()
        
        // 1. Check prompt cache for similar requests
        if let cachedResponse = await promptCache.getCachedResponse(for: request) {
            telemetry.recordCacheHit()
            return cachedResponse
        }
        
        // 2. Load relevant context from memory
        let context = await memorySystem.buildContext(for: request)
        
        // 3. Determine if this requires multi-agent coordination
        let executionPlan = await agentOrchestrator.planExecution(request: request, context: context)
        
        // 4. Execute the plan
        let response = try await executeAgenticPlan(executionPlan)
        
        // 5. Learn from this interaction
        await learnFromInteraction(request: request, response: response, context: context)
        
        // 6. Cache the result for future use
        await promptCache.cacheResponse(request, response: response)
        
        let processingTime = Date().timeIntervalSince(processStart)
        telemetry.recordMetric(.requestProcessingTime, value: processingTime)
        
        return response
    }
    
    /// Learn new tools from conversation patterns
    public func learnToolFromConversation(_ messages: [ConversationMessage]) async throws -> LearnedTool? {
        return try await toolEcosystem.learnFromConversation(messages)
    }
    
    /// Get comprehensive system status
    public func getSystemStatus() -> AgenticSystemStatus {
        return AgenticSystemStatus(
            isInitialized: isInitialized,
            cacheStats: promptCache.getStats(),
            toolCount: toolEcosystem.getToolCount(),
            memoryUtilization: memorySystem.getUtilization(),
            activeAgentCount: activeAgents.count,
            performanceMetrics: performanceMetrics
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupSystemIntegrations() async throws {
        // Connect tool ecosystem to memory system
        toolEcosystem.setMemorySystem(memorySystem)
        
        // Connect proactive engine to all systems
        proactiveEngine.setToolEcosystem(toolEcosystem)
        proactiveEngine.setMemorySystem(memorySystem)
        proactiveEngine.setAgentOrchestrator(agentOrchestrator)
        
        // Connect agent orchestrator to execution systems
        agentOrchestrator.setToolEcosystem(toolEcosystem)
        agentOrchestrator.setSecuritySandbox(securitySandbox)
        
        // Connect telemetry to all systems
        telemetry.monitor(promptCache)
        telemetry.monitor(toolEcosystem)
        telemetry.monitor(memorySystem)
        telemetry.monitor(agentOrchestrator)
        telemetry.monitor(proactiveEngine)
    }
    
    private func executeAgenticPlan(_ plan: ExecutionPlan) async throws -> AgenticResponse {
        switch plan.type {
        case .singleAgent(let agentID):
            return try await executeSingleAgent(agentID, plan: plan)
            
        case .multiAgent(let coordination):
            return try await executeMultiAgent(coordination)
            
        case .autonomous(let actions):
            return try await executeAutonomous(actions)
            
        case .hybrid(let steps):
            return try await executeHybrid(steps)
        }
    }
    
    private func executeSingleAgent(_ agentID: AgentID, plan: ExecutionPlan) async throws -> AgenticResponse {
        activeAgents.insert(agentID)
        defer { activeAgents.remove(agentID) }
        
        return try await agentOrchestrator.executeAgent(agentID, with: plan)
    }
    
    private func executeMultiAgent(_ coordination: MultiAgentCoordination) async throws -> AgenticResponse {
        let agentIDs = Set(coordination.agents.map(\.id))
        activeAgents.formUnion(agentIDs)
        defer { activeAgents.subtract(agentIDs) }
        
        return try await agentOrchestrator.coordinateExecution(coordination)
    }
    
    private func executeAutonomous(_ actions: [AutonomousAction]) async throws -> AgenticResponse {
        return try await proactiveEngine.executeActions(actions)
    }
    
    private func executeHybrid(_ steps: [ExecutionStep]) async throws -> AgenticResponse {
        var responses: [AgenticResponse] = []
        
        for step in steps {
            let stepResponse = try await executeStep(step)
            responses.append(stepResponse)
        }
        
        return AgenticResponse.synthesize(responses)
    }
    
    private func executeStep(_ step: ExecutionStep) async throws -> AgenticResponse {
        switch step {
        case .agentExecution(let plan):
            return try await executeAgenticPlan(plan)
        case .toolExecution(let toolCall):
            return try await toolEcosystem.executeTool(toolCall)
        case .memoryQuery(let query):
            return try await memorySystem.query(query)
        }
    }
    
    private func learnFromInteraction(
        request: UserRequest,
        response: AgenticResponse,
        context: AgenticContext
    ) async {
        // Store in episodic memory
        await memorySystem.storeEpisode(
            request: request,
            response: response.text,
            context: context,
            timestamp: Date()
        )
        
        // Update user model
        await memorySystem.updateUserModel(from: request, response: response.text)
        
        // Learn tool patterns
        await toolEcosystem.analyzeForToolLearning(
            request: request,
            response: response
        )
        
        // Update proactive predictions
        await proactiveEngine.updatePredictions(
            from: request,
            response: response,
            context: context
        )
    }
}

// MARK: - Supporting Types

public struct AgenticPerformanceMetrics: Codable, Sendable {
    public var averageResponseTime: Double = 0
    public var cacheHitRate: Double = 0
    public var toolSuccessRate: Double = 0
    public var memoryUtilization: Double = 0
    public var autonomousActionCount: Int = 0
    public var userSatisfactionScore: Double = 0
    
    public init() {}
}

public enum AgenticError: Error, LocalizedError {
    case notInitialized
    case initializationFailed(Error)
    case executionFailed(String)
    case securityViolation(String)
    case resourceExhausted
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Agentic core is not initialized"
        case .initializationFailed(let error):
            return "Failed to initialize agentic core: \(error.localizedDescription)"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        case .securityViolation(let reason):
            return "Security violation: \(reason)"
        case .resourceExhausted:
            return "System resources exhausted"
        }
    }
}

public struct AgenticSystemStatus: Codable, Sendable {
    public let isInitialized: Bool
    public let cacheStats: CacheStats
    public let toolCount: Int
    public let memoryUtilization: Double
    public let activeAgentCount: Int
    public let performanceMetrics: AgenticPerformanceMetrics
    
    public init(
        isInitialized: Bool,
        cacheStats: CacheStats,
        toolCount: Int,
        memoryUtilization: Double,
        activeAgentCount: Int,
        performanceMetrics: AgenticPerformanceMetrics
    ) {
        self.isInitialized = isInitialized
        self.cacheStats = cacheStats
        self.toolCount = toolCount
        self.memoryUtilization = memoryUtilization
        self.activeAgentCount = activeAgentCount
        self.performanceMetrics = performanceMetrics
    }
}