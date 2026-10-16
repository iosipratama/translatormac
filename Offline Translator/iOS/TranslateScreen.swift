//
//  TranslateScreen.swift
//  TranslatorMac
//

import SwiftData
import SwiftUI

/// The root screen: type, speak or point the camera, and read the
/// translation. Library and Settings push from its toolbar.
///
/// One text field serves every state: empty with recent translations under
/// it, typing with the live translation below, and the finished result with
/// its actions once the keyboard goes away.
struct TranslateScreen: View {
    var model: TranslationModel
    var open: (AppRoute) -> Void

    @Environment(ProPresentation.self) private var pro

    @Query(Self.recentDescriptor) private var recent: [TranslationHistory]

    @FocusState private var isEditing: Bool
    @State private var pickerSide: LanguageSide?
    @State private var isShowingToSomeone = false
    @State private var toast: ToastMessage?
    @State private var savedCount = 0
    @State private var copiedCount = 0

    @AppStorage(SettingsKey.showPronunciation) private var showsPronunciation = true

    private static var recentDescriptor: FetchDescriptor<TranslationHistory> {
        var descriptor = FetchDescriptor<TranslationHistory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 3
        return descriptor
    }

    private var hasInput: Bool { !model.trimmedInput.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sourceSection

                if hasInput {
                    resultSection
                } else if !isEditing, !recent.isEmpty {
                    RecentPreview(entries: recent) {
                        open(.library)
                    } select: { entry in
                        model.load(entry)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .animation(.snappy, value: isEditing)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.canvas)
        .toast($toast, bottomPadding: 12)
        .safeAreaBar(edge: .bottom) {
            if !isEditing {
                VStack(spacing: 22) {
                    LanguagePairCard(model: model) { pickerSide = $0 }
                    BottomControls(showsMicHint: recent.isEmpty && !hasInput) {
                        isEditing = true
                    } talk: {
                        comingSoon("Voice translation is coming soon")
                    } camera: {
                        comingSoon("Camera translation is coming soon")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        }
        .navigationTitle(isEditing ? "" : "Translate")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar { toolbar }
        .sheet(item: $pickerSide) { side in
            LanguagePickerSheet(model: model, side: side)
        }
        .fullScreenCover(isPresented: $isShowingToSomeone) {
            ShowToSomeoneView(model: model)
        }
        .onChange(of: isEditing) { _, isEditing in
            // Done, or a tap outside the field: the translation counts as made.
            guard !isEditing, hasInput else { return }
            model.settle()
            if model.needsPro { pro.present() }
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.success, trigger: copiedCount)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    pickerSide = .source
                } label: {
                    HStack(spacing: 8) {
                        Text(model.sourceTitle)
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.textMuted)
                        Text(model.name(for: model.targetLanguage))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .padding(.horizontal, 6)
                }
                .accessibilityLabel("\(model.sourceTitle) to \(model.name(for: model.targetLanguage))")
                .accessibilityHint("Choose languages")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") {
                    model.clearInput()
                    isEditing = false
                }
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.library) {
                    Label("Library", systemImage: "bookmark")
                }
                .tint(.textPrimary)
                NavigationLink(value: AppRoute.settings) {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tint(.textPrimary)
            }
        }
    }

    // MARK: - Source

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(model.sourceTitle)
                Spacer()
                if hasInput {
                    Button {
                        model.clearInput()
                        isEditing = true
                    } label: {
                        Label("Clear text", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.textMuted)
                            .frame(width: 28, height: 28)
                            .background(.raised, in: .circle)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 28)

            TextField("Text to translate", text: input, prompt: Text("Enter text").foregroundStyle(.textFaint), axis: .vertical)
                .font(sourceFont)
                .foregroundStyle(isEditing || !hasInput ? AnyShapeStyle(.textPrimary) : AnyShapeStyle(.textSecondary))
                .tint(Color.accent)
                .lineLimit(1...8)
                .focused($isEditing)
                .submitLabel(.done)
        }
        .padding(.bottom, hasInput ? 20 : 24)
        .frame(minHeight: hasInput ? nil : 150, alignment: .top)
        .contentShape(.rect)
        .onTapGesture { isEditing = true }
    }

    /// Large while writing; a step smaller once the translation takes over.
    private var sourceFont: Font {
        isEditing || !hasInput ? .title.weight(.semibold) : .title2.weight(.semibold)
    }

    /// The input, with Return taken as Done: a field that grows to several
    /// lines would otherwise insert a line break.
    private var input: Binding<String> {
        Binding {
            model.inputText
        } set: { newValue in
            let old = model.inputText
            let addedOneCharacter = newValue.count == old.count + 1
            if addedOneCharacter, newValue.filter(\.isNewline).count > old.filter(\.isNewline).count {
                isEditing = false
                return
            }
            model.inputText = newValue
        }
    }

    // MARK: - Result

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(.line).frame(height: 1)
                .padding(.bottom, 8)

            SectionLabel(targetLabel)

            if case .failed(let failure) = model.outcome {
                failureMessage(failure)
            } else if model.needsPro {
                limitMessage
            } else if let result = model.outcome?.result {
                translation(result)
            } else {
                Text(model.translatesAsYouType ? "The translation appears as you type." : "Tap Done to translate.")
                    .font(.title3)
                    .foregroundStyle(.textFaint)
            }
        }
    }

    private var targetLabel: Text {
        let name = model.name(for: model.targetLanguage)
        guard model.speaker.isSpeaking else { return Text(name) }
        return Text("\(name) · \(Text("Reading aloud").foregroundStyle(.accentForeground))")
    }

    private func translation(_ result: TranslationResult) -> some View {
        // A result for older text stays up, dimmed, until the new one lands.
        let isStale = result.sourceText != model.trimmedInput

        return VStack(alignment: .leading, spacing: 12) {
            Text(highlighted(result.text))
                .font(.largeTitle.bold())
                .foregroundStyle(.textPrimary)
                .typesettingLanguage(model.targetLanguage)
                .textSelection(.enabled)

            if showsPronunciation, let pronunciation = result.pronunciation {
                Text(pronunciation)
                    .font(.body)
                    .foregroundStyle(.textMuted)
            }

            if !isEditing, !isStale {
                ActionBar(model: model) {
                    isShowingToSomeone = true
                } toggleSaved: {
                    toggleSaved()
                } copy: {
                    copy()
                }
                .padding(.top, 8)
                .transition(.opacity)
            }
        }
        .opacity(isStale ? 0.5 : 1)
        .animation(.smooth, value: isStale)
    }

    /// The translation with the words being read aloud picked out.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard model.speaker.isSpeaking,
              let spoken = model.speaker.spokenRange,
              let range = Range(spoken, in: attributed) else { return attributed }
        attributed[range].foregroundColor = .accentForeground
        attributed[range].backgroundColor = .accentTint
        return attributed
    }

    private func failureMessage(_ failure: TranslationFailure) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if failure.offersDownload {
                Text("\(model.name(for: model.targetLanguage)) isn’t on this iPhone yet.")
                    .font(.body)
                    .foregroundStyle(.textSecondary)
                Button("Download", systemImage: "arrow.down.circle", action: model.downloadCurrentPair)
                    .buttonStyle(.glass)
            } else {
                Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.body)
                    .foregroundStyle(.danger)
            }
        }
    }

    private var limitMessage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("You’ve used today’s \(PlanLimits.freeTranslationsPerDay) free translations. Pro translates without a limit.")
                .font(.body)
                .foregroundStyle(.textSecondary)
            Button("Get Pro") { pro.present() }
                .buttonStyle(.glassProminent)
                .tint(Color.accent)
                .foregroundStyle(.onAccent)
        }
    }

    // MARK: - Actions

    private func toggleSaved() {
        let wasSaved = model.isCurrentSaved
        guard model.toggleSaved() else {
            pro.present()
            return
        }
        guard !wasSaved else { return }
        savedCount += 1
        toast = ToastMessage(
            text: "Saved to Library",
            systemImage: "star.fill",
            action: .init(title: "View") { open(.library) }
        )
    }

    private func copy() {
        model.copyTranslation()
        copiedCount += 1
        toast = ToastMessage(
            text: "Copied \(model.name(for: model.targetLanguage)) text",
            systemImage: "checkmark"
        )
    }

    private func comingSoon(_ text: LocalizedStringResource) {
        toast = ToastMessage(text: text)
    }
}
