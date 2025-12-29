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

    @Query(sort: \TranslationHistory.createdAt, order: .reverse)
    private var items: [TranslationHistory]

    // Small helper to centralize deletion and saving
    private func deleteAll() {
        for item in items { modelContext.delete(item) }
        do {
            try modelContext.save()
            print("Cleared all history")
        } catch {
            print("Failed to clear history:", error.localizedDescription)
        }
    }

    private func delete(at offsets: IndexSet) {
        // Support row deletion from the list
        for index in offsets { modelContext.delete(items[index]) }
        do { try modelContext.save() } catch {
            print("Failed to delete items:", error.localizedDescription)
        }
    }

    var body: some View {
        VStack {
            if items.isEmpty {
                // Convey empty state clearly
                ContentUnavailableView("No history yet", systemImage: "clock")
                    .foregroundStyle(.secondary)
            } else {
                List {
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
                    .onDelete(perform: delete)
                }
                .textSelection(.enabled)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .disabled(items.isEmpty)
                .help("Delete all history")
            }
        }
        .confirmationDialog(
            "Clear all translation history?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive, action: deleteAll)
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

