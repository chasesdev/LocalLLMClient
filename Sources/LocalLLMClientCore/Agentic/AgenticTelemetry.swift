import Foundation
import LocalLLMClientUtility

/// Comprehensive telemetry system for monitoring agentic performance
/// Provides real-time insights into system efficiency, user satisfaction, and optimization opportunities
public final class AgenticTelemetrySystem: ObservableObject, Sendable {
    
    // MARK: - Core Metrics Storage
    
    private let metricsStore = Locked<[TelemetryMetric: MetricTimeSeries]>([:])
    private let eventBuffer = Locked<[TelemetryEvent]>([])
    private let performanceProfiler = PerformanceProfiler()
    private let userAnalytics = UserAnalyticsTracker()
    
    // MARK: - Configuration
    
    private let enabledMetrics: Set<TelemetryMetric>
    private let reportingInterval: TimeInterval
    private let bufferSize: Int
    private let retentionPeriod: TimeInterval
    
    // MARK: - Real-time Monitoring
    
    @Published public private(set) var systemHealth: SystemHealthStatus = .optimal
    @Published public private(set) var realTimeMetrics: [TelemetryMetric: Double] = [:]
    @Published public private(set) var performanceAlerts: [PerformanceAlert] = []
    @Published public private(set) var usageInsights: [UsageInsight] = []
    
    private var reportingTimer: Timer?
    private var monitoredSystems: [MonitoredSystem] = []
    
    // MARK: - Initialization
    
    public init(
        enabledMetrics: Set<TelemetryMetric>,
        reportingInterval: TimeInterval = 60,
        bufferSize: Int = 10000,
        retentionPeriod: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    ) {
        self.enabledMetrics = enabledMetrics
        self.reportingInterval = reportingInterval
        self.bufferSize = bufferSize
        self.retentionPeriod = retentionPeriod
        
        print("📊 Agentic Telemetry System initialized")
        print("   Enabled metrics: \(enabledMetrics.count)")
        print("   Reporting interval: \(reportingInterval)s")
    }
    
    public func initialize() async throws {
        await initializeMetrics()
        startReporting()
        
        print("🚀 Telemetry system active - monitoring \(enabledMetrics.count) metrics")
    }
    
    // MARK: - Metric Recording
    
    /// Record a metric value
    public func recordMetric(_ metric: TelemetryMetric, value: Double) {
        guard enabledMetrics.contains(metric) else { return }
        
        let timestamp = Date()
        let dataPoint = MetricDataPoint(value: value, timestamp: timestamp)
        
        metricsStore.withLock { store in
            if var series = store[metric] {
                series.addDataPoint(dataPoint)
                store[metric] = series
            } else {
                store[metric] = MetricTimeSeries(metric: metric, dataPoints: [dataPoint])
            }
        }
        
        // Update real-time display
        Task { @MainActor in
            realTimeMetrics[metric] = value
            updateSystemHealth()
            checkForAlerts(metric: metric, value: value)
        }
    }
    
    /// Record a cache hit for performance tracking
    public func recordCacheHit() {
        recordMetric(.cacheHitRate, value: 1.0)
        recordEvent(.cacheHit, metadata: ["timestamp": ISO8601DateFormatter().string(from: Date())])
    }
    
    /// Record an event for detailed analysis
    public func recordEvent(_ eventType: TelemetryEventType, metadata: [String: String] = [:]) {
        let event = TelemetryEvent(
            type: eventType,
            timestamp: Date(),
            metadata: metadata
        )
        
        eventBuffer.withLock { buffer in
            buffer.append(event)
            
            // Maintain buffer size
            if buffer.count > bufferSize {
                buffer.removeFirst(buffer.count - bufferSize)
            }
        }
    }
    
    // MARK: - System Monitoring Integration
    
    /// Monitor a system component for automatic metric collection
    public func monitor(_ system: any MonitorableSystem) {
        let monitoredSystem = MonitoredSystem(
            name: system.systemName,
            system: system,
            lastCheck: Date()
        )
        monitoredSystems.append(monitoredSystem)
        
        // Start monitoring
        Task.detached { [weak self] in
            await self?.startMonitoring(monitoredSystem)
        }
    }
    
    private func startMonitoring(_ monitoredSystem: MonitoredSystem) async {
        while true {
            do {
                let metrics = await monitoredSystem.system.collectMetrics()
                
                for (metric, value) in metrics {
                    recordMetric(metric, value: value)
                }
                
                // Sleep until next collection interval
                try await Task.sleep(nanoseconds: UInt64(5 * 1_000_000_000)) // 5 seconds
                
            } catch {
                recordEvent(.monitoringError, metadata: [
                    "system": monitoredSystem.name,
                    "error": error.localizedDescription
                ])
                break
            }
        }
    }
    
    // MARK: - Performance Analysis
    
    /// Get comprehensive performance report
    public func getPerformanceReport(timeRange: TimeRange? = nil) async -> PerformanceReport {
        let range = timeRange ?? TimeRange.last(hours: 24)
        
        let metrics = await metricsStore.withLock { store in
            store.compactMapValues { series in
                series.getValuesInRange(range)
            }
        }
        
        let events = await eventBuffer.withLock { buffer in
            buffer.filter { range.contains($0.timestamp) }
        }
        
        let insights = await generateInsights(from: metrics, events: events)
        let recommendations = await generateRecommendations(from: insights)
        
        return PerformanceReport(
            timeRange: range,
            metrics: metrics,
            events: events,
            insights: insights,
            recommendations: recommendations,
            systemHealth: systemHealth,
            generatedAt: Date()
        )
    }
    
    /// Get user behavior insights
    public func getUserInsights(for timeRange: TimeRange) async -> [UserInsight] {
        return await userAnalytics.generateInsights(for: timeRange)
    }
    
    /// Get optimization recommendations
    public func getOptimizationRecommendations() async -> [OptimizationRecommendation] {
        let currentMetrics = await getCurrentMetrics()
        return await generateOptimizations(from: currentMetrics)
    }
    
    // MARK: - Real-time Monitoring
    
    private func startReporting() {
        reportingTimer = Timer.scheduledTimer(withTimeInterval: reportingInterval, repeats: true) { _ in
            Task { [weak self] in
                await self?.generateReport()
                await self?.cleanupOldData()
                await self?.updateInsights()
            }
        }
    }
    
    private func generateReport() async {
        let report = await getPerformanceReport()
        
        // Log key metrics
        print("📊 Telemetry Report:")
        for (metric, values) in report.metrics {
            let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
            print("   \(metric.rawValue): \(String(format: "%.2f", avg))")
        }
        
        // Check for performance issues
        await checkSystemHealth(report)
    }
    
    private func cleanupOldData() async {
        let cutoffDate = Date().addingTimeInterval(-retentionPeriod)
        
        await metricsStore.withLock { store in
            for (metric, var series) in store {
                series.removeDataBefore(cutoffDate)
                store[metric] = series
            }
        }
        
        await eventBuffer.withLock { buffer in
            buffer.removeAll { $0.timestamp < cutoffDate }
        }
    }
    
    private func updateInsights() async {
        let newInsights = await generateCurrentInsights()
        
        Task { @MainActor in
            usageInsights = newInsights
        }
    }
    
    // MARK: - Health and Alerting
    
    @MainActor
    private func updateSystemHealth() {
        let criticalMetrics = [
            TelemetryMetric.responseTime,
            TelemetryMetric.memoryUsage,
            TelemetryMetric.errorRate
        ]
        
        var healthScores: [Double] = []
        
        for metric in criticalMetrics {
            if let value = realTimeMetrics[metric] {
                let score = calculateHealthScore(for: metric, value: value)
                healthScores.append(score)
            }
        }
        
        let overallScore = healthScores.isEmpty ? 1.0 : healthScores.reduce(0, +) / Double(healthScores.count)
        
        systemHealth = switch overallScore {
        case 0.9...1.0: .optimal
        case 0.7..<0.9: .good
        case 0.5..<0.7: .warning
        case 0.3..<0.5: .critical
        default: .degraded
        }
    }
    
    @MainActor
    private func checkForAlerts(metric: TelemetryMetric, value: Double) {
        let threshold = getAlertThreshold(for: metric)
        
        if shouldAlert(metric: metric, value: value, threshold: threshold) {
            let alert = PerformanceAlert(
                metric: metric,
                value: value,
                threshold: threshold,
                severity: getAlertSeverity(metric: metric, value: value, threshold: threshold),
                timestamp: Date(),
                description: generateAlertDescription(metric: metric, value: value, threshold: threshold)
            )
            
            performanceAlerts.insert(alert, at: 0)
            
            // Limit alert history
            if performanceAlerts.count > 100 {
                performanceAlerts = Array(performanceAlerts.prefix(100))
            }
        }
    }
    
    // MARK: - Analytics and Insights
    
    private func generateInsights(
        from metrics: [TelemetryMetric: [Double]],
        events: [TelemetryEvent]
    ) async -> [PerformanceInsight] {
        var insights: [PerformanceInsight] = []
        
        // Response time analysis
        if let responseTimes = metrics[.responseTime], !responseTimes.isEmpty {
            let avg = responseTimes.reduce(0, +) / Double(responseTimes.count)
            let trend = calculateTrend(responseTimes)
            
            insights.append(PerformanceInsight(
                type: .performance,
                title: "Response Time Analysis",
                description: "Average response time: \(String(format: "%.2f", avg))ms",
                impact: avg > 1000 ? .high : avg > 500 ? .medium : .low,
                confidence: 0.9,
                actionable: avg > 500,
                trend: trend
            ))
        }
        
        // Cache efficiency analysis
        if let cacheHitRate = metrics[.cacheHitRate]?.last {
            insights.append(PerformanceInsight(
                type: .optimization,
                title: "Cache Efficiency",
                description: "Cache hit rate: \(String(format: "%.1f", cacheHitRate * 100))%",
                impact: cacheHitRate < 0.7 ? .high : cacheHitRate < 0.85 ? .medium : .low,
                confidence: 0.85,
                actionable: cacheHitRate < 0.8,
                trend: .stable
            ))
        }
        
        // Error rate analysis
        if let errorRate = metrics[.errorRate]?.last {
            if errorRate > 0.01 { // > 1% error rate
                insights.append(PerformanceInsight(
                    type: .reliability,
                    title: "Error Rate Alert",
                    description: "Error rate: \(String(format: "%.2f", errorRate * 100))%",
                    impact: errorRate > 0.05 ? .high : .medium,
                    confidence: 0.95,
                    actionable: true,
                    trend: .increasing
                ))
            }
        }
        
        return insights
    }
    
    private func generateRecommendations(from insights: [PerformanceInsight]) async -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []
        
        for insight in insights where insight.actionable {
            switch insight.type {
            case .performance:
                if insight.title.contains("Response Time") {
                    recommendations.append(OptimizationRecommendation(
                        category: .performance,
                        title: "Optimize Response Time",
                        description: "Consider implementing more aggressive caching or request batching",
                        estimatedImpact: .high,
                        difficulty: .medium,
                        priority: insight.impact == .high ? .high : .medium
                    ))
                }
                
            case .optimization:
                if insight.title.contains("Cache") {
                    recommendations.append(OptimizationRecommendation(
                        category: .caching,
                        title: "Improve Cache Strategy",
                        description: "Analyze cache miss patterns and optimize cache key generation",
                        estimatedImpact: .medium,
                        difficulty: .low,
                        priority: .medium
                    ))
                }
                
            case .reliability:
                recommendations.append(OptimizationRecommendation(
                    category: .reliability,
                    title: "Address Error Rate",
                    description: "Investigate error patterns and implement better error handling",
                    estimatedImpact: .high,
                    difficulty: .high,
                    priority: .high
                ))
                
            default:
                continue
            }
        }
        
        return recommendations
    }
    
    private func generateCurrentInsights() async -> [UsageInsight] {
        // Placeholder - would generate ML-based usage insights
        return []
    }
    
    private func generateOptimizations(from metrics: [TelemetryMetric: Double]) async -> [OptimizationRecommendation] {
        // Placeholder - would generate specific optimization recommendations
        return []
    }
    
    // MARK: - Helper Methods
    
    private func initializeMetrics() async {
        await metricsStore.withLock { store in
            for metric in enabledMetrics {
                store[metric] = MetricTimeSeries(metric: metric, dataPoints: [])
            }
        }
    }
    
    private func getCurrentMetrics() async -> [TelemetryMetric: Double] {
        return await metricsStore.withLock { store in
            store.compactMapValues { series in
                series.dataPoints.last?.value
            }
        }
    }
    
    private func calculateHealthScore(for metric: TelemetryMetric, value: Double) -> Double {
        switch metric {
        case .responseTime:
            // Lower is better, exponential penalty for high values
            return max(0, 1 - (value / 1000)) // Normalize to 1000ms baseline
            
        case .memoryUsage:
            // Lower is better, linear scale
            return max(0, 1 - value)
            
        case .errorRate:
            // Lower is better, exponential penalty
            return max(0, 1 - (value * 100)) // Convert to percentage
            
        case .cacheHitRate:
            // Higher is better
            return value
            
        default:
            return 0.8 // Default neutral score
        }
    }
    
    private func getAlertThreshold(for metric: TelemetryMetric) -> Double {
        switch metric {
        case .responseTime: return 2000 // 2 seconds
        case .memoryUsage: return 0.9 // 90%
        case .errorRate: return 0.05 // 5%
        case .cacheHitRate: return 0.7 // 70%
        default: return Double.infinity
        }
    }
    
    private func shouldAlert(metric: TelemetryMetric, value: Double, threshold: Double) -> Bool {
        switch metric {
        case .responseTime, .memoryUsage, .errorRate:
            return value > threshold
        case .cacheHitRate:
            return value < threshold
        default:
            return false
        }
    }
    
    private func getAlertSeverity(metric: TelemetryMetric, value: Double, threshold: Double) -> AlertSeverity {
        let ratio = value / threshold
        
        switch ratio {
        case ...1.0: return .info
        case 1.0..<1.5: return .warning
        case 1.5..<2.0: return .critical
        default: return .emergency
        }
    }
    
    private func generateAlertDescription(metric: TelemetryMetric, value: Double, threshold: Double) -> String {
        switch metric {
        case .responseTime:
            return "Response time (\(String(format: "%.0f", value))ms) exceeds threshold (\(String(format: "%.0f", threshold))ms)"
        case .memoryUsage:
            return "Memory usage (\(String(format: "%.1f", value * 100))%) exceeds threshold (\(String(format: "%.1f", threshold * 100))%)"
        case .errorRate:
            return "Error rate (\(String(format: "%.2f", value * 100))%) exceeds threshold (\(String(format: "%.2f", threshold * 100))%)"
        case .cacheHitRate:
            return "Cache hit rate (\(String(format: "%.1f", value * 100))%) below threshold (\(String(format: "%.1f", threshold * 100))%)"
        default:
            return "\(metric.rawValue) alert: \(value) vs threshold \(threshold)"
        }
    }
    
    private func calculateTrend(_ values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }
        
        let recent = values.suffix(min(10, values.count))
        let firstHalf = Array(recent.prefix(recent.count / 2))
        let secondHalf = Array(recent.suffix(recent.count / 2))
        
        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let change = (secondAvg - firstAvg) / firstAvg
        
        if change > 0.1 {
            return .increasing
        } else if change < -0.1 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func checkSystemHealth(_ report: PerformanceReport) async {
        // Check for system health issues and generate alerts
        for insight in report.insights where insight.impact == .high {
            recordEvent(.healthAlert, metadata: [
                "insight": insight.title,
                "impact": insight.impact.rawValue
            ])
        }
    }
}

// MARK: - Supporting Types

public struct MetricTimeSeries: Sendable {
    let metric: TelemetryMetric
    var dataPoints: [MetricDataPoint]
    
    mutating func addDataPoint(_ point: MetricDataPoint) {
        dataPoints.append(point)
        
        // Keep only recent data for performance
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours
        dataPoints.removeAll { $0.timestamp < cutoff }
    }
    
    func getValuesInRange(_ range: TimeRange) -> [Double] {
        return dataPoints
            .filter { range.contains($0.timestamp) }
            .map { $0.value }
    }
    
    mutating func removeDataBefore(_ date: Date) {
        dataPoints.removeAll { $0.timestamp < date }
    }
}

public struct MetricDataPoint: Sendable {
    let value: Double
    let timestamp: Date
}

public struct TelemetryEvent: Sendable {
    let type: TelemetryEventType
    let timestamp: Date
    let metadata: [String: String]
}

public enum TelemetryEventType: String, CaseIterable {
    case cacheHit = "cache_hit"
    case cacheMiss = "cache_miss"
    case toolExecution = "tool_execution"
    case agentActivation = "agent_activation"
    case userInteraction = "user_interaction"
    case errorOccurred = "error_occurred"
    case monitoringError = "monitoring_error"
    case healthAlert = "health_alert"
}

public enum SystemHealthStatus: String, CaseIterable {
    case optimal = "optimal"
    case good = "good"
    case warning = "warning"
    case critical = "critical"
    case degraded = "degraded"
}

public struct PerformanceAlert: Sendable, Identifiable {
    public let id = UUID()
    let metric: TelemetryMetric
    let value: Double
    let threshold: Double
    let severity: AlertSeverity
    let timestamp: Date
    let description: String
}

public enum AlertSeverity: String, CaseIterable {
    case info = "info"
    case warning = "warning"
    case critical = "critical"
    case emergency = "emergency"
}

public struct PerformanceReport: Sendable {
    let timeRange: TimeRange
    let metrics: [TelemetryMetric: [Double]]
    let events: [TelemetryEvent]
    let insights: [PerformanceInsight]
    let recommendations: [OptimizationRecommendation]
    let systemHealth: SystemHealthStatus
    let generatedAt: Date
}

public struct PerformanceInsight: Sendable {
    let type: InsightType
    let title: String
    let description: String
    let impact: ImpactLevel
    let confidence: Double
    let actionable: Bool
    let trend: TrendDirection
}

public enum InsightType: String, CaseIterable {
    case performance = "performance"
    case optimization = "optimization"
    case reliability = "reliability"
    case usage = "usage"
}

public enum ImpactLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

public enum TrendDirection: String, CaseIterable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
}

public struct OptimizationRecommendation: Sendable {
    let category: OptimizationCategory
    let title: String
    let description: String
    let estimatedImpact: ImpactLevel
    let difficulty: DifficultyLevel
    let priority: PriorityLevel
}

public enum OptimizationCategory: String, CaseIterable {
    case performance = "performance"
    case caching = "caching"
    case memory = "memory"
    case reliability = "reliability"
    case userExperience = "user_experience"
}

public enum DifficultyLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

public enum PriorityLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
}

public struct UsageInsight: Sendable {
    let category: UsageCategory
    let title: String
    let description: String
    let value: Double
    let trend: TrendDirection
    let timestamp: Date
}

public enum UsageCategory: String, CaseIterable {
    case toolUsage = "tool_usage"
    case userBehavior = "user_behavior"
    case systemUtilization = "system_utilization"
}

public struct UserInsight: Sendable {
    let type: UserInsightType
    let description: String
    let confidence: Double
    let timestamp: Date
}

public enum UserInsightType: String, CaseIterable {
    case preference = "preference"
    case pattern = "pattern"
    case opportunity = "opportunity"
}

// MARK: - Monitoring Protocol

public protocol MonitorableSystem: Sendable {
    var systemName: String { get }
    func collectMetrics() async -> [TelemetryMetric: Double]
}

private struct MonitoredSystem: Sendable {
    let name: String
    let system: any MonitorableSystem
    let lastCheck: Date
}

// MARK: - Component Stubs

private final class PerformanceProfiler: Sendable {
    // Placeholder - would implement detailed performance profiling
}

private final class UserAnalyticsTracker: Sendable {
    func generateInsights(for timeRange: TimeRange) async -> [UserInsight] {
        // Placeholder - would implement user behavior analytics
        return []
    }
}

// MARK: - Extensions for existing types

extension TimeRange {
    func contains(_ date: Date) -> Bool {
        return date >= start && date <= end
    }
}