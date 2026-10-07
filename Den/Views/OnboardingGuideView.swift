import SwiftUI

/// Shown after the first egg is chosen; the pending flag survives an interrupted launch.
struct OnboardingGuideView: View {
    let eggColor: EggColor
    let onDone: () -> Void
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let titles = ["Focus together", "Surprise inside!", "Start collecting your friends!"]
    private let captions = [
        "Study with your little friend.",
        "Focus for 10 hours to hatch a new friend.",
        "Every egg brings a new friend.",
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $step) {
                ForEach(0..<titles.count, id: \.self) { page in
                    ScrollView {
                        VStack(spacing: 28) {
                            illustration(page)
                                .frame(height: 200)
                                .padding(.top, 32)
                                .accessibilityHidden(true)
                            Text(titles[page])
                                .font(.title2.bold())
                            Text(captions[page])
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 290)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 36)
                    }
                    .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0..<titles.count, id: \.self) { page in
                    Capsule()
                        .fill(page == step ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: page == step ? 20 : 6, height: 6)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step + 1) of \(titles.count)")

            Button {
                if step == titles.count - 1 {
                    onDone()
                } else {
                    withAnimation(reduceMotion ? nil : .easeInOut) { step += 1 }
                }
            } label: {
                Text(step == titles.count - 1 ? "Let’s focus!" : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(560), .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private func illustration(_ page: Int) -> some View {
        switch page {
        case 0:
            tile(PetSprites.character(id: "fangfang").study1, size: 184)
        case 1:
            HStack(spacing: 16) {
                tile(PetSprites.character(id: eggColor.spriteID).idle, size: 110)
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.tint)
                tile(PetSprites.character(id: eggColor == .white ? "mochi" : "doudou").happy, size: 110)
            }
        default:
            HStack(alignment: .bottom, spacing: 12) {
                tile(PetSprites.character(id: "egg.white").idle, size: 96)
                tile(PetSprites.character(id: "cloud").happy, size: 112)
                tile(PetSprites.character(id: "egg.black").idle, size: 96)
            }
        }
    }

    private func tile(_ pixels: [String], size: CGFloat) -> some View {
        PixelSprite(pixels: pixels)
            .fill(LCDPalette.pixelOn)
            .padding(12)
            .frame(width: size, height: size)
            .background(LCDPalette.background, in: RoundedRectangle(cornerRadius: 20))
    }
}
