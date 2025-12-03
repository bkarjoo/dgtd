import SwiftUI

struct MarkdownHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Markdown Quick Reference")
                .font(.title2)
                .bold()

            referenceRow(
                title: "Headings",
                example: """
                # Heading 1
                ## Heading 2
                ### Heading 3
                """,
                syntax: """
                # Heading 1
                ## Heading 2
                ### Heading 3
                """
            )

            referenceRow(
                title: "Emphasis",
                example: """
                *italic*  **bold**
                ~~strikethrough~~
                """,
                syntax: """
                *italic* or _italic_
                **bold** or __bold__
                ~~strikethrough~~
                """
            )

            referenceRow(
                title: "Lists",
                example: """
                - Bullet item
                  - Nested bullet
                1. Numbered item
                2. Another item
                """,
                syntax: """
                - Bullet item
                  - Nested bullet

                1. Numbered item
                2. Another item
                """
            )

            referenceRow(
                title: "Links & Images",
                example: """
                [DirectGTD](https://directgtd.com)
                """,
                syntax: """
                [text](https://example.com)
                ![alt text](https://example.com/image.png)
                """
            )

            referenceRow(
                title: "Code",
                example: """
                `inline code`

                ```swift
                let foo = "bar"
                ```
                """,
                syntax: """
                `inline code`

                ```language
                code block
                ```
                """
            )

            referenceRow(
                title: "Other",
                example: """
                > Blockquote

                ---
                """,
                syntax: """
                > Blockquote

                ---
                """
            )

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 420, alignment: .topLeading)
    }

    private func referenceRow(title: String, example: String, syntax: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Result")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(example)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Syntax")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(verbatim: syntax)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

#Preview {
    MarkdownHelpView()
}
