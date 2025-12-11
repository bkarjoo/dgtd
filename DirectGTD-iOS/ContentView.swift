//
//  ContentView.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/9/25.
//

import SwiftUI
import DirectGTDCore
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = TreeViewModel()
    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var showingQuickCapture = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Custom header bar
                    headerBar

                    // Main content
                    TreeView()
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 30, coordinateSpace: .global)
                                .onEnded { value in
                                    // Swipe right from device's left edge to go back
                                    if value.translation.width > 80 &&
                                       abs(value.translation.height) < 50 &&
                                       viewModel.isFocused {
                                        viewModel.goToParent()
                                    }
                                }
                        )
                }
                .sheet(isPresented: $showingSearch) {
                    SearchView()
                        .environmentObject(viewModel)
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                        .environmentObject(viewModel)
                }
                .sheet(isPresented: $showingQuickCapture) {
                    QuickCaptureView()
                        .environmentObject(viewModel)
                }

                // Floating action button
                Button {
                    showingQuickCapture = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding(.trailing, 60)
                .padding(.bottom, 16)
            }
        }
        .environmentObject(viewModel)
        .task {
            await viewModel.syncAndReload()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                // Request background time to complete sync before suspension
                let application = UIApplication.shared
                var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

                backgroundTaskID = application.beginBackgroundTask(withName: "DirectGTD Sync") {
                    // Cleanup if time expires
                    if backgroundTaskID != .invalid {
                        application.endBackgroundTask(backgroundTaskID)
                        backgroundTaskID = .invalid
                    }
                }

                Task {
                    await viewModel.syncAndReload()
                    // End background task when sync completes
                    if backgroundTaskID != .invalid {
                        application.endBackgroundTask(backgroundTaskID)
                    }
                }
            case .active:
                // Sync when becoming active to pull latest changes
                Task {
                    await viewModel.syncAndReload()
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            // Back button (only when focused)
            if viewModel.isFocused {
                Button {
                    viewModel.goToParent()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        if let parentTitle = viewModel.focusedItemParentTitle {
                            Text(parentTitle)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Focused item title (center)
            if let title = viewModel.focusedItem?.title {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
            }

            Spacer()

            // Right side buttons
            HStack(spacing: 16) {
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.plain)

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

#Preview {
    ContentView()
}
