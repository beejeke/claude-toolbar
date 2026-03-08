import Foundation
import Security

/// Lee las credenciales OAuth del CLI de Claude Code desde el Keychain del sistema.
/// La entrada `Claude Code-credentials` la escribe el propio CLI durante el login OAuth.
/// No requiere entitlements especiales ya que la app no está sandboxed.
struct KeychainCredentialsService {

    /// Detecta el plan de suscripción leyendo `subscriptionType` y `rateLimitTier`
    /// del Keychain. Devuelve `.pro` como fallback si no se puede leer la entrada.
    static func readSubscriptionPlan() -> SubscriptionPlan {
        guard let oauth = readOAuthPayload() else { return .pro }
        let subType  = oauth["subscriptionType"] as? String ?? ""
        let rateTier = oauth["rateLimitTier"]    as? String ?? ""
        return SubscriptionPlan(subscriptionType: subType, rateLimitTier: rateTier)
    }

    // MARK: - Private

    private static func readOAuthPayload() -> [String: Any]? {
        let query: [String: Any] = [
            kSecClass       as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData  as String: true,
            kSecMatchLimit  as String: kSecMatchLimitOne
        ]

        var item: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data  = item as? Data,
              let root  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any]
        else { return nil }

        return oauth
    }
}
