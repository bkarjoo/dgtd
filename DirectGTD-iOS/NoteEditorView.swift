//
//  NoteEditorView.swift
//  DirectGTD-iOS
//
//  Created by Behrooz Karjoo on 12/11/25.
//

import SwiftUI
import UIKit
import DirectGTDCore

// MARK: - UIKit TextView Wrapper (stable scrolling)

struct NoteTextView: UIViewRepresentable {
    @Binding var text: String
    var becomeFirstResponder: Bool = false

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .systemBackground
        textView.delegate = context.coordinator
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
        textView.smartQuotesType = .default
        textView.smartDashesType = .default
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update text if it differs to avoid cursor jumping
        if uiView.text != text {
            uiView.text = text
        }

        if becomeFirstResponder && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteTextView

        init(_ parent: NoteTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

// MARK: - Note Editor View

struct NoteEditorView: View {
    let item: Item
    @EnvironmentObject var viewModel: TreeViewModel
    @State private var noteText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header bar with back button
            headerBar

            Divider()

            // Note editor - UIKit wrapper for stable scrolling
            NoteTextView(text: $noteText, becomeFirstResponder: true)
                .padding()
        }
        .onAppear {
            noteText = item.notes ?? ""
        }
        .onDisappear {
            // Save only when leaving the editor
            if noteText != (item.notes ?? "") {
                saveNote(noteText)
            }
        }
    }

    private var headerBar: some View {
        HStack {
            // Back button
            Button {
                viewModel.editingNoteId = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Note title
            Text(item.title ?? "Note")
                .font(.headline)
                .lineLimit(1)

            Spacer()

            // Placeholder for symmetry
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .opacity(0)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func saveNote(_ text: String) {
        var updatedItem = item
        updatedItem.notes = text
        updatedItem.modifiedAt = Int(Date().timeIntervalSince1970)
        viewModel.updateItem(updatedItem)
    }
}

#Preview {
    let item = Item(
        id: "test",
        title: "Test Note",
        itemType: .note,
        notes: "This is a test note with some content."
    )
    NoteEditorView(item: item)
        .environmentObject(TreeViewModel())
}
