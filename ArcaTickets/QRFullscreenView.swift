//
//  QRFullscreenView.swift
//  ArcaTickets
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import Vision
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
enum TicketsScreenAccess {
    static var active: UIScreen? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive })?.screen
            ?? scenes.first?.screen
    }

    static var brightness: CGFloat {
        active?.brightness ?? 0.5
    }

    static func setBrightness(_ value: CGFloat) {
        active?.brightness = min(max(value, 0), 1)
    }
}
#endif

struct QRFullscreenView: View {
    let imageURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var originalBrightness: CGFloat = 0.5
    @State private var codeCrop: CGRect?
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = UIImage(contentsOfFile: imageURL.path) {
                codeImage(uiImage: uiImage)
                    .offset(y: dragOffset)
                    .opacity(1.0 - Double(abs(dragOffset)) / 400.0)
            } else {
                ContentUnavailableView("Bild nöd verfügbar", systemImage: "photo")
                    .foregroundStyle(.white)
            }

            VStack {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)

                Spacer()

                Text("Nach unte wische zum Schliesse")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.bottom, 36)
            }
        }
        .statusBarHidden()
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 120 || value.predictedEndTranslation.height > 200 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            #if canImport(UIKit)
            originalBrightness = TicketsScreenAccess.brightness
            TicketsScreenAccess.setBrightness(1.0)
            #endif
            detectCode()
        }
        .onDisappear {
            #if canImport(UIKit)
            TicketsScreenAccess.setBrightness(originalBrightness)
            #endif
        }
    }

    @ViewBuilder
    private func codeImage(uiImage: UIImage) -> some View {
        if let crop = codeCrop {
            let anchorX = LayoutSafety.dimension(crop.midX, minimum: 0.5)
            let anchorY = LayoutSafety.dimension(1 - crop.midY, minimum: 0.5)
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .scaleEffect(2.4, anchor: UnitPoint(x: anchorX, y: anchorY))
                .padding(20)
        } else {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .padding(20)
        }
    }

    private func detectCode() {
        guard let uiImage = UIImage(contentsOfFile: imageURL.path),
              let cgImage = uiImage.cgImage else { return }

        let request = VNDetectBarcodesRequest { request, _ in
            guard let results = request.results as? [VNBarcodeObservation],
                  let code = results.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) else { return }
            DispatchQueue.main.async {
                codeCrop = code.boundingBox.insetBy(dx: -0.06, dy: -0.06)
            }
        }
        request.symbologies = [.qr, .aztec, .dataMatrix, .code128, .code39, .pdf417, .ean13, .ean8]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}
