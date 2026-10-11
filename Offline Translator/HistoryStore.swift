//
//  HistoryStore.swift
//  TranslatorMac
//

import Foundation
import SwiftData
import os

/// The rules for what Recent keeps: one entry per text and language pair,
/// the newest 500 unsaved entries, and saved entries for as long as they're
/// starred. Views query the store directly; this is only for writing.
struct HistoryStore {

    var context: ModelContext

    /// Unsaved entries beyond this many are dropped, oldest first. Depends on
    /// the plan, so callers that record pass it in.
    var recentLimit: Int = PlanLimits.proHistory

    init(context: ModelContext, recentLimit: Int = PlanLimits.proHistory) {
        self.context = context
        self.recentLimit = recentLimit
    }

    /// How many entries are starred.
    func savedCount() -> Int {
        let descriptor = FetchDescriptor<TranslationHistory>(predicate: #Predicate { $0.isSaved })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// How many unsaved entries Recent holds.
    func recentCount() -> Int {
        let descriptor = FetchDescriptor<TranslationHistory>(predicate: #Predicate { !$0.isSaved })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Whether another entry can be starred under a plan's limit.
    func canSave(limit: Int?) -> Bool {
        guard let limit else { return true }
        return savedCount() < limit
    }

    /// Enforces the limit, for when the plan changes or the limit shrinks.
    func pruneRecent() {
        prune()
        save()
    }

    /// Adds a translation to Recent. If the same text in the same pair is
    /// already there, that entry is refreshed and moved to the top instead,
    /// keeping its saved state.
    @discardableResult
    func record(
        sourceText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String
    ) -> TranslationHistory {
        if let existing = existingEntry(sourceText: sourceText, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) {
            existing.translatedText = translatedText
            existing.createdAt = .now
            save()
            return existing
        }

        let entry = TranslationHistory(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        context.insert(entry)
        prune()
        save()
        return entry
    }

    /// Stars or unstars an entry, undoably when an undo manager is given.
    /// Unsaving doesn't delete: the entry stays in Recent, and the usual
    /// pruning retires it once it falls past the newest 500.
    func setSaved(_ entry: TranslationHistory, _ isSaved: Bool, undoManager: UndoManager? = nil) {
        let previousDate = entry.savedAt
        entry.isSaved = isSaved
        entry.savedAt = isSaved ? .now : nil
        save()

        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: entry) { entry in
            entry.isSaved = !isSaved
            entry.savedAt = previousDate
            self.save()
            undoManager.registerUndo(withTarget: entry) { entry in
                self.setSaved(entry, isSaved, undoManager: undoManager)
            }
        }
        undoManager.setActionName(isSaved ? String(localized: "Save Translation") : String(localized: "Remove from Saved"))
    }

    func delete(_ entries: [TranslationHistory]) {
        for entry in entries {
            context.delete(entry)
        }
        save()
    }

    /// Removes everything that isn't saved.
    func clearRecent() {
        do {
            try context.delete(model: TranslationHistory.self, where: #Predicate { !$0.isSaved })
            save()
            Log.history.notice("Cleared recent translations")
        } catch {
            Log.history.error("Failed to clear history: \(error.localizedDescription, privacy: .public)")
        }
    }

    func save() {
        do {
            try context.save()
        } catch {
            Log.history.error("Failed to save history: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Rules

    private func existingEntry(sourceText: String, sourceLanguage: String, targetLanguage: String) -> TranslationHistory? {
        var descriptor = FetchDescriptor<TranslationHistory>(
            predicate: #Predicate {
                $0.sourceText == sourceText
                    && $0.sourceLanguage == sourceLanguage
                    && $0.targetLanguage == targetLanguage
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Drops the oldest unsaved entries past the limit. Saved entries never
    /// count toward it.
    private func prune() {
        // Fetched in full and trimmed here rather than through fetchOffset,
        // which SwiftData has been seen to ignore — and ignoring it would
        // delete everything.
        let descriptor = FetchDescriptor<TranslationHistory>(
            predicate: #Predicate { !$0.isSaved },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let unsaved = try? context.fetch(descriptor), unsaved.count > recentLimit else { return }
        for entry in unsaved.dropFirst(recentLimit) {
            context.delete(entry)
        }
    }
}
