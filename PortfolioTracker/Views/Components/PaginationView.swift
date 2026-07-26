//
//  PaginationView.swift
//  PortfolioTracker
//

import SwiftUI

struct PaginationView: View {
    @Binding var currentPage: Int
    var totalItems: Int
    var pageSize: Int = 10
    var skipCount: Int = 5
    
    var totalPages: Int {
        max(1, (totalItems + pageSize - 1) / pageSize)
    }
    
    var body: some View {
        if totalPages > 1 {
            HStack(spacing: 16) {
                // Extreme Previous
                Button {
                    currentPage = max(1, currentPage - skipCount)
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .disabled(currentPage == 1)
                
                // Previous
                Button {
                    currentPage = max(1, currentPage - 1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentPage == 1)
                
                // Current Page Info
                Text("Page \(currentPage) of \(totalPages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 80)
                
                // Next
                Button {
                    currentPage = min(totalPages, currentPage + 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentPage == totalPages)
                
                // Extreme Next
                Button {
                    currentPage = min(totalPages, currentPage + skipCount)
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .disabled(currentPage == totalPages)
            }
            .padding(.vertical, 8)
            .tint(AppTheme.accent)
        }
    }
}
