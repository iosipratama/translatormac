//
//  CapturedPhotoView.swift
//  TranslatorMac
//

import SwiftUI

/// The frozen photo, with each line of text covered by its translation in
/// the same place and at the same tilt. With translations hidden, the lines
/// can still be tapped for details.
struct CapturedPhotoView: View {
    var image: UIImage
    var lines: [CameraLine]
    var showsTranslations: Bool
    var selectedID: CameraLine.ID?
    var select: (CameraLine) -> Void

    var body: some View {
        GeometryReader { proxy in
            let fit = fitting(image.size, in: proxy.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: fit.size.width, height: fit.size.height)
                    .offset(x: fit.origin.x, y: fit.origin.y)
                    .accessibilityHidden(true)

                ForEach(lines) { line in
                    label(for: line, scale: fit.size.width / pixelWidth)
                        .position(
                            x: fit.origin.x + line.center.x * fit.size.width / pixelWidth,
                            y: fit.origin.y + line.center.y * fit.size.width / pixelWidth
                        )
                }
            }
        }
    }

    private var pixelWidth: CGFloat {
        image.size.width * image.scale
    }

    private func label(for line: CameraLine, scale: CGFloat) -> some View {
        let width = max(line.width * scale, 24)
        let height = max(line.height * scale, 14)
        let isSelected = line.id == selectedID

        return Button {
            select(line)
        } label: {
            Group {
                if showsTranslations {
                    Text(line.translation ?? line.text)
                        .font(.system(size: height * 0.7, weight: .semibold))
                        .minimumScaleFactor(0.3)
                        .lineLimit(1)
                        .foregroundStyle(Color(white: 0.08))
                        .padding(.horizontal, 4)
                        .frame(width: width + 8, height: height + 6)
                        .background(Color(white: 0.98), in: .rect(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                } else {
                    Color.clear
                        .frame(width: width + 8, height: height + 6)
                        .contentShape(.rect)
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.accent, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .rotationEffect(.radians(line.angle))
        .accessibilityLabel(line.translation ?? line.text)
        .accessibilityHint("Shows the original and more")
    }

    /// The photo scaled to fit, centered.
    private func fitting(_ imageSize: CGSize, in space: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(space.width / imageSize.width, space.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            origin: CGPoint(x: (space.width - size.width) / 2, y: (space.height - size.height) / 2),
            size: size
        )
    }
}
