import SwiftUI
import UIKit

final class RichTextController: ObservableObject {
    fileprivate weak var textView: UITextView?
    func toggleBold() { toggle(.traitBold) }
    func toggleItalic() { toggle(.traitItalic) }
    func toggleUnderline() { toggle(underline: true) }
    private func toggle(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        guard range.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        mutable.enumerateAttributes(in: range, options: []) { attrs, r, _ in
            let current = attrs[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
            var traits = current.fontDescriptor.symbolicTraits
            if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
            if let desc = current.fontDescriptor.withSymbolicTraits(traits) {
                let newFont = UIFont(descriptor: desc, size: current.pointSize)
                var newAttrs = attrs
                newAttrs[.font] = newFont
                mutable.setAttributes(newAttrs, range: r)
            }
        }
        tv.attributedText = mutable
        tv.selectedRange = range
    }
    private func toggle(underline: Bool) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        guard range.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: tv.attributedText)
        mutable.enumerateAttributes(in: range, options: []) { attrs, r, _ in
            let current = (attrs[.underlineStyle] as? Int) ?? 0
            var newAttrs = attrs
            newAttrs[.underlineStyle] = (current == 0) ? NSUnderlineStyle.single.rawValue : 0
            mutable.setAttributes(newAttrs, range: r)
        }
        tv.attributedText = mutable
        tv.selectedRange = range
    }
}

struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @ObservedObject var controller: RichTextController
    var placeholder: String
    
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.font = UIFont.systemFont(ofSize: 16)
        tv.isScrollEnabled = true
        tv.delegate = context.coordinator
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        tv.textContainer.lineFragmentPadding = 0
        // Paragraph and line spacing defaults for a more open feel
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        style.paragraphSpacing = 4
        uiApplyDefaultTypingAttributes(tv, style: style)
        controller.textView = tv
        return tv
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: RichTextEditor
        init(_ parent: RichTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText
        }
    }

    private func uiApplyDefaultTypingAttributes(_ tv: UITextView, style: NSParagraphStyle) {
        var attrs: [NSAttributedString.Key: Any] = tv.typingAttributes
        attrs[.paragraphStyle] = style
        attrs[.foregroundColor] = UIColor.black
        tv.typingAttributes = attrs
    }
}

