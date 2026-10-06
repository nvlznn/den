import SwiftData
import SwiftUI

/// 選擇陪你專注的角色。每個角色的等級各自計算。
struct CharacterSheet: View {
    @Binding var characterID: String

    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [FocusSession]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PetSprites.characters) { character in
                        row(for: character)
                    }
                }
            }
            .navigationTitle("Select Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
    }

    private func row(for character: PetCharacter) -> some View {
        let level = Level(totalSeconds: Level.totalSeconds(
            of: character.id,
            defaultID: PetSprites.defaultCharacterID,
            in: sessions,
            characterOf: \.characterID,
            isManual: \.isManual,
            duration: \.duration
        ))
        let isSelected = character.id == characterID

        return Button {
            characterID = character.id
            dismiss()
        } label: {
            HStack(spacing: 14) {
                CharacterThumbnail(character: character)
                    .frame(width: 52, height: 52)

                // 用具體的 Color；`.primary` 在 List 的按鈕裡會被換成 tint 色。
                VStack(alignment: .leading, spacing: 2) {
                    Text(character.name)
                        .foregroundStyle(Color.primary)
                    Text("Lv \(level.number) · \(DurationText.hoursAndMinutes(level.totalSeconds)) total")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 角色的小縮圖：LCD 底色上的待機像素圖。
struct CharacterThumbnail: View {
    let character: PetCharacter

    var body: some View {
        PixelSprite(pixels: character.idle)
            .fill(LCDPalette.pixelOn)
            .padding(8)
            .background(LCDPalette.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}
