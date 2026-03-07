// Punto de entrada: main.swift + AppDelegate + MenuBarController
// Este archivo conserva MenuBarLabel como referencia visual (no usado en produccion)
import SwiftUI

/// Indicador de color del icono en el menu bar (usado por MenuBarController)
extension MenuBarController {
    static func indicatorColor(session: UsageMetric?, weekly: UsageMetric?) -> NSColor {
        let minPct = [session?.remainingPercentage, weekly?.remainingPercentage]
            .compactMap { $0 }
            .min() ?? 1.0

        switch minPct {
        case 0.5...: return .systemGreen
        case 0.2..<0.5: return .systemOrange
        default: return .systemRed
        }
    }
}
