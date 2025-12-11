import DirectGTDCore
import SwiftUI

/// Toolbar view showing sync status with icon and optional details
struct SyncStatusView: View {
    @ObservedObject var syncEngine: SyncEngine

    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            statusText
        }
        .help(helpText)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch syncEngine.status {
        case .disabled:
            Image(systemName: "icloud.slash")
                .foregroundColor(.secondary)

        case .idle:
            Image(systemName: "checkmark.icloud")
                .foregroundColor(.green)

        case .syncing:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)

        case .initialSync:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)

        case .error:
            Image(systemName: "exclamationmark.icloud")
                .foregroundColor(.red)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch syncEngine.status {
        case .error(let message):
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .lineLimit(1)
        case .initialSync(_, let message):
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        default:
            EmptyView()
        }
    }

    private var helpText: String {
        switch syncEngine.status {
        case .disabled:
            if !syncEngine.isSyncEnabled {
                return "iCloud sync disabled by user"
            }
            return "iCloud sync disabled - sign in to iCloud to enable"
        case .idle:
            if let lastSync = syncEngine.lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                let relativeTime = formatter.localizedString(for: lastSync, relativeTo: Date())
                return "Synced \(relativeTime)"
            }
            return "Synced"
        case .syncing:
            return "Syncing..."
        case .initialSync(let progress, let message):
            return "Initial sync: \(Int(progress * 100))% - \(message)"
        case .error(let message):
            return "Sync error: \(message)"
        }
    }
}

/// Menu bar button with sync status and manual sync option
struct SyncMenuButton: View {
    @ObservedObject var syncEngine: SyncEngine

    private var isSyncing: Bool {
        switch syncEngine.status {
        case .syncing, .initialSync:
            return true
        default:
            return false
        }
    }

    var body: some View {
        Menu {
            Button(action: {
                syncEngine.requestSync()
            }) {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isSyncing || syncEngine.status == .disabled)

            Divider()

            if let accountName = syncEngine.iCloudAccountName {
                Text("Account: \(accountName)")
                    .font(.caption)
            }

            if let lastSync = syncEngine.lastSyncDate {
                Text("Last sync: \(lastSync, style: .relative) ago")
                    .font(.caption)
            }

            switch syncEngine.status {
            case .disabled:
                if !syncEngine.isSyncEnabled {
                    Text("Sync disabled by user")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("iCloud not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            case .initialSync(let progress, _):
                Text("Initial sync: \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.blue)
            case .error(let message):
                Text("Error: \(message)")
                    .font(.caption)
                    .foregroundColor(.red)
            default:
                EmptyView()
            }
        } label: {
            SyncStatusView(syncEngine: syncEngine)
        }
    }
}

/// Initial sync progress overlay shown during first-time sync
struct InitialSyncProgressView: View {
    @ObservedObject var syncEngine: SyncEngine

    var body: some View {
        if case .initialSync(let progress, let message) = syncEngine.status {
            VStack(spacing: 16) {
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Setting Up iCloud Sync")
                    .font(.headline)

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(32)
            .background(.regularMaterial)
            .cornerRadius(16)
            .shadow(radius: 10)
        }
    }
}
