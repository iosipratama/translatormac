//
//  AboutView.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 22/12/25.
//

import SwiftUI

struct AboutView: View {
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        return "Version \(version)(\(build))"
    }
    
    var body: some View {
        VStack(spacing: 16){
            Image(nsImage:  NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            
            VStack(spacing: 6){
                Text("Translate Offline")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(appVersion)
                    .foregroundStyle(.secondary)
                
                Link("by mekarya Studio", destination: URL(string: "https://www.mekarya.studio")!)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            
            
            
            Divider()
                .frame(height: 1)
            
            Text("Simple offline translation for macOS.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
        }
        .padding(24)
        .frame(maxWidth: 300, maxHeight: 300)
        .transition(.scale.combined(with: .opacity))
        
    }
}

#Preview {
    AboutView()
}
