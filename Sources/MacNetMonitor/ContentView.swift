import Charts
import SwiftUI

public struct ContentView: View {
    @ObservedObject var viewModel: NetworkMonitorViewModel

    public init(viewModel: NetworkMonitorViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerSection
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Content Area
            ScrollView {
                VStack(spacing: 20) {
                    // Speed Indicator Cards
                    speedCardsSection

                    // Real-time Traffic Chart
                    chartSection

                    // Session Total Summary
                    sessionSummarySection

                    // Detailed Per-Interface Table
                    interfacesSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: 640, minHeight: 680)
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Mac Network Monitor")
                    .font(.title2.bold())
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isConnectedToInternet ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isConnectedToInternet ? "Online (\(viewModel.connectionType))" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // CPU Limiter / Battery Saver Toggle
            Toggle(isOn: $viewModel.isCPULimiterEnabled) {
                Label(viewModel.isCPULimiterEnabled ? "CPU Saver: ON" : "CPU Saver: OFF", systemImage: "bolt.batteryblock.fill")
                    .font(.caption.bold())
                    .foregroundColor(viewModel.isCPULimiterEnabled ? .orange : .secondary)
            }
            .toggleStyle(.button)
            .controlSize(.regular)
            .help("Reduces timer wake-ups and throttles background polling to minimize CPU energy impact.")

            // Interface Picker
            Picker("Interface:", selection: $viewModel.selectedInterface) {
                Text("All (Primary)").tag("All")
                ForEach(viewModel.interfaceList) { iface in
                    Text(iface.name).tag(iface.name)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)

            Button(action: {
                viewModel.resetSessionStats()
            }) {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    // MARK: - Speed Cards
    private var speedCardsSection: some View {
        HStack(spacing: 16) {
            // Download Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("DOWNLOAD SPEED")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }

                Text(TrafficFormatter.formatSpeed(viewModel.currentDownloadSpeed))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Session: \(TrafficFormatter.formatBytes(viewModel.sessionDownloadedBytes))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )

            // Upload Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.purple)
                    Text("UPLOAD SPEED")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }

                Text(TrafficFormatter.formatSpeed(viewModel.currentUploadSpeed))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text("Session: \(TrafficFormatter.formatBytes(viewModel.sessionUploadedBytes))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Real-Time Bandwidth (Past 60 Seconds)")
                    .font(.headline)
                Spacer()
                HStack(spacing: 16) {
                    Label("Download", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Label("Upload", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }

            if viewModel.history.isEmpty {
                VStack {
                    Text("Collecting network bandwidth data...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(viewModel.history) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Speed (KB/s)", point.downloadSpeed / 1024.0),
                            series: .value("Stream", "Download")
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.monotone)

                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Speed (KB/s)", point.downloadSpeed / 1024.0),
                            series: .value("Stream", "Download")
                        )
                        .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)

                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Speed (KB/s)", point.uploadSpeed / 1024.0),
                            series: .value("Stream", "Upload")
                        )
                        .foregroundStyle(.purple)
                        .interpolationMethod(.monotone)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleVal = value.as(Double.self) {
                                Text("\(Int(doubleVal)) KB/s")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                        AxisGridLine()
                        AxisTick()
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
    }

    // MARK: - Session Summary
    private var sessionSummarySection: some View {
        HStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session Transferred")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let total = viewModel.sessionDownloadedBytes + viewModel.sessionUploadedBytes
                    Text(TrafficFormatter.formatBytes(total))
                        .font(.headline)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "arrow.down")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Received")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(TrafficFormatter.formatBytes(viewModel.sessionDownloadedBytes))
                        .font(.subheadline.bold())
                }
            }

            HStack(spacing: 12) {
                Image(systemName: "arrow.up")
                    .foregroundColor(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Sent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(TrafficFormatter.formatBytes(viewModel.sessionUploadedBytes))
                        .font(.subheadline.bold())
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor).opacity(0.6)))
    }

    // MARK: - Interfaces Table
    private var interfacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Interfaces Breakdown")
                .font(.headline)

            VStack(spacing: 8) {
                // Table Header
                HStack {
                    Text("Interface")
                        .font(.caption.bold())
                        .frame(width: 180, alignment: .leading)
                    Text("Down Speed")
                        .font(.caption.bold())
                        .frame(width: 90, alignment: .trailing)
                    Text("Up Speed")
                        .font(.caption.bold())
                        .frame(width: 90, alignment: .trailing)
                    Text("Lifetime In")
                        .font(.caption.bold())
                        .frame(width: 100, alignment: .trailing)
                    Text("Lifetime Out")
                        .font(.caption.bold())
                        .frame(width: 100, alignment: .trailing)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)

                Divider()

                ForEach(viewModel.interfaceList) { iface in
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(iface.isActive ? Color.green : Color.gray.opacity(0.5))
                                .frame(width: 7, height: 7)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(iface.name)
                                    .font(.system(.body, design: .monospaced).bold())
                                Text(iface.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 180, alignment: .leading)

                        Text(TrafficFormatter.formatSpeed(iface.downloadSpeed))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(iface.downloadSpeed > 0 ? .blue : .primary)
                            .frame(width: 90, alignment: .trailing)

                        Text(TrafficFormatter.formatSpeed(iface.uploadSpeed))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(iface.uploadSpeed > 0 ? .purple : .primary)
                            .frame(width: 90, alignment: .trailing)

                        Text(TrafficFormatter.formatBytes(iface.rxBytesTotal))
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .trailing)

                        Text(TrafficFormatter.formatBytes(iface.txBytesTotal))
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .trailing)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(iface.isActive ? Color.accentColor.opacity(0.06) : Color.clear)
                    )
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
    }
}
