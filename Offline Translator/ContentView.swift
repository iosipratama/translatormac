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
    
    //
    private func triggerTranslate(){
        // logic
        Task{
            do {
                if #available(macOS 26.0, *){
                    outputText = try await AppleTranslator.translate(
                        text: inputText,
                        from: fromLanguage,
                        to: toLanguage
                    )
                } else {
                  outputText = "Translation requires macOS 26 or newer."
                }
            } catch {
                if let tError = error as? AppleTranslator.TranslateError {
                    outputText = tError.localizedDescription
                } else {
                    outputText = error.localizedDescription
                }
            }
        }
    }
    
    
    var body: some View {
        VStack (spacing: 20){
            
            // Language control
            HStack{
                
                // From picker
                Picker("From", selection: $fromLanguage) {
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
                Picker ("To", selection: $toLanguage) {
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
                            
                            .disabled(true)
                        
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
                
            }
            
            let isDisabled = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            
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
            .help("Translate ⌘↩")
            
        }
        .padding()
        .frame(minWidth: 760, minHeight: 360)
    }
}

#Preview {
    ContentView()
}
