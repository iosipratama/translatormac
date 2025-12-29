//
//  HistoryView.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 29/12/25.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    
    @Environment(\.modelContext) private var modelContext
    @State private var showClearConfirm = false
    
    @Query(
        sort: \TranslationHistory.createdAt,
        order: .reverse
        
    )
    private var items: [TranslationHistory]
    
    var body: some View {
        VStack {
            List {
                if items.isEmpty {
                    Text("No history yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.sourceText)
                                .font(.headline)
                            Text(item.translatedText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .textSelection(.enabled)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .disabled(items.isEmpty)
            }
        }
        .confirmationDialog(
            "Clear all translation history?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                for item in items {
                    modelContext.delete(item)
                }
                do {
                    try modelContext.save()
                    print("Cleared all history (\(items.count) before delete)")
                } catch {
                    print("Failed to clear history:", error.localizedDescription)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .onAppear { print("HistoryView appeared. Items:", items.count) }
        .onChange(of: items) { _, new in print("HistoryView items changed:", new.count) }
    }
}
#Preview {
    HistoryView()
        .modelContainer(for: [TranslationHistory.self], inMemory: true)
}

