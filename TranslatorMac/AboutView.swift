//
//  AboutView.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 22/12/25.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16){
            Image(nsImage:  NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            
            Text("Offline Translator")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Version 1.0")
                .foregroundStyle(.secondary)
                
            
            Divider()
                .frame(height: 1)
            
            Text("Offline translation powered by Apple's on-device language models. No need to connect to the internet.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
                .fixedSize(horizontal: false, vertical: true)
            
        }
        .padding(24)
        .frame(maxWidth: 300, maxHeight: 300)
        
    }
}
