import SwiftUI

struct MarkdownHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Markdown Quick Reference")
                .font(.title2)
                .bold()

            Group {
                Text("**Headings**")
                    .font(.headline)
                Text("# Heading 1\n## Heading 2\n### Heading 3")
                    .font(.system(.body, design: .monospaced))
            }

            Group {
                Text("**Emphasis**")
                    .font(.headline)
                Text("*italic*  _italic_\n**bold**  __bold__\n***bold italic***\n~~strikethrough~~")
                    .font(.system(.body, design: .monospaced))
            }

            Group {
                Text("**Lists**")
                    .font(.headline)
                Text("- Bullet item\n- Item 2\n  - Nested item\n1. Numbered item\n2. Another")
                    .font(.system(.body, design: .monospaced))
            }

            Group {
                Text("**Links & Images**")
                    .font(.headline)
                Text("[link text](https://example.com)\n![alt text](https://example.com/image.png)")
                    .font(.system(.body, design: .monospaced))
            }

            Group {
                Text("**Code**")
                    .font(.headline)
                Text("`inline code`\n\n````\n```swift\nlet foo = \"bar\"\n```\n````")
                    .font(.system(.body, design: .monospaced))
            }

            Group {
                Text("**Other**")
                    .font(.headline)
                Text(">")
                    .font(.system(.body, design: .monospaced))
                Text("> Blockquote\n\n--- (horizontal rule)")
                    .font(.system(.body, design: .monospaced))
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 400, alignment: .topLeading)
    }
}

#Preview {
    MarkdownHelpView()
}
