//
//  PlaceFinderMapTableViewController.swift
//  TrackingAdvisor
//
//  Created by Benjamin BARON on 12/18/17.
//  Copyright © 2017 Benjamin BARON. All rights reserved.
//

import UIKit
import Mapbox
import Alamofire


struct PlaceSearchResult: Codable {
    let street: String?
    let city: String?
    let places: [PlaceSearchResultDetail]
}

struct VisitRawTrace: Codable {
    let lon: Double
    let lat: Double
    let ts: Int
}

struct PlaceSearchResultDetail: Codable {
    let name: String
    let placeid: String
    let venueid: String
    let category: String
    let city: String?
    let address: String?
    let checkins: Int
    let score: Float
    let distance: Float
    let origin: String
    let longitude: Double
    let latitude: Double
    let icon: String?
    let emoji: String?
}

enum VisitTimesEditType {
    case start
    case end
}

enum VisitActionType: Int {
    case add  = 0
    case edit = 1
    case delete = 2
    case visited = 3
    case placeType = 4
    case placeEdit = 5
}

protocol VisitTimesEditDelegate {
    func didPress(visitTimesEditType: VisitTimesEditType?)
    func hasChangedDate(visitTimesEditType: VisitTimesEditType?, oldDate: Date?, newDate: Date?)
}

class PlaceFinderMapTableViewController: UIViewController, MGLMapViewDelegate, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, VisitTimesEditDelegate {

    @objc func done(_ sender: Any) {
        
        // Check that the place is valid
        if name == "Add a place" {
            let alertController = UIAlertController(title: "Pick a place", message: "You need to pick a place", preferredStyle: UIAlertControllerStyle.alert)
            let agreeAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.default) { (result : UIAlertAction) -> Void in
                print("tapped ok")
            }
            
            alertController.addAction(agreeAction)
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        // create a user place from the different information
        let notificationView: NotificationView? = NotificationView(text: "Updating the place...")
        notificationView?.frame = CGRect(x: 0, y: 0, width: view.frame.width - 50, height: 50)
        notificationView?.center = CGPoint(x: view.center.x, y: view.frame.height - 100.0)
        
        if let vid = visit?.id {
            LogService.shared.log(LogService.types.visitEditSaved,
                                  args: [LogService.args.visitId: vid])
        }

        updateVisit {
            notificationView?.text = "Done"
            UIView.animate(withDuration: 2.0, animations: {
                notificationView?.alpha = 0
            }, completion: { success in
                notificationView?.remove()
            })
        }
        
        // quit the modal window
        view.endEditing(true)

        presentingViewController?.dismiss(animated: true)
        if let view = notificationView {
            presentingViewController?.view.addSubview(view)
        }
        notificationView?.autoRemove(with: 15, text: "Failed, try again")
    }
    
    @objc func back(_ sender: UIBarButtonItem) {
        view.endEditing(true)
        
        if let vid = visit?.id {
            LogService.shared.log(LogService.types.visitEditBack,
                                  args: [LogService.args.visitId: vid])
        }
        
        // TODO: - ask if user is sure to leave the screen if there was any changes
        
        guard let controllers = navigationController?.viewControllers else { return }
        let count = controllers.count
        if count >= 2 {
            // get the previous place detail controller
            let vc = controllers[controllers.count - 2]
            navigationController?.popToViewController(vc, animated: true)
            
        } else if count == 1 {
            // return to the timelinez
            presentingViewController?.dismiss(animated: true)
        }
    }
    
    @objc func deletePlace(_ sender: Any) {
        view.endEditing(true)
        let alertController = UIAlertController(title: "Delete this place", message: "This will delete this place from your timeline", preferredStyle: UIAlertControllerStyle.alert)
        
        let deletePlaceAction = UIAlertAction(title: "Delete this place",
                                            style: UIAlertActionStyle.destructive) {
            [weak self] result in
            if let visit = self?.visit, let vid = visit.id {
                
                print("is mainThread: \(Thread.isMainThread)")
                
                LogService.shared.log(LogService.types.visitEditDelete,
                                      args: [LogService.args.visitId: vid,
                                             LogService.args.userChoice: "delete"])
                
                print("call UserUpdateHandler delete place")
                UserUpdateHandler.deleteVisit(for: vid) { [weak self] in
                    print("call DataStoreService delete visit")
                    DataStoreService.shared.deleteVisit(vid: vid, ctxt: nil)
                    self?.presentingViewController?.dismiss(animated: true)
                }
            }
                                                
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) {
            [weak self] result in
            if let vid = self?.visit?.id {
                LogService.shared.log(LogService.types.visitEditDelete,
                                      args: [LogService.args.visitId: vid,
                                             LogService.args.userChoice: "cancel"])
            }
        }
        
        alertController.addAction(deletePlaceAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc func editPlace(_ sender: Any) {
        foldMapView() { [weak self] in
                self?.searchbarView.becomeFirstResponder()

        }
    }
    
    var searchbarView: UISearchBar!
    var tableView: UITableView!
    var mapView: MGLMapView!
    lazy var headerView: HeaderPlace = {
        return HeaderPlace()
    }()
    lazy var startVisitTimesEditView: VisitTimesEditRow = {
        let vter = VisitTimesEditRow()
        vter.type = .start
        vter.textLabel.text = "Start time of the visit"
        vter.delegate = self
        return vter
    }()
    lazy var endVisitTimesEditView: VisitTimesEditRow = {
        let vter = VisitTimesEditRow()
        vter.type = .end
        vter.textLabel.text = "End time of the visit"
        vter.delegate = self
        return vter
    }()
    lazy var deleteButton: UIButton = {
        let button = UIButton()
        button.setTitle("Delete this place", for: .normal)
        button.setTitleColor(Constants.colors.darkRed, for: .normal)
        button.setTitleColor(Constants.colors.darkRed.withAlphaComponent(0.5), for: .highlighted)
        button.setBackgroundColor(Constants.colors.darkRed.withAlphaComponent(0.1), for: .highlighted)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    lazy var editPlaceButton: UIButton = {
        let button = UIButton()
        button.setTitle("Search for another place", for: .normal)
        button.setTitleColor(Constants.colors.primaryDark, for: .normal)
        button.setTitleColor(Constants.colors.primaryDark.withAlphaComponent(0.5), for: .highlighted)
        button.setBackgroundColor(Constants.colors.primaryDark.withAlphaComponent(0.1), for: .highlighted)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let cellId = "locationSearchResultCell"
    
    // height constraints
    var mapHeightContraint: NSLayoutConstraint!
    var headerHeightConstraint: NSLayoutConstraint!
    var deleteButtonHeightConstraint: NSLayoutConstraint!
    var editPlaceButtonHeightConstraint: NSLayoutConstraint!
    
    var name: String? {
        didSet { headerView.placeName = name }
    }
    var formatedAddress: String? {
        didSet { headerView.placeAddress = formatedAddress }
    }
    var address: String?
    var city: String?
    var color = UIColor.white {
        didSet { headerView.backgroundColor = color
                 marker.tintColor = color }
    }
    var longitude: Double?
    var latitude: Double?
    var startDate: Date? {
        didSet {
            startVisitTimesEditView.date = startDate
            getRawTrace()
        }
    }
    var endDate: Date? {
        didSet {
            endVisitTimesEditView.date = endDate
            getRawTrace()
        }
    }
    var type: VisitActionType = .edit
    
    var visit: Visit? {
        didSet {
            if let visit = visit, let place = visit.place {
                color = place.getPlaceColor()
                name = place.name
                address = place.address
                city = place.city
                formatedAddress = place.formatAddressString()
                longitude = place.longitude
                latitude = place.latitude
                startDate = visit.arrival
                endDate = visit.departure
            }
        }
    }
    
    var showDeleteButton: Bool = true { didSet {
        if let constraint = deleteButtonHeightConstraint {
            constraint.isActive = !showDeleteButton
            deleteButton.isHidden = true
        }
    }}
    
    var showEditPlaceButton: Bool = true { didSet {
        if let constraint = editPlaceButtonHeightConstraint {
            constraint.isActive = !showEditPlaceButton
            editPlaceButton.isHidden = true
        }
    }}
    
    var rawTrace: [VisitRawTrace]? {
        didSet {
            guard rawTrace != nil, mapView != nil else { return }
            if mapView != nil, let annotations = mapView.annotations, annotations.count > 0 {
                mapView.removeAnnotations(annotations)
            }
            
            var annotations: [CustomPointAnnotation] = []
            for point in rawTrace! {
                let count = annotations.count + 1
                let pointAnnotation = CustomPointAnnotation(coordinate: CLLocationCoordinate2D(latitude: point.lon, longitude: point.lat), title: nil, subtitle: nil)
                pointAnnotation.reuseIdentifier = "customAnnotation\(count)"
                // This dot image grows in size as more annotations are added to the array.
                pointAnnotation.image = dot(size:15, color: color.withAlphaComponent(0.3))
                
                annotations.append(pointAnnotation)
            }
            
            mapView.addAnnotations(annotations)
        }
    }
    
    var isAnimating: Bool = false
    var isFolded: Bool = false
    var isShowingStartDatePicker = false
    var isShowingEndDatePicker = false
    var hasMadeChanges = false
    var searchActive = false
    var marker = UIImageView()
    var isFetchingFromServer = false
    var hasExactMatch = false
    
    var searchResult:PlaceSearchResult? = nil
    var selectedPlace: PlaceSearchResultDetail? = nil
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .white
        
        // set up the navigation controller bar
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.view.backgroundColor = UIColor.clear
        self.navigationController?.navigationBar.barStyle = .blackOpaque
        
        // set up the table view
        tableView = UITableView(frame: view.bounds)
        tableView.register(PlaceFinderTableViewCell.self, forCellReuseIdentifier: cellId)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 50
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // set up the search bar controller
        searchbarView = UISearchBar(frame: view.bounds)
        searchbarView.placeholder = "Search for a place..."
        searchbarView.searchBarStyle = .minimal
        searchbarView.setShowsCancelButton(true, animated: true)
        searchbarView.returnKeyType = .done
        searchbarView.isTranslucent = true
        searchbarView.delegate = self
        searchbarView.translatesAutoresizingMaskIntoConstraints = false
        
        // set up the delete button
        deleteButton.addTarget(self, action: #selector(deletePlace), for: .touchUpInside)
        editPlaceButton.addTarget(self, action: #selector(editPlace), for: .touchUpInside)
        
        // set up the map view
        mapView = MGLMapView(frame: view.bounds, styleURL: MGLStyle.streetsStyleURL)
        mapView.tintColor = color
        mapView.delegate = self
        mapView.zoomLevel = 15
        mapView.allowsRotating = false
        mapView.allowsTilting = false
        mapView.translatesAutoresizingMaskIntoConstraints = false
        
        // Center the map on the visit coordinates
        if longitude != nil && latitude != nil {
            let coordinates = CLLocationCoordinate2D(latitude: latitude!, longitude: longitude!)
            mapView.centerCoordinate = coordinates
        }
        
        // getting the raw trace from the server
        getRawTrace()
        
        // Enable keyboard notifications when showing and hiding the keyboard
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        if let vid = visit?.id {
            LogService.shared.log(LogService.types.visitEditAccess,
                                  args: [LogService.args.visitId: vid])
        }
        
        setupViews()
    }
    
    func setupViews() {
        let saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(done))
        saveButton.tintColor = Constants.colors.superLightGray
        self.navigationItem.rightBarButtonItem = saveButton
        
        let backButton = UIButton()
        backButton.setImage(UIImage(named: "angle-left")!.withRenderingMode(.alwaysTemplate), for: .normal)
        backButton.tintColor = Constants.colors.superLightGray
        backButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        let leftBarButton = UIBarButtonItem(customView: backButton)
        self.navigationItem.leftBarButtonItem = leftBarButton
        
        self.view.addSubview(startVisitTimesEditView)
        self.view.addSubview(endVisitTimesEditView)
        self.view.addSubview(deleteButton)
        self.view.addSubview(editPlaceButton)
        self.view.addSubview(headerView)
        self.view.addSubview(mapView)
        self.view.addSubview(searchbarView)
        self.view.addSubview(tableView)
        
        self.view.addVisualConstraint("H:|[v0]|", views: ["v0": headerView])
        self.view.addVisualConstraint("H:|[v0]|", views: ["v0": startVisitTimesEditView])
        self.view.addVisualConstraint("H:|[v0]|", views: ["v0": endVisitTimesEditView])
        self.view.addVisualConstraint("H:|[v0]|", views: ["v0": deleteButton])
        self.view.addVisualConstraint("H:|[v0]|", views: ["v0": editPlaceButton])
        self.view.addVisualConstraint("H:|[v0]|", views: ["v0": mapView])
        self.view.addVisualConstraint("H:|[v0]|", views: ["v0": searchbarView])
        self.view.addVisualConstraint("H:|[v0]|", views: ["v0": tableView])
        self.view.addVisualConstraint("V:|[header][start][end][delete(40@750)][edit(40@750)][map][search][table]|", views: ["header": headerView, "start": startVisitTimesEditView, "end": endVisitTimesEditView, "delete": deleteButton, "edit": editPlaceButton, "map": mapView, "search": searchbarView, "table": tableView])
        
        // set up the overlaying map marker
        marker = UIImageView(image: UIImage(named: "map-marker")!.withRenderingMode(.alwaysTemplate))
        marker.tintColor = color
        marker.contentMode = .scaleAspectFit
        mapView.addSubview(marker)
        marker.translatesAutoresizingMaskIntoConstraints = false
        
        // set up constraints
        let verticalConstraint = NSLayoutConstraint(item: marker, attribute: .centerY, relatedBy: .equal, toItem: mapView, attribute: .centerY, multiplier: 1, constant: 0)
        let horizontalConstraint = NSLayoutConstraint(item: marker, attribute: .centerX, relatedBy: .equal, toItem: mapView, attribute: .centerX, multiplier: 1, constant: 0)
        let widthConstraint = NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 40)
        let heightConstraint = NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 40)
        view.addConstraints([horizontalConstraint, verticalConstraint, widthConstraint, heightConstraint])
        
        // set up the constraints on the UI elements
        headerHeightConstraint = NSLayoutConstraint(item: headerView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0)
        view.addConstraint(headerHeightConstraint)
        headerHeightConstraint.isActive = false
        
        mapHeightContraint = NSLayoutConstraint(item: mapView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 100)
        view.addConstraint(mapHeightContraint)
        mapHeightContraint.isActive = false
        
        deleteButtonHeightConstraint = NSLayoutConstraint(item: deleteButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0)
        view.addConstraint(deleteButtonHeightConstraint)
        deleteButtonHeightConstraint.isActive = !showDeleteButton
        if !showDeleteButton {
            deleteButton.isHidden = true
        }
        
        editPlaceButtonHeightConstraint = NSLayoutConstraint(item: editPlaceButton, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0)
        view.addConstraint(editPlaceButtonHeightConstraint)
        editPlaceButtonHeightConstraint.isActive = !showEditPlaceButton
        if !showEditPlaceButton {
            editPlaceButton.isHidden = true
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - VisitTimesEditDelegate method
    
    func toggleStartDatePicker() {
        isAnimating = true
        if isShowingEndDatePicker {
            toggleEndDatePicker()
        }
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.isShowingStartDatePicker {
                strongSelf.startVisitTimesEditView.hideDatePicker()
            } else {
                strongSelf.startVisitTimesEditView.showDatePicker()
            }
            strongSelf.view.layoutIfNeeded()
            }, completion: { [weak self] completed in
                if completed {
                    guard let strongSelf = self else { return }
                    strongSelf.isAnimating = false
                    strongSelf.isShowingStartDatePicker = !strongSelf.isShowingStartDatePicker
                }
        })
    }
    
    func toggleEndDatePicker() {
        if isShowingStartDatePicker {
            toggleStartDatePicker()
        }
        
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.isShowingEndDatePicker {
                strongSelf.endVisitTimesEditView.hideDatePicker()
            } else {
                strongSelf.endVisitTimesEditView.showDatePicker()
            }
            strongSelf.view.layoutIfNeeded()
            }, completion: { [weak self] completed in
                if completed {
                    guard let strongSelf = self else { return }
                    strongSelf.isAnimating = false
                    strongSelf.isShowingEndDatePicker = !strongSelf.isShowingEndDatePicker
                }
        })
    }
    
    func didPress(visitTimesEditType: VisitTimesEditType?) {
        guard let type = visitTimesEditType else { return }
        switch type {
        case .start:
            toggleStartDatePicker()
        case .end:
            toggleEndDatePicker()
        }
    }
    
    func hasChangedDate(visitTimesEditType: VisitTimesEditType?, oldDate: Date?, newDate: Date?) {
        guard let type = visitTimesEditType else { return }
        
        switch type {
        case .start:
            startDate = newDate
        case .end:
            endDate = newDate
        }
        
        if oldDate != newDate {
            hasMadeChanges = true
        }
    }
    
    // MARK: - UITableViewDataSource delegate
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let offset = showAddOption(for: searchbarView.text) ? 1 : 0
        if let places = searchResult?.places {
            return places.count + offset
        } else {
            return offset
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! PlaceFinderTableViewCell
        guard let searchResult = searchResult else { return cell }
        
        let offset = showAddOption(for: searchbarView.text) ? 1 : 0
        
        if let searchText = searchbarView.text, offset == 1 && indexPath.row == 0  {
            // this is a user-custom place
            let formattedString = NSMutableAttributedString()
            formattedString
                .normal("Enter new place ")
                .bold("\(searchText)")
            cell.placeNameLabel.attributedText = formattedString
            cell.placeAddressLabel.text = "Near \(formatAddress(street: searchResult.street, city: searchResult.city))"
            cell.distanceLabel.text = ""
            cell.iconView.image = UIImage(named: "plus-circle")!.withRenderingMode(.alwaysTemplate)
            cell.iconView.tintColor = Constants.colors.primaryDark
            cell.iconView.contentMode = .scaleAspectFit
            cell.place = nil
            cell.name = searchText
            cell.city = searchResult.city
            cell.street = searchResult.street
        } else {
            // this is a search result place
            let idx = indexPath.row - offset
            if idx < searchResult.places.count {
                let place = searchResult.places[idx]
                cell.placeNameLabel.text = place.name
                cell.placeAddressLabel.text = place.city
                let distanceStr = place.distance < 10 ? "5 meters" : "\(Int(place.distance)) meters"
                cell.distanceLabel.text = distanceStr
                cell.icon = place.icon
                cell.iconView.tintColor = Constants.colors.primaryLight
                cell.place = place
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) as? PlaceFinderTableViewCell {
            if let place = cell.place {
                // select the place
                name = place.name
                address = place.address
                city = place.city
                formatedAddress = formatAddress(street: place.address, city: place.city)
                latitude = place.latitude
                longitude = place.longitude
                selectedPlace = place
                let coordinates = CLLocationCoordinate2D(latitude: latitude!, longitude: longitude!)
                mapView.centerCoordinate = coordinates
                hasMadeChanges = true
                
                if let vid = visit?.id {
                    LogService.shared.log(LogService.types.visitEditSelected,
                                          args: [LogService.args.visitId: vid,
                                                 LogService.args.placeId: place.placeid,
                                                 LogService.args.venueId: place.venueid,
                                                 LogService.args.searchedText: searchbarView.text ?? ""])
                }
                
            } else {
                if indexPath.row == 0 {
                    // select the new place
                    name = cell.name ?? ""
                    address = cell.street
                    city = cell.city
                    formatedAddress = formatAddress(street: cell.street, city: cell.city)
                    hasMadeChanges = true
                    
                    if let vid = visit?.id {
                        LogService.shared.log(LogService.types.visitEditSelected,
                                              args: [LogService.args.visitId: vid,
                                                     LogService.args.placeId: "",
                                                     LogService.args.venueId: "",
                                                     LogService.args.searchedText: searchbarView.text ?? ""])
                    }
                }
            }
            tableView.deselectRow(at: indexPath, animated: true)
        }
        if isFolded {
            unfoldMapView()
        }
    }
    
    // MARK: - UISearchBarDelegate Delegate
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchActive = true
        foldMapView()
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchActive = false
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false
        unfoldMapView()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchActive = false
        unfoldMapView()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(reloadSearch), object: searchBar)
        perform(#selector(reloadSearch), with: searchBar, afterDelay: 0.5)
    }
    
    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let oldText = searchBar.text {
            let newText = (searchBar.text ?? "").replacingCharacters(in: Range(range, in: oldText)!, with: text)
            if oldText.count > newText.count && newText.count < 3 {
                getPlaces(matching: "")
            }
        }
        return true
    }
    
    @objc func reloadSearch(_ searchBar: UISearchBar) {
        guard let searchText = searchBar.text else { return }
        if searchText.count >= 3 {
            getPlaces(matching: searchText)
        } else if searchText.count == 0 {
            getPlaces(matching: "")
        }
    }
    
    // MARK: - fetch search result from server
    private func showAddOption(for searchText: String?) -> Bool {
        guard let searchText = searchText else { return false }
        if searchText == "" { return false }
        if hasExactMatch { return false }
        return true
    }
    
    private func getPlaces(matching searchText: String) {
        if isFetchingFromServer ||
            (self.mapView.centerCoordinate.longitude == 0 && self.mapView.centerCoordinate.latitude == 0) {
            return
        }
        
        isFetchingFromServer = true
        
        let parameters: Parameters = [
            "userid": Settings.getUserId() ?? "",
            "lon": longitude!,
            "lat": latitude!,
            "query": searchText
        ]
        
        Alamofire.request(Constants.urls.placeAutocompleteURL, method: .get, parameters: parameters)
            .responseJSON { [weak self] response in
                guard let strongSelf = self else { return }
                if response.result.isSuccess {
                    guard let data = response.data else { return }
                    do {
                        let decoder = JSONDecoder()
                        strongSelf.searchResult = try decoder.decode(PlaceSearchResult.self, from: data)
                        strongSelf.hasExactMatch = false
                        for place in strongSelf.searchResult!.places {
                            if place.name.lowercased().hasPrefix(searchText.lowercased()) {
                                strongSelf.hasExactMatch = true
                                break
                            }
                        }
                        strongSelf.tableView.reloadData()
                    } catch {
                        print("Error serializing the json", error)
                    }
                }
                strongSelf.isFetchingFromServer = false
        }
    }
    
    // MARK: - Fetch the raw trace from the server
    private func getRawTrace() {
        guard let start = startDate, let end = endDate, start < end else { return }
        self.rawTrace?.removeAll()
        
        let parameters: Parameters = [
            "userid": Settings.getUserId() ?? "",
            "start": start.timeIntervalSince1970,
            "end": end.timeIntervalSince1970
        ]
        
        Alamofire.request(Constants.urls.rawTraceURL, method: .get, parameters: parameters)
            .responseJSON { [weak self] response in
                guard let strongSelf = self else { return }
                if response.result.isSuccess {
                    guard let data = response.data else { return }
                    do {
                        let decoder = JSONDecoder()
                        strongSelf.rawTrace = try decoder.decode([VisitRawTrace].self, from: data)
                    } catch {
                        print("Error serializing the json", error)
                    }
                }
        }
    }
    
    private func updateVisit(_ callback: (()->Void)?) {
        if !hasMadeChanges { return }
        
        guard let start = startDate, let end = endDate else { return }
        
        let parameters: Parameters = [
            "userid": Settings.getUserId() ?? "",
            "start": start.timeIntervalSince1970,
            "end": end.timeIntervalSince1970,
            "day": DateHandler.dateToDayString(from: start),
            "lon": longitude ?? 0.0,
            "lat": latitude ?? 0.0,
            "type": type.rawValue,
            "name": name ?? "",
            "address": address ?? "",
            "city": city ?? "",
            "visitid": visit?.id ?? "",
            "oldplaceid": visit?.placeid ?? "",
            "newplaceid": selectedPlace?.placeid ?? "",
            "venueid": selectedPlace?.venueid ?? "",
        ]
        
        let visitid = visit?.id
        
        DispatchQueue.global(qos: .background).async {
            Alamofire.request(Constants.urls.addvisitURL, method: .post, parameters: parameters, encoding: JSONEncoding.default)
                .responseJSON { [weak self] response in
                    if response.result.isSuccess {
                        guard let data = response.data else { return }
                        do {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .secondsSince1970
                            let userUpdate = try decoder.decode(UserUpdate.self, from: data)
                            if self?.type == .edit, let vid = visitid {
                                DataStoreService.shared.deleteVisit(vid: vid, ctxt: nil) {
                                    DataStoreService.shared.updateDatabase(with: userUpdate) {
                                        callback?()
                                    }
                                }
                            } else {
                                DataStoreService.shared.updateDatabase(with: userUpdate) {
                                    callback?()
                                }
                            }
                            
                        } catch {
                            print("Error serializing the json", error)
                        }
                    }
            }
        }
        
    }
    
    // MARK: - Map view interactions
    private func foldMapView(callback: (()->())? = nil) {
        isAnimating = true
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.mapHeightContraint.isActive = true
            strongSelf.deleteButtonHeightConstraint.isActive = true
            strongSelf.editPlaceButtonHeightConstraint.isActive = true
            strongSelf.startVisitTimesEditView.hide()
            strongSelf.endVisitTimesEditView.hide()
            strongSelf.view.layoutIfNeeded()
            }, completion: { [weak self] completed in
                if completed {
                    guard let strongSelf = self else { return }
                    strongSelf.isAnimating = false
                    strongSelf.isFolded = true
                    callback?()
                }
        })
    }
    
    private func unfoldMapView(callback: (()->())? = nil) {
        view.endEditing(true)
        isAnimating = true
        searchbarView.text = nil
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.mapHeightContraint.isActive = false
            strongSelf.deleteButtonHeightConstraint.isActive = !strongSelf.showDeleteButton
            strongSelf.editPlaceButtonHeightConstraint.isActive = !strongSelf.showEditPlaceButton
            strongSelf.startVisitTimesEditView.show()
            strongSelf.endVisitTimesEditView.show()
            strongSelf.view.layoutIfNeeded()
            }, completion: { [weak self] completed in
                if completed {
                    guard let strongSelf = self else { return }
                    strongSelf.isAnimating = false
                    strongSelf.isFolded = false
                    callback?()
                }
        })
    }
    
    private func formatAddress(street: String?, city: String?) -> String {
        let addressString = street ?? ""
        let cityString = city ?? ""
        let sep = addressString != "" && cityString != "" ? ", " : ""
        return addressString + sep + cityString
    }

    // MARK: - Keyboard notifications
    
    @objc func keyboardWillShow(_ notification: NSNotification){
        let userInfo = notification.userInfo ?? [:]
        let keyboardFrame = (userInfo[UIKeyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue
        tableView.keyboardRaised(height: keyboardFrame.height)
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification){
        tableView.keyboardClosed()
    }
    
    // MARK: - MGLMapViewDelegate protocol
    
    func mapView(_ mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
        if (self.mapView.centerCoordinate.longitude != 0 && self.mapView.centerCoordinate.latitude != 0) {
            longitude = self.mapView.centerCoordinate.longitude
            latitude = self.mapView.centerCoordinate.latitude
            hasMadeChanges = true
            getPlaces(matching: searchbarView.text ?? "")
        }
    }
    
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        if let point = annotation as? CustomPointAnnotation,
            
            let image = point.image,
            let reuseIdentifier = point.reuseIdentifier {
            
            if let annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: reuseIdentifier) {
                // The annotatation image has already been cached, just reuse it.
                return annotationImage
            } else {
                // Create a new annotation image.
                return MGLAnnotationImage(image: image, reuseIdentifier: reuseIdentifier)
            }
        }
        
        // Fallback to the default marker image.
        return nil
    }
}


class VisitTimesEditRow : UIView {
    
    var delegate:VisitTimesEditDelegate?
    var type: VisitTimesEditType?
    
    var date: Date? {
        didSet {
            dateLabel.text = DateHandler.dateToLetterAndPeriod(from: date!)
            datePicker.minimumDate = date!.startOfDay
            datePicker.maximumDate = date!.endOfDay
            datePicker.date = date!
        }
    }
    
    var textLabel: UILabel = {
        let label = UILabel()
        label.text = "Visit"
        label.font = UIFont.systemFont(ofSize: 14.0)
        label.textColor = Constants.colors.primaryLight
        label.textAlignment = .left
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    var dateLabel: UILabel = {
        let label = UILabel()
        label.text = "Visit date"
        label.font = UIFont.systemFont(ofSize: 14.0)
        label.textColor = Constants.colors.primaryDark
        label.textAlignment = .right
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    var datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .time
        dp.addTarget(self, action: #selector(VisitTimesEditRow.datePickerValueChanged), for: .valueChanged)
        dp.translatesAutoresizingMaskIntoConstraints = false
        return dp
    }()
    
    var datePickerHeightConstraint: NSLayoutConstraint!
    var heightConstraint: NSLayoutConstraint!
    
    @objc func datePickerValueChanged(_ sender: UIDatePicker) {
        delegate?.hasChangedDate(visitTimesEditType: type, oldDate: date, newDate: sender.date)
        date = sender.date
        self.layoutIfNeeded()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    convenience init() {
        self.init(frame: CGRect.zero)
        setupViews()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
    
    func hideDatePicker() {
        datePicker.isHidden = true
        datePickerHeightConstraint.constant = 0
    }
    
    func showDatePicker() {
        datePicker.isHidden = false
        datePickerHeightConstraint.constant = 150
    }
    
    func hide() {
        hideDatePicker()
        heightConstraint.isActive = true
        dateLabel.alpha = 0
        textLabel.alpha = 0
    }
    
    func show() {
        heightConstraint.isActive = false
        dateLabel.alpha = 1
        textLabel.alpha = 1
    }

    func setupViews() {
        backgroundColor = .white
        
        addSubview(textLabel)
        addSubview(dateLabel)
        addSubview(datePicker)
        
        addVisualConstraint("V:|-(8@750)-[v0]", views: ["v0": textLabel])
        addVisualConstraint("H:|-[v0]", views: ["v0": textLabel])
        addVisualConstraint("V:|-(8@750)-[v0]", views: ["v0": dateLabel])
        addVisualConstraint("H:[v0]-|", views: ["v0": dateLabel])
        addVisualConstraint("V:[v0][v1]-(8@750)-|", views: ["v0": dateLabel, "v1": datePicker])
        
        datePickerHeightConstraint = NSLayoutConstraint(item: datePicker, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0.0)
        datePicker.addConstraint(datePickerHeightConstraint)
        
        heightConstraint = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 0)
        addConstraint(heightConstraint)
        heightConstraint.isActive = false
        
        translatesAutoresizingMaskIntoConstraints = false
        
        addTapGestureRecognizer {
            self.delegate?.didPress(visitTimesEditType: self.type)
        }
    }
}


class PlaceFinderTableViewCell: UITableViewCell {
    
    var icon: String? {
        didSet {
            if let icon = icon {
                iconView.image = UIImage(named: icon)!.withRenderingMode(.alwaysTemplate)
            }
        }
    }
    
    var placeAddressLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = Constants.colors.descriptionColor
        label.textAlignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    var distanceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = Constants.colors.descriptionColor
        label.textAlignment = .right
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    var placeNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textColor = .black
        label.textAlignment = .left
        label.lineBreakMode = .byTruncatingTail
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    var iconView: UIImageView = {
        let icon = UIImageView(image: UIImage(named: "map-marker")!.withRenderingMode(.alwaysTemplate))
        icon.tintColor = Constants.colors.primaryLight
        icon.contentMode = .scaleAspectFit
        icon.clipsToBounds = true
        icon.translatesAutoresizingMaskIntoConstraints = false
        return icon
    }()
    
    var place: PlaceSearchResultDetail?
    var name: String?
    var city: String?
    var street: String?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setupViews() {
        addSubview(placeAddressLabel)
        addSubview(distanceLabel)
        addSubview(placeNameLabel)
        addSubview(iconView)
        
        // add constraints
        addVisualConstraint("V:|-5-[v0(25)]", views: ["v0": iconView])
        addVisualConstraint("H:|-[v0(25)]", views: ["v0": iconView])
        addVisualConstraint("V:|-5-[v0]", views: ["v0": placeNameLabel])
        addVisualConstraint("V:[v0][v1]", views: ["v0": placeNameLabel, "v1": placeAddressLabel])
        addVisualConstraint("V:[v0][v1]", views: ["v0": placeNameLabel, "v1": distanceLabel])
        addVisualConstraint("H:[v0]-[v1]-|", views: ["v0": iconView, "v1": placeNameLabel])
        addVisualConstraint("H:[v0]-[v1]-[v2]-|", views: ["v0": iconView, "v1": placeAddressLabel, "v2": distanceLabel])
    }
}


// MGLAnnotation protocol reimplementation
class CustomPointAnnotation: MGLPointAnnotation {
    
    // As a reimplementation of the MGLAnnotation protocol, we have to add mutable coordinate and (sub)title properties ourselves.
    var type: String?
    var color: UIColor?
    
    // Custom properties that we will use to customize the annotation's image.
    var image: UIImage?
    var reuseIdentifier: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?) {
        super.init()
        
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
