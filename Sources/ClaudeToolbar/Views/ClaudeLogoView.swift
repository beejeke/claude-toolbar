import SwiftUI

/// Logo de Claude: 4 capsulas superpuestas a 0°, 45°, 90° y 135°
/// formando la estrella/asterisco caracteristica de la marca.
struct ClaudeLogoView: View {
    var size: CGFloat = 16
    var color: Color = .primary

    var body: some View {
        Canvas { context, canvasSize in
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2
            let armLength = min(canvasSize.width, canvasSize.height) * 0.44
            let armWidth  = min(canvasSize.width, canvasSize.height) * 0.175

            for i in 0..<4 {
                let angle = Double(i) * .pi / 4

                let capsule = Path(
                    roundedRect: CGRect(
                        x: -armWidth / 2,
                        y: -armLength,
                        width: armWidth,
                        height: armLength * 2
                    ),
                    cornerRadius: armWidth / 2
                )

                let transform = CGAffineTransform(translationX: cx, y: cy)
                    .rotated(by: angle)

                context.fill(capsule.applying(transform), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}
