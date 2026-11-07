import SwiftUI
import MapKit

struct ChurchMapView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var locationManager = ChurchLocationManager()
    @State private var service = ChurchSearchService()
    @State private var feastCalendar = OrthodoxFeastCalendarService()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var selectedPlace: ChurchPlace?
    @State private var hasCenteredOnUser = false
    @State private var searchText = ""
    @State private var clusters: [PinCluster] = []
    @State private var clusterLevel: Int?
    @State private var feastHighlightTerms: Set<String> = []
    @State private var feastHighlightTitle: String?
    @FocusState private var searchFocused: Bool

    private var suggestionRows: [SearchSuggestion] {
        // ChurchSearchService has already ranked these by explicit region,
        // name relevance and only then distance. Re-sorting here by the user's
        // location destroys that order (and can move the exact match last).
        Array(service.suggestions.prefix(20))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                content

                VStack(spacing: 8) {
                    topBar
                    if !searchFocused && !feastHighlightTerms.isEmpty {
                        feastHighlightBanner
                    }
                    if searchFocused && !suggestionRows.isEmpty {
                        searchResultsList
                    }
                }
                .padding(.top, proxy.safeAreaInsets.top + 4)
                .padding(.horizontal, 16)

                locationButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16)
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 40)

                attribution
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, 10)
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 6)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if locationManager.authorizationStatus == .authorizedWhenInUse
                || locationManager.authorizationStatus == .authorizedAlways {
                locationManager.startUpdating()
            }
        }
        .onChange(of: service.isDataLoaded) { _, loaded in
            if loaded { recomputeClusters() }
        }
        .onChange(of: feastCalendar.isLoaded) { _, loaded in
            if loaded {
                rebuildFeastHighlights()
                recomputeClusters()
            }
        }
        .task {
            await feastCalendar.loadCalendar()
        }
        .task(id: searchText) {
            let q = searchText.trimmingCharacters(in: .whitespaces)
            guard q.count >= 2 else { service.clearSuggestions(); return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            await service.search(q, near: visibleRegion?.center ?? locationManager.userLocation)
        }
        .sheet(item: $selectedPlace) { place in
            ChurchDetailSheet(place: place, userLocation: locationManager.userLocation)
                .presentationDetents([.height(430), .large])
                .presentationBackground(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            permissionPromptView
        case .denied, .restricted:
            permissionDeniedView
        case .authorizedWhenInUse, .authorizedAlways:
            mapView
        @unknown default:
            mapView
        }
    }

    private var mapView: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            ForEach(clusters) { cluster in
                Annotation(cluster.places.count == 1 ? cluster.places[0].name : "",
                           coordinate: cluster.coordinate) {
                    clusterView(cluster)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .onChange(of: locationManager.userLocation != nil) { _, hasLocation in
            guard hasLocation else { return }
            if !hasCenteredOnUser {
                hasCenteredOnUser = true
                recenterOnUser()
            }
            recomputeClusters()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
            recomputeClusters()
        }
    }

    @ViewBuilder
    private func clusterView(_ cluster: PinCluster) -> some View {
        if cluster.places.count == 1 {
            Button {
                selectedPlace = cluster.places[0]
            } label: {
                pin(for: cluster.places[0])
            }
            .buttonStyle(.plain)
        } else {
            Button {
                zoomInto(cluster)
            } label: {
                clusterBubble(count: cluster.places.count, highlighted: cluster.places.contains(where: isFeastChurch))
            }
            .buttonStyle(.plain)
        }
    }

    private func pin(for place: ChurchPlace) -> some View {
        let highlighted = isFeastChurch(place)
        return ZStack {
            if highlighted {
                Circle()
                    .fill(Paper.gold.opacity(0.28))
                    .frame(width: 52, height: 52)
                    .blur(radius: 8)
                Circle()
                    .stroke(Paper.gold.opacity(0.85), lineWidth: 2)
                    .frame(width: 42, height: 42)
            }
            Image("orthodoxChurchMapMarker")
                .resizable()
                .scaledToFit()
                .frame(width: highlighted ? 42 : 34, height: highlighted ? 42 : 34)
                .shadow(color: highlighted ? Paper.gold.opacity(0.34) : .black.opacity(0.24),
                        radius: highlighted ? 8 : 2.5,
                        y: highlighted ? 3 : 1.5)
        }
            .accessibilityLabel(place.kind == .monastery ? "Μοναστήρι" : "Εκκλησία")
    }

    private func clusterBubble(count: Int, highlighted: Bool) -> some View {
        let size: CGFloat = count >= 100 ? 52 : (count >= 20 ? 46 : 40)
        return ZStack {
            if highlighted {
                Circle()
                    .fill(Paper.gold.opacity(0.22))
                    .frame(width: size + 18, height: size + 18)
                    .blur(radius: 8)
            }
            Circle().fill(highlighted ? Paper.gold : Paper.gold.opacity(0.9))
            Circle().stroke(.white.opacity(highlighted ? 0.95 : 1), lineWidth: highlighted ? 2.5 : 2)
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }

    private func zoomInto(_ cluster: PinCluster) {
        let currentSpan = visibleRegion?.span.latitudeDelta ?? 0.2
        let newSpan = max(currentSpan / 2.5, 0.01)
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: cluster.coordinate,
                span: MKCoordinateSpan(latitudeDelta: newSpan, longitudeDelta: newSpan)))
        }
    }

    // MARK: - Clustering: only recomputed when the camera settles, and only
    // over places roughly on screen — never the whole nationwide dataset,
    // and never on every view redraw.

    private func recomputeClusters() {
        let places = service.allPlaces
        guard !places.isEmpty else { clusters = []; return }

        let region = visibleRegion
        let latSpan = (region?.span.latitudeDelta ?? 1.2) * 1.6
        let lonSpan = (region?.span.longitudeDelta ?? 1.2) * 1.6
        let centerLat = region?.center.latitude ?? locationManager.userLocation?.latitude ?? places[0].lat
        let centerLon = region?.center.longitude ?? locationManager.userLocation?.longitude ?? places[0].lon

        let minLat = centerLat - latSpan / 2
        let maxLat = centerLat + latSpan / 2
        let minLon = centerLon - lonSpan / 2
        let maxLon = centerLon + lonSpan / 2

        var visible: [ChurchPlace] = []
        for place in places where place.lat >= minLat && place.lat <= maxLat
                                && place.lon >= minLon && place.lon <= maxLon {
            visible.append(place)
        }

        // Snap the grid to discrete zoom levels so small zoom changes keep the
        // exact same grid — clusters stay put instead of flickering. A little
        // hysteresis stops flip-flopping right at a level boundary.
        let unit = 0.0004
        let rawSpan = region?.span.latitudeDelta ?? 1.2
        let rawLevel = log2(max(rawSpan / 16.0, unit) / unit)
        let level: Int
        if let last = clusterLevel, abs(rawLevel - Double(last)) < 0.6 {
            level = last
        } else {
            level = max(0, Int(rawLevel.rounded()))
        }
        clusterLevel = level
        let cell = unit * pow(2.0, Double(level))

        var groups: [GridKey: [ChurchPlace]] = [:]
        for place in visible {
            let gx = Int((place.lat / cell).rounded(.down))
            let gy = Int((place.lon / cell).rounded(.down))
            groups[GridKey(x: gx, y: gy), default: []].append(place)
        }

        var built: [PinCluster] = []
        built.reserveCapacity(groups.count)
        for (key, group) in groups {
            var sumLat = 0.0
            var sumLon = 0.0
            for p in group {
                sumLat += p.lat
                sumLon += p.lon
            }
            let count = Double(group.count)
            let center = CLLocationCoordinate2D(latitude: sumLat / count, longitude: sumLon / count)
            // ID carries the level, so within a level annotations are reused
            // (stable), and only genuine level changes cause a re-cluster.
            built.append(PinCluster(id: "L\(level)_\(key.x)_\(key.y)", coordinate: center, places: group))
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            clusters = built
        }
    }

    // MARK: - Suggestions

    private func handleSuggestion(_ suggestion: SearchSuggestion) {
        searchFocused = false
        searchText = ""
        service.clearSuggestions()

        let span = suggestion.kind == .place ? 0.06 : 0.02
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: suggestion.coordinate,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)))
        }

        if suggestion.kind != .place {
            let place = ChurchPlace(id: suggestion.id, name: suggestion.name,
                                    lat: suggestion.coordinate.latitude,
                                    lon: suggestion.coordinate.longitude,
                                    kind: suggestion.kind == .monastery ? .monastery : .church,
                                    locality: suggestion.locality)
            selectedPlace = place
        }
        visibleRegion = MKCoordinateRegion(center: suggestion.coordinate,
                                           span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
        recomputeClusters()
    }

    private func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "el")).lowercased()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            searchField
            closeButton
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            if service.isLoading {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Paper.inkMute)
            }
            TextField("Αναζήτηση ναού, μονής ή τόπου", text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(Paper.ink)
                .submitLabel(.search)
                .focused($searchFocused)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    service.clearSuggestions()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Paper.inkMute.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .glassCircleFallback(shape: Capsule())
    }

    private var searchResultsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(suggestionRows) { suggestion in
                    Button {
                        handleSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: suggestion.kind))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(color(for: suggestion.kind))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(suggestion.name)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Paper.ink)
                                    .lineLimit(1)
                                if let locality = suggestion.locality, !locality.isEmpty {
                                    Text(locality)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Paper.inkMute)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if let d = distanceText(to: suggestion.coordinate) {
                                Text(d)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Paper.inkMute)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if suggestion.id != suggestionRows.last?.id {
                        Divider().padding(.leading, 50)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 320)
        .glassCircleFallback(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var feastHighlightBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Paper.gold)
            Text(feastHighlightTitle.map { "Σήμερα γιορτάζει: \($0)" } ?? "Σημερινοί εορτάζοντες ναοί")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Paper.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
            Text("χρυσοί δείκτες")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Paper.inkMute)
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .glassCircleFallback(shape: Capsule())
    }

    private func icon(for kind: SuggestionKind) -> String {
        switch kind {
        case .monastery: return "building.columns.fill"
        case .church: return "cross.fill"
        case .place: return "mappin.circle.fill"
        }
    }

    private func color(for kind: SuggestionKind) -> Color {
        switch kind {
        case .monastery: return Paper.ink
        case .church: return Paper.gold
        case .place: return Paper.inkMute
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Paper.ink)
                .frame(width: 44, height: 44)
        }
        .glassCircleFallback(shape: Circle())
    }

    private var locationButton: some View {
        Button {
            recenterOnUser()
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Paper.gold)
                .frame(width: 46, height: 46)
        }
        .glassCircleFallback(shape: Circle())
    }

    private var attribution: some View {
        Text("© OpenStreetMap")
            .font(.system(size: 10))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.black.opacity(0.35), in: Capsule())
    }

    private func distanceText(to coordinate: CLLocationCoordinate2D) -> String? {
        guard let origin = locationManager.userLocation else { return nil }
        let start = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let dest = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let meters = dest.distance(from: start)
        if meters < 1000 { return "\(Int(meters)) μ." }
        return String(format: "%.1f χλμ.", meters / 1000)
    }

    private func recenterOnUser() {
        guard let coordinate = locationManager.userLocation else { return }
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        }
        visibleRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    }

    private func rebuildFeastHighlights() {
        guard let today = feastCalendar.today() else {
            feastHighlightTerms = []
            feastHighlightTitle = nil
            return
        }

        let principal = today.majorFeast ?? today.feasts.first
        let terms = today.feasts.flatMap { dedicationTerms(for: $0) }
        feastHighlightTerms = Set(terms)
        feastHighlightTitle = principal?.namesCelebrated.first ?? principal?.title
    }

    private func dedicationTerms(for feast: OrthodoxFeast) -> [String] {
        var raw: [String] = feast.namesCelebrated
        raw.append(feast.title)

        let ignored: Set<String> = [
            "αγιοσ", "αγιου", "αγια", "αγιασ", "αγιων", "αγιοι",
            "οσιοσ", "οσιου", "οσια", "οσιασ", "οσιων", "ιεροσ", "ιερασ",
            "μαρτυροσ", "μαρτυρα", "μεγαλομαρτυροσ", "ομολογητου",
            "αποστολου", "αποστολων", "προφητου", "ιεραρχου",
            "και", "του", "τησ", "των", "εν", "ο", "η", "οι",
            "agios", "agiu", "agia", "agias", "agion", "agioi",
            "osios", "osiu", "osia", "osias", "osion",
            "mnimi", "mnimis", "martiras", "martiros", "megalomartiras",
            "apostolos", "apostolu", "apostolon", "profitis", "profitu",
            "ierarxis", "ierarxu", "omologitis", "omologitu",
            "kai", "tu", "tis", "ton", "en", "o", "i", "oi",
            "saint", "st", "holy", "church", "monastery"
        ]

        return raw.flatMap { text in
            ChurchSearchService.searchKey(text)
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count >= 4 && !ignored.contains($0) }
        }
    }

    private func isFeastChurch(_ place: ChurchPlace) -> Bool {
        guard !feastHighlightTerms.isEmpty else { return false }
        let key = ChurchSearchService.searchKey(place.name)
        let tokens = Set(key.split(separator: " ").map(String.init))
        return feastHighlightTerms.contains { term in
            tokens.contains(term) || key.contains(term)
        }
    }

    // MARK: - Permission states

    private var permissionPromptView: some View {
        ZStack {
            Paper.bg
            VStack(spacing: 16) {
                Image(systemName: "location.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(Paper.gold)
                Text("Βρες κοντινούς ναούς")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                Text("Χρειαζόμαστε την τοποθεσία σου για να σου δείξουμε τους ναούς και τα μοναστήρια κοντά σου.")
                    .font(.system(size: 13))
                    .foregroundStyle(Paper.inkMute)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Ενεργοποίηση Τοποθεσίας") {
                    locationManager.requestPermission()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding(.horizontal, 40)
        }
    }

    private var permissionDeniedView: some View {
        ZStack {
            Paper.bg
            VStack(spacing: 16) {
                Image(systemName: "location.slash")
                    .font(.system(size: 32))
                    .foregroundStyle(Paper.gold)
                Text("Η τοποθεσία είναι απενεργοποιημένη")
                    .font(.system(size: 26, weight: .regular, design: .serif))
                    .foregroundStyle(Paper.ink)
                Text("Πήγαινε στις Ρυθμίσεις για να ενεργοποιήσεις την τοποθεσία και να δεις τους κοντινούς ναούς.")
                    .font(.system(size: 13))
                    .foregroundStyle(Paper.inkMute)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Άνοιγμα Ρυθμίσεων") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Cluster model

private struct PinCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let places: [ChurchPlace]
}

private struct GridKey: Hashable {
    let x: Int
    let y: Int
}

private struct ChurchPhoto: Identifiable {
    let id = UUID()
    let url: URL
    let credit: String
}

// MARK: - Detail sheet with directions + name resolution

private struct ChurchDetailSheet: View {
    let place: ChurchPlace
    let userLocation: CLLocationCoordinate2D?

    @State private var resolvedLocality: String?
    @State private var resolvedName: String?
    @State private var lookingUpName = false
    @State private var photos: [ChurchPhoto] = []
    @State private var selectedPhoto = 0
    @State private var lookAroundScene: MKLookAroundScene?
    @State private var showingLookAround = false
    @State private var loadingMedia = true

    private var effectiveLocality: String? { place.locality ?? resolvedLocality }

    private var isGenericName: Bool {
        let f = place.name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                   locale: Locale(identifier: "el")).lowercased()
        return place.name.isEmpty || f == "ναος" || f == "church" || f == "εκκλησια"
    }

    private var displayName: String { resolvedName ?? place.name }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            mediaHeader
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 20, weight: .regular, design: .serif))
                        .foregroundStyle(Paper.ink)
                    if lookingUpName { ProgressView().controlSize(.mini) }
                }
                HStack(spacing: 6) {
                    if let locality = effectiveLocality, !locality.isEmpty {
                        Text(locality)
                    }
                    if let distance = distanceText {
                        if effectiveLocality != nil { Text("·") }
                        Text(distance)
                    }
                }
                .font(.system(size: 13))
                .foregroundStyle(Paper.inkMute)
            }

            Text("ΟΔΗΓΙΕΣ")
                .font(.system(size: 11, weight: .semibold)).tracking(2)
                .foregroundStyle(Paper.inkMute)

            HStack(spacing: 10) {
                directionButton("Apple Maps") { openAppleMaps() }
                directionButton("Google Maps") { openGoogleMaps() }
                directionButton("Waze") { openWaze() }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            if place.locality == nil { await resolveLocality() }
            // One POI lookup gives both the real name (if ours is generic) and
            // Apple's accurate building coordinate, which we use for media so
            // Look Around and photos lock onto the church, not a field nearby.
            let poi = await resolvePOI()
            if isGenericName, let name = poi.name { resolvedName = name }
            await loadMedia(at: poi.coordinate ?? place.coordinate)
        }
    }

    // Cover image (or Look Around, or a designed fallback) plus a strip of
    // thumbnails when there is more than one photo.
    @ViewBuilder private var mediaHeader: some View {
        VStack(spacing: 8) {
            ZStack {
                if showingLookAround, let scene = lookAroundScene {
                    LookAroundPreview(initialScene: scene)
                } else if !photos.isEmpty {
                    AsyncImage(url: photos[min(selectedPhoto, photos.count - 1)].url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        headerFallback.overlay(ProgressView().tint(.white))
                    }
                } else {
                    headerFallback.overlay { if loadingMedia { ProgressView().tint(.white) } }
                }
            }
            .frame(height: 168)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if !showingLookAround, !photos.isEmpty {
                    let credit = photos[min(selectedPhoto, photos.count - 1)].credit
                    if !credit.isEmpty {
                        Text(credit)
                            .font(.system(size: 9)).lineLimit(1)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.black.opacity(0.45))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .padding(6)
                    }
                }
            }

            if (lookAroundScene != nil && !photos.isEmpty) || photos.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if lookAroundScene != nil {
                            Button { showingLookAround = true } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Paper.ink)
                                    VStack(spacing: 2) {
                                        Image(systemName: "binoculars.fill")
                                            .foregroundStyle(.white).font(.system(size: 16))
                                        Text("Θέα").font(.system(size: 8, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.85))
                                    }
                                }
                                .frame(width: 54, height: 54)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(showingLookAround ? Paper.gold : .clear, lineWidth: 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                            Button {
                                showingLookAround = false
                                selectedPhoto = index
                            } label: {
                                AsyncImage(url: photo.url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { Rectangle().fill(Paper.hairline) }
                                .frame(width: 54, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(!showingLookAround && selectedPhoto == index ? Paper.gold : .clear, lineWidth: 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var headerFallback: some View {
        ZStack {
            LinearGradient(colors: [place.kind == .monastery ? Paper.ink : Paper.gold,
                                    Paper.gold.opacity(0.45)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image("orthodoxChurchMapMarker")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        }
    }

    private func loadMedia(at coordinate: CLLocationCoordinate2D) async {
        loadingMedia = true
        defer { loadingMedia = false }
        // Look Around at the accurate coordinate (may be unavailable — many
        // rural areas and much of Cyprus have no Look Around coverage yet).
        async let sceneTask = MKLookAroundSceneRequest(coordinate: coordinate).scene

        // First — identity photos, from THIS church's own OSM/Wikidata identifiers.
        //    These are the most reliable: the reference is attached to this
        //    exact building, so there is no same-name ambiguity at all.
        var identity: [ChurchPhoto] = []
        if let c = place.commons, !c.isEmpty {
            identity = await resolveCommonsReference(c)
        }
        if identity.isEmpty, let q = place.wikidata, !q.isEmpty {
            identity = await fetchWikidataImage(q)
        }
        if identity.isEmpty, let img = place.image, !img.isEmpty {
            identity = await directImagePhoto(img)
        }

        // Then — name + location photos: Wikipedia article, then nearby Commons
        //    files whose title/category name this church. Always location-
        //    anchored, so still correct; fills in churches without OSM tags.
        let tokens = distinctiveTokens(displayName)
        let article = tokens.isEmpty ? [] : await fetchWikipediaPhotos(at: coordinate, tokens: tokens)
        let nearby = await fetchCommonsPhotos(at: coordinate, tokens: tokens)

        var merged: [ChurchPhoto] = []
        var seen = Set<String>()
        for photo in identity + article + nearby {
            let key = fileKey(photo.url)
            if seen.insert(key).inserted { merged.append(photo) }
            if merged.count >= 8 { break }
        }
        photos = merged

        var scene = try? await sceneTask
        // If Apple has no Look Around exactly here, try our stored point too.
        if scene == nil, coordinate.latitude != place.coordinate.latitude || coordinate.longitude != place.coordinate.longitude {
            scene = try? await MKLookAroundSceneRequest(coordinate: place.coordinate).scene
        }
        lookAroundScene = scene
        // Look Around leads whenever Apple has it, so it's always the first
        // thing shown (and the first tile), not buried after the photos.
        if lookAroundScene != nil { showingLookAround = true }
    }

    // Resolve an OSM `wikimedia_commons` value — either a single "File:…" or a
    // whole "Category:…" of the church's photos.
    private func resolveCommonsReference(_ ref: String) async -> [ChurchPhoto] {
        let trimmed = ref.trimmingCharacters(in: .whitespaces)
        if trimmed.lowercased().hasPrefix("file:") {
            return await resolveCommonsTitles([trimmed])
        }
        let category = trimmed.lowercased().hasPrefix("category:") ? trimmed : "Category:\(trimmed)"
        return await fetchCategoryPhotos(category)
    }

    // Photographs filed in a specific Commons category (the church's own).
    private func fetchCategoryPhotos(_ category: String) async -> [ChurchPhoto] {
        var comps = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        comps.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "format", value: "json"),
            .init(name: "list", value: "categorymembers"),
            .init(name: "cmtitle", value: category),
            .init(name: "cmtype", value: "file"),
            .init(name: "cmlimit", value: "30"),
        ]
        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = obj["query"] as? [String: Any],
              let members = query["categorymembers"] as? [[String: Any]] else { return [] }
        let titles = members.compactMap { $0["title"] as? String }
            .filter { isPhotoTitle($0) }
        return await resolveCommonsTitles(Array(titles.prefix(8)))
    }

    // The image (P18) of a Wikidata entity, or its Commons category (P373).
    private func fetchWikidataImage(_ qid: String) async -> [ChurchPhoto] {
        let q = qid.trimmingCharacters(in: .whitespaces)
        guard q.hasPrefix("Q") else { return [] }
        guard let url = URL(string: "https://www.wikidata.org/wiki/Special:EntityData/\(q).json"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entities = obj["entities"] as? [String: Any],
              let entity = entities[q] as? [String: Any],
              let claims = entity["claims"] as? [String: Any] else { return [] }

        func firstStringValue(_ property: String) -> String? {
            guard let arr = claims[property] as? [[String: Any]], let first = arr.first,
                  let mainsnak = first["mainsnak"] as? [String: Any],
                  let datavalue = mainsnak["datavalue"] as? [String: Any],
                  let value = datavalue["value"] as? String else { return nil }
            return value
        }
        if let file = firstStringValue("P18") {
            let photos = await resolveCommonsTitles(["File:\(file)"])
            if !photos.isEmpty { return photos }
        }
        if let category = firstStringValue("P373") {
            return await fetchCategoryPhotos("Category:\(category)")
        }
        return []
    }

    // An OSM `image` tag: a direct photo URL, or a Commons File: page URL.
    private func directImagePhoto(_ value: String) async -> [ChurchPhoto] {
        let s = value.trimmingCharacters(in: .whitespaces)
        let lower = s.lowercased()
        // A Commons file page (…/wiki/File:Foo.jpg) → resolve to a real thumb.
        if lower.contains("commons.wikimedia.org"),
           let range = s.range(of: "File:", options: .caseInsensitive) {
            let tail = String(s[range.upperBound...])
            let title = "File:" + (tail.removingPercentEncoding ?? tail)
            let photos = await resolveCommonsTitles([title])
            if !photos.isEmpty { return photos }
        }
        // A plain direct image URL.
        if (lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".png")),
           let u = URL(string: s) {
            return [ChurchPhoto(url: u, credit: "OpenStreetMap")]
        }
        return []
    }

    // The distinctive words of the church name — the saint or dedication —
    // dropping generic words ("Ιερός", "Ναός", "Άγιος", "Παναγία") that would
    // match unrelated churches. Empty means we can't safely match photos.
    private func distinctiveTokens(_ name: String) -> [String] {
        let common: Set<String> = ["agios", "agiu", "agia", "agias", "agioi", "agion", "agioy",
                                    "agius", "agies", "agie", "ieros", "ieru", "iera", "ieras",
                                    "iero", "ieroi", "iere", "naos", "naoi", "ekklisia", "ekklisias",
                                    "ekklisi", "ekklisaki", "eksoklisi", "eksoklisio", "parekklisio",
                                    "parekklisi", "panagia", "panagias", "moni", "monis", "monastiri",
                                    "monastirion", "timiu", "timios", "timio", "ic", "gox",
                                    "tou", "tis", "ton", "sto", "stin", "of", "the", "and"]
        return ChurchSearchService.searchKey(name)
            .split(separator: " ").map(String.init)
            .filter { $0.count >= 4 && !common.contains($0) }
    }

    // Does a title (article or file) refer to this church, by sharing a
    // distinctive name word? Cross-script, reusing the search transliteration.
    private func isRelevant(_ text: String, _ tokens: [String]) -> Bool {
        let key = ChurchSearchService.searchKey(text)
        return tokens.contains { ChurchSearchService.wordHits(key, $0) }
    }

    // Deduplicate by the underlying file, ignoring thumbnail size prefixes.
    private func fileKey(_ url: URL) -> String {
        var name = url.lastPathComponent.lowercased()
        if let range = name.range(of: "px-") { name = String(name[range.upperBound...]) }
        return name
    }

    // The matching Wikipedia article's curated lead image plus its other
    // photos. We require the article to actually match the church name, so a
    // neighbouring stadium or shop can never supply the photos.
    private func fetchWikipediaPhotos(at coordinate: CLLocationCoordinate2D, tokens: [String]) async -> [ChurchPhoto] {
        guard let (host, pageid) = await relevantArticle(at: coordinate, tokens: tokens) else { return [] }

        var comps = URLComponents(string: "https://\(host)/w/api.php")!
        comps.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "format", value: "json"),
            .init(name: "pageids", value: "\(pageid)"),
            .init(name: "prop", value: "pageimages|images"),
            .init(name: "piprop", value: "name"),
            .init(name: "imlimit", value: "40"),
        ]
        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = obj["query"] as? [String: Any],
              let pages = query["pages"] as? [String: Any],
              let page = pages["\(pageid)"] as? [String: Any] else { return [] }

        var titles: [String] = []
        if let lead = page["pageimage"] as? String { titles.append("File:\(lead)") }
        if let images = page["images"] as? [[String: Any]] {
            for image in images {
                if let title = image["title"] as? String, isPhotoTitle(title) { titles.append(title) }
            }
        }
        var seen = Set<String>()
        titles = titles.filter { seen.insert($0.lowercased()).inserted }
        titles = Array(titles.prefix(12))
        guard !titles.isEmpty else { return [] }
        return await resolveCommonsTitles(titles)
    }

    // The nearest Wikipedia article whose title matches the church name.
    private func relevantArticle(at coordinate: CLLocationCoordinate2D, tokens: [String]) async -> (host: String, pageid: Int)? {
        for host in ["el.wikipedia.org", "en.wikipedia.org"] {
            var comps = URLComponents(string: "https://\(host)/w/api.php")!
            comps.queryItems = [
                .init(name: "action", value: "query"),
                .init(name: "format", value: "json"),
                .init(name: "list", value: "geosearch"),
                .init(name: "gscoord", value: "\(coordinate.latitude)|\(coordinate.longitude)"),
                .init(name: "gsradius", value: "600"),
                .init(name: "gslimit", value: "10"),
            ]
            guard let url = comps.url,
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let query = obj["query"] as? [String: Any],
                  let results = query["geosearch"] as? [[String: Any]] else { continue }
            for result in results {
                guard let title = result["title"] as? String, isRelevant(title, tokens),
                      let pageid = result["pageid"] as? Int else { continue }
                return (host, pageid)
            }
        }
        return nil
    }

    // Resolve a list of "File:…" titles to Commons thumbnails + credits,
    // preserving the input order (so the lead image stays first).
    private func resolveCommonsTitles(_ titles: [String]) async -> [ChurchPhoto] {
        var comps = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        comps.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "format", value: "json"),
            .init(name: "titles", value: titles.joined(separator: "|")),
            .init(name: "prop", value: "imageinfo"),
            .init(name: "iiprop", value: "url|extmetadata"),
            .init(name: "iiurlwidth", value: "800"),
        ]
        guard let url = comps.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = obj["query"] as? [String: Any],
              let pages = query["pages"] as? [String: Any] else { return [] }

        var byTitle: [String: ChurchPhoto] = [:]
        for value in pages.values {
            guard let page = value as? [String: Any],
                  let title = page["title"] as? String,
                  let infos = page["imageinfo"] as? [[String: Any]], let info = infos.first,
                  let thumb = info["thumburl"] as? String, let u = URL(string: thumb) else { continue }
            byTitle[title.lowercased().replacingOccurrences(of: "_", with: " ")] =
                ChurchPhoto(url: u, credit: creditLine(info["extmetadata"] as? [String: Any]))
        }
        return titles.compactMap { byTitle[$0.lowercased().replacingOccurrences(of: "_", with: " ")] }
    }

    private func creditLine(_ ext: [String: Any]?) -> String {
        guard let ext else { return "Wikimedia Commons" }
        let artist = ((ext["Artist"] as? [String: Any])?["value"] as? String) ?? ""
        let lic = ((ext["LicenseShortName"] as? [String: Any])?["value"] as? String) ?? ""
        let cleanArtist = artist.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [cleanArtist, lic].filter { !$0.isEmpty }
        return parts.isEmpty ? "Wikimedia Commons" : parts.joined(separator: " · ")
    }

    // Filters out logos, icons, maps, flags and other non-photo files that
    // articles often include, keeping real photographs.
    private func isPhotoTitle(_ title: String) -> Bool {
        let t = title.lowercased()
        guard t.hasSuffix(".jpg") || t.hasSuffix(".jpeg") || t.hasSuffix(".png") else { return false }
        let junk = ["logo", "icon", "flag", "coat of arms", "map", "location", "pog.",
                    "wiki", "commons-", "edit-", "ambox", "question book", "oojs",
                    "symbol", "gnome", "nuvola", "crystal", "seal", "emblem"]
        return !junk.contains { t.contains($0) }
    }

    // Nearby Commons photos that we can PROVE belong to this church: the file
    // title OR one of its Commons categories must match the church's name.
    // Proximity alone is not enough — in a city a photo geotagged next to the
    // church is often something else entirely (a nearby event, shop, statue),
    // so we never trust distance by itself. No name match ⇒ no photo (the
    // icon fallback), which is always better than a confidently wrong picture.
    private func fetchCommonsPhotos(at coordinate: CLLocationCoordinate2D, tokens: [String]) async -> [ChurchPhoto] {
        guard !tokens.isEmpty else { return [] }

        // Step one: nearby files and their distance.
        var geo = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        geo.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "format", value: "json"),
            .init(name: "list", value: "geosearch"),
            .init(name: "gscoord", value: "\(coordinate.latitude)|\(coordinate.longitude)"),
            .init(name: "gsradius", value: "500"),
            .init(name: "gslimit", value: "60"),
            .init(name: "gsnamespace", value: "6"),
        ]
        guard let gurl = geo.url,
              let (gdata, _) = try? await URLSession.shared.data(from: gurl),
              let gobj = try? JSONSerialization.jsonObject(with: gdata) as? [String: Any],
              let gquery = gobj["query"] as? [String: Any],
              let results = gquery["geosearch"] as? [[String: Any]] else { return [] }

        var dist: [String: Double] = [:]
        var candidates: [String] = []
        for r in results {
            guard let title = r["title"] as? String else { continue }
            let t = title.lowercased()
            guard t.hasSuffix(".jpg") || t.hasSuffix(".jpeg") || t.hasSuffix(".png"), isPhotoTitle(title) else { continue }
            dist[title] = (r["dist"] as? Double) ?? ((r["dist"] as? NSNumber)?.doubleValue ?? 9999)
            candidates.append(title)
            if candidates.count >= 30 { break }
        }
        guard !candidates.isEmpty else { return [] }

        // Step two: fetch each candidate's categories + image info in one call, and
        //    keep only those whose title or a category names this church.
        var info = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        info.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "format", value: "json"),
            .init(name: "titles", value: candidates.joined(separator: "|")),
            .init(name: "prop", value: "categories|imageinfo"),
            .init(name: "cllimit", value: "500"),
            .init(name: "iiprop", value: "url|extmetadata"),
            .init(name: "iiurlwidth", value: "800"),
        ]
        guard let iurl = info.url,
              let (idata, _) = try? await URLSession.shared.data(from: iurl),
              let iobj = try? JSONSerialization.jsonObject(with: idata) as? [String: Any],
              let iquery = iobj["query"] as? [String: Any],
              let pages = iquery["pages"] as? [String: Any] else { return [] }

        struct Hit { let photo: ChurchPhoto; let d: Double; let titleMatch: Bool }
        var hits: [Hit] = []
        for value in pages.values {
            guard let page = value as? [String: Any],
                  let title = page["title"] as? String,
                  let infos = page["imageinfo"] as? [[String: Any]], let ii = infos.first,
                  let thumb = ii["thumburl"] as? String, let u = URL(string: thumb) else { continue }
            let titleMatch = isRelevant(title, tokens)
            var catMatch = false
            if let cats = page["categories"] as? [[String: Any]] {
                catMatch = cats.contains { ($0["title"] as? String).map { isRelevant($0, tokens) } ?? false }
            }
            guard titleMatch || catMatch else { continue }
            hits.append(Hit(photo: ChurchPhoto(url: u, credit: creditLine(ii["extmetadata"] as? [String: Any])),
                            d: dist[title] ?? 9999, titleMatch: titleMatch))
        }
        // Title matches first, then closest.
        hits.sort { $0.titleMatch != $1.titleMatch ? $0.titleMatch && !$1.titleMatch : $0.d < $1.d }
        return Array(hits.prefix(8).map { $0.photo })
    }

    // One POI lookup: returns the real church name (if any) and Apple's
    // accurate coordinate for it, so media locks onto the real building.
    private func resolvePOI() async -> (name: String?, coordinate: CLLocationCoordinate2D?) {
        lookingUpName = isGenericName
        defer { lookingUpName = false }

        let request = MKLocalPointsOfInterestRequest(center: place.coordinate, radius: 200)
        guard let response = try? await MKLocalSearch(request: request).start() else { return (nil, nil) }

        let target = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        var best: (name: String, coord: CLLocationCoordinate2D, distance: CLLocationDistance)?
        for item in response.mapItems {
            guard let name = item.name, looksLikeChurch(name) else { continue }
            let c = item.placemark.coordinate
            let d = CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: target)
            if best == nil || d < best!.distance { best = (name, c, d) }
        }
        guard let best else { return (nil, nil) }
        return (best.name, best.coord)
    }

    private func looksLikeChurch(_ name: String) -> Bool {
        let f = name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                             locale: Locale(identifier: "el")).lowercased()
        if f == "ναος" || f == "church" || f == "εκκλησια" || f.isEmpty { return false }
        let markers = ["αγιος", "αγια", "αγιοι", "αγιου", "αγιων", "παναγια", "προφητης",
                       "τιμιου", "σταυρου", "μεταμορφωσ", "κοιμησ", "ευαγγελισμ", "αναληψ",
                       "εκκλησ", "ναος", "μον", "church", "chapel", "agios", "agia", "panagia",
                       "monast", "orthodox", "αρχαγγελ", "ταξιαρχ", "αναργυρ", "τριαδα", "προδρομ"]
        return markers.contains { f.contains($0) }
    }

    private func resolveLocality() async {
        let location = CLLocation(latitude: place.coordinate.latitude,
                                  longitude: place.coordinate.longitude)
        let geocoder = CLGeocoder()
        if let placemarks = try? await geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "el")),
           let placemark = placemarks.first {
            resolvedLocality = placemark.subLocality ?? placemark.locality ?? placemark.name
        }
    }

    private func directionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Paper.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Paper.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Paper.hairline, lineWidth: 1))
        }
    }

    private var distanceText: String? {
        guard let userLocation else { return nil }
        let origin = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let dest = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let meters = dest.distance(from: origin)
        if meters < 1000 { return "\(Int(meters)) μ. μακριά" }
        return String(format: "%.1f χλμ. μακριά", meters / 1000)
    }

    private func openAppleMaps() {
        let placemark = MKPlacemark(coordinate: place.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = displayName
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openGoogleMaps() {
        let lat = place.coordinate.latitude
        let lng = place.coordinate.longitude
        if let url = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)") {
            UIApplication.shared.open(url)
        }
    }

    private func openWaze() {
        let lat = place.coordinate.latitude
        let lng = place.coordinate.longitude
        if let url = URL(string: "https://waze.com/ul?ll=\(lat),\(lng)&navigate=yes") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ChurchMapView()
}
