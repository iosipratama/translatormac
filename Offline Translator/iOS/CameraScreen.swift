//
//  CameraScreen.swift
//  TranslatorMac
//

import PhotosUI
import SwiftData
import SwiftUI
import os
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// Point at a sign or menu, take a photo, and read it translated in place.
///
/// Live viewfinder → shutter (or a photo from the library) → the photo,
/// frozen, with each line replaced by its translation. Nothing is uploaded
/// or saved to Photos; the picture is gone when the camera closes.
struct CameraScreen: View {
    var model: TranslationModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PurchaseStore.self) private var purchases

    private enum Stage {
        case live
        /// Reading and translating the photo.
        case working(UIImage)
        case translated(UIImage, [CameraLine])
    }

    @State private var feed = CameraFeed()
    @State private var stage: Stage = .live
    /// The camera reads the pair's target and shows its source, the right way
    /// round for reading what's around you; the menu can turn it.
    @State private var readsTarget = true
    @State private var showsTranslations = true
    @State private var selectedLine: CameraLine?
    @State private var photo: PhotosPickerItem?
    @State private var pickerSide: LanguageSide?
    @State private var isShowingPro = false
    @State private var toast: ToastMessage?
    @State private var copiedCount = 0

    /// Lines waiting for the translation session.
    @State private var pendingLines: [CameraLine] = []
    @State private var configuration: TranslationSession.Configuration?

    @AppStorage(SettingsKey.keepHistory) private var keepsHistory = true

    var body: some View {
        Group {
            switch feed.access {
            case .denied:
                if case .live = stage {
                    CameraOffView(photo: $photo) { dismiss() }
                } else {
                    capture
                }
            case .notAsked, .granted:
                capture
            }
        }
        .toast($toast, bottomPadding: 140)
        .task {
            await feed.requestAccess()
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            photo = nil
            Task { await usePhoto(item) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { feed.refreshAccess() }
        }
        .onDisappear {
            feed.setTorch(false)
            feed.plainSession.stop()
        }
        .translationTask(configuration) { session in
            await translatePending(using: session)
        }
        .sheet(item: $selectedLine) { line in
            CameraLineSheet(line: line, source: source, target: target, model: model) {
                isShowingPro = true
            }
        }
        .sheet(item: $pickerSide) { side in
            LanguagePickerSheet(model: model, side: side)
        }
        .sheet(isPresented: $isShowingPro) {
            ProPlaceholderSheet()
        }
        .sensoryFeedback(.success, trigger: copiedCount)
    }

    // MARK: - Languages

    private var source: Locale.Language {
        readsTarget ? model.targetLanguage : (model.sourceLanguage ?? model.targetLanguage)
    }

    private var target: Locale.Language {
        readsTarget ? (model.sourceLanguage ?? model.targetLanguage) : model.targetLanguage
    }

    private var canRead: Bool {
        CameraTextReader.canRead(source)
    }

    // MARK: - Layout

    /// The viewfinder or photo, always dark like the Camera app, with the
    /// controls floating over it.
    private var capture: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch stage {
            case .live:
                if feed.access == .granted {
                    CameraViewfinder(feed: feed, language: source)
                        .ignoresSafeArea()
                }
            case .working(let image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.45)
                    .overlay { ProgressView().controlSize(.large).tint(.white) }
                    .accessibilityLabel("Translating the photo")
            case .translated(let image, let lines):
                CapturedPhotoView(
                    image: image,
                    lines: lines,
                    showsTranslations: showsTranslations,
                    selectedID: selectedLine?.id
                ) { line in
                    selectedLine = line
                }
            }
        }
        .safeAreaInset(edge: .top) {
            topBar
                .environment(\.colorScheme, .dark)
        }
        .safeAreaInset(edge: .bottom) {
            if case .translated(_, let lines) = stage {
                resultPanel(lines)
            } else {
                liveControls
                    .environment(\.colorScheme, .dark)
            }
        }
    }

    private var topBar: some View {
        HStack {
            RoundIconButton(title: isLive ? "Close" : "Retake", systemImage: "xmark", diameter: 40) {
                close()
            }
            Spacer()
            languageMenu
            Spacer()
            if isLive, feed.hasTorch {
                RoundIconButton(
                    title: feed.isTorchOn ? "Turn off light" : "Turn on light",
                    systemImage: feed.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                    diameter: 40,
                    iconColor: feed.isTorchOn ? Color.accent : .white
                ) {
                    feed.toggleTorch()
                }
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// "Japanese → English": which way the camera reads, and a way to
    /// change the languages themselves.
    private var languageMenu: some View {
        Menu {
            Picker("Direction", selection: $readsTarget) {
                Text("\(model.name(for: model.targetLanguage)) → \(model.sourceLanguage.map(model.name(for:)) ?? "")")
                    .tag(true)
                Text("\(model.sourceLanguage.map(model.name(for:)) ?? "") → \(model.name(for: model.targetLanguage))")
                    .tag(false)
            }
            Button("Choose Languages…", systemImage: "globe") {
                pickerSide = .target
            }
        } label: {
            HStack(spacing: 8) {
                if !canRead {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.accent)
                        .accessibilityLabel("Can't read this language")
                }
                Text(model.name(for: source))
                Image(systemName: "arrow.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(model.name(for: target))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 40)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .disabled(isWorking)
    }

    private var liveControls: some View {
        VStack(spacing: 22) {
            Text(hint)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
                .opacity(isLive ? 1 : 0)

            HStack {
                PhotosPicker(selection: $photo, matching: .images) {
                    Label("Choose a photo", systemImage: "photo")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
                }
                .disabled(!isLive)

                Spacer()

                Button(action: shoot) {
                    Circle()
                        .fill(.white)
                        .frame(width: 64, height: 64)
                        .padding(5)
                        .overlay { Circle().strokeBorder(.white, lineWidth: 4) }
                        .frame(width: 78, height: 78)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Take photo and translate")
                .disabled(!isLive || !canRead || feed.access != .granted)
                .opacity(canRead ? 1 : 0.4)

                Spacer()

                Color.clear.frame(width: 52, height: 52)
            }
            .padding(.horizontal, 32)
        }
        .padding(.bottom, 12)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .frame(height: 240)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var hint: LocalizedStringKey {
        if !canRead { return "Camera can’t read \(model.name(for: source)) yet." }
        if feed.visibleTextCount > 0 { return "Text found · tap the shutter to translate" }
        return "Point at a menu or sign"
    }

    /// Below the photo, in the app's own colors: switch between translated
    /// and original, and copy everything.
    private func resultPanel(_ lines: [CameraLine]) -> some View {
        VStack(spacing: 16) {
            Picker("Show", selection: $showsTranslations) {
                Text("Translated").tag(true)
                Text("Original").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Text("^[\(lines.count) line](inflect: true) · tap one for details")
                    .font(.subheadline)
                    .foregroundStyle(.textMuted)
                Spacer()
                Button {
                    Clipboard.copy(lines.map { $0.translation ?? $0.text }.joined(separator: "\n"))
                    copiedCount += 1
                    toast = ToastMessage(text: "Copied all lines", systemImage: "checkmark")
                } label: {
                    Text("Copy All")
                        .font(.headline)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(.inverse)
                .foregroundStyle(.onInverse)
            }
        }
        .padding(20)
        .background(.canvas, in: .rect(topLeadingRadius: 28, topTrailingRadius: 28))
        .background(alignment: .bottom) {
            Color.canvas.frame(height: 40).ignoresSafeArea()
        }
    }

    private var isLive: Bool {
        if case .live = stage { return true }
        return false
    }

    private var isWorking: Bool {
        if case .working = stage { return true }
        return false
    }

    // MARK: - Actions

    private func close() {
        switch stage {
        case .live:
            dismiss()
        case .working, .translated:
            selectedLine = nil
            showsTranslations = true
            stage = .live
        }
    }

    private func shoot() {
        guard purchases.canTranslate else {
            isShowingPro = true
            return
        }
        Task {
            do {
                let image = try await feed.capturePhoto()
                feed.setTorch(false)
                await read(image)
            } catch {
                Log.translation.error("Capture failed: \(String(describing: error), privacy: .public)")
                toast = ToastMessage(text: "Couldn’t take the photo. Try again.")
            }
        }
    }

    private func usePhoto(_ item: PhotosPickerItem) async {
        guard purchases.canTranslate else {
            isShowingPro = true
            return
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            toast = ToastMessage(text: "Couldn’t open that photo.")
            return
        }
        await read(image)
    }

    /// Finds the lines in the photo, then hands them to the translation
    /// session as one batch.
    private func read(_ image: UIImage) async {
        guard let cgImage = image.uprightCGImage() else { return }
        let upright = UIImage(cgImage: cgImage)
        stage = .working(upright)

        let lines: [CameraLine]
        do {
            lines = try await CameraTextReader.lines(in: cgImage, language: source)
        } catch {
            Log.translation.error("Text recognition failed: \(String(describing: error), privacy: .public)")
            lines = []
        }
        guard !lines.isEmpty else {
            stage = .live
            toast = ToastMessage(text: "No text found. Move closer or add more light.")
            return
        }

        pendingLines = lines
        let desired = LanguageCatalog.configuration(source: source, target: target)
        if var current = configuration, current.source == desired.source, current.target == desired.target {
            current.invalidate()
            configuration = current
        } else {
            configuration = desired
        }
    }

    private func translatePending(using session: TranslationSession) async {
        let lines = pendingLines
        guard !lines.isEmpty, case .working(let image) = stage else { return }
        pendingLines = []

        do {
            let byID = try await Self.translate(lines.map { (String($0.id), $0.text) }, with: session)
            let translated = lines.map { line in
                var line = line
                line.translation = byID[String(line.id)]
                return line
            }
            showsTranslations = true
            stage = .translated(image, translated)
            record(translated)
        } catch {
            Log.translation.error("Photo translation failed: \(String(describing: error), privacy: .public)")
            stage = .live
            toast = ToastMessage(text: "Couldn’t translate this photo. Check that both languages are downloaded.")
        }
    }

    /// Translates every line in one batch, keyed by line.
    private nonisolated static func translate(
        _ texts: [(id: String, text: String)],
        with session: TranslationSession
    ) async throws -> [String: String] {
        let requests = texts.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: $0.id) }
        var byID: [String: String] = [:]
        for response in try await session.translations(from: requests) {
            if let id = response.clientIdentifier { byID[id] = response.targetText }
        }
        return byID
    }

    /// One capture is one translation: one entry in Recent and one toward
    /// the free plan's daily count.
    private func record(_ lines: [CameraLine]) {
        purchases.recordTranslation()
        guard keepsHistory else { return }
        HistoryStore(context: modelContext, recentLimit: purchases.historyLimit).record(
            sourceText: lines.map(\.text).joined(separator: "\n"),
            translatedText: lines.map { $0.translation ?? $0.text }.joined(separator: "\n"),
            sourceLanguage: LanguageCatalog.identifier(for: source),
            targetLanguage: LanguageCatalog.identifier(for: target)
        )
    }
}
