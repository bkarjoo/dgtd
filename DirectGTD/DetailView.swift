import DirectGTDCore
import SwiftUI
import Combine

struct DetailView: View {
    @ObservedObject var store: ItemStore
    @State private var showingTagPicker: Bool = false
    @State private var timerTick: Int = 0  // Triggers view updates for live elapsed time
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        VStack {
            if let selectedId = store.selectedItemId,
               let selectedItem = store.items.first(where: { $0.id == selectedId }) {
                Form {
                    Section {
                        Text(selectedItem.title ?? "Untitled")
                            .font(.title)
                    }

                    Section {
                        Picker("Item Type", selection: Binding(
                            get: { selectedItem.itemType },
                            set: { newType in
                                store.updateItemType(id: selectedId, itemType: newType)
                            }
                        )) {
                            ForEach(ItemType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Section("Dates") {
                        HStack {
                            Text("Due Date")
                            Spacer()
                            if selectedItem.dueDate != nil {
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { Date(timeIntervalSince1970: TimeInterval(selectedItem.dueDate ?? 0)) },
                                        set: { newDate in
                                            store.updateDueDate(id: selectedId, dueDate: Int(newDate.timeIntervalSince1970))
                                        }
                                    ),
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()

                                Button(action: {
                                    store.updateDueDate(id: selectedId, dueDate: nil)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button("Set") {
                                    // Set to tomorrow at 5pm by default
                                    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                                    let components = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
                                    let tomorrowAt5pm = Calendar.current.date(from: DateComponents(
                                        year: components.year,
                                        month: components.month,
                                        day: components.day,
                                        hour: 17,
                                        minute: 0
                                    )) ?? tomorrow
                                    store.updateDueDate(id: selectedId, dueDate: Int(tomorrowAt5pm.timeIntervalSince1970))
                                }
                            }
                        }

                        HStack {
                            Text("Earliest Start")
                            Spacer()
                            if selectedItem.earliestStartTime != nil {
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { Date(timeIntervalSince1970: TimeInterval(selectedItem.earliestStartTime ?? 0)) },
                                        set: { newDate in
                                            store.updateEarliestStartTime(id: selectedId, earliestStartTime: Int(newDate.timeIntervalSince1970))
                                        }
                                    ),
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()

                                Button(action: {
                                    store.updateEarliestStartTime(id: selectedId, earliestStartTime: nil)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button("Set") {
                                    // Set to today at 9am by default
                                    let today = Date()
                                    let components = Calendar.current.dateComponents([.year, .month, .day], from: today)
                                    let todayAt9am = Calendar.current.date(from: DateComponents(
                                        year: components.year,
                                        month: components.month,
                                        day: components.day,
                                        hour: 9,
                                        minute: 0
                                    )) ?? today
                                    store.updateEarliestStartTime(id: selectedId, earliestStartTime: Int(todayAt9am.timeIntervalSince1970))
                                }
                            }
                        }
                    }

                    Section("Tags") {
                        FlowLayout(spacing: 8) {
                            ForEach(store.getTagsForItem(itemId: selectedId)) { tag in
                                TagChip(tag: tag, showRemove: true) {
                                    store.removeTagFromItem(itemId: selectedId, tagId: tag.id)
                                }
                            }

                            Button(action: { showingTagPicker = true }) {
                                Label("Add Tag", systemImage: "plus")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                        }
                        .frame(minHeight: 32)
                    }

                    Section("Time Tracking") {
                        HStack {
                            Text("Total Time")
                            Spacer()
                            Text(formatDuration(store.totalTime(for: selectedId)))
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Timer")
                            Spacer()

                            if let activeEntry = store.activeTimeEntry(for: selectedId) {
                                // Show running timer with elapsed time (timerTick forces refresh)
                                let _ = timerTick
                                Text(formatDuration(activeEntry.elapsedSeconds()))
                                    .foregroundColor(.green)
                                    .font(.system(.body, design: .monospaced))

                                Button(action: {
                                    store.stopTimer(entryId: activeEntry.id)
                                }) {
                                    Image(systemName: "stop.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Stop timer")
                            } else {
                                Text("Not running")
                                    .foregroundColor(.secondary)

                                Button(action: {
                                    store.startTimer(for: selectedId)
                                }) {
                                    Image(systemName: "play.fill")
                                        .foregroundColor(.green)
                                }
                                .buttonStyle(.plain)
                                .help("Start timer")
                            }
                        }
                    }
                    .onChange(of: store.activeTimeEntries) { _, _ in
                        updateTimerSubscription()
                    }
                    .onChange(of: store.selectedItemId) { _, _ in
                        updateTimerSubscription()
                    }
                    .onAppear {
                        updateTimerSubscription()
                    }
                    .onDisappear {
                        timerCancellable?.cancel()
                        timerCancellable = nil
                        timerTick = 0
                    }

                    Section("Notes") {
                        TextEditor(text: Binding(
                            get: { selectedItem.notes ?? "" },
                            set: { newValue in
                                store.updateNotes(id: selectedId, notes: newValue.isEmpty ? nil : newValue)
                            }
                        ))
                        .font(.body)
                        .frame(minHeight: 100, maxHeight: 300)
                    }

                    if selectedItem.itemType == .task {
                        Section {
                            Toggle("Completed", isOn: Binding(
                                get: { selectedItem.completedAt != nil },
                                set: { _ in
                                    store.toggleTaskCompletion(id: selectedId)
                                }
                            ))
                        }
                    }

                    Section("Debug (Temporary)") {
                        HStack {
                            Text("Item ID:")
                            Spacer()
                            Text(selectedId)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .formStyle(.grouped)
                .padding()
                .sheet(isPresented: $showingTagPicker) {
                    if let selectedId = store.selectedItemId {
                        TagPickerView(store: store, itemId: selectedId)
                    }
                }
                Spacer()
            } else {
                Text("No item selected")
                    .foregroundColor(.secondary)
                    .padding()
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else if seconds > 0 {
            return "<1m"
        } else {
            return "0m"
        }
    }

    private func updateTimerSubscription() {
        let needsTimer = store.selectedItemId.flatMap { store.hasActiveTimer(for: $0) } ?? false

        if needsTimer && timerCancellable == nil {
            // Start the timer
            timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    timerTick += 1
                }
        } else if !needsTimer && timerCancellable != nil {
            // Stop the timer
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }
}

#Preview {
    let settings = UserSettings()
    DetailView(store: ItemStore(settings: settings))
}
