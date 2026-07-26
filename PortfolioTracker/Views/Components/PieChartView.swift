//
//  PieChartView.swift
//  PortfolioTracker
//

import SwiftUI

struct PieSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

struct PieChartView: View {
    let slices: [PieSlice]
    let size: CGFloat
    
    init(slices: [PieSlice], size: CGFloat = 120) {
        self.slices = slices
        self.size = size
    }
    
    private var total: Double {
        slices.reduce(0) { $0 + $1.value }
    }
    
    var body: some View {
        if total > 0 {
            HStack(spacing: 20) {
                // Pie Chart
                ZStack {
                    ForEach(Array(sliceAngles.enumerated()), id: \.element.id) { index, slice in
                        PieSliceShape(startAngle: slice.start, endAngle: slice.end)
                            .fill(AppTheme.chartColors[index % AppTheme.chartColors.count])
                    }
                }
                .frame(width: size, height: size)
                
                // Legend
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(AppTheme.chartColors[index % AppTheme.chartColors.count])
                                .frame(width: 10, height: 10)
                            
                            Text("\(slice.label) (\(String(format: "%.1f", (slice.value / total) * 100))%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var sliceAngles: [(id: UUID, start: Angle, end: Angle)] {
        var angles: [(id: UUID, start: Angle, end: Angle)] = []
        var currentAngle = Angle.degrees(-90)
        
        for slice in slices {
            let sweep = Angle.degrees((slice.value / total) * 360)
            angles.append((id: slice.id, start: currentAngle, end: currentAngle + sweep))
            currentAngle += sweep
        }
        return angles
    }
}

struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        
        return path
    }
}
