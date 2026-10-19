import GlossCore
import SwiftUI

/// TextResultView shows a translated sentence.
struct TextResultView: View {
    let translation: TextTranslation

    var body: some View {
        Text(translation.translation)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}
