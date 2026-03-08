// Punto de entrada: main.swift + AppDelegate + MenuBarController
import SwiftUI

/// Color del icono en el menu bar segun el coste de hoy
extension MenuBarController {
    static func indicatorColor(todayTotal: PeriodUsage?) -> NSColor {
        let cost = todayTotal?.apiRefCostUSD ?? 0
        switch cost {
        case ..<1.0:  return .systemGreen
        case ..<5.0:  return .systemOrange
        default:      return .systemRed
        }
    }
}
