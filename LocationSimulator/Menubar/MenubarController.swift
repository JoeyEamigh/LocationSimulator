//
//  MenubarController.swift
//  LocationSimulator
//
//  Created by David Klopp on 20.12.20.
//  Copyright © 2020 David Klopp. All rights reserved.
//

import AppKit
import CoreLocation

let kProjectWebsite = "https://schlaubischlump.github.io/LocationSimulator/"
let kGithubWebseite = "https://github.com/Schlaubischlump/LocationSimulator"

class MenubarController: NSResponder {
    /// The notification observer for status changes.
    private var statusObserver: NSObjectProtocol?

    /// Observe the search status.
    private var searchStartObserver: NSObjectProtocol?
    private var searchEndObserver: NSObjectProtocol?

    /// The main menu should always represent the status of the key window.
    private var windowController: WindowController? {
        return NSApp.keyWindow?.windowController as? WindowController
    }

    /// The current status.
    var deviceStatus: DeviceStatus = .disconnected

    /// True if the search is currently active, false otherwise.
    public var isSearching: Bool = false {
        didSet {
            if self.isSearching {
                self.disableMoveControls()
            } else {
                self.enableMoveControls()
            }
        }
    }

    // MARK: - Constructor

    override init() {
        super.init()
        self.registerNotifications()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.registerNotifications()
    }

    // MARK: - Destructor

    deinit {
        // Remove the observer
        if let observer = self.statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = self.searchStartObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = self.searchEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        self.searchStartObserver = nil
        self.searchEndObserver = nil
        self.statusObserver = nil
    }

    // MARK: - Notification

    /// Listen for state changes
    public func registerNotifications() {
        self.statusObserver = NotificationCenter.default.addObserver(forName: .StatusChanged, object: nil,
                                                                     queue: .main) { [weak self] notification in
            // Make sure the request is send from the key window subview.
            guard let viewController = notification.object as? NSViewController,
                  let windowController = viewController.view.window?.windowController,
                  windowController == self?.windowController,
                  let newState = notification.userInfo?["status"] as? DeviceStatus else { return }
            // Enable the items relevant for this state.
            newState.allMenubarItems.forEach { $0.disable() }
            newState.enabledMenubarItems.forEach { $0.enable() }
            // Save the current state.
            self?.deviceStatus = newState
            // Disable the movement controls if we are searching.
            if self?.isSearching ?? false {
                self?.disableMoveControls()
            }
        }

        // Observe the search status.
        self.searchStartObserver = NotificationCenter.default.addObserver(forName: .SearchDidStart, object: nil,
                                                                     queue: .main) { [weak self] notification in
            // Only handle search events from the active window.
            guard self?.windowController?.window == notification.object as? NSWindow else { return }
            self?.isSearching = true
        }

        self.searchEndObserver = NotificationCenter.default.addObserver(forName: .SearchDidEnd, object: nil,
                                                                     queue: .main) { [weak self] notification in
            // Only handle search events from the active window.
            guard self?.windowController?.window == notification.object as? NSWindow else { return }
            self?.isSearching = false
        }
    }

    // MARK: - Search
    private func enableMoveControls() {
        // Only enable the controls if required.
        guard self.deviceStatus == .manual else { return }
        let moveControls: [NavigationMenubarItem] = [.moveUp, .moveDown, .moveClockwise, .moveCounterclockwise]
        moveControls.forEach { $0.enable() }
    }

    private func disableMoveControls() {
        let moveControls: [NavigationMenubarItem] = [.moveUp, .moveDown, .moveClockwise, .moveCounterclockwise]
        moveControls.forEach { $0.disable() }
    }

    // MARK: - Navigation Menu

    @IBAction func setMoveType(_ sender: NSMenuItem) {
        var moveType: MoveType
        switch NavigationMenubarItem(rawValue: sender.tag) {
        case .walk:  moveType = .walk
        case .cycle: moveType = .cycle
        case .drive: moveType = .car
        default: return
        }
        self.windowController?.setMoveType(moveType)
    }

    /// Show the `Go to Location` view.
    @IBAction func requestLocationChange(_ sender: NSMenuItem) {
        self.windowController?.requestLocationChange()
    }

    /// Reset the currently spoofed location to the original device location.
    @IBAction func resetLocation(_ sender: NSMenuItem) {
        self.windowController?.resetLocation()
    }

    /// Set the spoofed location to the current location of this mac.
    @IBAction func setLocationToCurrentLocation(_ sender: NSMenuItem) {
        self.windowController?.setLocationToCurrentLocation()
    }

    /// Toggle between automove and manual move. If a navigation is running, the navigation will be paused.
    /// Call this function again to resume the navigation.
    @IBAction func toggleAutomoveState(_ sender: NSMenuItem) {
        self.windowController?.toggleAutomoveState()
    }

    @IBAction func stopNavigation(_ sender: Any) {
        self.windowController?.stopNavigation()
    }

    @IBAction func move(_ sender: NSMenuItem) {
        switch NavigationMenubarItem(rawValue: sender.tag) {
        case .moveCounterclockwise: self.windowController?.rotate(.counterclockwise)
        case .moveClockwise:        self.windowController?.rotate(.clockwise)
        case .moveDown:             self.windowController?.move(.down)
        case .moveUp:               self.windowController?.move(.up)
        default: break
        }
    }

    // MARK: - Recent Location Submenu

    /// Change the current location to the coordinates defined by a recently visited location.
    /// - Parameter sender: the selected menu item that triggered this function
    @objc func selectRecentLocation(_ sender: NSMenuItem) {
        guard let idx: Int = RecentLocationMenubarItem.menu?.items.firstIndex(of: sender) else { return }
        let loc: Location = UserDefaults.standard.recentLocations[idx]
        let coord = CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.long)
        self.windowController?.requestLocationChange(coord: coord)
    }

    /// Clear the `Recent locations` menu by removing all its stored entries.
    /// - Parameter sender: the selected menu item that triggered this function
    @IBAction func clearRecentLocations(_ sender: NSMenuItem? = nil) {
        // Remove all entries from the user defaults.
        UserDefaults.standard.recentLocations = []
        // Clear the menu item.
        RecentLocationMenubarItem.clearLocationMenuItems()
    }

    /// Load the recent locations from the user defaults and add them to the menu.
    public func loadRecentLocations() {
        // Remove all recent locations menu items.
        RecentLocationMenubarItem.clearLocationMenuItems()
        // Add all recent locations from the user defaults.
        UserDefaults.standard.recentLocations.reversed().forEach { item in
            RecentLocationMenubarItem.addLocationMenuItem(item)
        }
    }

    /// Add a new location to the UserDefaults and add a corresponding menubar entry.
    /// - Parameter coords: coordinates of the location to add
    public func addLocation(_ coords: CLLocationCoordinate2D) {
        // load all entries and delete the last one if we have to many
        var recentLocations = UserDefaults.standard.recentLocations
        // Make sure that we did not already store this location in the recent entries and if we do, then remove the
        // entry and call the remaining function to insert the item at the beginning. If the name of the location
        // has changed since the last teleportation this will guarantee that the information is updated.
        var index = 0
        while index < recentLocations.count {
            let loc = recentLocations[index]
            let locCoords = CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.long)
            if locCoords.distanceTo(coordinate: coords) < 0.005 {
                recentLocations.remove(at: index)
                RecentLocationMenubarItem.removeLocationMenuItem(at: index)
            }
            index += 1
        }
        // Add the new location to the UserDefaults and the menu
        coords.getLocationName { loc, name in
            // Remove the last item if we exceed the maximum number
            if recentLocations.count >= kMaxRecentItems {
                _ = recentLocations.popLast()
                RecentLocationMenubarItem.removeLocationMenuItem(at: kMaxRecentItems-1)
            }
            // Add a new user defaults entry
            let loc = Location(name: name, lat: loc.coordinate.latitude, long: loc.coordinate.longitude)
            recentLocations.insert(loc, at: 0)
            // Save the changes
            UserDefaults.standard.recentLocations = recentLocations
            // Add the menubaritem
            RecentLocationMenubarItem.addLocationMenuItem(loc)
        }
    }

    // MARK: - File Menu

    @IBAction func openGPXFile(_ sender: NSMenuItem) {
        self.windowController?.requestGPXOpenDialog()
    }

    // MARK: - Help Menu

    /// Open the main project website in a browser.
    @IBAction func openProjectPage(_ sender: Any) {
        if let url = URL(string: kProjectWebsite) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Open the report an issue website in a browser.
    @IBAction func reportBugPage(_ sender: Any) {
        if let url = URL(string: kGithubWebseite + "/issues") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - View Menu

    @IBAction func toggleSidebar(_ sender: NSMenuItem) {
        self.windowController?.toggleSidebar()
    }
}
