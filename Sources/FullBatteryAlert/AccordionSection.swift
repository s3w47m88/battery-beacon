import SwiftUI

struct AccordionSection<Content: View>: View {
    let id: String
    let title: String
    @ViewBuilder var content: () -> Content

    @AppStorage private var isOpen: Bool

    init(id: String, title: String, defaultOpen: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.title = title
        self.content = content
        self._isOpen = AppStorage(wrappedValue: defaultOpen, "accordion.\(id).open")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isOpen.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Text(title).font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                content()
                    .padding(.leading, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
