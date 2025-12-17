//
//  SettingsView.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/9/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TreeViewModel
    @State private var showingResetConfirmation = false
    @State private var isResetting = false

    var body: some View {
        NavigationStack {
            List {
                Section("Sync") {
                    Button {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Text("Reset Sync")
                                .foregroundColor(.red)
                            Spacer()
                            if isResetting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isResetting)
                }

                Section("Appearance") {
                    Text("Font size")
                }

                Section("About") {
                    Text("Version 1.0")
                }

                Section("Debug") {
                    HStack {
                        Text("Selected Item ID")
                        Spacer()
                        if let selectedId = viewModel.selectedItemId {
                            Text(selectedId)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text("None")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Inbox Folder ID")
                        Spacer()
                        if let inboxId = viewModel.inboxFolderId {
                            Text(inboxId)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text("Not set")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(isResetting)
                }
            }
            .confirmationDialog(
                "Reset Sync?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    performResetSync()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will clear all local data and re-download everything from iCloud. Use this if items appear out of sync.")
            }
        }
    }

    private func performResetSync() {
        isResetting = true
        Task {
            await viewModel.resetSync()
            await MainActor.run {
                isResetting = false
                dismiss()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(TreeViewModel())
}
