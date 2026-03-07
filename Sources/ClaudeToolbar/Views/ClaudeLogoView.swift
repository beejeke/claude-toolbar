import SwiftUI

/// Logo de Claude: 4 capsulas superpuestas a 0°, 45°, 90° y 135°
/// formando la estrella/asterisco caracteristica de la marca.
/// Implementado con Capsule + rotationEffect para compatibilidad
/// con el contexto de menu bar de SwiftUI (Canvas no renderiza ahi).
struct ClaudeLogoView: View {
    var size: CGFloat = 16
    var color: Color = .primary

    var body: some View {
        ZStack {
            ForEach(0..<4) { i in
                Capsule()
                    .frame(width: size * 0.18, height: size * 0.88)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
    }
}
