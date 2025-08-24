import Foundation

// MARK: - Core Request/Response Types

/// Represents a user request with full context
public struct UserRequest: Codable, Sendable, Hashable {
    public let id: String
    public let text: String
    public let context: RequestContext?
    public let timestamp: Date
    public let priority: RequestPriority
    public let metadata: [String: String]
    
    public init(
        id: String = UUID().uuidString,
        text: String,
        context: RequestContext? = nil,
        timestamp: Date = Date(),
        priority: RequestPriority = .normal,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.text = text
        self.context = context
        self.timestamp = timestamp
        self.priority = priority
        self.metadata = metadata
    }
}

public struct RequestContext: Codable, Sendable, Hashable {
    public let conversationHistory: [ConversationMessage]
    public let activeTools: [String]
    public let userPreferences: UserPreferences
    public let environmentContext: EnvironmentContext
    public let description: String
    
    public init(
        conversationHistory: [ConversationMessage] = [],
        activeTools: [String] = [],
        userPreferences: UserPreferences = UserPreferences(),
        environmentContext: EnvironmentContext = EnvironmentContext(),
        description: String = ""
    ) {
        self.conversationHistory = conversationHistory
        self.activeTools = activeTools
        self.userPreferences = userPreferences
        self.environmentContext = environmentContext
        self.description = description
    }
}

public enum RequestPriority: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
}

/// Comprehensive agentic response
public struct AgenticResponse: Codable, Sendable {
    public let id: String
    public let text: String
    public let toolCalls: [AgenticToolCall]
    public let agentActions: [AgentAction]
    public let confidence: Double
    public let reasoning: String?
    public let suggestions: [Suggestion]
    public let timestamp: Date
    public let processingTime: TimeInterval
    public let metadata: [String: String]
    
    public init(
        id: String = UUID().uuidString,
        text: String,
        toolCalls: [AgenticToolCall] = [],
        agentActions: [AgentAction] = [],
        confidence: Double = 1.0,
        reasoning: String? = nil,
        suggestions: [Suggestion] = [],
        timestamp: Date = Date(),
        processingTime: TimeInterval = 0,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.text = text
        self.toolCalls = toolCalls
        self.agentActions = agentActions
        self.confidence = confidence
        self.reasoning = reasoning
        self.suggestions = suggestions
        self.timestamp = timestamp
        self.processingTime = processingTime
        self.metadata = metadata
    }
    
    /// Combine multiple responses into a single synthesized response
    public static func synthesize(_ responses: [AgenticResponse]) -> AgenticResponse {
        guard !responses.isEmpty else {
            return AgenticResponse(text: "No responses to synthesize")
        }
        
        if responses.count == 1 {
            return responses[0]
        }
        
        let combinedText = responses.map { $0.text }.joined(separator: "\n\n")
        let combinedToolCalls = responses.flatMap { $0.toolCalls }
        let combinedActions = responses.flatMap { $0.agentActions }
        let avgConfidence = responses.map { $0.confidence }.reduce(0, +) / Double(responses.count)
        let combinedSuggestions = responses.flatMap { $0.suggestions }
        let totalProcessingTime = responses.map { $0.processingTime }.reduce(0, +)
        
        return AgenticResponse(
            text: combinedText,
            toolCalls: combinedToolCalls,
            agentActions: combinedActions,
            confidence: avgConfidence,
            reasoning: "Synthesized from \(responses.count) agent responses",
            suggestions: combinedSuggestions,
            processingTime: totalProcessingTime
        )
    }
}

// MARK: - Agent System Types

public struct AgentID: Codable, Sendable, Hashable {
    public let id: String
    public let specialty: AgentSpecialty
    
    public init(id: String = UUID().uuidString, specialty: AgentSpecialty) {
        self.id = id
        self.specialty = specialty
    }
}

public struct AgentAction: Codable, Sendable {
    public let id: String
    public let agentID: AgentID
    public let action: ActionType
    public let parameters: [String: String]
    public let result: ActionResult?
    public let timestamp: Date
    
    public init(
        id: String = UUID().uuidString,
        agentID: AgentID,
        action: ActionType,
        parameters: [String: String] = [:],
        result: ActionResult? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.agentID = agentID
        self.action = action
        self.parameters = parameters
        self.result = result
        self.timestamp = timestamp
    }
}

public enum ActionType: String, Codable, CaseIterable {
    case toolExecution = "tool_execution"
    case dataAnalysis = "data_analysis"
    case codeGeneration = "code_generation"
    case research = "research"
    case planning = "planning"
    case communication = "communication"
    case automation = "automation"
}

public struct ActionResult: Codable, Sendable {
    public let success: Bool
    public let output: String
    public let error: String?
    public let metadata: [String: String]
    
    public init(
        success: Bool,
        output: String,
        error: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.success = success
        self.output = output
        self.error = error
        self.metadata = metadata
    }
}

// MARK: - Execution Planning Types

public struct ExecutionPlan: Codable, Sendable {
    public let id: String
    public let type: ExecutionType
    public let estimatedTime: TimeInterval
    public let requiredResources: [ResourceRequirement]
    public let riskLevel: RiskLevel
    public let steps: [ExecutionStep]
    
    public init(
        id: String = UUID().uuidString,
        type: ExecutionType,
        estimatedTime: TimeInterval,
        requiredResources: [ResourceRequirement] = [],
        riskLevel: RiskLevel = .low,
        steps: [ExecutionStep] = []
    ) {
        self.id = id
        self.type = type
        self.estimatedTime = estimatedTime
        self.requiredResources = requiredResources
        self.riskLevel = riskLevel
        self.steps = steps
    }
}

public enum ExecutionType: Codable, Sendable {
    case singleAgent(AgentID)
    case multiAgent(MultiAgentCoordination)
    case autonomous([AutonomousAction])
    case hybrid([ExecutionStep])
}

public struct MultiAgentCoordination: Codable, Sendable {
    public let agents: [AgentID]
    public let protocol: CollaborationProtocol
    public let coordination: CoordinationType
    public let conflictResolution: ConflictResolutionStrategy
    
    public init(
        agents: [AgentID],
        protocol: CollaborationProtocol,
        coordination: CoordinationType,
        conflictResolution: ConflictResolutionStrategy
    ) {
        self.agents = agents
        self.protocol = protocol
        self.coordination = coordination
        self.conflictResolution = conflictResolution
    }
}

public enum CoordinationType: String, Codable, CaseIterable {
    case sequential = "sequential"
    case parallel = "parallel"
    case hierarchical = "hierarchical"
    case pipeline = "pipeline"
}

public enum ConflictResolutionStrategy: String, Codable, CaseIterable {
    case consensus = "consensus"
    case majority = "majority"
    case expertise = "expertise"
    case user = "user"
}

public enum ExecutionStep: Codable, Sendable {
    case agentExecution(ExecutionPlan)
    case toolExecution(AgenticToolCall)
    case memoryQuery(MemoryQuery)
}

public enum RiskLevel: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

// MARK: - Tool System Types

public struct AgenticToolCall: Codable, Sendable {
    public let id: String
    public let toolName: String
    public let parameters: [String: String]
    public let expectation: ToolExpectation
    public let timeout: TimeInterval
    public let retryPolicy: RetryPolicy
    
    public init(
        id: String = UUID().uuidString,
        toolName: String,
        parameters: [String: String],
        expectation: ToolExpectation = .success,
        timeout: TimeInterval = 30,
        retryPolicy: RetryPolicy = .default
    ) {
        self.id = id
        self.toolName = toolName
        self.parameters = parameters
        self.expectation = expectation
        self.timeout = timeout
        self.retryPolicy = retryPolicy
    }
}

public enum ToolExpectation: String, Codable, CaseIterable {
    case success = "success"
    case mayFail = "may_fail"
    case experimental = "experimental"
}

public struct RetryPolicy: Codable, Sendable {
    public let maxRetries: Int
    public let backoffMultiplier: Double
    public let initialDelay: TimeInterval
    
    public init(maxRetries: Int = 3, backoffMultiplier: Double = 2.0, initialDelay: TimeInterval = 1.0) {
        self.maxRetries = maxRetries
        self.backoffMultiplier = backoffMultiplier
        self.initialDelay = initialDelay
    }
    
    public static let `default` = RetryPolicy()
    public static let aggressive = RetryPolicy(maxRetries: 5, backoffMultiplier: 1.5, initialDelay: 0.5)
    public static let conservative = RetryPolicy(maxRetries: 2, backoffMultiplier: 3.0, initialDelay: 2.0)
}

// MARK: - Memory System Types

public struct AgenticContext: Codable, Sendable {
    public let userProfile: UserProfile
    public let conversationContext: ConversationContext
    public let environmentContext: EnvironmentContext
    public let taskContext: TaskContext
    
    public init(
        userProfile: UserProfile = UserProfile(),
        conversationContext: ConversationContext = ConversationContext(),
        environmentContext: EnvironmentContext = EnvironmentContext(),
        taskContext: TaskContext = TaskContext()
    ) {
        self.userProfile = userProfile
        self.conversationContext = conversationContext
        self.environmentContext = environmentContext
        self.taskContext = taskContext
    }
}

public struct UserProfile: Codable, Sendable {
    public let preferences: UserPreferences
    public let expertise: [ExpertiseDomain]
    public let workPatterns: [WorkPattern]
    public let communicationStyle: CommunicationStyle
    
    public init(
        preferences: UserPreferences = UserPreferences(),
        expertise: [ExpertiseDomain] = [],
        workPatterns: [WorkPattern] = [],
        communicationStyle: CommunicationStyle = .balanced
    ) {
        self.preferences = preferences
        self.expertise = expertise
        self.workPatterns = workPatterns
        self.communicationStyle = communicationStyle
    }
}

public struct UserPreferences: Codable, Sendable, Hashable {
    public let verbosity: VerbosityLevel
    public let autonomyLevel: AutonomyLevel
    public let preferredTools: [String]
    public let workingHours: WorkingHours?
    
    public init(
        verbosity: VerbosityLevel = .balanced,
        autonomyLevel: AutonomyLevel = .moderate,
        preferredTools: [String] = [],
        workingHours: WorkingHours? = nil
    ) {
        self.verbosity = verbosity
        self.autonomyLevel = autonomyLevel
        self.preferredTools = preferredTools
        self.workingHours = workingHours
    }
}

public enum VerbosityLevel: String, Codable, CaseIterable {
    case minimal = "minimal"
    case concise = "concise"
    case balanced = "balanced"
    case detailed = "detailed"
    case comprehensive = "comprehensive"
}

public enum AutonomyLevel: String, Codable, CaseIterable {
    case manual = "manual"
    case assisted = "assisted"
    case moderate = "moderate"
    case autonomous = "autonomous"
    case full = "full"
}

public struct WorkingHours: Codable, Sendable, Hashable {
    public let startHour: Int
    public let endHour: Int
    public let timeZone: String
    public let workDays: Set<Int> // 1-7, Sunday = 1
    
    public init(startHour: Int, endHour: Int, timeZone: String, workDays: Set<Int>) {
        self.startHour = startHour
        self.endHour = endHour
        self.timeZone = timeZone
        self.workDays = workDays
    }
}

// MARK: - Conversation Types

public struct ConversationMessage: Codable, Sendable, Hashable {
    public let id: String
    public let role: MessageRole
    public let content: String
    public let timestamp: Date
    public let toolCalls: [String]
    public let metadata: [String: String]
    
    public init(
        id: String = UUID().uuidString,
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        toolCalls: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.toolCalls = toolCalls
        self.metadata = metadata
    }
}

public enum MessageRole: String, Codable, CaseIterable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    case tool = "tool"
}

public struct ConversationContext: Codable, Sendable {
    public let currentTopic: String?
    public let recentTopics: [String]
    public let conversationGoals: [String]
    public let unfinishedTasks: [String]
    
    public init(
        currentTopic: String? = nil,
        recentTopics: [String] = [],
        conversationGoals: [String] = [],
        unfinishedTasks: [String] = []
    ) {
        self.currentTopic = currentTopic
        self.recentTopics = recentTopics
        self.conversationGoals = conversationGoals
        self.unfinishedTasks = unfinishedTasks
    }
}

// MARK: - Environment and Task Context

public struct EnvironmentContext: Codable, Sendable, Hashable {
    public let platform: String
    public let deviceCapabilities: [String]
    public let networkStatus: String
    public let batteryLevel: Double?
    public let currentLocation: String?
    
    public init(
        platform: String = "unknown",
        deviceCapabilities: [String] = [],
        networkStatus: String = "unknown",
        batteryLevel: Double? = nil,
        currentLocation: String? = nil
    ) {
        self.platform = platform
        self.deviceCapabilities = deviceCapabilities
        self.networkStatus = networkStatus
        self.batteryLevel = batteryLevel
        self.currentLocation = currentLocation
    }
}

public struct TaskContext: Codable, Sendable {
    public let currentTasks: [Task]
    public let completedTasks: [Task]
    public let taskDependencies: [String: [String]]
    public let deadlines: [String: Date]
    
    public init(
        currentTasks: [Task] = [],
        completedTasks: [Task] = [],
        taskDependencies: [String: [String]] = [:],
        deadlines: [String: Date] = [:]
    ) {
        self.currentTasks = currentTasks
        self.completedTasks = completedTasks
        self.taskDependencies = taskDependencies
        self.deadlines = deadlines
    }
}

public struct Task: Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let priority: TaskPriority
    public let status: TaskStatus
    public let estimatedDuration: TimeInterval?
    public let requiredTools: [String]
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String,
        priority: TaskPriority = .normal,
        status: TaskStatus = .pending,
        estimatedDuration: TimeInterval? = nil,
        requiredTools: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.status = status
        self.estimatedDuration = estimatedDuration
        self.requiredTools = requiredTools
    }
}

public enum TaskPriority: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
}

public enum TaskStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case blocked = "blocked"
}

// MARK: - Autonomous Action Types

public struct AutonomousAction: Codable, Sendable {
    public let id: String
    public let type: AutonomousActionType
    public let description: String
    public let parameters: [String: String]
    public let riskLevel: RiskLevel
    public let requiresConfirmation: Bool
    public let estimatedImpact: String
    
    public init(
        id: String = UUID().uuidString,
        type: AutonomousActionType,
        description: String,
        parameters: [String: String] = [:],
        riskLevel: RiskLevel,
        requiresConfirmation: Bool,
        estimatedImpact: String
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.parameters = parameters
        self.riskLevel = riskLevel
        self.requiresConfirmation = requiresConfirmation
        self.estimatedImpact = estimatedImpact
    }
}

public enum AutonomousActionType: String, Codable, CaseIterable {
    case dataCollection = "data_collection"
    case backgroundProcessing = "background_processing"
    case proactiveSuggestion = "proactive_suggestion"
    case workflowOptimization = "workflow_optimization"
    case resourceManagement = "resource_management"
    case learning = "learning"
}

// MARK: - Resource Management Types

public struct ResourceRequirement: Codable, Sendable {
    public let type: ResourceType
    public let amount: Double
    public let unit: String
    public let priority: ResourcePriority
    
    public init(type: ResourceType, amount: Double, unit: String, priority: ResourcePriority) {
        self.type = type
        self.amount = amount
        self.unit = unit
        self.priority = priority
    }
}

public enum ResourceType: String, Codable, CaseIterable {
    case memory = "memory"
    case cpu = "cpu"
    case network = "network"
    case storage = "storage"
    case battery = "battery"
}

public enum ResourcePriority: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
}

// MARK: - Additional Supporting Types

public struct ExpertiseDomain: Codable, Sendable {
    public let domain: String
    public let level: ExpertiseLevel
    public let keywords: [String]
    
    public init(domain: String, level: ExpertiseLevel, keywords: [String] = []) {
        self.domain = domain
        self.level = level
        self.keywords = keywords
    }
}

public enum ExpertiseLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
}

public struct WorkPattern: Codable, Sendable {
    public let pattern: String
    public let frequency: Double
    public let timeOfDay: String
    public let associatedTools: [String]
    
    public init(pattern: String, frequency: Double, timeOfDay: String, associatedTools: [String]) {
        self.pattern = pattern
        self.frequency = frequency
        self.timeOfDay = timeOfDay
        self.associatedTools = associatedTools
    }
}

public enum CommunicationStyle: String, Codable, CaseIterable {
    case direct = "direct"
    case collaborative = "collaborative"
    case analytical = "analytical"
    case creative = "creative"
    case balanced = "balanced"
}

public struct Suggestion: Codable, Sendable {
    public let id: String
    public let type: SuggestionType
    public let title: String
    public let description: String
    public let confidence: Double
    public let priority: SuggestionPriority
    public let actionable: Bool
    
    public init(
        id: String = UUID().uuidString,
        type: SuggestionType,
        title: String,
        description: String,
        confidence: Double,
        priority: SuggestionPriority,
        actionable: Bool = true
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.confidence = confidence
        self.priority = priority
        self.actionable = actionable
    }
}

public enum SuggestionType: String, Codable, CaseIterable {
    case toolRecommendation = "tool_recommendation"
    case workflowImprovement = "workflow_improvement"
    case learningOpportunity = "learning_opportunity"
    case automation = "automation"
    case optimization = "optimization"
}

public enum SuggestionPriority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case immediate = "immediate"
}

// MARK: - Memory Query Types

public struct MemoryQuery: Codable, Sendable {
    public let type: MemoryQueryType
    public let parameters: [String: String]
    public let timeRange: TimeRange?
    public let resultLimit: Int
    
    public init(
        type: MemoryQueryType,
        parameters: [String: String] = [:],
        timeRange: TimeRange? = nil,
        resultLimit: Int = 10
    ) {
        self.type = type
        self.parameters = parameters
        self.timeRange = timeRange
        self.resultLimit = resultLimit
    }
}

public enum MemoryQueryType: String, Codable, CaseIterable {
    case episodic = "episodic"
    case semantic = "semantic"
    case procedural = "procedural"
    case contextual = "contextual"
}

public struct TimeRange: Codable, Sendable {
    public let start: Date
    public let end: Date
    
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
    
    public static func last(hours: Int) -> TimeRange {
        let end = Date()
        let start = end.addingTimeInterval(-TimeInterval(hours * 3600))
        return TimeRange(start: start, end: end)
    }
    
    public static func last(days: Int) -> TimeRange {
        let end = Date()
        let start = end.addingTimeInterval(-TimeInterval(days * 24 * 3600))
        return TimeRange(start: start, end: end)
    }
}