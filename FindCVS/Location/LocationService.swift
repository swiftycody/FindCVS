//
//  LocationService.swift
//  FindCVS
//
//  Created by Cody on 2023/02/12.
//

import Combine
import CoreLocation

enum LocationError: Error {
    case unauthorized
    case unableToDetermineLocation
    
    var errorDescription: String {
        switch self {
        case .unauthorized:
            return "위치 정보를 비활성화하면 사용자의 현져 위치를 알 수 없습니다."
        case .unableToDetermineLocation:
            return "아직 위치 정보 권한이 없습니다."
        }
    }
}

class LocationService: NSObject {
    private let locationManager = CLLocationManager()

    private var authorizationRequests: [(Result<Void, LocationError>) -> Void] = []
    private var locationRequests: [(Result<CLLocation, LocationError>) -> Void] = []

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestWhenInUseAuthorization() -> Future<Void, LocationError> {
        guard locationManager.authorizationStatus == .notDetermined else {
            return Future { $0(.success(())) }
        }

        let future = Future<Void, LocationError> { completion in
            self.authorizationRequests.append(completion)
        }

        locationManager.requestWhenInUseAuthorization()

        return future
    }

    func requestLocation() -> Future<CLLocation, LocationError> {
        guard locationManager.authorizationStatus == .authorizedAlways ||
                locationManager.authorizationStatus == .authorizedWhenInUse
        else {
            return Future { $0(.failure(LocationError.unauthorized)) }
        }

        let future = Future<CLLocation, LocationError> { completion in
            self.locationRequests.append(completion)
        }

        locationManager.requestLocation()

        return future
    }

    private func handleLocationRequestResult(_ result: Result<CLLocation, LocationError>) {
        while locationRequests.count > 0 {
            let request = locationRequests.removeFirst()
            request(result)
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let locationError: LocationError
        if let error = error as? CLError, error.code == .denied {
            locationError = .unauthorized
        } else {
            locationError = .unableToDetermineLocation
        }
        
        handleLocationRequestResult(.failure(locationError))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            handleLocationRequestResult(.success(location))
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        while authorizationRequests.count > 0 {
            let request = authorizationRequests.removeFirst()
            request(.success(()))
        }
    }
}
