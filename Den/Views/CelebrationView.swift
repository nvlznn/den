import SwiftUI

/// 專注結束後的慶祝畫面：上面是跳舞的角色，中間是專注時長，下面是慶祝的話。
/// 升級時多一行等級變化，Lv 也會閃動。
struct CelebrationView: View {
    let celebration: Celebration
    let onDone: () -> Void

    @State private var appearedAt = Date.now

    private var character: PetCharacter {
        PetSprites.character(id: celebration.characterID)
    }

    var body: some View {
        VStack(spacing: 24) {
            LCDScreenView(
                character: character,
                level: celebration.levelAfter,
                pet: PetState(isTiming: false),
                levelFlashSince: celebration.didLevelUp ? appearedAt : nil,
                activityOverride: .dancing,
                onPetTap: {}
            )
            .aspectRatio(1, contentMode: .fit)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                if celebration.didLevelUp {
                    Label("Level Up!  Lv \(celebration.levelBefore) → Lv \(celebration.levelAfter)", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.tint)
                }
                Text("You focused for")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(DurationText.spoken(celebration.duration))
                    .font(.system(size: 48, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)

            Text(celebration.message)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Button(action: onDone) {
                Text("Done")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
        }
        .padding()
        .background(Color(.systemBackground))
        .sensoryFeedback(.success, trigger: appearedAt)
        .interactiveDismissDisabled()
    }
}
