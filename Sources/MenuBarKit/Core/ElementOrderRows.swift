import SwiftUI

/// Settings rows for a menu bar label's elements: a checkbox per element plus
/// up/down buttons, where top-to-bottom order is left-to-right in the bar.
struct ElementOrderRows<Item>: View {
    @Binding var items: [Item]
    let isEnabled: WritableKeyPath<Item, Bool>
    let label: (Item) -> String
    let symbol: (Item) -> String

    var body: some View {
        ForEach(items.indices, id: \.self) { index in
            HStack {
                Toggle(isOn: $items[index][dynamicMember: isEnabled]) {
                    Label(label(items[index]), systemImage: symbol(items[index]))
                }
                .toggleStyle(.checkbox)
                Spacer()
                Button { move(index, by: -1) } label: { Image(systemName: "chevron.up") }
                    .disabled(index == 0)
                Button { move(index, by: 1) } label: { Image(systemName: "chevron.down") }
                    .disabled(index == items.count - 1)
            }
            .buttonStyle(.borderless)
        }
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard items.indices.contains(target) else { return }
        items.swapAt(index, target)
    }
}
