//
//  TimelineChartView.swift
//  PortfolioTracker
//

import SwiftUI
import Charts
import SwiftData

struct TimelinePoint: Identifiable {
    let id = UUID()
    let date: Date
    let invested: Double
    let value: Double
}

struct AssetLedger {
    var buyLots: [(remainingUnits: Double, buyPrice: Double)] = []
    var currentUnits: Double = 0.0
    
    mutating func process(type: TransactionType, units: Double, price: Double) {
        switch type {
        case .buy:
            buyLots.append((remainingUnits: units, buyPrice: price))
            currentUnits += units
        case .sell:
            var unitsToSell = units
            currentUnits -= units
            for i in stride(from: buyLots.count - 1, through: 0, by: -1) {
                if unitsToSell <= 0 { break }
                let lot = buyLots[i]
                if lot.remainingUnits > 0 {
                    let taken = min(unitsToSell, lot.remainingUnits)
                    buyLots[i].remainingUnits -= taken
                    unitsToSell -= taken
                }
            }
        case .dividend:
            break
        }
    }
    
    var invested: Double {
        buyLots.filter { $0.remainingUnits > 0 }.reduce(0.0) { $0 + ($1.remainingUnits * $1.buyPrice) }
    }
}

struct TimelineChartView: View {
    let assets: [Asset]
    let currencyCode: String
    
    private var chartData: [TimelinePoint] {
        var allTx: [(date: Date, type: TransactionType, units: Double, pricePerUnit: Double, assetId: PersistentIdentifier, createdAt: Date)] = []
        
        for asset in assets {
            for t in asset.transactions {
                allTx.append((
                    date: t.date,
                    type: t.type,
                    units: t.units,
                    pricePerUnit: t.pricePerUnit,
                    assetId: asset.persistentModelID,
                    createdAt: t.createdAt
                ))
            }
        }
        
        let sorted = allTx.sorted {
            if $0.date == $1.date {
                return $0.createdAt < $1.createdAt
            }
            return $0.date < $1.date
        }
        
        var points: [TimelinePoint] = []
        var ledgers: [PersistentIdentifier: AssetLedger] = [:]
        
        for tx in sorted {
            var ledger = ledgers[tx.assetId] ?? AssetLedger()
            ledger.process(type: tx.type, units: tx.units, price: tx.pricePerUnit)
            ledgers[tx.assetId] = ledger
            
            var totalInvested = 0.0
            var totalValue = 0.0
            
            for (assetId, l) in ledgers {
                let currentPrice = assets.first(where: { $0.persistentModelID == assetId })?.currentPrice ?? 0.0
                totalInvested += l.invested
                totalValue += max(0, l.currentUnits) * currentPrice
            }
            
            points.append(TimelinePoint(date: tx.date, invested: totalInvested, value: totalValue))
        }
        
        if let last = points.last, !Calendar.current.isDateInToday(last.date) {
            points.append(TimelinePoint(date: Date(), invested: last.invested, value: last.value))
        }
        
        return points
    }
    
    var body: some View {
        let data = chartData
        if data.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Growth Timeline")
                    .font(.headline)
                    .padding(.horizontal)
                
                let isProfit = (data.last?.value ?? 0) >= (data.last?.invested ?? 0)
                
                Chart(data) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Amount", point.invested),
                        series: .value("DataLine", "Invested")
                    )
                    .foregroundStyle(AppTheme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Amount", point.value),
                        series: .value("DataLine", "Portfolio Value")
                    )
                    .foregroundStyle(isProfit ? AppTheme.profit : AppTheme.loss)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
                .chartForegroundStyleScale([
                    "Invested": AppTheme.accent,
                    "Portfolio Value": isProfit ? AppTheme.profit : AppTheme.loss
                ])
                .chartLegend(position: .bottom)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        if let doubleVal = value.as(Double.self) {
                            AxisValueLabel {
                                Text(doubleVal.formattedCompactChart(currencyCode: currencyCode))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 220)
                .padding(.horizontal)
            }
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
}
