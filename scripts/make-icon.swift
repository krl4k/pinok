// Рисует иконку Pinok и собирает Resources/AppIcon.icns.
// Запуск: swift scripts/make-icon.swift
import AppKit
import SwiftUI

struct PinokIcon: View {
    var body: some View {
        ZStack {
            // Тень под иконкой
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(.black.opacity(0.35))
                .frame(width: 824, height: 824)
                .blur(radius: 18)
                .offset(y: 14)

            ZStack {
                MeshGradient(
                    width: 3, height: 3,
                    points: [[0, 0], [0.55, 0], [1, 0], [0, 0.45], [0.5, 0.55], [1, 0.4], [0, 1], [0.45, 1], [1, 1]],
                    colors: [
                        Color(red: 0.99, green: 0.47, blue: 0.56), Color(red: 1.00, green: 0.62, blue: 0.40), Color(red: 1.00, green: 0.78, blue: 0.45),
                        Color(red: 0.70, green: 0.38, blue: 0.95), Color(red: 0.93, green: 0.42, blue: 0.68), Color(red: 1.00, green: 0.55, blue: 0.45),
                        Color(red: 0.28, green: 0.42, blue: 0.96), Color(red: 0.45, green: 0.50, blue: 1.00), Color(red: 0.62, green: 0.40, blue: 0.95),
                    ])
                // Блик сверху
                LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center)

                // «Стеклянный» круг
                Circle()
                    .fill(LinearGradient(colors: [.white.opacity(0.38), .white.opacity(0.12)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 500, height: 500)
                    .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.25)],
                                                                   startPoint: .top, endPoint: .bottom), lineWidth: 7))
                    .shadow(color: .black.opacity(0.18), radius: 24, y: 14)

                Image(systemName: "arrow.up")
                    .font(.system(size: 270, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
            }
            .frame(width: 824, height: 824)
            .clipShape(RoundedRectangle(cornerRadius: 186, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 186, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 2))
        }
        .frame(width: 1024, height: 1024)
    }
}

@MainActor
func render() throws {
    let renderer = ImageRenderer(content: PinokIcon())
    renderer.scale = 1
    guard let cg = renderer.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: URL(fileURLWithPath: "docs/icon-1024.png"))
}

MainActor.assumeIsolated { try! render() }
print("✅ docs/icon-1024.png")
