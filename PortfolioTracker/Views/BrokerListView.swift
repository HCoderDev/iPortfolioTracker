//
//  BrokerListView.swift
//  PortfolioTracker
//

import SwiftUI
import SwiftData

struct BrokerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Broker.name) private var brokers: [Broker]
    
    @State private var showAddAlert = false
    @State private var showEditAlert = false
    @State private var brokerName = ""
    @State private var brokerToEdit: Broker?
    
    var body: some View {
        List {
            if brokers.isEmpty {
                ContentUnavailableView(
                    "No Brokers",
                    systemImage: "building.columns",
                    description: Text("Add a broker to track your investments.")
                )
            } else {
                ForEach(brokers) { broker in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(broker.name)
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        Button {
                            brokerToEdit = broker
                            brokerName = broker.name
                            showEditAlert = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                        
                        Button(role: .destructive) {
                            deleteBroker(broker)
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .foregroundStyle(AppTheme.loss)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteBrokers)
            }
        }
        .navigationTitle("Brokers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    brokerName = ""
                    showAddAlert = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .alert("Add Broker", isPresented: $showAddAlert) {
            TextField("Broker Name (e.g. Zerodha)", text: $brokerName)
            Button("Cancel", role: .cancel) { brokerName = "" }
            Button("Save") {
                if !brokerName.trimmingCharacters(in: .whitespaces).isEmpty {
                    modelContext.insert(Broker(name: brokerName.trimmingCharacters(in: .whitespaces)))
                    brokerName = ""
                }
            }
        }
        .alert("Edit Broker", isPresented: $showEditAlert) {
            TextField("Broker Name", text: $brokerName)
            Button("Cancel", role: .cancel) { brokerName = "" }
            Button("Delete", role: .destructive) {
                if let broker = brokerToEdit {
                    deleteBroker(broker)
                }
                brokerName = ""
                brokerToEdit = nil
            }
            Button("Save") {
                if let broker = brokerToEdit, !brokerName.trimmingCharacters(in: .whitespaces).isEmpty {
                    broker.name = brokerName.trimmingCharacters(in: .whitespaces)
                    brokerName = ""
                    brokerToEdit = nil
                }
            }
        }
    }
    
    private func deleteBrokers(offsets: IndexSet) {
        for index in offsets {
            deleteBroker(brokers[index])
        }
    }
    
    private func deleteBroker(_ broker: Broker) {
        let txDescriptor = FetchDescriptor<AssetTransaction>()
        if let allTransactions = try? modelContext.fetch(txDescriptor) {
            for transaction in allTransactions where transaction.broker?.persistentModelID == broker.persistentModelID {
                transaction.broker = nil
            }
        }
        modelContext.delete(broker)
    }
}
