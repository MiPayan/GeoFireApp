//  Created by Edoardo de Cal on 10/20/19.
//  Copyright © 2019 Edoardo de Cal. All rights reserved.
//

import UIKit
import MapKit
import GeoFire
import CoreLocation
import FirebaseAuth
import SwiftLocation

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    let mapView: MKMapView = {
        let mapView = MKMapView()
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsBuildings = true
        mapView.showsLargeContentViewer = true
        mapView.showsUserLocation = false
        mapView.translatesAutoresizingMaskIntoConstraints = false
        return mapView
    }()
    
    var detailView: CustomView?
    let locationManager = CLLocationManager()
    let clusteringManager = FBClusteringManager()
    var array: [FBAnnotation] = []
    var arrayKeys: [String] = []
    
    var authEndResult: AuthDataResult!
    var geoRef = DatabaseReference()
    var lastLocation: CLLocation!
    var fountainID = "Id"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addMapView()
        authenticateUser()
        setupFirebase()
        addDetailView()
    }
    
    func addDetailView() {
        detailView = CustomView()
        guard let detailView = detailView else { return }
        view.addSubview(detailView)
        detailView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        detailView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20).isActive = true
    }
    
    
    func setupFirebase() {
        geoRef = Database.database().reference().child("Fountains")
    }
    
    func authenticateUser() {
        Auth.auth().signInAnonymously(completion: { (authResult, error) in
            if let error = error {
                print("Anon sign in faild:", error.localizedDescription)
            } else {
                self.authEndResult = authResult
                self.setLocationManager()
            }
        })
    }
    
    func setLocationManager() {
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        locationManager.distanceFilter = kCLLocationAccuracyNearestTenMeters
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
    }
    
    func getLocation() -> CLLocation {
        if let newLocation = locationManager.location {
            lastLocation = newLocation
            return newLocation
        } else {
            return lastLocation
        }
    }
    
    func setLocation() {
        let newLocation = getLocation()
        GeoFire(firebaseRef: geoRef).setLocation(CLLocation(latitude: newLocation.coordinate.latitude, longitude: newLocation.coordinate.longitude), forKey: self.authEndResult.user.uid) { (error) in
            if (error != nil) {
                print("An error occured: \(error!)")
            } else {
                print("Saved location successfully")
            }
        }
    }
    
    func setQuery(center: CLLocation, radius: Double) -> GFQuery {
        let query =  GeoFire(firebaseRef: geoRef).query(at: center, withRadius: radius)
        return query
    }

    func addMapView() {
        mapView.delegate = self
        view.addSubview(mapView)
        mapView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        mapView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        mapView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        LocationManager.shared.locateFromGPS(.continous, accuracy: .city) { result in
        switch result {
          case .failure(let error):
            debugPrint("Received error: \(error)")
          case .success(let location):
            debugPrint("Location received: \(location)")
        }
        
//        let userLocation:CLLocation = locations[0] as CLLocation
//
//        let location2D = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        
//        guard let randomID = Database.database().reference().childByAutoId().key else { return }
//        geoFueg.setLocation(userLocation, forKey: randomID) { (error) in
//            if (error != nil) {
//                print("An error occured: \(error!)")
//            } else {
//                print("Saved location successfully")
//            }
//        }
    
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        
            let mapBoundsWidth = Double(self.mapView.bounds.size.width)
            let mapVisibleRect = self.mapView.visibleMapRect
            let scale = mapBoundsWidth / mapVisibleRect.size.width
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let strongSelf = self else { return }
                let annotationArray = strongSelf.clusteringManager.clusteredAnnotations(withinMapRect: mapVisibleRect, zoomScale:scale)
                DispatchQueue.main.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.clusteringManager.display(annotations: annotationArray, onMapView:strongSelf.mapView)
                }
            }
            
            let centerLocation = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
            
            var radius = mapView.currentRadius()
            print("radius: ", radius)
            
            if radius > 5000 { return }
            
            self.setQuery(center: centerLocation, radius: 2).observe(.keyEntered, with: {(key: String!, location: CLLocation!) in
                guard let key = key else { return }
                var addKey = true
                
                for element in self.arrayKeys {
                    if element == key {
                        addKey = false
                    }
                }
                
                if addKey {
                    self.arrayKeys.append(key)
                    print("Pin ADDED! \(key)")
                    
                    let coordinate = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                    

                    
                    
                }
                
                
                
                
                return
            })
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        var reuseId = ""
        if annotation is FBAnnotationCluster {
            reuseId = "Cluster"
            var clusterView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
            if clusterView == nil {
                clusterView = FBAnnotationClusterView(annotation: annotation, reuseIdentifier: reuseId, configuration: FBAnnotationClusterViewConfiguration.default())
            } else {
                clusterView?.annotation = annotation
            }
            return clusterView
        } else {
            reuseId = "Pin"
            var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView
            if pinView == nil {
                pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                pinView?.pinTintColor = UIColor.green
            } else {
                pinView?.annotation = annotation
            }
            return pinView
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        print("You tapped an annotation!")
        guard let latitude = view.annotation?.coordinate.latitude else { return }
        guard let longitude = view.annotation?.coordinate.longitude else { return}
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude)) { (placemarks, error) in
            guard let placemark = placemarks?[0] as? CLPlacemark else { return }

            print(placemark.subLocality)

            guard let nameLabel = placemark.thoroughfare, let nameCity = placemark.subAdministrativeArea, let nameRegion = placemark.administrativeArea else { return }
            
            if let annotation = view.annotation as? Fountain {
                print("Hai toccato una fontana")
                annotation.nameCity = nameCity
                annotation.nameRegion = nameRegion
            }
            
            self.detailView?.setTextLabels(textStreet: nameLabel, textCity: nameCity, textRegion: nameRegion)
            
        }
    }
    
    func addPin(location: CLLocation) {
        let coordinate = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let annotation = Fountain(coordinate: coordinate)
        clusteringManager.add(annotations: [annotation])
    }
    

}
