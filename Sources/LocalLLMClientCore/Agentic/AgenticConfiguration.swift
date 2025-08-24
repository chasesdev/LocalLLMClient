import Foundation

/// Comprehensive configuration for all agentic systems
/// Designed for production deployment with sensible defaults and full customization
public struct AgenticConfiguration: Codable, Sendable {
    
    /// Cache system configuration
    public let cacheConfiguration: CacheConfiguration
    
    /// Tool learning and execution configuration
    public let toolConfiguration: ToolConfiguration
    
    /// Memory system configuration
    public let memoryConfiguration: MemoryConfiguration
    
    /// Multi-agent system configuration
    public let agentConfiguration: AgentConfiguration
    
    /// Autonomous action configuration
    public let autonomyConfiguration: AutonomyConfiguration
    
    /// Security and sandboxing configuration
    public let securityConfiguration: SecurityConfiguration
    
    /// Performance monitoring configuration
    public let telemetryConfiguration: TelemetryConfiguration
    
    public init(
        cacheConfiguration: CacheConfiguration = .default,
        toolConfiguration: ToolConfiguration = .default,
        memoryConfiguration: MemoryConfiguration = .default,
        agentConfiguration: AgentConfiguration = .default,
        autonomyConfiguration: AutonomyConfiguration = .default,
        securityConfiguration: SecurityConfiguration = .default,
        telemetryConfiguration: TelemetryConfiguration = .default
    ) {
        self.cacheConfiguration = cacheConfiguration
        self.toolConfiguration = toolConfiguration
        self.memoryConfiguration = memoryConfiguration
        self.agentConfiguration = agentConfiguration
        self.autonomyConfiguration = autonomyConfiguration
        self.securityConfiguration = securityConfiguration
        self.telemetryConfiguration = telemetryConfiguration
    }
}

// MARK: - Cache Configuration

public struct CacheConfiguration: Codable, Sendable {
    /// Maximum memory size for prompt cache (bytes)
    public let maxMemorySize: Int
    
    /// Disk persistence path for cached prompts
    public let persistencePath: URL
    
    /// Cache compression level (0-9, higher = more compression)
    public let compressionLevel: Int
    
    /// Maximum age for cached entries (seconds)
    public let maxAge: TimeInterval
    
    /// Enable semantic deduplication
    public let semanticDeduplication: Bool
    
    /// Similarity threshold for semantic matching (0-1)
    public let similarityThreshold: Double
    
    public init(
        maxMemorySize: Int = 512 * 1024 * 1024, // 512MB
        persistencePath: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("toke_cache"),
        compressionLevel: Int = 6,
        maxAge: TimeInterval = 24 * 60 * 60, // 24 hours
        semanticDeduplication: Bool = true,
        similarityThreshold: Double = 0.85
    ) {
        self.maxMemorySize = maxMemorySize
        self.persistencePath = persistencePath
        self.compressionLevel = compressionLevel
        self.maxAge = maxAge
        self.semanticDeduplication = semanticDeduplication
        self.similarityThreshold = similarityThreshold
    }
    
    public static let `default` = CacheConfiguration()
}

// MARK: - Tool Configuration

public struct ToolConfiguration: Codable, Sendable {
    /// Maximum number of tools that can be learned automatically
    public let maxLearnedTools: Int
    
    /// Enable automatic tool generation from conversations
    public let autoToolGeneration: Bool
    
    /// Security level for tool execution
    public let executionSecurityLevel: ToolSecurityLevel
    
    /// Timeout for tool execution (seconds)
    public let executionTimeout: TimeInterval
    
    /// Enable community tool sharing
    public let communitySharing: Bool
    
    /// API rate limits for external tool calls
    public let rateLimits: RateLimitConfiguration
    
    public init(
        maxLearnedTools: Int = 1000,
        autoToolGeneration: Bool = true,
        executionSecurityLevel: ToolSecurityLevel = .safe,
        executionTimeout: TimeInterval = 30,
        communitySharing: Bool = true,
        rateLimits: RateLimitConfiguration = .default
    ) {
        self.maxLearnedTools = maxLearnedTools
        self.autoToolGeneration = autoToolGeneration
        self.executionSecurityLevel = executionSecurityLevel
        self.executionTimeout = executionTimeout
        self.communitySharing = communitySharing
        self.rateLimits = rateLimits
    }
    
    public static let `default` = ToolConfiguration()
}

public enum ToolSecurityLevel: String, Codable, CaseIterable {
    case restricted  // Only pre-approved tools
    case safe        // Generated tools with safety checks
    case permissive  // All tools allowed with user confirmation
    case unrestricted // No restrictions (development only)
}

public struct RateLimitConfiguration: Codable, Sendable {
    public let requestsPerMinute: Int
    public let requestsPerHour: Int
    public let burstLimit: Int
    
    public init(
        requestsPerMinute: Int = 60,
        requestsPerHour: Int = 1000,
        burstLimit: Int = 10
    ) {
        self.requestsPerMinute = requestsPerMinute
        self.requestsPerHour = requestsPerHour
        self.burstLimit = burstLimit
    }
    
    public static let `default` = RateLimitConfiguration()
}

// MARK: - Memory Configuration

public struct MemoryConfiguration: Codable, Sendable {
    /// Maximum episodic memory entries
    public let episodicCapacity: Int
    
    /// Maximum semantic memory nodes
    public let semanticCapacity: Int
    
    /// Working memory size (active context)
    public let workingMemorySize: Int
    
    /// Enable automatic memory consolidation
    public let autoConsolidation: Bool
    
    /// Memory persistence interval (seconds)
    public let persistenceInterval: TimeInterval
    
    /// Enable user profile learning
    public let userProfileLearning: Bool
    
    public init(
        episodicCapacity: Int = 10000,
        semanticCapacity: Int = 50000,
        workingMemorySize: Int = 100,
        autoConsolidation: Bool = true,
        persistenceInterval: TimeInterval = 300, // 5 minutes
        userProfileLearning: Bool = true
    ) {
        self.episodicCapacity = episodicCapacity
        self.semanticCapacity = semanticCapacity
        self.workingMemorySize = workingMemorySize
        self.autoConsolidation = autoConsolidation
        self.persistenceInterval = persistenceInterval
        self.userProfileLearning = userProfileLearning
    }
    
    public static let `default` = MemoryConfiguration()
}

// MARK: - Agent Configuration

public struct AgentConfiguration: Codable, Sendable {
    /// Maximum concurrent agents
    public let maxConcurrentAgents: Int
    
    /// Available agent specialties
    public let availableSpecialties: [AgentSpecialty]
    
    /// Inter-agent collaboration protocols
    public let protocols: [CollaborationProtocol]
    
    /// Agent resource limits
    public let resourceLimits: AgentResourceLimits
    
    /// Enable dynamic agent creation
    public let dynamicAgentCreation: Bool
    
    public init(
        maxConcurrentAgents: Int = 5,
        availableSpecialties: [AgentSpecialty] = AgentSpecialty.allCases,
        protocols: [CollaborationProtocol] = CollaborationProtocol.allCases,
        resourceLimits: AgentResourceLimits = .default,
        dynamicAgentCreation: Bool = true
    ) {
        self.maxConcurrentAgents = maxConcurrentAgents
        self.availableSpecialties = availableSpecialties
        self.protocols = protocols
        self.resourceLimits = resourceLimits
        self.dynamicAgentCreation = dynamicAgentCreation
    }
    
    public static let `default` = AgentConfiguration()
}

public enum AgentSpecialty: String, Codable, CaseIterable {
    case coding = "coding"
    case research = "research"
    case creative = "creative"
    case analysis = "analysis"
    case automation = "automation"
    case communication = "communication"
    case planning = "planning"
}

public enum CollaborationProtocol: String, Codable, CaseIterable {
    case sequential = "sequential"
    case parallel = "parallel"
    case hierarchical = "hierarchical"
    case consensus = "consensus"
    case competition = "competition"
}

public struct AgentResourceLimits: Codable, Sendable {
    public let maxMemoryPerAgent: Int
    public let maxExecutionTime: TimeInterval
    public let maxToolCalls: Int
    
    public init(
        maxMemoryPerAgent: Int = 64 * 1024 * 1024, // 64MB
        maxExecutionTime: TimeInterval = 300, // 5 minutes
        maxToolCalls: Int = 50
    ) {
        self.maxMemoryPerAgent = maxMemoryPerAgent
        self.maxExecutionTime = maxExecutionTime
        self.maxToolCalls = maxToolCalls
    }
    
    public static let `default` = AgentResourceLimits()
}

// MARK: - Autonomy Configuration

public struct AutonomyConfiguration: Codable, Sendable {
    /// Level of autonomous permissions
    public let permissionLevel: AutonomyPermissionLevel
    
    /// Enable background processing
    public let backgroundProcessing: Bool
    
    /// Proactive suggestion threshold
    public let suggestionThreshold: Double
    
    /// Maximum autonomous actions per session
    public let maxAutonomousActions: Int
    
    /// Require confirmation for high-impact actions
    public let confirmHighImpactActions: Bool
    
    public init(
        permissionLevel: AutonomyPermissionLevel = .moderate,
        backgroundProcessing: Bool = true,
        suggestionThreshold: Double = 0.8,
        maxAutonomousActions: Int = 10,
        confirmHighImpactActions: Bool = true
    ) {
        self.permissionLevel = permissionLevel
        self.backgroundProcessing = backgroundProcessing
        self.suggestionThreshold = suggestionThreshold
        self.maxAutonomousActions = maxAutonomousActions
        self.confirmHighImpactActions = confirmHighImpactActions
    }
    
    public static let `default` = AutonomyConfiguration()
}

public enum AutonomyPermissionLevel: String, Codable, CaseIterable {
    case minimal     // Only basic suggestions
    case moderate    // Safe autonomous actions
    case extended    // Broader autonomous capabilities
    case full        // Maximum autonomy (expert users)
}

// MARK: - Security Configuration

public struct SecurityConfiguration: Codable, Sendable {
    /// Tool execution security level
    public let toolSecurityLevel: ToolSecurityLevel
    
    /// Sandbox isolation level
    public let isolationLevel: SandboxIsolationLevel
    
    /// Resource limits for tool execution
    public let resourceLimits: ExecutionResourceLimits
    
    /// Enable audit logging
    public let auditLogging: Bool
    
    /// Data encryption settings
    public let encryptionSettings: EncryptionSettings
    
    public init(
        toolSecurityLevel: ToolSecurityLevel = .safe,
        isolationLevel: SandboxIsolationLevel = .standard,
        resourceLimits: ExecutionResourceLimits = .default,
        auditLogging: Bool = true,
        encryptionSettings: EncryptionSettings = .default
    ) {
        self.toolSecurityLevel = toolSecurityLevel
        self.isolationLevel = isolationLevel
        self.resourceLimits = resourceLimits
        self.auditLogging = auditLogging
        self.encryptionSettings = encryptionSettings
    }
    
    public static let `default` = SecurityConfiguration()
}

public enum SandboxIsolationLevel: String, Codable, CaseIterable {
    case none        // No sandboxing
    case basic       // Basic process isolation
    case standard    // Standard containerization
    case strict      // Maximum isolation
}

public struct ExecutionResourceLimits: Codable, Sendable {
    public let maxMemory: Int
    public let maxCPUTime: TimeInterval
    public let maxNetworkRequests: Int
    public let maxFileOperations: Int
    
    public init(
        maxMemory: Int = 128 * 1024 * 1024, // 128MB
        maxCPUTime: TimeInterval = 10,
        maxNetworkRequests: Int = 100,
        maxFileOperations: Int = 50
    ) {
        self.maxMemory = maxMemory
        self.maxCPUTime = maxCPUTime
        self.maxNetworkRequests = maxNetworkRequests
        self.maxFileOperations = maxFileOperations
    }
    
    public static let `default` = ExecutionResourceLimits()
}

public struct EncryptionSettings: Codable, Sendable {
    public let encryptStoredData: Bool
    public let encryptInTransit: Bool
    public let keyRotationInterval: TimeInterval
    
    public init(
        encryptStoredData: Bool = true,
        encryptInTransit: Bool = true,
        keyRotationInterval: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    ) {
        self.encryptStoredData = encryptStoredData
        self.encryptInTransit = encryptInTransit
        self.keyRotationInterval = keyRotationInterval
    }
    
    public static let `default` = EncryptionSettings()
}

// MARK: - Telemetry Configuration

public struct TelemetryConfiguration: Codable, Sendable {
    /// Enabled performance metrics
    public let enabledMetrics: Set<TelemetryMetric>
    
    /// Reporting interval for metrics
    public let reportingInterval: TimeInterval
    
    /// Enable user analytics
    public let userAnalytics: Bool
    
    /// Enable performance profiling
    public let performanceProfiling: Bool
    
    /// Data retention period
    public let dataRetentionPeriod: TimeInterval
    
    public init(
        enabledMetrics: Set<TelemetryMetric> = Set(TelemetryMetric.allCases),
        reportingInterval: TimeInterval = 60, // 1 minute
        userAnalytics: Bool = true,
        performanceProfiling: Bool = true,
        dataRetentionPeriod: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    ) {
        self.enabledMetrics = enabledMetrics
        self.reportingInterval = reportingInterval
        self.userAnalytics = userAnalytics
        self.performanceProfiling = performanceProfiling
        self.dataRetentionPeriod = dataRetentionPeriod
    }
    
    public static let `default` = TelemetryConfiguration()
}

public enum TelemetryMetric: String, Codable, CaseIterable, Hashable {
    case responseTime = "response_time"
    case memoryUsage = "memory_usage"
    case cacheHitRate = "cache_hit_rate"
    case toolSuccessRate = "tool_success_rate"
    case agentUtilization = "agent_utilization"
    case userSatisfaction = "user_satisfaction"
    case autonomousActionCount = "autonomous_action_count"
    case initializationTime = "initialization_time"
    case requestProcessingTime = "request_processing_time"
    case errorRate = "error_rate"
}

// MARK: - Convenience Extensions

extension AgenticConfiguration {
    /// Production-ready configuration with optimal performance settings
    public static let production = AgenticConfiguration(
        cacheConfiguration: CacheConfiguration(
            maxMemorySize: 1024 * 1024 * 1024, // 1GB
            compressionLevel: 9,
            maxAge: 7 * 24 * 60 * 60 // 7 days
        ),
        memoryConfiguration: MemoryConfiguration(
            episodicCapacity: 50000,
            semanticCapacity: 100000
        ),
        securityConfiguration: SecurityConfiguration(
            isolationLevel: .standard,
            auditLogging: true
        )
    )
    
    /// Development configuration with relaxed security and extensive logging
    public static let development = AgenticConfiguration(
        securityConfiguration: SecurityConfiguration(
            toolSecurityLevel: .permissive,
            isolationLevel: .basic
        ),
        telemetryConfiguration: TelemetryConfiguration(
            performanceProfiling: true
        )
    )
    
    /// High-performance configuration for power users
    public static let performance = AgenticConfiguration(
        cacheConfiguration: CacheConfiguration(
            maxMemorySize: 2048 * 1024 * 1024, // 2GB
            semanticDeduplication: true
        ),
        agentConfiguration: AgentConfiguration(
            maxConcurrentAgents: 10
        ),
        autonomyConfiguration: AutonomyConfiguration(
            permissionLevel: .extended
        )
    )
}