//
//  OneTimelineViewController.swift
//  TrackingAdvisor
//
//  Created by Benjamin BARON on 11/6/17.
//  Copyright © 2017 Benjamin BARON. All rights reserved.
//

import UIKit
import Mapbox

enum MapViewState {
    case folded
    case full
    case half
}

enum PointAnnotationType {
    case original
    case matched
}

class PointAnnotation: MGLPointAnnotation {
    var annotationType: PointAnnotationType?
}

class OneTimelineViewController: UIViewController, UIScrollViewDelegate, MGLMapViewDelegate {

    @IBOutlet weak var mapView: MGLMapView?
    @IBOutlet weak var mapViewHeight: NSLayoutConstraint!
    @IBOutlet weak var timeline: ISTimeline!
    
    var mapCloseView: CloseView!
    
    var timelineTitle: String!
    var timelineSubtitle: String!
    var timelineDay: String!
    var canUpdate: Bool = true
    var isAnimating = false
    var isFolded = true
    var annotations: [PointAnnotation] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timeline.delegate = self
        timeline.alwaysBounceVertical = true
        mapView?.delegate = self
        
        timeline.contentInset = UIEdgeInsetsMake(20.0, 20.0, 20.0, 20.0)
        mapView?.zoomLevel = 15
        mapView?.centerCoordinate = CLLocationCoordinate2D(latitude: 51.524543, longitude: -0.132176)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        LogService.shared.log(LogService.types.timelineDay,
                              args: [LogService.args.day: timelineDay])
        reload()
    }
    
    func reload() {
        guard let timeline = self.timeline else { return }
        
        let visits = DataStoreService.shared.getVisits(for: timelineDay, sameContext: false)
        updateLastVisit(from: visits)
        annotations.removeAll()
        
        let touchAction = { [weak self] (point:ISPoint) in
            guard let strongSelf = self else { return }
            
            // Load the place detail view and the navigation controller
            let controller = OneTimelinePlaceDetailViewController()
            controller.visit = point.visit
            
            let controllerNavigation = UINavigationController(rootViewController: controller)
            controllerNavigation.modalTransitionStyle = .crossDissolve
            controllerNavigation.modalPresentationStyle = .fullScreen
            strongSelf.present(controllerNavigation, animated: true, completion: nil)
            // TODO: Implement a push-style animation
        }
        
        let feedbackTouchAction = { [weak self] (point: ISPoint) in
            guard let strongSelf = self else { return }
            
            let controller = PlaceFinderMapTableViewController()
            controller.visit = point.visit
            
            if let vid = point.visit?.id {
                LogService.shared.log(LogService.types.timelineFeedback,
                                      args: [LogService.args.day: strongSelf.timelineDay,
                                             LogService.args.visitId: vid,
                                             LogService.args.value: "edit"])
            }
            
            let controllerNavigation = UINavigationController(rootViewController: controller)
            controllerNavigation.modalTransitionStyle = .crossDissolve
            controllerNavigation.modalPresentationStyle = .fullScreen
            strongSelf.present(controllerNavigation, animated: true, completion: nil)
        }
        
        let visitValidatedTouchAction = { [weak self] (_ point: ISPoint?) in
            guard let strongSelf = self else { return }
            
            if let vid = point?.visit?.id {
                point?.visit?.visited = 1
                LogService.shared.log(LogService.types.timelineFeedback,
                                      args: [LogService.args.day: strongSelf.timelineDay,
                                             LogService.args.visitId: vid,
                                             LogService.args.value: "yes"])
                UserUpdateHandler.visitedVisit(for: vid) {
                    print("timeline - updateVisit \(vid)")
                    DataStoreService.shared.updateVisit(with: vid, visited: 1)
                }
                
            }
        }
        
        let visitRemovedTouchAction = { [weak self](_ point: ISPoint?) in
            guard let strongSelf = self else { return }
            
            if let vid = point?.visit?.id {
                LogService.shared.log(LogService.types.timelineFeedback,
                                      args: [LogService.args.day: strongSelf.timelineDay,
                                             LogService.args.visitId: vid,
                                             LogService.args.value: "delete"])
                UserUpdateHandler.deleteVisit(for: vid) {
                    DataStoreService.shared.deleteVisit(vid: vid)
                }
                
            }
        }
        
        let addPlaceTouchAction = { [weak self] (pt1: ISPoint?, pt2: ISPoint?) in
            guard let strongSelf = self else { return }
            
            let controller = PlaceFinderMapTableViewController()
            controller.color = Constants.colors.primaryDark
            controller.name = "Add a place"
            controller.address = "Pick a place with the map and search bar below"
            
            if let startPt = pt1 {
                controller.startDate = startPt.visit?.arrival?.startOfDay
                controller.endDate = startPt.visit?.arrival
            }
            if let endPt = pt2 {
                controller.startDate = endPt.visit?.departure
                controller.endDate = endPt.visit?.departure?.endOfDay
            }
            if let startPt = pt1, let endPt = pt2 {
                controller.startDate = startPt.visit?.departure
                controller.endDate = endPt.visit?.arrival
            }
            
            controller.showDeleteButton = false
            controller.type = .add
            if let place1 = pt1?.visit?.place {
                controller.latitude = place1.latitude
                controller.longitude = place1.longitude
            }
            if let place2 = pt2?.visit?.place {
                controller.latitude = place2.latitude
                controller.longitude = place2.longitude
            }
            if let place1 = pt1?.visit?.place, let place2 = pt2?.visit?.place {
                let coords = CLLocationCoordinate2D.middlePoint(of: [
                    CLLocationCoordinate2D(latitude: place1.latitude, longitude: place1.longitude),
                    CLLocationCoordinate2D(latitude: place2.latitude, longitude: place2.longitude) ])
                controller.latitude = coords.latitude
                controller.longitude = coords.longitude
            }
            
            let controllerNavigation = UINavigationController(rootViewController: controller)
            controllerNavigation.modalTransitionStyle = .crossDissolve
            controllerNavigation.modalPresentationStyle = .fullScreen
            strongSelf.present(controllerNavigation, animated: true, completion: nil)
        }
        
        let updateTimelineTouchAction = { [weak self] (sender: UIButton) in
            guard let strongSelf = self else { return }
            if !strongSelf.canUpdate { return }
            
            LogService.shared.log(LogService.types.timelineUpdate,
                                  args: [LogService.args.day: strongSelf.timelineDay])
            
            
            strongSelf.canUpdate = false
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                self?.canUpdate = true
            }
            UserUpdateHandler.retrieveLatestUserUpdates(for: strongSelf.timelineDay, force: true) {
                strongSelf.reload()
            }
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm a"
        
        var timelinePoints: [ISPoint] = []
        var count = 0
        for visit in visits {
            guard let arrival = visit.arrival, let departure = visit.departure,
                  let placeName = visit.place?.name else { continue }
            
            let arrivalTime = dateFormatter.string(from: arrival)
            let departureTime = dateFormatter.string(from: departure)
            var icon = UIImage(named: "location")!
            if let placeIcon = visit.place?.icon {
                icon = UIImage(named: placeIcon)!.withRenderingMode(.alwaysTemplate)
            }
            let placePersonalInformationIcons = visit.place?.getPersonalInformationIcons()
            let times = "Visited from \(arrivalTime) to \(departureTime)"
                        
            let lineColor = Constants.colors.primaryDark
            
            var label: String?
            var labelColor: UIColor?
            if let placeType = visit.place?.placetype {
                if placeType == 1 {
                    label = "Home"
                    labelColor = Constants.colors.primaryLight
                } else if placeType == 3 {
                    label = "Work"
                    labelColor = Constants.colors.primaryLight
                } else if placeType == 4 {
                    label = "Work"
                    labelColor = Constants.colors.primaryDark
                }
            }
            
            var showFeedback = true
            if visit.visited != 0 {
                showFeedback = false
            }
            
            let point = ISPoint(
                title: placeName,
                label: label,
                description: times,
                descriptionSupp: placePersonalInformationIcons,
                pointColor: Constants.colors.primaryLight,
                lineColor: lineColor,
                labelColor: labelColor,
                touchUpInside: touchAction,
                feedbackTouchUpInside: feedbackTouchAction,
                addPlaceTouchUpInside: addPlaceTouchAction,
                icon: icon,
                iconBg: Constants.colors.primaryLight,
                fill: true,
                showFeedback: showFeedback)
            
            point.visit = visit
            timelinePoints.append(point)
            
            let matchedAnnotation = PointAnnotation()
            matchedAnnotation.coordinate = CLLocationCoordinate2D(latitude: (visit.place?.latitude) ?? 0.0, longitude: (visit.place?.longitude) ?? 0.0)
            matchedAnnotation.title = title
            matchedAnnotation.annotationType = .matched
            annotations.append(matchedAnnotation)
            
            count += 1
        }
        
        timeline.points = timelinePoints
        timeline.bubbleArrows = false
        timeline.timelineTitle = timelineTitle
        timeline.timelineSubtitle = timelineSubtitle
        timeline.timelineUpdateTouchAction = updateTimelineTouchAction
        timeline.timelimeAddPlaceFirstTouchAction = addPlaceTouchAction
        timeline.timelimeAddPlaceLastTouchAction = addPlaceTouchAction
        timeline.timelineValidatedPlaceTouchAction = visitValidatedTouchAction
        timeline.timelineRemovedPlaceTouchAction = visitRemovedTouchAction
    }
    
    private func updateLastVisit(from visits: [Visit]) {
        if  let lastVisit = visits.last,
            let lon = lastVisit.place?.longitude,
            let lat = lastVisit.place?.latitude,
            let lastKnownLocation = Settings.getLastKnownLocation() {
            
            let now = Date()
            let todayStr = DateHandler.dateToDayString(from: now)
            // if distance within the last known location
            let visitLocation = CLLocation(latitude: lat, longitude: lon)
            let distance = visitLocation.distance(from: lastKnownLocation)
            
            if todayStr == timelineDay && distance <= 50 {
                lastVisit.departure = now
            }
            
        }
    }
    
    private func showAnnotations() {
        mapView?.addAnnotations(annotations)
        mapView?.showAnnotations(annotations, animated: false)
        if let zoomLevel = mapView?.zoomLevel {
            mapView?.setZoomLevel(min(zoomLevel, 15), animated: true)
        }
    }
    
    private func hideAnnotations() {
        mapView?.removeAnnotations(annotations)
    }
    
    private func foldMapView() {
        LogService.shared.log(LogService.types.timelineMap,
                              args: [LogService.args.day: timelineDay,
                                     LogService.args.toggle: "hide"])
        
        isAnimating = true
        self.hideAnnotations()
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            self?.mapViewHeight.constant = 0
            self?.view.layoutIfNeeded()
            }, completion: { [weak self] c in
                if c {
                    self?.isAnimating = false
                    self?.isFolded = true
                    self?.mapCloseView.removeFromSuperview()
                }
        })
    }
    
    private func unfoldMapView() {
        LogService.shared.log(LogService.types.timelineMap,
                              args: [LogService.args.day: timelineDay,
                                     LogService.args.toggle: "show"])
        
        isAnimating = true
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            self?.mapViewHeight.constant = 350
            self?.view.layoutIfNeeded()
            }, completion: { [weak self] completed in
                if completed {
                    self?.isAnimating = false
                    self?.isFolded = false
                    self?.showAnnotations()
                    if let map = self?.mapView {
                        self?.mapCloseView = CloseView(text: "Close")
                        self?.mapCloseView.frame = CGRect(x: 0, y: 0, width: 95.0, height: 40)
                        self?.mapCloseView.center = CGPoint(x: map.center.x, y: map.frame.height - 40)
                        map.addSubview((self?.mapCloseView)!)
                        self?.mapCloseView.addTapGestureRecognizer { [weak self] in
                            self?.mapCloseView.alpha = 0.7
                            self?.foldMapView()
                            UIView.animate(withDuration: 0.3) { [weak self] in
                                self?.mapCloseView.alpha = 1
                            }
                        }
                    }
                }
        })
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        
        if isAnimating { return }
        let y = scrollView.contentOffset.y
        
        if !isFolded && y < -50.0 {
            foldMapView()
        } else if isFolded && y < -50.0 {
            unfoldMapView()
        }
    }
    
    // MARK: -  MGLMapViewDelegate methods
    
    func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        guard let pointAnnotation = annotation as? PointAnnotation else {
            return nil
        }
        
        // Use the point annotation’s longitude value (as a string) as the reuse identifier for its view.
        let reuseIdentifier = "\(pointAnnotation.coordinate.longitude)"
        
        // For better performance, always try to reuse existing annotations.
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
        
        // If there’s no reusable annotation view available, initialize a new one.
        if annotationView == nil {
            annotationView = CustomAnnotationView(reuseIdentifier: reuseIdentifier)
            annotationView!.frame = CGRect(x: 0, y: 0, width: 15, height: 15)
            
            // Set the annotation view’s background color to a value determined by its longitude.
            var color = Constants.colors.primaryDark
            if pointAnnotation.annotationType == .matched {
                color = Constants.colors.primaryLight
            }
            annotationView!.backgroundColor = color
        }
        
        return annotationView
    }
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        showAnnotations()
    }
    
    // DataStoreUpdateProtocol methods
    func dataStoreDidUpdate(for day: String?) {
        print("called dataStoreDidUpdate")
        if day != nil && day == timelineDay {
            reload()
        }
    }
}

// MGLAnnotationView subclass
class CustomAnnotationView: MGLAnnotationView {
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Force the annotation view to maintain a constant size when the map is tilted.
        scalesWithViewingDistance = false
        
        // Use CALayer’s corner radius to turn this view into a circle.
        layer.cornerRadius = frame.width / 2
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.cgColor
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Animate the border width in/out, creating an iris effect.
        let animation = CABasicAnimation(keyPath: "borderWidth")
        animation.duration = 0.1
        layer.borderWidth = selected ? frame.width / 4 : 2
        layer.add(animation, forKey: "borderWidth")
    }
}
