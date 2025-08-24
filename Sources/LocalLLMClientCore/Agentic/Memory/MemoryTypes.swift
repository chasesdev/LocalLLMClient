import Foundation

// MARK: - User Profile Types

public struct UserProfile: Sendable, Codable {
    public let id: String
    public let createdAt: Date
    public var lastUpdated: Date
    public var interactionCount: Int
    
    // Core profile components
    public var demographics: UserDemographics
    public var preferences: [String: UserPreferenceValue]
    public var skillLevels: [String: Double]
    public var behaviorPatterns: [String: String]
    public var personalityTraits: PersonalityProfile
    public var cognitiveStyle: CognitiveStyle
    public var communicationStyle: CommunicationStyle
    public var workflowPreferences: WorkflowPreferences
    public var domainExpertise: [String: DomainExpertise]
    public var learningStyle: LearningStyle
    public var goals: [UserGoal]
    public var contextPreferences: [String: Any]
    public var privacySettings: PrivacySettings
    
    public init(
        id: String,
        createdAt: Date,
        lastUpdated: Date,
        interactionCount: Int,
        demographics: UserDemographics,
        preferences: [String: UserPreferenceValue],
        skillLevels: [String: Double],
        behaviorPatterns: [String: String],
        personalityTraits: PersonalityProfile,
        cognitiveStyle: CognitiveStyle,
        communicationStyle: CommunicationStyle,
        workflowPreferences: WorkflowPreferences,
        domainExpertise: [String: DomainExpertise],
        learningStyle: LearningStyle,
        goals: [UserGoal],
        contextPreferences: [String: Any],
        privacySettings: PrivacySettings
    ) {
        self.id = id
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.interactionCount = interactionCount
        self.demographics = demographics
        self.preferences = preferences
        self.skillLevels = skillLevels
        self.behaviorPatterns = behaviorPatterns
        self.personalityTraits = personalityTraits
        self.cognitiveStyle = cognitiveStyle
        self.communicationStyle = communicationStyle
        self.workflowPreferences = workflowPreferences
        self.domainExpertise = domainExpertise
        self.learningStyle = learningStyle
        self.goals = goals
        self.contextPreferences = contextPreferences
        self.privacySettings = privacySettings
    }
}

public struct UserDemographics: Sendable, Codable {
    public var timeZone: String?
    public var locale: String?
    public var professionalArea: String?
    public var experienceLevel: ExperienceLevel?
    
    public init(
        timeZone: String? = nil,
        locale: String? = nil,
        professionalArea: String? = nil,
        experienceLevel: ExperienceLevel? = nil
    ) {
        self.timeZone = timeZone
        self.locale = locale
        self.professionalArea = professionalArea
        self.experienceLevel = experienceLevel
    }
}

public enum ExperienceLevel: String, Sendable, Codable, CaseIterable {
    case beginner
    case intermediate
    case advanced
    case expert
}

public struct PersonalityProfile: Sendable, Codable {
    public var openness: Double
    public var conscientiousness: Double
    public var extraversion: Double
    public var agreeableness: Double
    public var neuroticism: Double
    public var confidence: Double
    
    public init(
        openness: Double = 0.5,
        conscientiousness: Double = 0.5,
        extraversion: Double = 0.5,
        agreeableness: Double = 0.5,
        neuroticism: Double = 0.5,
        confidence: Double = 0.3
    ) {
        self.openness = openness
        self.conscientiousness = conscientiousness
        self.extraversion = extraversion
        self.agreeableness = agreeableness
        self.neuroticism = neuroticism
        self.confidence = confidence
    }
}

public struct CognitiveStyle: Sendable, Codable {
    public var processingSpeed: Double
    public var detailOrientation: Double
    public var abstractThinking: Double
    public var systematicThinking: Double
    public var creativityLevel: Double
    public var confidence: Double
    
    public init(
        processingSpeed: Double = 0.5,
        detailOrientation: Double = 0.5,
        abstractThinking: Double = 0.5,
        systematicThinking: Double = 0.5,
        creativityLevel: Double = 0.5,
        confidence: Double = 0.3
    ) {
        self.processingSpeed = processingSpeed
        self.detailOrientation = detailOrientation
        self.abstractThinking = abstractThinking
        self.systematicThinking = systematicThinking
        self.creativityLevel = creativityLevel
        self.confidence = confidence
    }
}

public struct CommunicationStyle: Sendable, Codable {
    public var verbosity: Double
    public var directness: Double
    public var formalityLevel: Double
    public var technicalLanguage: Double
    public var emotionalExpression: Double
    public var confidence: Double
    
    public init(
        verbosity: Double = 0.5,
        directness: Double = 0.5,
        formalityLevel: Double = 0.5,
        technicalLanguage: Double = 0.5,
        emotionalExpression: Double = 0.5,
        confidence: Double = 0.3
    ) {
        self.verbosity = verbosity
        self.directness = directness
        self.formalityLevel = formalityLevel
        self.technicalLanguage = technicalLanguage
        self.emotionalExpression = emotionalExpression
        self.confidence = confidence
    }
}

public struct WorkflowPreferences: Sendable, Codable {
    public var preferredPacing: WorkflowPacing
    public var collaborationStyle: CollaborationStyle
    public var planningStyle: PlanningStyle
    public var feedbackFrequency: FeedbackFrequency
    public var errorTolerance: Double
    
    public init(
        preferredPacing: WorkflowPacing = .balanced,
        collaborationStyle: CollaborationStyle = .balanced,
        planningStyle: PlanningStyle = .balanced,
        feedbackFrequency: FeedbackFrequency = .regular,
        errorTolerance: Double = 0.5
    ) {
        self.preferredPacing = preferredPacing
        self.collaborationStyle = collaborationStyle
        self.planningStyle = planningStyle
        self.feedbackFrequency = feedbackFrequency
        self.errorTolerance = errorTolerance
    }
}

public enum WorkflowPacing: String, Sendable, Codable, CaseIterable {
    case methodical
    case balanced
    case efficient
    case rapid
}

public enum CollaborationStyle: String, Sendable, Codable, CaseIterable {
    case independent
    case balanced
    case collaborative
}

public enum PlanningStyle: String, Sendable, Codable, CaseIterable {
    case detailed
    case balanced
    case adaptive
}

public enum FeedbackFrequency: String, Sendable, Codable, CaseIterable {
    case minimal
    case regular
    case frequent
}

public struct DomainExpertise: Sendable, Codable {
    public let domain: String
    public var demonstratedLevel: Double
    public var confidence: Double
    public let firstDemonstrated: Date
    public var lastDemonstrated: Date
    public var demonstrationCount: Int
    public var keyAreas: [String]
    
    public init(
        domain: String,
        demonstratedLevel: Double,
        confidence: Double,
        firstDemonstrated: Date,
        lastDemonstrated: Date,
        demonstrationCount: Int,
        keyAreas: [String]
    ) {
        self.domain = domain
        self.demonstratedLevel = demonstratedLevel
        self.confidence = confidence
        self.firstDemonstrated = firstDemonstrated
        self.lastDemonstrated = lastDemonstrated
        self.demonstrationCount = demonstrationCount
        self.keyAreas = keyAreas
    }
}

public struct LearningStyle: Sendable, Codable {
    public var preferredModalities: [LearningModality]
    public var pacePreference: LearningPace
    public var feedbackPreference: LearningFeedback
    public var complexityPreference: ComplexityPreference
    public var examplePreference: ExamplePreference
    
    public init(
        preferredModalities: [LearningModality] = [.textual],
        pacePreference: LearningPace = .selfPaced,
        feedbackPreference: LearningFeedback = .immediate,
        complexityPreference: ComplexityPreference = .progressive,
        examplePreference: ExamplePreference = .concrete
    ) {
        self.preferredModalities = preferredModalities
        self.pacePreference = pacePreference
        self.feedbackPreference = feedbackPreference
        self.complexityPreference = complexityPreference
        self.examplePreference = examplePreference
    }
}

public enum LearningModality: String, Sendable, Codable, CaseIterable {
    case visual
    case textual
    case auditory
    case kinesthetic
    case interactive
}

public enum LearningPace: String, Sendable, Codable, CaseIterable {
    case structured
    case selfPaced
    case intensive
}

public enum LearningFeedback: String, Sendable, Codable, CaseIterable {
    case immediate
    case summary
    case periodic
}

public enum ComplexityPreference: String, Sendable, Codable, CaseIterable {
    case simple
    case progressive
    case comprehensive
}

public enum ExamplePreference: String, Sendable, Codable, CaseIterable {
    case concrete
    case abstract
    case mixed
}

public struct UserGoal: Sendable, Codable {
    public let id: String
    public let description: String
    public let category: GoalCategory
    public var priority: Double
    public var confidence: Double
    public let firstDetected: Date
    public var lastReinforced: Date
    public var reinforcementCount: Int
    public let estimatedTimeline: Timeline
    
    public init(
        id: String,
        description: String,
        category: GoalCategory,
        priority: Double,
        confidence: Double,
        firstDetected: Date,
        lastReinforced: Date,
        reinforcementCount: Int,
        estimatedTimeline: Timeline
    ) {
        self.id = id
        self.description = description
        self.category = category
        self.priority = priority
        self.confidence = confidence
        self.firstDetected = firstDetected
        self.lastReinforced = lastReinforced
        self.reinforcementCount = reinforcementCount
        self.estimatedTimeline = estimatedTimeline
    }
}

public enum GoalCategory: String, Sendable, Codable, CaseIterable {
    case skill
    case knowledge
    case productivity
    case creative
    case career
    case personal
}

public enum Timeline: String, Sendable, Codable, CaseIterable {
    case immediate
    case short
    case medium
    case long
}

public struct PrivacySettings: Sendable, Codable {
    public let dataRetentionDays: Int
    public let personalizeRecommendations: Bool
    public let storeConversationHistory: Bool
    public let shareAnonymousAnalytics: Bool
    public let rememberPreferences: Bool
    public let adaptCommunicationStyle: Bool
    
    public static let `default` = PrivacySettings(
        dataRetentionDays: 90,
        personalizeRecommendations: true,
        storeConversationHistory: true,
        shareAnonymousAnalytics: false,
        rememberPreferences: true,
        adaptCommunicationStyle: true
    )
    
    public static let minimal = PrivacySettings(
        dataRetentionDays: 7,
        personalizeRecommendations: false,
        storeConversationHistory: false,
        shareAnonymousAnalytics: false,
        rememberPreferences: false,
        adaptCommunicationStyle: false
    )
    
    public init(
        dataRetentionDays: Int,
        personalizeRecommendations: Bool,
        storeConversationHistory: Bool,
        shareAnonymousAnalytics: Bool,
        rememberPreferences: Bool,
        adaptCommunicationStyle: Bool
    ) {
        self.dataRetentionDays = dataRetentionDays
        self.personalizeRecommendations = personalizeRecommendations
        self.storeConversationHistory = storeConversationHistory
        self.shareAnonymousAnalytics = shareAnonymousAnalytics
        self.rememberPreferences = rememberPreferences
        self.adaptCommunicationStyle = adaptCommunicationStyle
    }
}

// MARK: - Behavior Analysis Types

public struct BehaviorPattern: Sendable, Codable {
    public let id: String
    public let type: BehaviorPatternType
    public let description: String
    public let triggers: [String]
    public let actions: [String]
    public let outcomes: [String]
    public var frequency: Int
    public let strength: Double
    public var confidence: Double
    public let firstObserved: Date
    public var lastObserved: Date
    public let context: [String: Any]
    
    public init(
        id: String,
        type: BehaviorPatternType,
        description: String,
        triggers: [String],
        actions: [String],
        outcomes: [String],
        frequency: Int,
        strength: Double,
        confidence: Double,
        firstObserved: Date,
        lastObserved: Date,
        context: [String: Any]
    ) {
        self.id = id
        self.type = type
        self.description = description
        self.triggers = triggers
        self.actions = actions
        self.outcomes = outcomes
        self.frequency = frequency
        self.strength = strength
        self.confidence = confidence
        self.firstObserved = firstObserved
        self.lastObserved = lastObserved
        self.context = context
    }
}

public enum BehaviorPatternType: String, Sendable, Codable, CaseIterable {
    case taskBased
    case temporal
    case contextual
    case social
    case cognitive
    case emotional
}

public struct UserPreference: Sendable, Codable {
    public let id: String
    public let category: String
    public let value: UserPreferenceValue
    public var strength: Double
    public var confidence: Double
    public let firstDetected: Date
    public var lastReinforced: Date
    public var reinforcementCount: Int
    public let source: PreferenceSource
    
    public init(
        id: String,
        category: String,
        value: UserPreferenceValue,
        strength: Double,
        confidence: Double,
        firstDetected: Date,
        lastReinforced: Date,
        reinforcementCount: Int,
        source: PreferenceSource
    ) {
        self.id = id
        self.category = category
        self.value = value
        self.strength = strength
        self.confidence = confidence
        self.firstDetected = firstDetected
        self.lastReinforced = lastReinforced
        self.reinforcementCount = reinforcementCount
        self.source = source
    }
}

public enum UserPreferenceValue: Sendable, Codable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case array([String])
    case dictionary([String: String])
}

public enum PreferenceSource: String, Sendable, Codable, CaseIterable {
    case explicit
    case behavioral
    case inferred
    case imported
}

public struct SkillAssessment: Sendable, Codable {
    public let id: String
    public let skillName: String
    public let domain: String
    public var currentLevel: Double
    public var confidence: Double
    public var evidence: [SkillEvidence]
    public let firstAssessed: Date
    public var lastAssessed: Date
    public var trendDirection: TrendDirection
    
    public init(
        id: String,
        skillName: String,
        domain: String,
        currentLevel: Double,
        confidence: Double,
        evidence: [SkillEvidence],
        firstAssessed: Date,
        lastAssessed: Date,
        trendDirection: TrendDirection
    ) {
        self.id = id
        self.skillName = skillName
        self.domain = domain
        self.currentLevel = currentLevel
        self.confidence = confidence
        self.evidence = evidence
        self.firstAssessed = firstAssessed
        self.lastAssessed = lastAssessed
        self.trendDirection = trendDirection
    }
}

public struct SkillEvidence: Sendable, Codable {
    public let demonstration: String
    public let quality: Double
    public let context: String
    public let timestamp: Date
    
    public init(
        demonstration: String,
        quality: Double,
        context: String,
        timestamp: Date
    ) {
        self.demonstration = demonstration
        self.quality = quality
        self.context = context
        self.timestamp = timestamp
    }
}

public enum TrendDirection: String, Sendable, Codable, CaseIterable {
    case improving
    case stable
    case declining
    case unknown
}

// MARK: - Interaction Types

public struct UserInteraction: Sendable, Codable {
    public let id: String
    public let userId: String
    public let timestamp: Date
    public let type: InteractionType
    public let content: String
    public let duration: TimeInterval
    public let success: Bool
    public let context: InteractionContext
    public let tools: [String]
    public let outcome: InteractionOutcome
    public let trigger: String?
    public let metadata: [String: Any]
    
    public init(
        id: String,
        userId: String,
        timestamp: Date,
        type: InteractionType,
        content: String,
        duration: TimeInterval,
        success: Bool,
        context: InteractionContext,
        tools: [String],
        outcome: InteractionOutcome,
        trigger: String?,
        metadata: [String: Any]
    ) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
        self.type = type
        self.content = content
        self.duration = duration
        self.success = success
        self.context = context
        self.tools = tools
        self.outcome = outcome
        self.trigger = trigger
        self.metadata = metadata
    }
}

public enum InteractionType: String, Sendable, Codable, CaseIterable {
    case question
    case request
    case conversation
    case task
    case feedback
    case exploration
    case learning
}

public enum InteractionContext: String, Sendable, Codable, CaseIterable {
    case work
    case personal
    case learning
    case creative
    case problem_solving
    case exploration
    case entertainment
}

public enum InteractionOutcome: String, Sendable, Codable, CaseIterable {
    case satisfied
    case partially_satisfied
    case unsatisfied
    case follow_up_needed
    case goal_achieved
    case learning_occurred
}

// MARK: - Request Types

public struct UserRequest: Sendable {
    public let id: String
    public let text: String
    public let type: RequestType
    public let priority: Double
    public let context: [String: Any]
    public let timestamp: Date
    
    public init(
        id: String,
        text: String,
        type: RequestType,
        priority: Double = 0.5,
        context: [String: Any] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.type = type
        self.priority = priority
        self.context = context
        self.timestamp = timestamp
    }
}

public enum RequestType: String, Sendable, CaseIterable {
    case question
    case task
    case analysis
    case creation
    case optimization
    case learning
    case exploration
}

// MARK: - Recommendation Types

public struct RecommendationContext: Sendable {
    public let userId: String
    public let currentTask: String?
    public let recentInteractions: [UserInteraction]
    public let activeGoals: [UserGoal]
    public let contextHints: [String]
    
    public init(
        userId: String,
        currentTask: String?,
        recentInteractions: [UserInteraction],
        activeGoals: [UserGoal],
        contextHints: [String]
    ) {
        self.userId = userId
        self.currentTask = currentTask
        self.recentInteractions = recentInteractions
        self.activeGoals = activeGoals
        self.contextHints = contextHints
    }
}

public struct PersonalizedRecommendation: Sendable {
    public let id: String
    public let type: RecommendationType
    public let title: String
    public let description: String
    public let confidence: Double
    public let relevance: Double
    public let reasoning: String
    public let actionable: Bool
    public let category: String
    public let metadata: [String: Any]
    
    public init(
        id: String,
        type: RecommendationType,
        title: String,
        description: String,
        confidence: Double,
        relevance: Double,
        reasoning: String,
        actionable: Bool,
        category: String,
        metadata: [String: Any]
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.confidence = confidence
        self.relevance = relevance
        self.reasoning = reasoning
        self.actionable = actionable
        self.category = category
        self.metadata = metadata
    }
}

public enum RecommendationType: String, Sendable, CaseIterable {
    case tool
    case workflow
    case learning
    case interface
    case context
    case goal
}

public struct PersonalizedContext: Sendable {
    public let userId: String
    public let requestContext: UserRequest
    public let relevantPatterns: [BehaviorPattern]
    public let relevantPreferences: [UserPreference]
    public let relevantSkills: [SkillAssessment]
    public let relevantExpertise: [DomainExpertise]
    public let personalityAdaptations: [String]
    public let communicationAdaptations: [String]
    public let cognitiveAdaptations: [String]
    public let workflowAdaptations: [String]
    public let contextAdaptations: [String]
    public let confidenceLevel: Double
    public let generatedAt: Date
    
    public init(
        userId: String,
        requestContext: UserRequest,
        relevantPatterns: [BehaviorPattern],
        relevantPreferences: [UserPreference],
        relevantSkills: [SkillAssessment],
        relevantExpertise: [DomainExpertise],
        personalityAdaptations: [String],
        communicationAdaptations: [String],
        cognitiveAdaptations: [String],
        workflowAdaptations: [String],
        contextAdaptations: [String],
        confidenceLevel: Double,
        generatedAt: Date
    ) {
        self.userId = userId
        self.requestContext = requestContext
        self.relevantPatterns = relevantPatterns
        self.relevantPreferences = relevantPreferences
        self.relevantSkills = relevantSkills
        self.relevantExpertise = relevantExpertise
        self.personalityAdaptations = personalityAdaptations
        self.communicationAdaptations = communicationAdaptations
        self.cognitiveAdaptations = cognitiveAdaptations
        self.workflowAdaptations = workflowAdaptations
        self.contextAdaptations = contextAdaptations
        self.confidenceLevel = confidenceLevel
        self.generatedAt = generatedAt
    }
}

// MARK: - Analysis Types

public struct ProfileAnalysis: Sendable {
    public let userId: String
    public let profileMaturity: Double
    public let dataQuality: Double
    public let strengths: [String]
    public let growthAreas: [String]
    public let behaviorTrends: [String]
    public let preferenceStability: Double
    public let expertiseDevelopment: [String: Double]
    public let goalProgress: [String: Double]
    public let recommendedActions: [String]
    public let confidenceScore: Double
    public let lastAnalysis: Date
    
    public init(
        userId: String,
        profileMaturity: Double,
        dataQuality: Double,
        strengths: [String],
        growthAreas: [String],
        behaviorTrends: [String],
        preferenceStability: Double,
        expertiseDevelopment: [String: Double],
        goalProgress: [String: Double],
        recommendedActions: [String],
        confidenceScore: Double,
        lastAnalysis: Date
    ) {
        self.userId = userId
        self.profileMaturity = profileMaturity
        self.dataQuality = dataQuality
        self.strengths = strengths
        self.growthAreas = growthAreas
        self.behaviorTrends = behaviorTrends
        self.preferenceStability = preferenceStability
        self.expertiseDevelopment = expertiseDevelopment
        self.goalProgress = goalProgress
        self.recommendedActions = recommendedActions
        self.confidenceScore = confidenceScore
        self.lastAnalysis = lastAnalysis
    }
}

// MARK: - Storage Types

public struct UserDataExport: Sendable, Codable {
    public let profile: UserProfile
    public let interactionHistory: [UserInteraction]
    public let behaviorPatterns: [BehaviorPattern]
    public let preferences: [UserPreference]
    public let skillLevels: [SkillAssessment]
    public let exportedAt: Date
    public let version: String
    
    public init(
        profile: UserProfile,
        interactionHistory: [UserInteraction],
        behaviorPatterns: [BehaviorPattern],
        preferences: [UserPreference],
        skillLevels: [SkillAssessment],
        exportedAt: Date,
        version: String
    ) {
        self.profile = profile
        self.interactionHistory = interactionHistory
        self.behaviorPatterns = behaviorPatterns
        self.preferences = preferences
        self.skillLevels = skillLevels
        self.exportedAt = exportedAt
        self.version = version
    }
}

// MARK: - Storage Configuration Types

public struct UserProfileStorageConfiguration: Sendable {
    public let persistToDisk: Bool
    public let storageDirectory: String
    public let compressionEnabled: Bool
    public let encryptionEnabled: Bool
    public let backupEnabled: Bool
    
    public static let `default` = UserProfileStorageConfiguration(
        persistToDisk: true,
        storageDirectory: ".toke/user_profiles",
        compressionEnabled: true,
        encryptionEnabled: true,
        backupEnabled: true
    )
    
    public init(
        persistToDisk: Bool,
        storageDirectory: String,
        compressionEnabled: Bool,
        encryptionEnabled: Bool,
        backupEnabled: Bool
    ) {
        self.persistToDisk = persistToDisk
        self.storageDirectory = storageDirectory
        self.compressionEnabled = compressionEnabled
        self.encryptionEnabled = encryptionEnabled
        self.backupEnabled = backupEnabled
    }
}

// MARK: - User Profile Storage

public class UserProfileStorage: Sendable {
    private let configuration: UserProfileStorageConfiguration
    
    public init(configuration: UserProfileStorageConfiguration) {
        self.configuration = configuration
    }
    
    public func saveProfile(_ profile: UserProfile) async {
        // Implementation for saving profile to persistent storage
    }
    
    public func loadProfile(userId: String) async -> UserProfile? {
        // Implementation for loading profile from persistent storage
        return nil
    }
    
    public func clearProfile(userId: String) async {
        // Implementation for clearing profile from persistent storage
    }
    
    public func loadInteractionHistory(userId: String) async -> [UserInteraction] {
        // Implementation for loading interaction history
        return []
    }
    
    public func loadBehaviorPatterns(userId: String) async -> [BehaviorPattern] {
        // Implementation for loading behavior patterns
        return []
    }
    
    public func loadPreferences(userId: String) async -> [UserPreference] {
        // Implementation for loading preferences
        return []
    }
    
    public func loadSkillAssessments(userId: String) async -> [SkillAssessment] {
        // Implementation for loading skill assessments
        return []
    }
}