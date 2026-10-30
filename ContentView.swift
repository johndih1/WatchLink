import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var bluetooth: WatchBluetooth
    @State private var tab = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            dashboard.tabItem { Label("My watch", systemImage: "applewatch") }.tag(0)
            nearby.tabItem { Label("Find watch", systemImage: "antenna.radiowaves.left.and.right") }.tag(1)
            serviceBrowser.tabItem { Label("Services", systemImage: "waveform.path") }.tag(2)
            about.tabItem { Label("About", systemImage: "info.circle") }.tag(3)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { bluetooth.stopScan() }
        }
    }

    private var dashboard: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("YOUR WATCH. YOUR CONNECTION.")
                            .font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                        Spacer()
                    }
                    VStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(.white.opacity(0.07), lineWidth: 12)
                            Circle().trim(from: 0, to: bluetooth.battery.map { CGFloat($0) / 100 } ?? 0)
                                .stroke(.mint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 6) {
                                Image(systemName: "applewatch").font(.system(size: 36)).foregroundStyle(.mint)
                                Text(bluetooth.battery.map { "\($0)%" } ?? "—")
                                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                                Text("BATTERY").font(.caption2).tracking(2).foregroundStyle(.secondary)
                            }
                        }.frame(width: 180, height: 180).padding(.top, 8)
                        Text(bluetooth.watchName ?? "Galaxy Watch").font(.title2.bold())
                        Label(bluetooth.connected ? "Connected to WatchLink" : "Not connected to WatchLink",
                              systemImage: bluetooth.connected ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.subheadline).foregroundStyle(bluetooth.connected ? Color.mint : Color.secondary)
                        Text(bluetooth.batteryStatus).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if bluetooth.connected || bluetooth.connecting {
                            Button("Disconnect", role: .destructive) { bluetooth.disconnect() }
                                .buttonStyle(.bordered)
                        } else {
                            Button { tab = 1; bluetooth.startScan() } label: {
                                Label("Find my watch", systemImage: "magnifyingglass")
                                    .frame(maxWidth: .infinity).padding(.vertical, 5)
                            }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(24)
                    .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 28))

                    Text(bluetooth.status).font(.footnote).foregroundStyle(.secondary)
                    if !bluetooth.deviceInfo.isEmpty {
                        GroupBox("Device information") {
                            ForEach(bluetooth.deviceInfo.keys.sorted(), id: \.self) { key in
                                HStack { Text(key); Spacer(); Text(bluetooth.deviceInfo[key] ?? "").foregroundStyle(.secondary) }
                                    .font(.subheadline).padding(.vertical, 4)
                            }
                        }
                    }
                    Text("FEATURE AVAILABILITY").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
                    feature("heart.text.square", "Health & activity", "Not implemented · Samsung data access needs investigation")
                    feature("photo.on.rectangle", "Photos & music", "Not implemented · transfer protocol needs investigation")
                    feature("bell", "Notifications", "Not managed by WatchLink · existing system pairing may still deliver them")
                    feature("play.circle", "Music controls", "Not managed by WatchLink · existing system pairing may still provide them")
                }.padding(20)
            }
            .navigationTitle("WatchLink")
            .toolbar {
                if bluetooth.canRefreshBattery {
                    Button { bluetooth.refreshBattery() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Refresh battery")
                }
            }
        }
    }

    private var nearby: some View {
        NavigationStack {
            List {
                Section {
                    Label("Bluetooth: \(bluetooth.radioState)", systemImage: "antenna.radiowaves.left.and.right")
                    Text("Wake your watch and keep it nearby. Choose it by name. Other Bluetooth devices can also appear.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button(bluetooth.scanning ? "Stop search" : "Search for devices") {
                        if bluetooth.scanning { bluetooth.stopScan() } else { bluetooth.startScan() }
                    }.disabled(bluetooth.connecting)
                    if bluetooth.scanning { ProgressView("Searching…") }
                }
                Section("Devices · \(bluetooth.devices.count)") {
                    if bluetooth.devices.isEmpty {
                        Text("No devices yet. Tap Search for devices.").foregroundStyle(.secondary)
                    }
                    ForEach(bluetooth.sortedDevices) { device in
                        Button { bluetooth.connect(device) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: device.likelyWatch ? "applewatch" : "dot.radiowaves.left.and.right")
                                    .foregroundStyle(.mint).frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.name).foregroundStyle(.primary)
                                    Text(device.source).font(.caption).foregroundStyle(.secondary)
                                    Text(String(device.id.uuidString.prefix(8))).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                                }
                                Spacer()
                                if let rssi = device.rssi { Text("\(rssi) dBm").font(.caption).foregroundStyle(.secondary) }
                            }.padding(.vertical, 5)
                        }.disabled(bluetooth.connected || bluetooth.connecting)
                    }
                }
                Section {
                    Text(bluetooth.status).font(.footnote)
                    if bluetooth.connected || bluetooth.connecting {
                        Button("Disconnect current device", role: .destructive) { bluetooth.disconnect() }
                    }
                }
                Section("If your watch does not appear") {
                    Text("Allow Bluetooth access in iPhone Settings. Keep the watch awake and try another search. A paired watch may not advertise its services to third-party apps; pairing in Settings does not guarantee access here. Do not reset the watch.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Find your watch")
        }
    }

    private var serviceBrowser: some View {
        NavigationStack {
            List {
                Section {
                    Text("These are the Bluetooth services visible to WatchLink. Finding a service does not mean its features are supported.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ShareLink(item: bluetooth.report()) {
                        Label("Share capability report", systemImage: "square.and.arrow.up")
                    }
                    Text("The report excludes device names, identifiers and raw values. Review before sharing.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if bluetooth.services.isEmpty {
                    Section { Text("Connect to your watch to inspect its services.").foregroundStyle(.secondary) }
                }
                ForEach(bluetooth.services) { service in
                    Section("Service \(service.uuid)") {
                        if service.characteristics.isEmpty { Text("No characteristics returned yet").foregroundStyle(.secondary) }
                        ForEach(service.characteristics) { characteristic in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(characteristic.uuid).font(.footnote.monospaced()).textSelection(.enabled)
                                Text(characteristic.properties).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }.navigationTitle("Services")
        }
    }

    private var about: some View {
        NavigationStack {
            List {
                Section("WatchLink · 0.1 prototype") {
                    Text("An independent connection explorer for your Galaxy Watch. This is an early native app, not a complete Samsung companion replacement.")
                    Text("Designed for testing with SM-R800 / Tizen 5.5.0.2. Hardware compatibility is not yet verified.")
                }
                Section("Your data") {
                    Text("No account, analytics, server or automatic upload. Bluetooth data stays on this phone unless you choose to share a report. Only the last selected peripheral identifier is saved for reconnecting.")
                    Text("WatchLink reads standard battery, model, firmware and manufacturer fields when exposed. It does not read health records or notification content, and does not write proprietary commands.")
                }
                Section("Connection notes") {
                    Text("LE means Bluetooth Low Energy. It is normal. This app uses a foreground connection; background syncing is not implemented. Samsung’s existing app and iOS pairing remain separate.")
                }
                Section("Session log") {
                    if bluetooth.events.isEmpty { Text("No events yet").foregroundStyle(.secondary) }
                    ForEach(Array(bluetooth.events.enumerated()), id: \.offset) { event in
                        Text(event.element).font(.caption).textSelection(.enabled)
                    }
                }
            }.navigationTitle("About")
        }
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.mint).frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(16).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18))
    }
}
