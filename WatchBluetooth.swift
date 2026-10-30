import Foundation
import CoreBluetooth
import Combine

struct NearbyDevice: Identifiable {
    let id: UUID
    var name: String
    var rssi: Int?
    var source: String
    var likelyWatch: Bool {
        name.localizedCaseInsensitiveContains("watch") || name.localizedCaseInsensitiveContains("gear")
    }
}

struct CharacteristicInfo: Identifiable {
    let id: String
    let uuid: String
    let properties: String
}

struct ServiceInfo: Identifiable {
    let id: String
    let uuid: String
    var characteristics: [CharacteristicInfo]
}

// CoreBluetooth uses the main dispatch queue; all published state and delegates
// are accessed there. Swift 5 language mode is intentional for delegate compatibility.
final class WatchBluetooth: NSObject, ObservableObject {
    @Published private(set) var radioState = "Not started"
    @Published private(set) var status = "Ready to find your watch"
    @Published private(set) var scanning = false
    @Published private(set) var devices: [NearbyDevice] = []
    @Published private(set) var connected = false
    @Published private(set) var connecting = false
    @Published private(set) var watchName: String?
    @Published private(set) var battery: Int?
    @Published private(set) var batteryStatus = "Connect to check availability"
    @Published private(set) var deviceInfo: [String: String] = [:]
    @Published private(set) var services: [ServiceInfo] = []
    @Published private(set) var events: [String] = []

    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var selected: CBPeripheral?
    private var scanTimer: Timer?
    private var connectTimer: Timer?
    private var discoveryTimer: Timer?
    private var pendingScan = false
    private var pendingServices = Set<ObjectIdentifier>()
    private var batteryCharacteristic: CBCharacteristic?
    private var savedID: UUID? {
        UserDefaults.standard.string(forKey: "selectedPeripheral").flatMap(UUID.init(uuidString:))
    }

    var sortedDevices: [NearbyDevice] {
        devices.sorted {
            if $0.likelyWatch != $1.likelyWatch { return $0.likelyWatch }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func startScan() {
        guard !connecting else { return }
        if central == nil {
            pendingScan = true
            central = CBCentralManager(delegate: self, queue: .main)
            return
        }
        guard let central, central.state == .poweredOn else {
            status = "Bluetooth is unavailable. Check iPhone Bluetooth permissions and settings."
            return
        }
        stopScan()
        devices = []
        peripherals = selected.map { [$0.identifier: $0] } ?? [:]
        // These standard services can help retrieve already-connected peripherals.
        // This is not a complete list of devices paired in iOS Settings.
        let known = ["1800", "1801", "180A", "180F"].map { CBUUID(string: $0) }
        for peripheral in central.retrieveConnectedPeripherals(withServices: known) {
            remember(peripheral, name: peripheral.name, rssi: nil, source: "Connected to iPhone")
        }
        if let id = savedID {
            for peripheral in central.retrievePeripherals(withIdentifiers: [id]) {
                remember(peripheral, name: peripheral.name, rssi: nil, source: "Previously selected; availability unknown")
            }
        }
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        scanning = true
        status = "Searching nearby for 15 seconds…"
        log("Started foreground Bluetooth scan")
        scanTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            self?.stopScan()
            guard let self else { return }
            self.status = self.connected ? "Connected to \(self.watchName ?? "device")" : "Search finished. Select your watch below."
        }
    }

    func stopScan() {
        scanTimer?.invalidate()
        scanTimer = nil
        central?.stopScan()
        scanning = false
    }

    func connect(_ device: NearbyDevice) {
        guard !connected, !connecting, let peripheral = peripherals[device.id],
              let central, central.state == .poweredOn else { return }
        stopScan()
        resetReadings()
        selected = peripheral
        peripheral.delegate = self
        connecting = true
        watchName = device.name
        status = "Connecting to \(device.name)…"
        log("Connection requested")
        central.connect(peripheral, options: nil)
        connectTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
            guard let self, self.connecting, let selected = self.selected else { return }
            self.central?.cancelPeripheralConnection(selected)
            self.selected = nil
            self.connecting = false
            self.connected = false
            self.status = "Connection timed out. Wake your watch and try again."
            self.log("Connection timed out")
        }
    }

    func disconnect() {
        stopScan()
        connectTimer?.invalidate()
        discoveryTimer?.invalidate()
        if let selected { central?.cancelPeripheralConnection(selected) }
        selected = nil
        connected = false
        connecting = false
        resetReadings()
        status = "Disconnected from WatchLink"
        log("Disconnected by user; system pairing was not removed")
    }

    func refreshBattery() {
        guard connected, let selected, let batteryCharacteristic,
              batteryCharacteristic.properties.contains(.read) else { return }
        batteryStatus = "Reading battery…"
        selected.readValue(for: batteryCharacteristic)
    }

    var canRefreshBattery: Bool {
        connected && (batteryCharacteristic?.properties.contains(.read) ?? false)
    }

    func report() -> String {
        var lines = ["WatchLink 0.1 — Bluetooth capability report",
                     "Generated: \(ISO8601DateFormatter().string(from: Date()))",
                     "Radio: \(radioState)", "Session: \(connected ? "Connected" : (connecting ? "Connecting" : "Disconnected"))",
                     "Battery: \(battery.map { String($0) + "%" } ?? batteryStatus)",
                     "Names, peripheral identifiers and raw characteristic values omitted.", ""]
        for service in services {
            lines.append("Service \(service.uuid)")
            for characteristic in service.characteristics {
                lines.append("  \(characteristic.uuid): \(characteristic.properties)")
            }
        }
        if services.isEmpty { lines.append("No services discovered in this session.") }
        lines += ["", "Health sync, transfers, notification forwarding and media control are not implemented.",
                  "A discovered service does not prove those features are supported."]
        return lines.joined(separator: "\n")
    }

    private func remember(_ peripheral: CBPeripheral, name: String?, rssi: Int?, source: String) {
        peripherals[peripheral.identifier] = peripheral
        let item = NearbyDevice(id: peripheral.identifier, name: name ?? "Unnamed Bluetooth device", rssi: rssi, source: source)
        if let index = devices.firstIndex(where: { $0.id == item.id }) {
            devices[index] = item
        } else { devices.append(item) }
    }

    private func resetReadings() {
        battery = nil
        batteryStatus = "Connect to check availability"
        batteryCharacteristic = nil
        deviceInfo = [:]
        services = []
        pendingServices = []
    }

    private func log(_ text: String) {
        events.insert(text, at: 0)
        events = Array(events.prefix(40))
    }

    private func finishDiscovery() {
        discoveryTimer?.invalidate()
        discoveryTimer = nil
        if batteryCharacteristic == nil { batteryStatus = "No standard battery reading available" }
        status = "Connected · \(services.count) services discovered"
        log("Service discovery finished; availability is not feature support")
    }
}

extension WatchBluetooth: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: radioState = "On"
        case .poweredOff: radioState = "Off"
        case .unauthorized: radioState = "Permission denied"
        case .unsupported: radioState = "Unsupported"
        case .resetting: radioState = "Restarting"
        case .unknown: radioState = "Starting"
        @unknown default: radioState = "Unknown"
        }
        if central.state == .poweredOn {
            if pendingScan { pendingScan = false; startScan() }
        } else {
            stopScan()
            connectTimer?.invalidate()
            discoveryTimer?.invalidate()
            selected = nil
            connected = false
            connecting = false
            resetReadings()
            status = "Bluetooth: \(radioState)"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name
        remember(peripheral, name: name, rssi: RSSI.intValue == 127 ? nil : RSSI.intValue, source: "Nearby advertisement")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard selected === peripheral else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        connectTimer?.invalidate()
        connecting = false
        connected = true
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: "selectedPeripheral")
        status = "Connected. Inspecting services…"
        batteryStatus = "Checking availability…"
        log("Bluetooth connection established")
        peripheral.discoverServices(nil)
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
            guard let self, self.connected else { return }
            self.status = "Connected · service discovery incomplete"
            if self.battery == nil { self.batteryStatus = "No battery reading received" }
            self.log("Service discovery exceeded 20 seconds; partial results retained")
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard selected === peripheral else { return }
        connectTimer?.invalidate()
        connecting = false
        connected = false
        selected = nil
        status = "Connection failed: \(error?.localizedDescription ?? "unknown reason")"
        log(status)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard selected === peripheral else { return }
        connectTimer?.invalidate()
        discoveryTimer?.invalidate()
        selected = nil
        connecting = false
        connected = false
        resetReadings()
        status = error.map { "Disconnected: \($0.localizedDescription)" } ?? "Disconnected"
        log(status)
    }
}

extension WatchBluetooth: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard selected === peripheral else { return }
        if let error {
            discoveryTimer?.invalidate()
            status = "Connected · service discovery failed"
            batteryStatus = "Unavailable"
            log(error.localizedDescription)
            return
        }
        let discovered = peripheral.services ?? []
        pendingServices = Set(discovered.map { ObjectIdentifier($0) })
        services = discovered.enumerated().map {
            ServiceInfo(id: String($0.offset), uuid: $0.element.uuid.uuidString, characteristics: [])
        }
        for service in discovered { peripheral.discoverCharacteristics(nil, for: service) }
        if discovered.isEmpty { finishDiscovery() }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard selected === peripheral else { return }
        defer {
            pendingServices.remove(ObjectIdentifier(service))
            if pendingServices.isEmpty { finishDiscovery() }
        }
        if let error { log("Characteristic discovery: \(error.localizedDescription)"); return }
        if let index = peripheral.services?.firstIndex(where: { $0 === service }), index < services.count {
            services[index].characteristics = (service.characteristics ?? []).enumerated().map { offset, characteristic in
                var flags: [String] = []
                if characteristic.properties.contains(.read) { flags.append("read") }
                if characteristic.properties.contains(.write) { flags.append("write") }
                if characteristic.properties.contains(.writeWithoutResponse) { flags.append("write without response") }
                if characteristic.properties.contains(.notify) { flags.append("notify") }
                if characteristic.properties.contains(.indicate) { flags.append("indicate") }
                return CharacteristicInfo(id: "\(index)-\(offset)", uuid: characteristic.uuid.uuidString,
                                          properties: flags.isEmpty ? "other" : flags.joined(separator: ", "))
            }
        }
        // Only read the standard battery and non-sensitive device-information fields.
        // Do not read or write Samsung's unknown proprietary characteristics.
        for characteristic in service.characteristics ?? [] {
            let uuid = characteristic.uuid.uuidString
            if service.uuid == CBUUID(string: "180F"), uuid == "2A19" {
                batteryCharacteristic = characteristic
                batteryStatus = "Standard battery service found; awaiting value"
                if characteristic.properties.contains(.read) { peripheral.readValue(for: characteristic) }
                if characteristic.properties.contains(.notify) { peripheral.setNotifyValue(true, for: characteristic) }
            } else if service.uuid == CBUUID(string: "180A"), ["2A24", "2A26", "2A29"].contains(uuid),
                      characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard selected === peripheral else { return }
        if let error {
            if characteristic === batteryCharacteristic {
                battery = nil
                batteryStatus = "Battery read was denied or failed"
            }
            log("Read \(characteristic.uuid.uuidString): \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value else { return }
        if characteristic === batteryCharacteristic {
            guard data.count == 1, let value = data.first, value <= 100 else {
                battery = nil
                batteryStatus = "Invalid battery value received"
                return
            }
            battery = Int(value)
            batteryStatus = "Live reading from connected device"
        } else if characteristic.service?.uuid == CBUUID(string: "180A") {
            let labels = ["2A24": "Model", "2A26": "Firmware", "2A29": "Manufacturer"]
            if let label = labels[characteristic.uuid.uuidString], let text = String(data: data, encoding: .utf8) {
                deviceInfo[label] = String(text.prefix(160)).trimmingCharacters(in: .controlCharacters)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        guard selected === peripheral else { return }
        // Avoid showing stale service handles after the remote GATT database changes.
        disconnect()
        status = "Watch services changed. Reconnect to inspect them again."
    }
}
