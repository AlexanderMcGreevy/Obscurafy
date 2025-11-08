import Foundation
import Combine

protocol PrivacyConsentManaging {
    var hasConsented: Bool { get }
    func recordConsent(_ consented: Bool)
}

final class PrivacyConsentManager: PrivacyConsentManaging, ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private let storageKey = "com.vaulteye.privacyConsent"
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var hasConsented: Bool {
        userDefaults.bool(forKey: storageKey)
    }

    func recordConsent(_ consented: Bool) {
        guard hasConsented != consented else { return }
        objectWillChange.send()
        userDefaults.set(consented, forKey: storageKey)
    }
}
