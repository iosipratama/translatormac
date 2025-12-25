//
//  ContentView.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 19/12/25.
//

import SwiftUI

struct ContentView: View {
    
    // Declare private variable with nill value.
    // @State local UI state, automatically change the value in the UI
    // $inputText -> binding
    // Text states
    @State private var inputText = ""
    @State private var outputText = ""
    
    
    @State private var fromLanguage = "English"
    @State private var toLanguage = "Indonesian"
    
    private let languages = ["Auto ", "English", "Indonesian", "Arabic", "German", "Japanese", "French"]
    
    private enum EditedSide { case source, result }
    @State private var lastEdited: EditedSide = .source
    
    private func triggerTranslate(){
        // Decide direction based on which editor was last edited
        let textToTranslate: String
        let fromLang: String
        let toLang: String

        switch lastEdited {
        case .source:
            textToTranslate = inputText
            fromLang = fromLanguage
            toLang = toLanguage
        case .result:
            textToTranslate = outputText
            fromLang = toLanguage
            toLang = fromLanguage
        }

        Task{
            do {
                if #available(macOS 26.0, *){
                    let translated = try await AppleTranslator.translate(
                        text: textToTranslate,
                        from: fromLang,
                        to: toLang
                    )

                    // Write result to the opposite side
                    switch lastEdited {
                    case .source:
                        outputText = translated
                    case .result:
                        inputText = translated
                    }
                } else {
                    let message = "Translation requires macOS 26 or newer."
                    switch lastEdited {
                    case .source:
                        outputText = message
                    case .result:
                        inputText = message
                    }
                }
            } catch {
                let message: String
                if let tError = error as? AppleTranslator.TranslateError {
                    message = tError.localizedDescription
                } else {
                    message = error.localizedDescription
                }
                switch lastEdited {
                case .source:
                    outputText = message
                case .result:
                    inputText = message
                }
            }
        }
    }
    
    
    var body: some View {
        VStack (spacing: 20){
            
            // Language control
            HStack{
                
                // From picker
                Picker("", selection: $fromLanguage) {
                    ForEach(languages, id: \.self) { lang in
                        Text(lang).tag(lang)
                    }
                    
                }
                .frame(width:200)
                
                // swap button
                Button("Swap") {
                    let tmp = fromLanguage
                    fromLanguage = toLanguage
                    toLanguage = tmp
                }
                
                // To picker
                Picker ("", selection: $toLanguage) {
                    ForEach(languages, id:\.self) { lang in
                        Text(lang).tag(lang)
                    }
                }
                .frame(width: 200)
                
            }
            
            

            HStack{
                    // Input field.
                    ZStack(alignment: .topLeading){
                        if inputText.isEmpty {
                            Text("Type or paste text and ⌘↵ to translate")
                                .foregroundStyle(.tertiary)
                                .allowsHitTesting(false)
                        }
                        
                        TextEditor(text: $inputText)
                            .padding(.leading, -4)
                            .frame(minHeight: 180)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                            .onChange(of: inputText) { _, _ in lastEdited = .source }
                            
                    }
                    .font(.body)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary)
                    )
                    
                    
                
                
                // Translation
                    ZStack(alignment: .topLeading){
                        if outputText.isEmpty {
                            Text("Translation")
                                .foregroundStyle(.tertiary)

                        }
                        
                        TextEditor(text: $outputText)
                            .padding(.leading, -4)
                            .frame(minHeight: 180)
                            .background(.clear)
                            .scrollContentBackground(.hidden)
                            .onChange(of: outputText) { _, _ in lastEdited = .result }
                        
                    }
                    .font(.body)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary)
                    )
                    
                
            }
            // automatically set translation value to zero if input text zero
            .onChange(of: inputText) { oldValue, newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // clear the output field
                    outputText = ""
                }
                lastEdited = .source
            }
            
            let isDisabled: Bool = {
                switch lastEdited {
                case .source:
                    return inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                case .result:
                    return outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }()
            
            Button(action: {
                // clicking the buttons run the translation
                triggerTranslate()
            }) {
                Text("Translate")
                
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.4 : 1.0)
            .keyboardShortcut(.return, modifiers: [.command])
            .help(lastEdited == .source ? "Translate source → result (⌘↩)" : "Translate result → source (⌘↩)")
            
        }
        .padding()
        .frame(minWidth: 760, minHeight: 360)
    }
}

#Preview {
    ContentView()
}
