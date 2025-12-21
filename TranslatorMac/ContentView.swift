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
    
    private let languages = ["English", "Indonesian", "Arabic", "German", "Japanese"]
    
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
                outputText = error.localizedDescription
            }
        }
    }
    
    
    var body: some View {
        VStack (spacing: 20){
            Text("Translator")
                .font(.title2)
            
            
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
            
            
            // Input and Output field
            HStack{
                VStack{
                    Text("Input")
                    //
                    
                    ZStack(alignment: .topLeading){
                        if inputText.isEmpty {
                            Text("Type or paste text to translate")
                                .foregroundStyle(.tertiary)
                                .padding(8)
                                .allowsHitTesting(false)
                        }
                        
                        TextEditor(text: $inputText)
                            
                            .frame(minHeight: 180)
                            .padding(8)
                            .background(.clear)
                            .scrollContentBackground(.hidden)
                            
                        
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary)
                    )
                    
                    
                }
                
                VStack{
                    Text("Output")
                    TextEditor(text: $outputText)
                        .frame(minHeight: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary)
                        )
                        .disabled(true)
                }
            }
            
            Button("Translate") {
                // clicking the buttons run the translation
                triggerTranslate()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help("Translate Command Enter")
        }
        .padding()
        .frame(minWidth: 760, minHeight: 360)
    }
}

#Preview {
    ContentView()
}
