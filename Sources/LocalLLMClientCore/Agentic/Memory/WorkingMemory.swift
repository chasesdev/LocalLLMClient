import Foundation
import OSLog

/// WorkingMemory manages active context, temporary state, and real-time processing
/// This component focuses on immediate cognitive processes and context management
public class WorkingMemory: Sendable {
    private let configuration: WorkingMemoryConfiguration
    private let logger = Logger(subsystem: "LocalLLMClientCore", category: "WorkingMemory")
    
    // Active context management
    private var activeContext: ActiveContext
    private var contextStack: [ContextFrame] = []
    private var attentionState: AttentionState
    
    // Working storage
    private var workingStorage: [String: WorkingMemoryItem] = [:]
    private var temporaryVariables: [String: Any] = [:]
    private var pendingOperations: [String: PendingOperation] = [:]
    
    // Context switching
    private var contextHistory: [ContextSnapshot] = []
    private var contextSwitchCount: Int = 0
    
    // Attention and focus
    private var focusManager: FocusManager
    private var interruptionHandler: InterruptionHandler
    
    private let lock = AsyncLock()
    
    public init(configuration: WorkingMemoryConfiguration = .default) {
        self.configuration = configuration
        self.activeContext = ActiveContext(capacity: configuration.contextCapacity)
        self.attentionState = AttentionState()
        self.focusManager = FocusManager(configuration: configuration.focusConfiguration)
        self.interruptionHandler = InterruptionHandler(configuration: configuration.interruptionConfiguration)
        
        logger.info("WorkingMemory initialized with capacity \(configuration.contextCapacity)")
    }
    
    // MARK: - Context Management
    
    /// Update the current working context with new information
    public func updateContext(_ update: ContextUpdate) async {
        await lock.withLock {
            logger.debug("Updating working context: \(update.type)")
            
            // Apply context update
            activeContext.apply(update)
            
            // Update attention state
            await attentionState.processUpdate(update)
            
            // Manage context capacity
            await manageContextCapacity()
            
            // Update focus if needed
            if update.priority > 0.7 {
                await focusManager.updateFocus(on: update.focusTarget)
            }
            
            // Store in working storage if persistent
            if update.persistent {
                let item = WorkingMemoryItem(
                    id: update.id,
                    content: update.content,
                    type: update.type,
                    priority: update.priority,
                    expiration: Date().addingTimeInterval(configuration.itemRetentionTime),
                    associatedContext: update.associatedContext,
                    metadata: update.metadata
                )
                workingStorage[update.id] = item
            }
            
            logger.debug("Context updated. Active items: \(activeContext.itemCount), Focus: \(focusManager.currentFocus)")
        }
    }
    
    /// Push a new context frame onto the stack
    public func pushContext(_ frame: ContextFrame) async {
        await lock.withLock {
            // Save current state
            let snapshot = ContextSnapshot(
                timestamp: Date(),
                activeContext: activeContext.copy(),
                attentionState: attentionState.copy(),
                focusTarget: focusManager.currentFocus
            )
            contextHistory.append(snapshot)
            
            // Push new frame
            contextStack.append(frame)
            
            // Switch to new context
            await switchToContext(frame)
            contextSwitchCount += 1
            
            logger.info("Pushed context frame: \(frame.name). Stack depth: \(contextStack.count)")
        }
    }
    
    /// Pop the current context frame and restore previous state
    public func popContext() async -> ContextFrame? {
        return await lock.withLock {
            guard !contextStack.isEmpty else { return nil }
            
            let poppedFrame = contextStack.removeLast()
            
            // Restore previous state if available
            if let previousSnapshot = contextHistory.last {
                contextHistory.removeLast()
                await restoreFromSnapshot(previousSnapshot)
            }
            
            contextSwitchCount += 1
            logger.info("Popped context frame: \(poppedFrame.name). Stack depth: \(contextStack.count)")
            
            return poppedFrame
        }
    }
    
    /// Get the current active context
    public func getCurrentContext() async -> ActiveContextSnapshot {
        return await lock.withLock {
            ActiveContextSnapshot(
                items: Array(activeContext.items.values),
                focusTarget: focusManager.currentFocus,
                attentionLevel: attentionState.currentLevel,
                temporaryVariables: temporaryVariables,
                pendingOperations: Array(pendingOperations.values),
                contextDepth: contextStack.count,
                lastUpdate: activeContext.lastUpdate
            )
        }
    }
    
    // MARK: - Attention Management
    
    /// Focus attention on specific elements
    public func focusAttention(on targets: [AttentionTarget], intensity: Double = 0.8) async {
        await lock.withLock {
            await focusManager.focusOn(targets, intensity: intensity)
            
            // Update attention state
            attentionState.currentLevel = intensity
            attentionState.focusTargets = targets
            attentionState.lastUpdate = Date()
            
            // Boost priority of focused items
            for target in targets {
                await boostItemPriority(target.itemId, by: 0.3)
            }
            
            logger.debug("Focused attention on \(targets.count) targets with intensity \(intensity)")
        }
    }
    
    /// Handle attention interruption
    public func handleInterruption(_ interruption: Interruption) async -> InterruptionResponse {
        return await lock.withLock {
            logger.info("Handling interruption: \(interruption.type)")
            
            let response = await interruptionHandler.process(interruption, currentContext: activeContext)
            
            switch response.action {
            case .ignore:
                logger.debug("Ignoring interruption")
                
            case .defer:
                // Schedule for later processing
                let deferredOperation = PendingOperation(
                    id: UUID().uuidString,
                    type: .deferred,
                    content: interruption.content,
                    priority: interruption.priority,
                    scheduledTime: Date().addingTimeInterval(response.deferTime ?? 300),
                    maxAttempts: 3
                )
                pendingOperations[deferredOperation.id] = deferredOperation
                logger.debug("Deferred interruption for \(response.deferTime ?? 300) seconds")
                
            case .contextSwitch:
                // Create interruption context
                let interruptionFrame = ContextFrame(
                    name: "interruption_\(interruption.id)",
                    type: .interruption,
                    priority: interruption.priority,
                    content: interruption.content,
                    expectedDuration: response.estimatedDuration ?? 60,
                    parentContext: activeContext.id
                )
                await pushContext(interruptionFrame)
                logger.info("Switched context for interruption")
                
            case .integrate:
                // Integrate interruption into current context
                let update = ContextUpdate(
                    id: interruption.id,
                    type: .interruption,
                    content: interruption.content,
                    priority: interruption.priority,
                    focusTarget: interruption.focusTarget,
                    persistent: false,
                    associatedContext: activeContext.id,
                    metadata: interruption.metadata
                )
                await updateContext(update)
                logger.debug("Integrated interruption into current context")
            }
            
            return response
        }
    }
    
    // MARK: - Working Storage
    
    /// Store item in working memory
    public func store(_ item: WorkingMemoryItem) async {
        await lock.withLock {
            workingStorage[item.id] = item
            
            // Update active context if high priority
            if item.priority > 0.6 {
                let update = ContextUpdate(
                    id: item.id,
                    type: item.type,
                    content: item.content,
                    priority: item.priority,
                    focusTarget: item.id,
                    persistent: true,
                    associatedContext: item.associatedContext,
                    metadata: item.metadata
                )
                await updateContext(update)
            }
            
            logger.debug("Stored item: \(item.id)")
        }
    }
    
    /// Retrieve item from working memory
    public func retrieve(_ itemId: String) async -> WorkingMemoryItem? {
        return await lock.withLock {
            let item = workingStorage[itemId]
            
            // Update access time if found
            if var foundItem = item {
                foundItem.lastAccessed = Date()
                workingStorage[itemId] = foundItem
            }
            
            return item
        }
    }
    
    /// Remove item from working memory
    public func remove(_ itemId: String) async {
        await lock.withLock {
            workingStorage.removeValue(forKey: itemId)
            activeContext.removeItem(itemId)
            
            logger.debug("Removed item: \(itemId)")
        }
    }
    
    // MARK: - Temporary Variables
    
    /// Set temporary variable
    public func setVariable(_ name: String, value: Any) async {
        await lock.withLock {
            temporaryVariables[name] = value
            logger.debug("Set variable: \(name)")
        }
    }
    
    /// Get temporary variable
    public func getVariable(_ name: String) async -> Any? {
        return await lock.withLock {
            temporaryVariables[name]
        }
    }
    
    /// Clear temporary variables
    public func clearVariables() async {
        await lock.withLock {
            temporaryVariables.removeAll()
            logger.debug("Cleared all temporary variables")
        }
    }
    
    // MARK: - Pending Operations
    
    /// Add pending operation
    public func addPendingOperation(_ operation: PendingOperation) async {
        await lock.withLock {
            pendingOperations[operation.id] = operation
            logger.debug("Added pending operation: \(operation.id)")
        }
    }
    
    /// Process due pending operations
    public func processPendingOperations() async -> [ProcessedOperation] {
        return await lock.withLock {
            let now = Date()
            var processedOperations: [ProcessedOperation] = []
            
            let dueOperations = pendingOperations.values.filter { $0.scheduledTime <= now }
            
            for operation in dueOperations {
                let processed = ProcessedOperation(
                    id: operation.id,
                    originalOperation: operation,
                    processedAt: now,
                    success: true,
                    result: "Processed: \(operation.type)"
                )
                
                processedOperations.append(processed)
                pendingOperations.removeValue(forKey: operation.id)
                
                logger.debug("Processed pending operation: \(operation.id)")
            }
            
            return processedOperations
        }
    }
    
    // MARK: - Memory Consolidation
    
    /// Consolidate working memory and clean up expired items
    public func consolidate() async -> ConsolidationResult {
        return await lock.withLock {
            let startTime = Date()
            let initialItemCount = workingStorage.count
            
            logger.info("Starting working memory consolidation")
            
            // Remove expired items
            let now = Date()
            let expiredItems = workingStorage.filter { _, item in
                item.expiration < now
            }
            
            for (itemId, _) in expiredItems {
                workingStorage.removeValue(forKey: itemId)
                activeContext.removeItem(itemId)
            }
            
            // Clean up old context history
            let cutoffDate = now.addingTimeInterval(-configuration.contextHistoryRetention)
            contextHistory = contextHistory.filter { $0.timestamp > cutoffDate }
            
            // Process attention decay
            await attentionState.applyDecay(configuration.attentionDecayRate)
            
            // Clean up completed pending operations
            let completedOperations = pendingOperations.filter { _, op in
                op.scheduledTime.addingTimeInterval(3600) < now // 1 hour timeout
            }
            
            for (opId, _) in completedOperations {
                pendingOperations.removeValue(forKey: opId)
            }
            
            // Update focus based on current priorities
            await focusManager.updateBasedOnPriorities(Array(workingStorage.values))
            
            let consolidationTime = Date().timeIntervalSince(startTime)
            let finalItemCount = workingStorage.count
            
            let result = ConsolidationResult(
                duration: consolidationTime,
                itemsRemoved: initialItemCount - finalItemCount,
                itemsRetained: finalItemCount,
                contextHistoryCleaned: expiredItems.count,
                attentionUpdated: true,
                focusUpdated: true
            )
            
            logger.info("Consolidation completed: \(result.itemsRemoved) items removed, \(result.itemsRetained) retained")
            
            return result
        }
    }
    
    // MARK: - Analytics
    
    /// Get working memory analytics
    public func getAnalytics() async -> WorkingMemoryAnalytics {
        return await lock.withLock {
            let itemsByType = Dictionary(grouping: workingStorage.values) { $0.type }
                .mapValues { $0.count }
            
            let averagePriority = workingStorage.values.isEmpty ? 0.0 :
                workingStorage.values.map { $0.priority }.reduce(0, +) / Double(workingStorage.count)
            
            let expiringItems = workingStorage.values.filter { item in
                item.expiration.timeIntervalSince(Date()) < 300 // 5 minutes
            }.count
            
            return WorkingMemoryAnalytics(
                totalItems: workingStorage.count,
                itemsByType: itemsByType,
                averagePriority: averagePriority,
                contextDepth: contextStack.count,
                contextSwitches: contextSwitchCount,
                attentionLevel: attentionState.currentLevel,
                focusTargets: attentionState.focusTargets.count,
                pendingOperations: pendingOperations.count,
                temporaryVariables: temporaryVariables.count,
                expiringItems: expiringItems,
                lastConsolidation: Date(), // This would be tracked separately
                memoryPressure: calculateMemoryPressure()
            )
        }
    }
    
    // MARK: - Private Implementation
    
    private func manageContextCapacity() async {
        // Remove lowest priority items if over capacity
        if activeContext.itemCount > configuration.contextCapacity {
            let excessCount = activeContext.itemCount - configuration.contextCapacity
            await activeContext.removeLowPriorityItems(count: excessCount)
            
            logger.debug("Removed \(excessCount) items due to capacity limit")
        }
    }
    
    private func switchToContext(_ frame: ContextFrame) async {
        // Update active context based on frame
        activeContext.switchTo(frame)
        
        // Adjust attention state
        await attentionState.switchContext(to: frame)
        
        // Update focus
        if let focusTarget = frame.focusTarget {
            await focusManager.updateFocus(on: focusTarget)
        }
    }
    
    private func restoreFromSnapshot(_ snapshot: ContextSnapshot) async {
        activeContext = snapshot.activeContext
        attentionState = snapshot.attentionState
        
        if let focusTarget = snapshot.focusTarget {
            await focusManager.updateFocus(on: focusTarget)
        }
    }
    
    private func boostItemPriority(_ itemId: String, by amount: Double) async {
        if var item = workingStorage[itemId] {
            item.priority = min(1.0, item.priority + amount)
            workingStorage[itemId] = item
            
            activeContext.updateItemPriority(itemId, priority: item.priority)
        }
    }
    
    private func calculateMemoryPressure() -> Double {
        let capacityUsage = Double(workingStorage.count) / Double(configuration.maxItems)
        let contextUsage = Double(activeContext.itemCount) / Double(configuration.contextCapacity)
        
        return max(capacityUsage, contextUsage)
    }
}

// MARK: - Supporting Types

public struct WorkingMemoryConfiguration: Sendable {
    public let contextCapacity: Int
    public let maxItems: Int
    public let itemRetentionTime: TimeInterval
    public let contextHistoryRetention: TimeInterval
    public let attentionDecayRate: Double
    public let focusConfiguration: FocusConfiguration
    public let interruptionConfiguration: InterruptionConfiguration
    
    public static let `default` = WorkingMemoryConfiguration(
        contextCapacity: 50,
        maxItems: 1000,
        itemRetentionTime: 3600, // 1 hour
        contextHistoryRetention: 86400, // 24 hours
        attentionDecayRate: 0.1,
        focusConfiguration: .default,
        interruptionConfiguration: .default
    )
}

public struct WorkingMemoryItem: Sendable {
    public let id: String
    public let content: Any
    public let type: String
    public var priority: Double
    public let expiration: Date
    public let associatedContext: String?
    public let metadata: [String: Any]
    public var lastAccessed: Date
    
    public init(id: String, content: Any, type: String, priority: Double, expiration: Date, associatedContext: String?, metadata: [String: Any]) {
        self.id = id
        self.content = content
        self.type = type
        self.priority = priority
        self.expiration = expiration
        self.associatedContext = associatedContext
        self.metadata = metadata
        self.lastAccessed = Date()
    }
}

public struct ContextUpdate: Sendable {
    public let id: String
    public let type: String
    public let content: Any
    public let priority: Double
    public let focusTarget: String?
    public let persistent: Bool
    public let associatedContext: String?
    public let metadata: [String: Any]
}

public struct ContextFrame: Sendable {
    public let name: String
    public let type: ContextFrameType
    public let priority: Double
    public let content: Any
    public let expectedDuration: TimeInterval
    public let parentContext: String?
    public let focusTarget: String?
    
    public init(name: String, type: ContextFrameType, priority: Double, content: Any, expectedDuration: TimeInterval, parentContext: String?, focusTarget: String? = nil) {
        self.name = name
        self.type = type
        self.priority = priority
        self.content = content
        self.expectedDuration = expectedDuration
        self.parentContext = parentContext
        self.focusTarget = focusTarget
    }
}

public enum ContextFrameType: String, Sendable, CaseIterable {
    case task
    case conversation
    case interruption
    case background
    case emergency
}

public struct ActiveContext: Sendable {
    public let id: String
    public let capacity: Int
    public var items: [String: ContextItem]
    public var lastUpdate: Date
    
    public var itemCount: Int { items.count }
    
    public init(capacity: Int) {
        self.id = UUID().uuidString
        self.capacity = capacity
        self.items = [:]
        self.lastUpdate = Date()
    }
    
    public mutating func apply(_ update: ContextUpdate) {
        let item = ContextItem(
            id: update.id,
            content: update.content,
            type: update.type,
            priority: update.priority,
            timestamp: Date()
        )
        items[update.id] = item
        lastUpdate = Date()
    }
    
    public mutating func removeItem(_ itemId: String) {
        items.removeValue(forKey: itemId)
        lastUpdate = Date()
    }
    
    public mutating func updateItemPriority(_ itemId: String, priority: Double) {
        items[itemId]?.priority = priority
        lastUpdate = Date()
    }
    
    public mutating func removeLowPriorityItems(count: Int) {
        let sortedItems = items.values.sorted { $0.priority < $1.priority }
        let itemsToRemove = Array(sortedItems.prefix(count))
        
        for item in itemsToRemove {
            items.removeValue(forKey: item.id)
        }
        
        lastUpdate = Date()
    }
    
    public func copy() -> ActiveContext {
        var copy = ActiveContext(capacity: capacity)
        copy.items = items
        copy.lastUpdate = lastUpdate
        return copy
    }
    
    public mutating func switchTo(_ frame: ContextFrame) {
        // Implementation for context switching
        lastUpdate = Date()
    }
}

public struct ContextItem: Sendable {
    public let id: String
    public let content: Any
    public let type: String
    public var priority: Double
    public let timestamp: Date
}

public struct ContextSnapshot: Sendable {
    public let timestamp: Date
    public let activeContext: ActiveContext
    public let attentionState: AttentionState
    public let focusTarget: String?
}

public struct ActiveContextSnapshot: Sendable {
    public let items: [ContextItem]
    public let focusTarget: String?
    public let attentionLevel: Double
    public let temporaryVariables: [String: Any]
    public let pendingOperations: [PendingOperation]
    public let contextDepth: Int
    public let lastUpdate: Date
}

public struct AttentionState: Sendable {
    public var currentLevel: Double
    public var focusTargets: [AttentionTarget]
    public var lastUpdate: Date
    
    public init() {
        self.currentLevel = 0.5
        self.focusTargets = []
        self.lastUpdate = Date()
    }
    
    public mutating func processUpdate(_ update: ContextUpdate) async {
        // Update attention based on context change
        if update.priority > 0.7 {
            currentLevel = min(1.0, currentLevel + 0.2)
        }
        lastUpdate = Date()
    }
    
    public func copy() -> AttentionState {
        var copy = AttentionState()
        copy.currentLevel = currentLevel
        copy.focusTargets = focusTargets
        copy.lastUpdate = lastUpdate
        return copy
    }
    
    public mutating func switchContext(to frame: ContextFrame) async {
        // Adjust attention for context switch
        currentLevel = min(1.0, frame.priority)
        lastUpdate = Date()
    }
    
    public mutating func applyDecay(_ rate: Double) async {
        currentLevel = max(0.1, currentLevel * (1.0 - rate))
        lastUpdate = Date()
    }
}

public struct AttentionTarget: Sendable {
    public let itemId: String
    public let type: String
    public let importance: Double
}

public struct FocusManager: Sendable {
    public let configuration: FocusConfiguration
    public var currentFocus: String?
    public var focusIntensity: Double
    public var lastUpdate: Date
    
    public init(configuration: FocusConfiguration) {
        self.configuration = configuration
        self.currentFocus = nil
        self.focusIntensity = 0.0
        self.lastUpdate = Date()
    }
    
    public mutating func focusOn(_ targets: [AttentionTarget], intensity: Double) async {
        // Implementation for focusing on targets
        if let primaryTarget = targets.first {
            currentFocus = primaryTarget.itemId
            focusIntensity = intensity
            lastUpdate = Date()
        }
    }
    
    public mutating func updateFocus(on target: String) async {
        currentFocus = target
        lastUpdate = Date()
    }
    
    public mutating func updateBasedOnPriorities(_ items: [WorkingMemoryItem]) async {
        // Update focus based on item priorities
        if let highestPriorityItem = items.max(by: { $0.priority < $1.priority }) {
            currentFocus = highestPriorityItem.id
            focusIntensity = highestPriorityItem.priority
            lastUpdate = Date()
        }
    }
}

public struct FocusConfiguration: Sendable {
    public let maxFocusTargets: Int
    public let focusDecayRate: Double
    public let refocusThreshold: Double
    
    public static let `default` = FocusConfiguration(
        maxFocusTargets: 3,
        focusDecayRate: 0.05,
        refocusThreshold: 0.3
    )
}

public struct Interruption: Sendable {
    public let id: String
    public let type: String
    public let content: Any
    public let priority: Double
    public let urgency: Double
    public let focusTarget: String?
    public let metadata: [String: Any]
}

public struct InterruptionHandler: Sendable {
    public let configuration: InterruptionConfiguration
    
    public init(configuration: InterruptionConfiguration) {
        self.configuration = configuration
    }
    
    public func process(_ interruption: Interruption, currentContext: ActiveContext) async -> InterruptionResponse {
        let shouldHandle = interruption.priority > configuration.minimumPriority ||
                          interruption.urgency > configuration.urgencyThreshold
        
        if !shouldHandle {
            return InterruptionResponse(action: .ignore)
        }
        
        if interruption.priority > 0.9 {
            return InterruptionResponse(action: .contextSwitch, estimatedDuration: 120)
        } else if interruption.priority > 0.7 {
            return InterruptionResponse(action: .integrate)
        } else {
            return InterruptionResponse(action: .defer, deferTime: 300)
        }
    }
}

public struct InterruptionConfiguration: Sendable {
    public let minimumPriority: Double
    public let urgencyThreshold: Double
    public let maxDeferTime: TimeInterval
    
    public static let `default` = InterruptionConfiguration(
        minimumPriority: 0.3,
        urgencyThreshold: 0.8,
        maxDeferTime: 3600
    )
}

public struct InterruptionResponse: Sendable {
    public let action: InterruptionAction
    public let deferTime: TimeInterval?
    public let estimatedDuration: TimeInterval?
    
    public init(action: InterruptionAction, deferTime: TimeInterval? = nil, estimatedDuration: TimeInterval? = nil) {
        self.action = action
        self.deferTime = deferTime
        self.estimatedDuration = estimatedDuration
    }
}

public enum InterruptionAction: String, Sendable, CaseIterable {
    case ignore
    case defer
    case contextSwitch
    case integrate
}

public struct PendingOperation: Sendable {
    public let id: String
    public let type: PendingOperationType
    public let content: Any
    public let priority: Double
    public let scheduledTime: Date
    public let maxAttempts: Int
    public var currentAttempts: Int
    
    public init(id: String, type: PendingOperationType, content: Any, priority: Double, scheduledTime: Date, maxAttempts: Int) {
        self.id = id
        self.type = type
        self.content = content
        self.priority = priority
        self.scheduledTime = scheduledTime
        self.maxAttempts = maxAttempts
        self.currentAttempts = 0
    }
}

public enum PendingOperationType: String, Sendable, CaseIterable {
    case deferred
    case scheduled
    case retry
    case background
}

public struct ProcessedOperation: Sendable {
    public let id: String
    public let originalOperation: PendingOperation
    public let processedAt: Date
    public let success: Bool
    public let result: String
}

public struct ConsolidationResult: Sendable {
    public let duration: TimeInterval
    public let itemsRemoved: Int
    public let itemsRetained: Int
    public let contextHistoryCleaned: Int
    public let attentionUpdated: Bool
    public let focusUpdated: Bool
}

public struct WorkingMemoryAnalytics: Sendable {
    public let totalItems: Int
    public let itemsByType: [String: Int]
    public let averagePriority: Double
    public let contextDepth: Int
    public let contextSwitches: Int
    public let attentionLevel: Double
    public let focusTargets: Int
    public let pendingOperations: Int
    public let temporaryVariables: Int
    public let expiringItems: Int
    public let lastConsolidation: Date
    public let memoryPressure: Double
}

// MARK: - Async Lock

private actor AsyncLock {
    func withLock<T>(_ operation: () async throws -> T) async rethrows -> T {
        return try await operation()
    }
}