//
//  QuickCaptureView.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/9/25.
//

import SwiftUI
import DirectGTDCore

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TreeViewModel
    @State private var title: String = ""
    @State private var selectedType: ItemType = .task
    @FocusState private var titleFieldFocused: Bool

    // Available types for quick capture
    private let availableTypes: [ItemType] = [.task, .note, .project, .folder]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("What needs to be done?", text: $title)
                    .font(.title3)
                    .textFieldStyle(.plain)
                    .focused($titleFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        saveAndDismiss()
                    }

                // Type picker
                HStack(spacing: 12) {
                    ForEach(availableTypes, id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: iconForType(type))
                                    .font(.system(size: 20))
                                Text(type.rawValue)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(selectedType == type ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                            .foregroundColor(selectedType == type ? .accentColor : .primary)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            titleFieldFocused = true
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func iconForType(_ type: ItemType) -> String {
        switch type {
        case .task: return "circle"
        case .note: return "doc.text"
        case .project: return "folder"
        case .folder: return "folder.fill"
        default: return "questionmark.circle"
        }
    }

    private func saveAndDismiss() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        viewModel.addQuickCaptureItem(title: trimmedTitle, itemType: selectedType)

        // Trigger sync in background
        Task {
            await viewModel.syncAndReload()
        }

        dismiss()
    }
}

#Preview {
    QuickCaptureView()
        .environmentObject(TreeViewModel())
}
