import Foundation
import CoreLocation
import MapKit

/// Location is requested only when the user taps a feature that needs it; one-shot, never tracked.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let mgr = CLLocationManager()
    private var cont: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func current() async throws -> CLLocation {
        guard cont == nil else { throw AppError.interrupted }
        switch mgr.authorizationStatus {
        case .denied, .restricted: throw AppError.locationDenied
        default: break
        }
        return try await withCheckedThrowingContinuation { c in
            cont = c
            if mgr.authorizationStatus == .notDetermined { mgr.requestWhenInUseAuthorization() } else { mgr.requestLocation() }
        }
    }

    /// Reverse geocoding sends the coordinates to Apple's geocoding service.
    func placeDescription(for loc: CLLocation) async -> String {
        guard let p = try? await CLGeocoder().reverseGeocodeLocation(loc).first else {
            return "I have your location but could not look up an address."
        }
        let parts = [p.name, p.subLocality, p.locality].compactMap { $0 }
        return parts.isEmpty ? "I have your location but could not look up an address." : "You appear to be near " + parts.joined(separator: ", ") + ". This is approximate."
    }

    func nearbyPlaces(to loc: CLLocation, radius: CLLocationDistance = 300) async -> [String] {
        let req = MKLocalPointsOfInterestRequest(center: loc.coordinate, radius: radius)
        guard let resp = try? await MKLocalSearch(request: MKLocalSearch.Request(pointsOfInterestRequest: req)).start() else { return [] }
        return resp.mapItems
            .sorted { ($0.placemark.location?.distance(from: loc) ?? .infinity) < ($1.placemark.location?.distance(from: loc) ?? .infinity) }
            .compactMap { item -> String? in
                guard let name = item.name else { return nil }
                guard let l = item.placemark.location else { return name }
                return "\(name), about \(Int(l.distance(from: loc) / 10) * 10) metres"
            }
    }

    struct RoutePlan { var destination: String; var meters: Double; var minutes: Int; var steps: [String] }

    /// Route overview (list of steps), NOT live turn-by-turn guidance.
    func walkingRoute(to query: String, from loc: CLLocation) async throws -> RoutePlan {
        let search = MKLocalSearch.Request(); search.naturalLanguageQuery = query
        search.region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)
        guard let dest = try? await MKLocalSearch(request: search).start().mapItems.first else { throw AppError.nothingFound }
        let dreq = MKDirections.Request()
        dreq.source = MKMapItem(placemark: MKPlacemark(coordinate: loc.coordinate)); dreq.destination = dest
        dreq.transportType = .walking
        guard let route = try? await MKDirections(request: dreq).calculate().routes.first else { throw AppError.nothingFound }
        return RoutePlan(destination: dest.name ?? query, meters: route.distance, minutes: Int((route.expectedTravelTime / 60).rounded()),
                         steps: route.steps.map(\.instructions).filter { !$0.isEmpty })
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        Task { @MainActor in self.cont?.resume(returning: l); self.cont = nil }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.cont?.resume(throwing: AppError.locationUnavailable); self.cont = nil }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.cont != nil else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
            case .denied, .restricted: self.cont?.resume(throwing: AppError.locationDenied); self.cont = nil
            default: break
            }
        }
    }
}
