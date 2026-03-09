import Foundation
import SwiftUI

// MARK: - Language enum

enum AppLanguage: String, CaseIterable, Identifiable {
    case english  = "en"
    case spanish  = "es"
    case japanese = "ja"
    case chinese  = "zh"
    case italian  = "it"
    case french   = "fr"
    case german   = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:  return "English"
        case .spanish:  return "Español"
        case .japanese: return "日本語"
        case .chinese:  return "中文"
        case .italian:  return "Italiano"
        case .french:   return "Français"
        case .german:   return "Deutsch"
        }
    }
}

// MARK: - Localization keys

enum L10nKey {
    // Cards
    case currentSession, windowFiveH, lastSevenDays, noActivity
    case tokensGenerated, refAPI
    case percentOfLimit, tok
    case windowIn, windowExhausted
    case todayTotal, todayTokensGenerated
    case calls, sessions, real
    // Rate limit
    case rateLimitToday, rateLimitPast, rateLimitResets
    // No data
    case noDataMessage
    // Header / actions
    case settingsOpen, settingsClose, quit, refresh
    // Settings
    case sectionNotifications, thresholdAlerts, thresholdDesc, notificationsOff
    case sectionLimits, windowFiveHLabel, weeklyLabel, modified, detectedPlan, resetButton
    case sectionAbout, dataSource, network, noExternalConns
    case languageLabel
    // Bottom bar
    case apiRefNote, lastUpdated
    // Calibration
    case calibrated
    // Reset countdown
    case resetsIn
}

// MARK: - Localization manager

@MainActor
final class LocalizationManager: ObservableObject {

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? AppLanguage.english.rawValue
        language = AppLanguage(rawValue: saved) ?? .english
    }

    func s(_ key: L10nKey) -> String {
        Self.strings[language]?[key] ?? Self.strings[.english]![key]!
    }

    // MARK: - String table

    private static let strings: [AppLanguage: [L10nKey: String]] = [

        .english: [
            .currentSession:       "Current Session",
            .windowFiveH:          "Window (5h)",
            .lastSevenDays:        "Last 7 Days",
            .noActivity:           "No activity",
            .tokensGenerated:      "tokens generated",
            .refAPI:               "API ref.",
            .percentOfLimit:       "% of limit",
            .tok:                  "tok",
            .windowIn:             "window in",
            .windowExhausted:      "window exhausted",
            .todayTotal:           "Today total",
            .todayTokensGenerated: "tokens generated",
            .calls:                "calls",
            .sessions:             "sessions",
            .real:                 "real",
            .rateLimitToday:       "Limit reached",
            .rateLimitPast:        "Last limit",
            .rateLimitResets:      "Resets:",
            .noDataMessage:        "Run `claude` in the terminal to see your usage",
            .settingsOpen:         "Settings",
            .settingsClose:        "Close settings",
            .quit:                 "Quit",
            .refresh:              "Refresh (Cmd+R)",
            .sectionNotifications: "Notifications",
            .thresholdAlerts:      "Threshold alerts",
            .thresholdDesc:        "Alerts at 70% and 90% of the window (5h) and weekly limit",
            .notificationsOff:     "Notifications are disabled",
            .sectionLimits:        "Token limits",
            .windowFiveHLabel:     "Window 5h",
            .weeklyLabel:          "Weekly",
            .modified:             "(modified)",
            .detectedPlan:         "Detected plan:",
            .resetButton:          "Reset",
            .sectionAbout:         "About",
            .dataSource:           "Data source",
            .network:              "Network",
            .noExternalConns:      "No external connections",
            .languageLabel:        "Language",
            .apiRefNote:           "Ref. API: Anthropic public pricing",
            .lastUpdated:          "Updated",
            .calibrated:           "calibrated",
            .resetsIn:             "resets in",
        ],

        .spanish: [
            .currentSession:       "Sesión actual",
            .windowFiveH:          "Ventana (5h)",
            .lastSevenDays:        "Últimos 7 días",
            .noActivity:           "Sin actividad",
            .tokensGenerated:      "tokens generados",
            .refAPI:               "ref. API",
            .percentOfLimit:       "% del límite",
            .tok:                  "tok",
            .windowIn:             "ventana en",
            .windowExhausted:      "ventana agotada",
            .todayTotal:           "Hoy total",
            .todayTokensGenerated: "tokens generados",
            .calls:                "llamadas",
            .sessions:             "sesiones",
            .real:                 "reales",
            .rateLimitToday:       "Límite alcanzado",
            .rateLimitPast:        "Último límite",
            .rateLimitResets:      "Se restablece:",
            .noDataMessage:        "Ejecuta `claude` en la terminal para ver tu uso",
            .settingsOpen:         "Ajustes",
            .settingsClose:        "Cerrar ajustes",
            .quit:                 "Salir",
            .refresh:              "Actualizar (Cmd+R)",
            .sectionNotifications: "Notificaciones",
            .thresholdAlerts:      "Alertas de umbral",
            .thresholdDesc:        "Avisa al 70% y 90% del límite de ventana (5h) y semanal",
            .notificationsOff:     "Las notificaciones están desactivadas",
            .sectionLimits:        "Límites de tokens",
            .windowFiveHLabel:     "Ventana 5h",
            .weeklyLabel:          "Semanal",
            .modified:             "(modificado)",
            .detectedPlan:         "Detectado: plan",
            .resetButton:          "Restablecer",
            .sectionAbout:         "Acerca de",
            .dataSource:           "Fuente de datos",
            .network:              "Red",
            .noExternalConns:      "Sin conexiones externas",
            .languageLabel:        "Idioma",
            .apiRefNote:           "Ref. API: precios Anthropic públicos",
            .lastUpdated:          "Actualizado",
            .calibrated:           "calibrado",
            .resetsIn:             "se restablece en",
        ],

        .japanese: [
            .currentSession:       "現在のセッション",
            .windowFiveH:          "ウィンドウ (5h)",
            .lastSevenDays:        "過去7日間",
            .noActivity:           "アクティビティなし",
            .tokensGenerated:      "生成済みトークン",
            .refAPI:               "API参考",
            .percentOfLimit:       "制限の%",
            .tok:                  "tok",
            .windowIn:             "ウィンドウまで",
            .windowExhausted:      "ウィンドウ枯渇",
            .todayTotal:           "今日の合計",
            .todayTokensGenerated: "生成済みトークン",
            .calls:                "コール",
            .sessions:             "セッション",
            .real:                 "実際",
            .rateLimitToday:       "制限に達しました",
            .rateLimitPast:        "前回の制限",
            .rateLimitResets:      "リセット:",
            .noDataMessage:        "ターミナルで `claude` を実行して使用状況を確認",
            .settingsOpen:         "設定",
            .settingsClose:        "設定を閉じる",
            .quit:                 "終了",
            .refresh:              "更新 (Cmd+R)",
            .sectionNotifications: "通知",
            .thresholdAlerts:      "閾値アラート",
            .thresholdDesc:        "ウィンドウ(5h)と週次制限の70%と90%でアラート",
            .notificationsOff:     "通知は無効です",
            .sectionLimits:        "トークン制限",
            .windowFiveHLabel:     "ウィンドウ5h",
            .weeklyLabel:          "週次",
            .modified:             "(変更済み)",
            .detectedPlan:         "検出されたプラン:",
            .resetButton:          "リセット",
            .sectionAbout:         "について",
            .dataSource:           "データソース",
            .network:              "ネットワーク",
            .noExternalConns:      "外部接続なし",
            .languageLabel:        "言語",
            .apiRefNote:           "参考API: Anthropic公開価格",
            .lastUpdated:          "更新済み",
            .calibrated:           "キャリブ済み",
            .resetsIn:             "リセットまで",
        ],

        .chinese: [
            .currentSession:       "当前会话",
            .windowFiveH:          "时间窗口 (5小时)",
            .lastSevenDays:        "最近7天",
            .noActivity:           "无活动",
            .tokensGenerated:      "已生成的令牌",
            .refAPI:               "API参考",
            .percentOfLimit:       "%的限制",
            .tok:                  "tok",
            .windowIn:             "窗口还剩",
            .windowExhausted:      "窗口已耗尽",
            .todayTotal:           "今日总计",
            .todayTokensGenerated: "已生成的令牌",
            .calls:                "调用",
            .sessions:             "会话",
            .real:                 "实际",
            .rateLimitToday:       "已达到限制",
            .rateLimitPast:        "上次限制",
            .rateLimitResets:      "重置:",
            .noDataMessage:        "在终端运行 `claude` 查看使用情况",
            .settingsOpen:         "设置",
            .settingsClose:        "关闭设置",
            .quit:                 "退出",
            .refresh:              "刷新 (Cmd+R)",
            .sectionNotifications: "通知",
            .thresholdAlerts:      "阈值警报",
            .thresholdDesc:        "在窗口(5小时)和每周限制的70%和90%时提醒",
            .notificationsOff:     "通知已禁用",
            .sectionLimits:        "令牌限制",
            .windowFiveHLabel:     "窗口5小时",
            .weeklyLabel:          "每周",
            .modified:             "(已修改)",
            .detectedPlan:         "检测到的计划:",
            .resetButton:          "重置",
            .sectionAbout:         "关于",
            .dataSource:           "数据来源",
            .network:              "网络",
            .noExternalConns:      "无外部连接",
            .languageLabel:        "语言",
            .apiRefNote:           "参考API: Anthropic公开定价",
            .lastUpdated:          "已更新",
            .calibrated:           "已校准",
            .resetsIn:             "重置于",
        ],

        .italian: [
            .currentSession:       "Sessione corrente",
            .windowFiveH:          "Finestra (5h)",
            .lastSevenDays:        "Ultimi 7 giorni",
            .noActivity:           "Nessuna attività",
            .tokensGenerated:      "token generati",
            .refAPI:               "rif. API",
            .percentOfLimit:       "% del limite",
            .tok:                  "tok",
            .windowIn:             "finestra tra",
            .windowExhausted:      "finestra esaurita",
            .todayTotal:           "Totale oggi",
            .todayTokensGenerated: "token generati",
            .calls:                "chiamate",
            .sessions:             "sessioni",
            .real:                 "reali",
            .rateLimitToday:       "Limite raggiunto",
            .rateLimitPast:        "Ultimo limite",
            .rateLimitResets:      "Ripristino:",
            .noDataMessage:        "Esegui `claude` nel terminale per vedere l'utilizzo",
            .settingsOpen:         "Impostazioni",
            .settingsClose:        "Chiudi impostazioni",
            .quit:                 "Esci",
            .refresh:              "Aggiorna (Cmd+R)",
            .sectionNotifications: "Notifiche",
            .thresholdAlerts:      "Avvisi soglia",
            .thresholdDesc:        "Avvisi al 70% e 90% del limite finestra (5h) e settimanale",
            .notificationsOff:     "Le notifiche sono disabilitate",
            .sectionLimits:        "Limiti token",
            .windowFiveHLabel:     "Finestra 5h",
            .weeklyLabel:          "Settimanale",
            .modified:             "(modificato)",
            .detectedPlan:         "Piano rilevato:",
            .resetButton:          "Ripristina",
            .sectionAbout:         "Informazioni",
            .dataSource:           "Fonte dati",
            .network:              "Rete",
            .noExternalConns:      "Nessuna connessione esterna",
            .languageLabel:        "Lingua",
            .apiRefNote:           "Rif. API: prezzi pubblici Anthropic",
            .lastUpdated:          "Aggiornato",
            .calibrated:           "calibrato",
            .resetsIn:             "ripristino tra",
        ],

        .french: [
            .currentSession:       "Session actuelle",
            .windowFiveH:          "Fenêtre (5h)",
            .lastSevenDays:        "7 derniers jours",
            .noActivity:           "Pas d'activité",
            .tokensGenerated:      "tokens générés",
            .refAPI:               "réf. API",
            .percentOfLimit:       "% de la limite",
            .tok:                  "tok",
            .windowIn:             "fenêtre dans",
            .windowExhausted:      "fenêtre épuisée",
            .todayTotal:           "Total aujourd'hui",
            .todayTokensGenerated: "tokens générés",
            .calls:                "appels",
            .sessions:             "sessions",
            .real:                 "réels",
            .rateLimitToday:       "Limite atteinte",
            .rateLimitPast:        "Dernière limite",
            .rateLimitResets:      "Réinitialise:",
            .noDataMessage:        "Lancez `claude` dans le terminal pour voir votre utilisation",
            .settingsOpen:         "Paramètres",
            .settingsClose:        "Fermer les paramètres",
            .quit:                 "Quitter",
            .refresh:              "Actualiser (Cmd+R)",
            .sectionNotifications: "Notifications",
            .thresholdAlerts:      "Alertes de seuil",
            .thresholdDesc:        "Alertes à 70% et 90% de la limite fenêtre (5h) et hebdomadaire",
            .notificationsOff:     "Les notifications sont désactivées",
            .sectionLimits:        "Limites de tokens",
            .windowFiveHLabel:     "Fenêtre 5h",
            .weeklyLabel:          "Hebdomadaire",
            .modified:             "(modifié)",
            .detectedPlan:         "Plan détecté:",
            .resetButton:          "Réinitialiser",
            .sectionAbout:         "À propos",
            .dataSource:           "Source de données",
            .network:              "Réseau",
            .noExternalConns:      "Aucune connexion externe",
            .languageLabel:        "Langue",
            .apiRefNote:           "Réf. API: tarifs publics Anthropic",
            .lastUpdated:          "Mis à jour",
            .calibrated:           "calibré",
            .resetsIn:             "réinitialise dans",
        ],

        .german: [
            .currentSession:       "Aktuelle Sitzung",
            .windowFiveH:          "Fenster (5Std)",
            .lastSevenDays:        "Letzte 7 Tage",
            .noActivity:           "Keine Aktivität",
            .tokensGenerated:      "erzeugte Token",
            .refAPI:               "API-Ref.",
            .percentOfLimit:       "% des Limits",
            .tok:                  "tok",
            .windowIn:             "Fenster in",
            .windowExhausted:      "Fenster erschöpft",
            .todayTotal:           "Heute gesamt",
            .todayTokensGenerated: "erzeugte Token",
            .calls:                "Aufrufe",
            .sessions:             "Sitzungen",
            .real:                 "real",
            .rateLimitToday:       "Limit erreicht",
            .rateLimitPast:        "Letztes Limit",
            .rateLimitResets:      "Zurücksetzung:",
            .noDataMessage:        "Starte `claude` im Terminal, um deine Nutzung zu sehen",
            .settingsOpen:         "Einstellungen",
            .settingsClose:        "Einstellungen schließen",
            .quit:                 "Beenden",
            .refresh:              "Aktualisieren (Cmd+R)",
            .sectionNotifications: "Benachrichtigungen",
            .thresholdAlerts:      "Schwellenwert-Benachrichtigungen",
            .thresholdDesc:        "Benachrichtigungen bei 70% und 90% des Fenster- (5Std) und Wochenlimits",
            .notificationsOff:     "Benachrichtigungen sind deaktiviert",
            .sectionLimits:        "Token-Limits",
            .windowFiveHLabel:     "Fenster 5Std",
            .weeklyLabel:          "Wöchentlich",
            .modified:             "(geändert)",
            .detectedPlan:         "Erkannter Plan:",
            .resetButton:          "Zurücksetzen",
            .sectionAbout:         "Über",
            .dataSource:           "Datenquelle",
            .network:              "Netzwerk",
            .noExternalConns:      "Keine externen Verbindungen",
            .languageLabel:        "Sprache",
            .apiRefNote:           "API-Ref.: öffentliche Anthropic-Preise",
            .lastUpdated:          "Aktualisiert",
            .calibrated:           "kalibriert",
            .resetsIn:             "zurückgesetzt in",
        ],
    ]
}
