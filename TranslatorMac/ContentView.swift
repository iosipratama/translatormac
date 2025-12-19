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
                    TextEditor(text: $inputText)
                        .frame(minHeight: 180)
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
                // logic
                outputText = "From: \(fromLanguage) -> To: \(toLanguage)\n\(inputText)"
                
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .frame(minWidth: 760, minHeight: 360)
    }
}

#Preview {
    ContentView()
}
