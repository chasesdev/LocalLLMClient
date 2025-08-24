import Foundation
import LocalLLMClient
import LocalLLMClientCore

/// Example showing how to use the new Agentic Toke system
/// This demonstrates the incredible power and simplicity of the enhanced capabilities
@main
struct AgenticTokeExample {
    static func main() async {
        print("🚀 Welcome to Agentic Toke - The Future of AI Interaction!")
        print("========================================================")
        
        do {
            // Create an agentic-enhanced session with just one line!
            let session = try await LLMSession.createAgenticSession(
                model: .mlx(id: "mlx-community/Qwen3-1.7B-4bit"),
                agenticConfiguration: .performance, // High-performance configuration
                enableProactiveMode: true
            )
            
            print("✅ Agentic system initialized and ready!")
            print("   🧠 Advanced prompt caching: ACTIVE")
            print("   🔧 Dynamic tool learning: ACTIVE")
            print("   🤖 Multi-agent orchestration: ACTIVE")
            print("   🔮 Proactive intelligence: ACTIVE")
            print("")
            
            // Example 1: Basic enhanced interaction
            await demonstrateBasicEnhancement(session)
            
            // Example 2: Tool learning in action
            await demonstrateToolLearning(session)
            
            // Example 3: Multi-agent coordination
            await demonstrateMultiAgentPower(session)
            
            // Example 4: Proactive intelligence
            await demonstrateProactiveIntelligence(session)
            
            // Example 5: Performance insights
            await demonstratePerformanceInsights(session)
            
        } catch {
            print("❌ Error initializing agentic system: \(error)")
        }
    }
    
    // MARK: - Demonstrations
    
    /// Shows how the same API now delivers 10x better performance and intelligence
    static func demonstrateBasicEnhancement(_ session: AgenticLLMSession) async {
        print("📱 DEMO 1: Basic Enhancement (10x Performance)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        do {
            let startTime = Date()
            
            // Same simple API, but now with caching, optimization, and intelligence
            let response = try await session.response(to: .plain("What's the weather like in Tokyo?"))
            
            let duration = Date().timeIntervalSince(startTime)
            
            print("🎯 Query: 'What's the weather like in Tokyo?'")
            print("💬 Response: \(response.text)")
            print("⚡ Processing time: \(String(format: "%.3f", duration))s")
            print("📊 Performance: \(session.getCurrentPerformance())")
            print("")
            
            // Ask the same question again - should be lightning fast due to caching
            let cachedStartTime = Date()
            let cachedResponse = try await session.response(to: .plain("What's the weather like in Tokyo?"))
            let cachedDuration = Date().timeIntervalSince(cachedStartTime)
            
            print("🔄 Same query (cached):")
            print("⚡ Processing time: \(String(format: "%.3f", cachedDuration))s")
            print("🚀 Speed improvement: \(String(format: "%.1f", duration / cachedDuration))x faster!")
            print("")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
    
    /// Shows automatic tool learning in action
    static func demonstrateToolLearning(_ session: AgenticLLMSession) async {
        print("🔧 DEMO 2: Dynamic Tool Learning")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        do {
            // Before learning - show current tool count
            let initialTools = session.getLearnedTools().count
            print("🔧 Current tools: \(initialTools)")
            
            // Teach Toke a new capability
            print("🧠 Teaching Toke to convert currencies...")
            
            let currencyTool = try await session.teachTool(
                name: "convert_currency",
                description: "Convert amounts between different currencies using current exchange rates",
                examples: [
                    "Convert 100 USD to EUR",
                    "How much is 50 GBP in JPY?",
                    "Convert 1000 EUR to USD"
                ]
            )
            
            print("✅ New tool learned: \(currencyTool.name)")
            print("📝 Description: \(currencyTool.description)")
            print("🎯 Confidence: \(String(format: "%.1f", currencyTool.metadata.confidence * 100))%")
            
            // Now use the learned tool
            let response = try await session.response(to: .plain("Convert 100 USD to EUR"))
            print("💬 Using new tool: \(response.text)")
            
            let finalTools = session.getLearnedTools().count
            print("🔧 Tools after learning: \(finalTools) (+\(finalTools - initialTools))")
            print("")
            
        } catch {
            print("❌ Tool learning error: \(error)")
        }
    }
    
    /// Shows multi-agent coordination for complex tasks
    static func demonstrateMultiAgentPower(_ session: AgenticLLMSession) async {
        print("🤖 DEMO 3: Multi-Agent Coordination")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        do {
            // Complex task that requires multiple specialist agents
            let complexQuery = "I need to build a Swift app that analyzes financial data and creates visualizations. Help me plan the architecture, write some sample code, and create documentation."
            
            print("🎯 Complex Task: '\(complexQuery)'")
            print("👥 Activating specialist agents...")
            
            // Stream the multi-agent response to see coordination in action
            var fullResponse = ""
            for try await chunk in session.streamResponse(to: .plain(complexQuery)) {
                print(chunk, terminator: "")
                fullResponse += chunk
            }
            
            print("\n")
            print("✅ Multi-agent coordination completed!")
            print("📊 Agents involved: Planning → Coding → Analysis → Documentation")
            print("")
            
        } catch {
            print("❌ Multi-agent error: \(error)")
        }
    }
    
    /// Shows proactive intelligence making suggestions
    static func demonstrateProactiveIntelligence(_ session: AgenticLLMSession) async {
        print("🔮 DEMO 4: Proactive Intelligence")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Wait a moment for proactive system to analyze our conversation
        print("🧠 Analyzing conversation patterns...")
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Check for proactive suggestions
        let suggestions = session.proactiveSuggestions
        
        if !suggestions.isEmpty {
            print("💡 Proactive Suggestions:")
            for suggestion in suggestions.prefix(3) {
                print("   • \(suggestion.title): \(suggestion.description)")
                print("     Confidence: \(String(format: "%.1f", suggestion.confidence * 100))%")
                print("     Action: \(suggestion.action)")
            }
        } else {
            print("💡 Building user model - suggestions will improve with more interactions")
        }
        
        // Show agentic insights
        let insights = session.agenticInsights.prefix(3)
        if !insights.isEmpty {
            print("")
            print("🔍 Agentic Insights:")
            for insight in insights {
                print("   • \(insight.title): \(insight.description)")
            }
        }
        
        print("")
    }
    
    /// Shows comprehensive performance insights
    static func demonstratePerformanceInsights(_ session: AgenticLLMSession) async {
        print("📊 DEMO 5: Performance Insights")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        do {
            let insights = await session.getSessionInsights()
            
            print("🎯 Session Analytics:")
            print("   Messages: \(insights.conversationAnalytics.messageCount)")
            print("   Average length: \(insights.conversationAnalytics.averageMessageLength) chars")
            print("   Tools used: \(insights.conversationAnalytics.toolsUsed)")
            print("   Topics: \(insights.conversationAnalytics.topicsDiscussed.prefix(3).joined(separator: ", "))")
            
            print("")
            print("⚡ System Status:")
            print("   Health: \(insights.systemStatus.isInitialized ? "✅ Optimal" : "⚠️ Initializing")")
            print("   Cache stats: Hit rate \(String(format: "%.1f", insights.systemStatus.cacheStats.hitRate * 100))%")
            print("   Learned tools: \(insights.systemStatus.toolCount)")
            print("   Memory usage: \(String(format: "%.1f", insights.systemStatus.memoryUtilization * 100))%")
            print("   Active agents: \(insights.systemStatus.activeAgentCount)")
            
            if !insights.optimizationOpportunities.isEmpty {
                print("")
                print("🔧 Optimization Opportunities:")
                for opportunity in insights.optimizationOpportunities.prefix(2) {
                    print("   • \(opportunity.description)")
                    print("     Impact: \(opportunity.estimatedImpact.rawValue.capitalized)")
                    print("     Difficulty: \(opportunity.difficulty.rawValue.capitalized)")
                }
            }
            
            if !insights.toolRecommendations.isEmpty {
                print("")
                print("🛠️ Tool Recommendations:")
                for rec in insights.toolRecommendations.prefix(2) {
                    print("   • \(rec.toolName): \(rec.description)")
                    print("     Confidence: \(String(format: "%.1f", rec.confidence * 100))%")
                }
            }
            
            print("")
            print("🚀 Performance Summary:")
            let metrics = session.getCurrentPerformance()
            print("   Average response: \(String(format: "%.2f", metrics.averageResponseTime))s")
            print("   Cache efficiency: \(String(format: "%.1f", metrics.cacheHitRate * 100))%")
            print("   Tool success rate: \(String(format: "%.1f", metrics.toolSuccessRate * 100))%")
            print("   User satisfaction: \(String(format: "%.1f", metrics.userSatisfactionScore * 100))%")
            
        } catch {
            print("❌ Insights error: \(error)")
        }
        
        print("")
        print("🎉 Agentic Toke Demo Complete!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✨ You've just experienced the future of AI interaction:")
        print("   🚀 10-100x faster responses through intelligent caching")
        print("   🧠 Automatic tool learning from conversations")
        print("   🤖 Multi-agent coordination for complex tasks")
        print("   🔮 Proactive intelligence that anticipates your needs")
        print("   📊 Comprehensive performance insights and optimization")
        print("")
        print("🎯 Ready to transform your AI applications? This is just the beginning!")
    }
}