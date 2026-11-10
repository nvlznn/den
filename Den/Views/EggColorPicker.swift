import SwiftUI

/// Shared by onboarding, the second free egg and paid eggs.
struct EggColorPicker: View {
    let collection: CharacterCollection
    @Binding var selection: EggColor
    var reservedIDs: Set<String> = []
    var thumbnailSize: CGFloat = 88
    /// 第一次選蛋時，白蛋回報自己的位置給等待畫面的蛋飛過來，落地前先藏起來；其他部分用 `restOpacity` 淡入。
    var reportsWhiteEggFrame = false
    var whiteEggOpacity: Double = 1
    var restOpacity: Double = 1

    var body: some View {
        HStack(spacing: 16) {
            ForEach(EggColor.allCases) { color in
                let remaining = collection.order.filter { color.characterIDs.contains($0) && !collection.ownedIDs.contains($0) && !reservedIDs.contains($0) }.count
                Button {
                    selection = color
                } label: {
                    VStack(spacing: 10) {
                        CharacterThumbnail(character: PetSprites.character(id: color.spriteID))
                            .frame(width: thumbnailSize, height: thumbnailSize)
                            .opacity(color == .white ? whiteEggOpacity : restOpacity)
                            .background {
                                if reportsWhiteEggFrame && color == .white {
                                    GeometryReader { Color.clear.preference(key: FirstEggFrameKey.self, value: $0.frame(in: .global)) }
                                }
                            }
                        Group {
                            Text(color.name).font(.headline)
                            if remaining == 0 {
                                Text("Sold Out")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: selection == color ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection == color ? Color.accentColor : Color.secondary)
                            }
                        }
                        .opacity(restOpacity)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selection == color ? Color.accentColor.opacity(0.08 * restOpacity) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 18))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(remaining == 0)
                .opacity(remaining == 0 ? 0.65 : 1)
                .accessibilityLabel(remaining == 0 ? String(localized: "\(color.name), sold out") : String(localized: "\(color.name), \(remaining) remaining"))
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
    }
}
