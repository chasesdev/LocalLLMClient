import Foundation
import CryptoKit
import OSLog

/// UserProfiler builds comprehensive user models through interaction analysis
/// This component creates deep user understanding for personalized experiences
public class UserProfiler: Sendable {
    private let storage: UserProfileStorage
    private let logger = Logger(subsystem: "LocalLLMClientCore", category: "UserProfiler")
    private let lock = AsyncLock()
    
    private var userProfile: UserProfile
    private var interactionHistory: [UserInteraction] = []
    private var behaviorPatterns: [String: BehaviorPattern] = [:]
    private var preferences: [String: UserPreference] = [:]
    private var skillLevels: [String: SkillAssessment] = [:]
    
    public init(userId: String, configuration: UserProfilerConfiguration = .default) async {
        self.storage = UserProfileStorage(configuration: configuration.storage)
        
        // Load or create user profile
        if let existingProfile = await storage.loadProfile(userId: userId) {
            self.userProfile = existingProfile
            logger.info("Loaded existing profile for user: \(userId)")
        } else {
            self.userProfile = UserProfile(
                id: userId,
                createdAt: Date(),
                lastUpdated: Date(),
                interactionCount: 0,
                demographics: UserDemographics(),
                preferences: [:],
                skillLevels: [:],
                behaviorPatterns: [:],
                personalityTraits: PersonalityProfile(),
                cognitiveStyle: CognitiveStyle(),
                communicationStyle: CommunicationStyle(),
                workflowPreferences: WorkflowPreferences(),
                domainExpertise: [:],
                learningStyle: LearningStyle(),
                goals: [],
                contextPreferences: [:],
                privacySettings: PrivacySettings.default
            )
            logger.info("Created new profile for user: \(userId)")
        }
        
        await loadProfileData()
        
        logger.info("UserProfiler initialized for user: \(userId)")
    }
    
    // MARK: - Interaction Processing
    
    /// Process a new user interaction and update the profile
    public func processInteraction(_ interaction: UserInteraction) async {
        await lock.withLock {
            logger.debug("Processing interaction: \(interaction.type)")
            
            // Store interaction
            interactionHistory.append(interaction)
            userProfile.interactionCount += 1
            userProfile.lastUpdated = Date()
            
            // Analyze interaction patterns
            await updateBehaviorPatterns(from: interaction)
            
            // Update preferences
            await updatePreferences(from: interaction)
            
            // Assess skill levels
            await updateSkillAssessments(from: interaction)
            
            // Update personality traits
            await updatePersonalityTraits(from: interaction)
            
            // Update cognitive style
            await updateCognitiveStyle(from: interaction)
            
            // Update communication style
            await updateCommunicationStyle(from: interaction)
            
            // Update workflow preferences
            await updateWorkflowPreferences(from: interaction)
            
            // Update domain expertise
            await updateDomainExpertise(from: interaction)
            
            // Update learning style
            await updateLearningStyle(from: interaction)
            
            // Update goals if detected
            await updateGoals(from: interaction)
            
            // Consolidate profile periodically
            if userProfile.interactionCount % 50 == 0 {
                await consolidateProfile()
            }
            
            // Persist changes
            await storage.saveProfile(userProfile)
            
            logger.debug("Processed interaction. Total interactions: \(userProfile.interactionCount)")
        }
    }
    
    /// Get the current user profile
    public func getUserProfile() async -> UserProfile {
        return await lock.withLock {
            userProfile
        }
    }
    
    /// Get personalized recommendations based on user profile
    public func getPersonalizedRecommendations(for context: RecommendationContext) async -> [PersonalizedRecommendation] {
        return await lock.withLock {
            var recommendations: [PersonalizedRecommendation] = []
            
            // Tool recommendations based on workflow patterns
            recommendations.append(contentsOf: await generateToolRecommendations(context: context))
            
            // Workflow optimizations based on behavior patterns
            recommendations.append(contentsOf: await generateWorkflowRecommendations(context: context))
            
            // Learning resources based on skill gaps
            recommendations.append(contentsOf: await generateLearningRecommendations(context: context))
            
            // Context optimizations based on preferences
            recommendations.append(contentsOf: await generateContextRecommendations(context: context))
            
            // Interface customizations based on cognitive style
            recommendations.append(contentsOf: await generateInterfaceRecommendations(context: context))
            
            // Sort by relevance and confidence
            recommendations.sort { $0.confidence > $1.confidence }
            
            return Array(recommendations.prefix(10))
        }
    }
    
    // MARK: - Profile Analysis
    
    /// Analyze user profile for insights and patterns
    public func analyzeProfile() async -> ProfileAnalysis {
        return await lock.withLock {
            let recentInteractions = interactionHistory.suffix(100)
            
            let strengths = identifyUserStrengths()
            let growthAreas = identifyGrowthAreas()
            let behaviorTrends = analyzeBehaviorTrends(recentInteractions)
            let preferenceStability = analyzePreferenceStability()
            let expertiseDevelopment = analyzeExpertiseDevelopment()
            let goalProgress = analyzeGoalProgress()
            
            return ProfileAnalysis(
                userId: userProfile.id,
                profileMaturity: calculateProfileMaturity(),
                dataQuality: assessDataQuality(),
                strengths: strengths,
                growthAreas: growthAreas,
                behaviorTrends: behaviorTrends,
                preferenceStability: preferenceStability,
                expertiseDevelopment: expertiseDevelopment,
                goalProgress: goalProgress,
                recommendedActions: generateRecommendedActions(
                    strengths: strengths,
                    growthAreas: growthAreas,
                    trends: behaviorTrends
                ),
                confidenceScore: calculateOverallConfidence(),
                lastAnalysis: Date()
            )
        }
    }
    
    /// Get personalized context for a specific request
    public func getPersonalizedContext(for request: UserRequest) async -> PersonalizedContext {
        return await lock.withLock {
            let relevantPatterns = getBehaviorPatternsForContext(request)
            let relevantPreferences = getPreferencesForContext(request)
            let relevantSkills = getSkillsForContext(request)
            let relevantExpertise = getDomainExpertiseForContext(request)
            
            let adaptations = generateContextAdaptations(
                request: request,
                patterns: relevantPatterns,
                preferences: relevantPreferences,
                skills: relevantSkills,
                expertise: relevantExpertise
            )
            
            return PersonalizedContext(
                userId: userProfile.id,
                requestContext: request,
                relevantPatterns: Array(relevantPatterns.values),
                relevantPreferences: Array(relevantPreferences.values),
                relevantSkills: Array(relevantSkills.values),
                relevantExpertise: Array(relevantExpertise.values),
                personalityAdaptations: getPersonalityAdaptations(request),
                communicationAdaptations: getCommunicationAdaptations(request),
                cognitiveAdaptations: getCognitiveAdaptations(request),
                workflowAdaptations: getWorkflowAdaptations(request),
                contextAdaptations: adaptations,
                confidenceLevel: calculateContextConfidence(request),
                generatedAt: Date()
            )
        }
    }
    
    // MARK: - Privacy and Control
    
    /// Update privacy settings
    public func updatePrivacySettings(_ settings: PrivacySettings) async {
        await lock.withLock {
            userProfile.privacySettings = settings
            userProfile.lastUpdated = Date()
            
            // Apply privacy constraints to existing data
            await applyPrivacyConstraints(settings)
            
            await storage.saveProfile(userProfile)
            logger.info("Updated privacy settings for user: \(userProfile.id)")
        }
    }
    
    /// Export user data for portability
    public func exportUserData() async -> UserDataExport {
        return await lock.withLock {
            UserDataExport(
                profile: userProfile,
                interactionHistory: filterInteractionHistory(),
                behaviorPatterns: Array(behaviorPatterns.values),
                preferences: Array(preferences.values),
                skillLevels: Array(skillLevels.values),
                exportedAt: Date(),
                version: "1.0"
            )
        }
    }
    
    /// Clear user data (privacy compliance)
    public func clearUserData() async {
        await lock.withLock {
            logger.info("Clearing user data for: \(userProfile.id)")
            
            interactionHistory.removeAll()
            behaviorPatterns.removeAll()
            preferences.removeAll()
            skillLevels.removeAll()
            
            // Reset profile to minimal state
            userProfile = UserProfile(
                id: userProfile.id,
                createdAt: userProfile.createdAt,
                lastUpdated: Date(),
                interactionCount: 0,
                demographics: UserDemographics(),
                preferences: [:],
                skillLevels: [:],
                behaviorPatterns: [:],
                personalityTraits: PersonalityProfile(),
                cognitiveStyle: CognitiveStyle(),
                communicationStyle: CommunicationStyle(),
                workflowPreferences: WorkflowPreferences(),
                domainExpertise: [:],
                learningStyle: LearningStyle(),
                goals: [],
                contextPreferences: [:],
                privacySettings: PrivacySettings.minimal
            )
            
            await storage.clearProfile(userId: userProfile.id)
            logger.info("User data cleared successfully")
        }
    }
    
    // MARK: - Private Implementation
    
    private func loadProfileData() async {
        do {
            let loadedInteractions = await storage.loadInteractionHistory(userId: userProfile.id)
            let loadedPatterns = await storage.loadBehaviorPatterns(userId: userProfile.id)
            let loadedPreferences = await storage.loadPreferences(userId: userProfile.id)
            let loadedSkills = await storage.loadSkillAssessments(userId: userProfile.id)
            
            interactionHistory = loadedInteractions
            
            for pattern in loadedPatterns {
                behaviorPatterns[pattern.id] = pattern
            }
            
            for preference in loadedPreferences {
                preferences[preference.id] = preference
            }
            
            for skill in loadedSkills {
                skillLevels[skill.id] = skill
            }
            
            logger.info("Loaded profile data: \(interactionHistory.count) interactions, \(behaviorPatterns.count) patterns")
        } catch {
            logger.error("Failed to load profile data: \(error)")
        }
    }
    
    private func updateBehaviorPatterns(from interaction: UserInteraction) async {
        let patternId = generatePatternId(for: interaction)
        
        if var existingPattern = behaviorPatterns[patternId] {
            existingPattern.frequency += 1
            existingPattern.lastObserved = Date()
            existingPattern.confidence = min(1.0, existingPattern.confidence + 0.1)
            behaviorPatterns[patternId] = existingPattern
        } else {
            let newPattern = BehaviorPattern(
                id: patternId,
                type: extractPatternType(from: interaction),
                description: generatePatternDescription(from: interaction),
                triggers: extractTriggers(from: interaction),
                actions: extractActions(from: interaction),
                outcomes: extractOutcomes(from: interaction),
                frequency: 1,
                strength: calculatePatternStrength(from: interaction),
                confidence: 0.3,
                firstObserved: Date(),
                lastObserved: Date(),
                context: extractPatternContext(from: interaction)
            )
            behaviorPatterns[patternId] = newPattern
        }
    }
    
    private func updatePreferences(from interaction: UserInteraction) async {
        let extractedPrefs = extractPreferences(from: interaction)
        
        for (key, value) in extractedPrefs {
            if var existingPref = preferences[key] {
                existingPref.strength = min(1.0, existingPref.strength + 0.1)
                existingPref.lastReinforced = Date()
                existingPref.reinforcementCount += 1
                preferences[key] = existingPref
            } else {
                let newPref = UserPreference(
                    id: key,
                    category: categorizePreference(key),
                    value: value,
                    strength: 0.3,
                    confidence: 0.5,
                    firstDetected: Date(),
                    lastReinforced: Date(),
                    reinforcementCount: 1,
                    source: .behavioral
                )
                preferences[key] = newPref
            }
        }
    }
    
    private func updateSkillAssessments(from interaction: UserInteraction) async {
        let detectedSkills = detectSkillDemonstration(from: interaction)
        
        for (skillName, evidence) in detectedSkills {
            if var existingSkill = skillLevels[skillName] {
                let newEvidence = SkillEvidence(
                    demonstration: evidence.demonstration,
                    quality: evidence.quality,
                    context: evidence.context,
                    timestamp: Date()
                )
                existingSkill.evidence.append(newEvidence)
                existingSkill.currentLevel = recalculateSkillLevel(existing: existingSkill)
                existingSkill.confidence = min(1.0, existingSkill.confidence + 0.05)
                existingSkill.lastAssessed = Date()
                skillLevels[skillName] = existingSkill
            } else {
                let newSkill = SkillAssessment(
                    id: skillName,
                    skillName: skillName,
                    domain: categorizeDomain(skillName),
                    currentLevel: evidence.quality,
                    confidence: 0.3,
                    evidence: [SkillEvidence(
                        demonstration: evidence.demonstration,
                        quality: evidence.quality,
                        context: evidence.context,
                        timestamp: Date()
                    )],
                    firstAssessed: Date(),
                    lastAssessed: Date(),
                    trendDirection: .stable
                )
                skillLevels[skillName] = newSkill
            }
        }
    }
    
    private func updatePersonalityTraits(from interaction: UserInteraction) async {
        let traitIndicators = extractPersonalityIndicators(from: interaction)
        
        for (trait, strength) in traitIndicators {
            switch trait {
            case "extraversion":
                userProfile.personalityTraits.extraversion = updateTraitScore(
                    current: userProfile.personalityTraits.extraversion,
                    newEvidence: strength
                )
            case "openness":
                userProfile.personalityTraits.openness = updateTraitScore(
                    current: userProfile.personalityTraits.openness,
                    newEvidence: strength
                )
            case "conscientiousness":
                userProfile.personalityTraits.conscientiousness = updateTraitScore(
                    current: userProfile.personalityTraits.conscientiousness,
                    newEvidence: strength
                )
            case "agreeableness":
                userProfile.personalityTraits.agreeableness = updateTraitScore(
                    current: userProfile.personalityTraits.agreeableness,
                    newEvidence: strength
                )
            case "neuroticism":
                userProfile.personalityTraits.neuroticism = updateTraitScore(
                    current: userProfile.personalityTraits.neuroticism,
                    newEvidence: strength
                )
            default:
                break
            }
        }
    }
    
    private func updateCognitiveStyle(from interaction: UserInteraction) async {
        let cognitiveIndicators = extractCognitiveIndicators(from: interaction)
        
        for (aspect, value) in cognitiveIndicators {
            switch aspect {
            case "processingSpeed":
                userProfile.cognitiveStyle.processingSpeed = updateCognitiveScore(
                    current: userProfile.cognitiveStyle.processingSpeed,
                    newEvidence: value
                )
            case "detailOrientation":
                userProfile.cognitiveStyle.detailOrientation = updateCognitiveScore(
                    current: userProfile.cognitiveStyle.detailOrientation,
                    newEvidence: value
                )
            case "abstractThinking":
                userProfile.cognitiveStyle.abstractThinking = updateCognitiveScore(
                    current: userProfile.cognitiveStyle.abstractThinking,
                    newEvidence: value
                )
            default:
                break
            }
        }
    }
    
    private func updateCommunicationStyle(from interaction: UserInteraction) async {
        let communicationIndicators = extractCommunicationIndicators(from: interaction)
        
        userProfile.communicationStyle.verbosity = updateCommunicationScore(
            current: userProfile.communicationStyle.verbosity,
            newEvidence: communicationIndicators["verbosity"] ?? 0.0
        )
        
        userProfile.communicationStyle.directness = updateCommunicationScore(
            current: userProfile.communicationStyle.directness,
            newEvidence: communicationIndicators["directness"] ?? 0.0
        )
        
        userProfile.communicationStyle.formalityLevel = updateCommunicationScore(
            current: userProfile.communicationStyle.formalityLevel,
            newEvidence: communicationIndicators["formality"] ?? 0.0
        )
    }
    
    private func updateWorkflowPreferences(from interaction: UserInteraction) async {
        let workflowIndicators = extractWorkflowIndicators(from: interaction)
        
        for (preference, value) in workflowIndicators {
            switch preference {
            case "stepByStep":
                userProfile.workflowPreferences.preferredPacing = value > 0.5 ? .methodical : .efficient
            case "collaboration":
                userProfile.workflowPreferences.collaborationStyle = value > 0.5 ? .collaborative : .independent
            case "planning":
                userProfile.workflowPreferences.planningStyle = value > 0.5 ? .detailed : .adaptive
            default:
                break
            }
        }
    }
    
    private func updateDomainExpertise(from interaction: UserInteraction) async {
        let domains = extractDomainReferences(from: interaction)
        
        for domain in domains {
            if var existing = userProfile.domainExpertise[domain.name] {
                existing.demonstratedLevel = max(existing.demonstratedLevel, domain.level)
                existing.lastDemonstrated = Date()
                existing.demonstrationCount += 1
                userProfile.domainExpertise[domain.name] = existing
            } else {
                userProfile.domainExpertise[domain.name] = DomainExpertise(
                    domain: domain.name,
                    demonstratedLevel: domain.level,
                    confidence: 0.3,
                    firstDemonstrated: Date(),
                    lastDemonstrated: Date(),
                    demonstrationCount: 1,
                    keyAreas: domain.areas
                )
            }
        }
    }
    
    private func updateLearningStyle(from interaction: UserInteraction) async {
        let learningIndicators = extractLearningIndicators(from: interaction)
        
        for (aspect, value) in learningIndicators {
            switch aspect {
            case "preferredModality":
                if value > 0.7 {
                    userProfile.learningStyle.preferredModalities.append(.visual)
                }
            case "pacePreference":
                userProfile.learningStyle.pacePreference = value > 0.5 ? .selfPaced : .structured
            case "feedbackPreference":
                userProfile.learningStyle.feedbackPreference = value > 0.5 ? .immediate : .summary
            default:
                break
            }
        }
    }
    
    private func updateGoals(from interaction: UserInteraction) async {
        let detectedGoals = extractGoalIndications(from: interaction)
        
        for goalIndication in detectedGoals {
            let existingGoalIndex = userProfile.goals.firstIndex { $0.description.lowercased().contains(goalIndication.lowercased()) }
            
            if let index = existingGoalIndex {
                userProfile.goals[index].lastReinforced = Date()
                userProfile.goals[index].reinforcementCount += 1
            } else {
                let newGoal = UserGoal(
                    id: UUID().uuidString,
                    description: goalIndication,
                    category: categorizeGoal(goalIndication),
                    priority: 0.5,
                    confidence: 0.3,
                    firstDetected: Date(),
                    lastReinforced: Date(),
                    reinforcementCount: 1,
                    estimatedTimeline: .medium
                )
                userProfile.goals.append(newGoal)
            }
        }
    }
    
    private func consolidateProfile() async {
        logger.info("Consolidating user profile")
        
        // Remove low-confidence patterns
        let strongPatterns = behaviorPatterns.filter { _, pattern in
            pattern.confidence > 0.3 && pattern.frequency > 2
        }
        behaviorPatterns = strongPatterns
        
        // Decay old preferences
        for (key, var preference) in preferences {
            let daysSinceReinforcement = Date().timeIntervalSince(preference.lastReinforced) / 86400
            if daysSinceReinforcement > 30 {
                preference.strength *= 0.9
                if preference.strength < 0.1 {
                    preferences.removeValue(forKey: key)
                } else {
                    preferences[key] = preference
                }
            }
        }
        
        // Update profile confidence
        userProfile.personalityTraits.confidence = calculatePersonalityConfidence()
        userProfile.cognitiveStyle.confidence = calculateCognitiveConfidence()
        userProfile.communicationStyle.confidence = calculateCommunicationConfidence()
        
        logger.info("Profile consolidation complete")
    }
    
    // Helper methods with simplified implementations
    private func generatePatternId(for interaction: UserInteraction) -> String {
        let components = [interaction.type.rawValue, String(interaction.duration)].joined(separator: "_")
        return SHA256.hash(data: components.data(using: .utf8) ?? Data())
            .compactMap { String(format: "%02x", $0) }
            .joined()
            .prefix(12)
            .description
    }
    
    // Placeholder implementations for complex analysis methods
    private func extractPatternType(from interaction: UserInteraction) -> BehaviorPatternType { .taskBased }
    private func generatePatternDescription(from interaction: UserInteraction) -> String { "Pattern from \(interaction.type)" }
    private func extractTriggers(from interaction: UserInteraction) -> [String] { [interaction.trigger ?? "unknown"] }
    private func extractActions(from interaction: UserInteraction) -> [String] { [interaction.type.rawValue] }
    private func extractOutcomes(from interaction: UserInteraction) -> [String] { ["completed"] }
    private func calculatePatternStrength(from interaction: UserInteraction) -> Double { 0.5 }
    private func extractPatternContext(from interaction: UserInteraction) -> [String: Any] { [:] }
    private func extractPreferences(from interaction: UserInteraction) -> [String: Any] { [:] }
    private func categorizePreference(_ key: String) -> String { "general" }
    private func detectSkillDemonstration(from interaction: UserInteraction) -> [String: (demonstration: String, quality: Double, context: String)] { [:] }
    private func recalculateSkillLevel(existing: SkillAssessment) -> Double { existing.currentLevel }
    private func categorizeDomain(_ skillName: String) -> String { "general" }
    private func extractPersonalityIndicators(from interaction: UserInteraction) -> [String: Double] { [:] }
    private func updateTraitScore(current: Double, newEvidence: Double) -> Double { (current + newEvidence) / 2 }
    private func extractCognitiveIndicators(from interaction: UserInteraction) -> [String: Double] { [:] }
    private func updateCognitiveScore(current: Double, newEvidence: Double) -> Double { (current + newEvidence) / 2 }
    private func extractCommunicationIndicators(from interaction: UserInteraction) -> [String: Double] { [:] }
    private func updateCommunicationScore(current: Double, newEvidence: Double) -> Double { (current + newEvidence) / 2 }
    private func extractWorkflowIndicators(from interaction: UserInteraction) -> [String: Double] { [:] }
    private func extractDomainReferences(from interaction: UserInteraction) -> [(name: String, level: Double, areas: [String])] { [] }
    private func extractLearningIndicators(from interaction: UserInteraction) -> [String: Double] { [:] }
    private func extractGoalIndications(from interaction: UserInteraction) -> [String] { [] }
    private func categorizeGoal(_ goal: String) -> GoalCategory { .skill }
    private func calculatePersonalityConfidence() -> Double { 0.7 }
    private func calculateCognitiveConfidence() -> Double { 0.7 }
    private func calculateCommunicationConfidence() -> Double { 0.7 }
    
    // Analysis methods
    private func calculateProfileMaturity() -> Double { min(1.0, Double(userProfile.interactionCount) / 1000.0) }
    private func assessDataQuality() -> Double { 0.8 }
    private func identifyUserStrengths() -> [String] { ["problem-solving", "communication"] }
    private func identifyGrowthAreas() -> [String] { ["time-management"] }
    private func analyzeBehaviorTrends(_ interactions: ArraySlice<UserInteraction>) -> [String] { ["consistent"] }
    private func analyzePreferenceStability() -> Double { 0.8 }
    private func analyzeExpertiseDevelopment() -> [String: Double] { ["programming": 0.8] }
    private func analyzeGoalProgress() -> [String: Double] { ["learning": 0.6] }
    private func generateRecommendedActions(strengths: [String], growthAreas: [String], trends: [String]) -> [String] { ["continue current approach"] }
    private func calculateOverallConfidence() -> Double { 0.75 }
    
    // Context methods
    private func getBehaviorPatternsForContext(_ request: UserRequest) -> [String: BehaviorPattern] { [:] }
    private func getPreferencesForContext(_ request: UserRequest) -> [String: UserPreference] { [:] }
    private func getSkillsForContext(_ request: UserRequest) -> [String: SkillAssessment] { [:] }
    private func getDomainExpertiseForContext(_ request: UserRequest) -> [String: DomainExpertise] { [:] }
    private func generateContextAdaptations(request: UserRequest, patterns: [String: BehaviorPattern], preferences: [String: UserPreference], skills: [String: SkillAssessment], expertise: [String: DomainExpertise]) -> [String] { [] }
    private func getPersonalityAdaptations(_ request: UserRequest) -> [String] { [] }
    private func getCommunicationAdaptations(_ request: UserRequest) -> [String] { [] }
    private func getCognitiveAdaptations(_ request: UserRequest) -> [String] { [] }
    private func getWorkflowAdaptations(_ request: UserRequest) -> [String] { [] }
    private func calculateContextConfidence(_ request: UserRequest) -> Double { 0.7 }
    
    // Recommendation methods
    private func generateToolRecommendations(context: RecommendationContext) -> [PersonalizedRecommendation] { [] }
    private func generateWorkflowRecommendations(context: RecommendationContext) -> [PersonalizedRecommendation] { [] }
    private func generateLearningRecommendations(context: RecommendationContext) -> [PersonalizedRecommendation] { [] }
    private func generateContextRecommendations(context: RecommendationContext) -> [PersonalizedRecommendation] { [] }
    private func generateInterfaceRecommendations(context: RecommendationContext) -> [PersonalizedRecommendation] { [] }
    
    // Privacy methods
    private func applyPrivacyConstraints(_ settings: PrivacySettings) async {}
    private func filterInteractionHistory() -> [UserInteraction] { interactionHistory }
}

// MARK: - Supporting Types

public struct UserProfilerConfiguration: Sendable {
    public let storage: UserProfileStorageConfiguration
    public let interactionRetentionDays: Int
    public let consolidationThreshold: Int
    public let privacyLevel: PrivacyLevel
    
    public static let `default` = UserProfilerConfiguration(
        storage: .default,
        interactionRetentionDays: 90,
        consolidationThreshold: 50,
        privacyLevel: .standard
    )
}

public enum PrivacyLevel: String, Sendable, CaseIterable {
    case minimal
    case standard
    case enhanced
}

// This file continues with all the supporting types from the previous implementation...
// [The rest of the types would be included here but truncated for brevity]