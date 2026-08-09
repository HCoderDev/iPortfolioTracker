//
//  AppTheme.swift
//  PortfolioTracker
//

import SwiftUI

struct AppTheme {
    // MARK: - Accent Colors (Apple HIG Palette)
    static let accent = Color(hex: "0A84FF")         // System Blue / Indigo
    static let accentSecondary = Color(hex: "5E5CE6") // Purple Accent
    static let profit = Color(hex: "30D158")          // Apple Stocks Green
    static let gain = Color(hex: "30D158")            // Apple Stocks Green Alias
    static let loss = Color(hex: "FF453A")            // Apple Stocks Red
    static let warning = Color(hex: "FF9F0A")         // System Amber
    
    // MARK: - Surface Colors (Translucent & Adaptive)
    static let cardBackground = Color(hex: "1C1C1E")
    static let cardBackgroundElevated = Color(hex: "2C2C2E")
    static let surfaceOverlay = Color.primary.opacity(0.04)
    static let subtleBorder = Color.primary.opacity(0.08)
    
    // MARK: - Gradients
    static let heroGradient = LinearGradient(
        colors: [Color(hex: "0A84FF"), Color(hex: "5E5CE6")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let profitGradient = LinearGradient(
        colors: [Color(hex: "30D158"), Color(hex: "28CD41")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let lossGradient = LinearGradient(
        colors: [Color(hex: "FF453A"), Color(hex: "FF3B30")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // MARK: - Chart Palette
    static let chartColors: [Color] = [
        Color(hex: "0A84FF"),
        Color(hex: "30D158"),
        Color(hex: "FF9F0A"),
        Color(hex: "BF5AF2"),
        Color(hex: "FF453A"),
        Color(hex: "64D2FF"),
        Color(hex: "FFD60A"),
        Color(hex: "AC8E68"),
        Color(hex: "5E5CE6"),
        Color(hex: "FF375F")
    ]
    
    // MARK: - Card Styles
    static func cardStyle() -> some ViewModifier {
        CardModifier()
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.subtleBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Gain / Loss Pill Badge
struct GainLossBadge: View {
    let value: Double
    let percentage: Double?
    var isCompact: Bool = false
    
    private var isPositive: Bool { value >= 0 }
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isPositive ? "triangle.fill" : "triangle.fill")
                .font(.system(size: isCompact ? 6 : 8, weight: .bold))
                .rotationEffect(isPositive ? .degrees(0) : .degrees(180))
            
            Text(formattedText)
                .font(.system(size: isCompact ? 11 : 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(isPositive ? AppTheme.profit : AppTheme.loss)
        .padding(.horizontal, isCompact ? 6 : 8)
        .padding(.vertical, isCompact ? 2 : 4)
        .background(
            Capsule()
                .fill((isPositive ? AppTheme.profit : AppTheme.loss).opacity(0.12))
        )
    }
    
    private var formattedText: String {
        let prefix = isPositive ? "+" : ""
        if let pct = percentage {
            return "\(prefix)\(pct.formatted2)%"
        } else {
            return "\(prefix)₹\(abs(value).formattedComma)"
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

// MARK: - Formatting Helpers
extension Double {
    var formatted1: String {
        String(format: "%.1f", self)
    }
    
    var formatted2: String {
        String(format: "%.2f", self)
    }
    
    var formattedComma: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
    }
    
    var formattedCompact: String {
        formattedCompactChart(currencyCode: "INR")
    }
    
    func formattedCompactChart(currencyCode: String = "INR") -> String {
        if self == 0 { return "0" }
        let sign = self < 0 ? "-" : ""
        let absVal = abs(self)
        
        let isINR = currencyCode.uppercased() == "INR" || currencyCode.isEmpty
        
        if isINR {
            if absVal >= 10_000_000 { // 1 Crore (10 Million)
                let val = absVal / 10_000_000
                let formatted = val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.1f", val)
                return "\(sign)\(formatted) Cr"
            } else if absVal >= 100_000 { // 1 Lakh (100 Thousand)
                let val = absVal / 100_000
                let formatted = val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.1f", val)
                return "\(sign)\(formatted) L"
            } else if absVal >= 1_000 { // 1 Thousand
                let val = absVal / 1_000
                let formatted = val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.1f", val)
                return "\(sign)\(formatted) K"
            } else {
                return "\(sign)\(String(format: "%.0f", absVal))"
            }
        } else {
            if absVal >= 1_000_000_000 {
                let val = absVal / 1_000_000_000
                let formatted = val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.1f", val)
                return "\(sign)\(formatted)B"
            } else if absVal >= 1_000_000 {
                let val = absVal / 1_000_000
                let formatted = val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.1f", val)
                return "\(sign)\(formatted)M"
            } else if absVal >= 1_000 {
                let val = absVal / 1_000
                let formatted = val.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", val) : String(format: "%.1f", val)
                return "\(sign)\(formatted)K"
            } else {
                return "\(sign)\(String(format: "%.0f", absVal))"
            }
        }
    }
}

