import Foundation
import UserNotifications

/// Διαχειριστής τοπικών ειδοποιήσεων του Klimax.
/// Μόνο τοπικές ειδοποιήσεις: χωρίς διακομιστή, χωρίς push.
/// Οι απομακρυσμένες ειδοποιήσεις (πίνακας ανακοινώσεων ενορίας) θα προστεθούν σε ξεχωριστό αρχείο.
@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    /// Αναγνωριστικά ειδοποιήσεων (machine keys, με τελείες).
    private enum ID {
        static let morningPrayer = "klimax.notification.morningPrayer"
        static let feastPrefix   = "klimax.notification.feast."
        static let nameDayPrefix = "klimax.notification.nameDay."
    }

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {}

    // MARK: Άδεια

    /// Ενημερώνει την τρέχουσα κατάσταση άδειας (χρήσιμο κατά το άνοιγμα των ρυθμίσεων).
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        #if DEBUG
        print("[Notifications] κατάσταση άδειας: \(settings.authorizationStatus.rawValue)")
        #endif
    }

    /// Ζητά άδεια από τον χρήστη. Καλέστε το σε πλαίσιο (π.χ. όταν ενεργοποιεί υπενθύμιση), όχι στην πρώτη εκκίνηση.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            #if DEBUG
            print("[Notifications] αίτημα άδειας, αποτέλεσμα: \(granted)")
            #endif
            return granted
        } catch {
            #if DEBUG
            print("[Notifications] σφάλμα άδειας: \(error)")
            #endif
            return false
        }
    }

    // MARK: Καθημερινή υπενθύμιση προσευχής

    /// Προγραμματίζει καθημερινή υπενθύμιση για την Προοιμιακὴ (πρωινή) Προσευχή.
    /// Επαναλαμβάνεται κάθε μέρα στην ίδια ώρα.
    func scheduleMorningPrayerReminder(hour: Int, minute: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: [ID.morningPrayer])

        let content = UNMutableNotificationContent()
        content.title = "Καιρός προσευχής"
        content.body  = "Η Προοιμιακή Προσευχή σε περιμένει."
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: ID.morningPrayer, content: content, trigger: trigger)

        do {
            try await center.add(request)
            #if DEBUG
            print("[Notifications] πρωινή υπενθύμιση στις \(hour):\(String(format: "%02d", minute))")
            #endif
        } catch {
            #if DEBUG
            print("[Notifications] σφάλμα προγραμματισμού πρωινής: \(error)")
            #endif
        }
    }

    func cancelMorningPrayerReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [ID.morningPrayer])
    }

    // MARK: Εορτή της ημέρας

    /// Προγραμματίζει ειδοποίηση εορτής για συγκεκριμένη ημερομηνία (μία φορά).
    /// Το `date` θέλει τουλάχιστον month και day.
    func scheduleFeastNotification(feastTitle: String, on date: DateComponents, hour: Int = 8, minute: Int = 0) async {
        var components = date
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Εορτή σήμερα"
        content.body  = feastTitle
        content.sound = .default

        let identifier = ID.feastPrefix + "\(components.month ?? 0).\(components.day ?? 0)"
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            #if DEBUG
            print("[Notifications] εορτή: \(feastTitle) στις \(components.day ?? 0)/\(components.month ?? 0)")
            #endif
        } catch {
            #if DEBUG
            print("[Notifications] σφάλμα εορτής: \(error)")
            #endif
        }
    }

    // MARK: Ονομαστική εορτή

    /// Προγραμματίζει ειδοποίηση ονομαστικής εορτής για συγκεκριμένη ημερομηνία (μία φορά).
    func scheduleNameDayNotification(names: String, on date: DateComponents, hour: Int = 8, minute: Int = 0) async {
        var components = date
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "Ονομαστική εορτή"
        content.body  = "Σήμερα γιορτάζουν: \(names). Χρόνια πολλά."
        content.sound = .default

        let identifier = ID.nameDayPrefix + "\(components.month ?? 0).\(components.day ?? 0)"
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            #if DEBUG
            print("[Notifications] ονομαστική: \(names) στις \(components.day ?? 0)/\(components.month ?? 0)")
            #endif
        } catch {
            #if DEBUG
            print("[Notifications] σφάλμα ονομαστικής: \(error)")
            #endif
        }
    }

    // MARK: Καθαρισμός και έλεγχος

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        #if DEBUG
        print("[Notifications] ακυρώθηκαν όλες οι εκκρεμείς ειδοποιήσεις")
        #endif
    }

    /// Τυπώνει τις εκκρεμείς ειδοποιήσεις στην κονσόλα (μόνο σε DEBUG) για επιβεβαίωση.
    func listPending() async {
        let requests = await center.pendingNotificationRequests()
        #if DEBUG
        print("[Notifications] εκκρεμείς: \(requests.count)")
        for r in requests { print("  • \(r.identifier)") }
        #endif
    }
}
