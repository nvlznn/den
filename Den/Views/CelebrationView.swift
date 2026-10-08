import SwiftUI

/// 專注結束後的慶祝畫面：上面是跳舞的角色，中間是專注時長，下面是慶祝的話。
/// 升級時 LCD 放像素煙火、整個畫面噴彩帶，等級變化那行彈出來。
/// 剛孵化的話，下面的按鈕變成幫新夥伴取名字，預設是原本的名字。
struct CelebrationView: View {
    let celebration: Celebration
    /// 關掉畫面；剛孵化時帶著使用者取的名字。
    let onDone: (_ name: String?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appearedAt = Date.now
    @State private var showsLevelUp = false
    @State private var isNaming = false
    @State private var name = ""

    private var character: PetCharacter {
        PetSprites.character(id: celebration.characterID)
    }

    var body: some View {
        VStack(spacing: 24) {
            LCDScreenView(
                character: character,
                level: celebration.levelAfter,
                pet: PetState(isTiming: false),
                levelUpSince: celebration.didLevelUp ? appearedAt : nil,
                activityOverride: .dancing,
                onPetTap: {}
            )
            .aspectRatio(1, contentMode: .fit)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                if celebration.didLevelUp {
                    Label(celebration.didHatch ? String(localized: "Your egg hatched!") : String(localized: "Level Up!  Lv \(celebration.levelBefore) → Lv \(celebration.levelAfter)"), systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .symbolEffect(.bounce, value: showsLevelUp)
                        .scaleEffect(showsLevelUp ? 1 : 0.4)
                        .opacity(showsLevelUp ? 1 : 0)
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

            Button {
                if celebration.didHatch {
                    name = character.name
                    isNaming = true
                } else {
                    onDone(nil)
                }
            } label: {
                Text(celebration.didHatch ? "Name Your New Friend" : "Done")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
        }
        .padding()
        .overlay {
            if celebration.didLevelUp && !reduceMotion {
                ConfettiBurst(start: appearedAt)
            }
        }
        .background(Color(.systemBackground))
        .alert("Name Your New Friend", isPresented: $isNaming) {
            TextField(character.name, text: $name)
                .onChange(of: name) { _, value in
                    if value.count > CharacterCollection.maxNameLength {
                        name = String(value.prefix(CharacterCollection.maxNameLength))
                    }
                }
            Button("Cancel", role: .cancel) {}
            Button("Save") { onDone(name) }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.5).delay(0.2)) { showsLevelUp = true }
        }
        .sensoryFeedback(celebration.didLevelUp ? .levelChange : .success, trigger: appearedAt)
        .interactiveDismissDisabled()
    }
}

/// 升級時從 LCD 中央噴出來的彩帶，三秒多就落完消失，不擋點擊。
private struct ConfettiBurst: View {
    let start: Date

    private static let lifetime: TimeInterval = 3.4
    private static let colors: [Color] = [.pink, .orange, .yellow, .green, .mint, .blue, .purple]

    private struct Piece {
        let velocity: CGVector
        let delay: TimeInterval
        let size: CGSize
        let spin: Double
        let flip: Double
        let color: Color
    }

    @State private var pieces: [Piece] = (0..<110).map { index in
        let angle = Double.random(in: -.pi * 0.92 ... -.pi * 0.08)
        let speed = Double.random(in: 380...820)
        return Piece(
            velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
            delay: index < 70 ? 0 : 0.35,
            size: CGSize(width: .random(in: 6...9), height: .random(in: 10...15)),
            spin: .random(in: -9...9),
            flip: .random(in: 6...14),
            color: colors[index % colors.count]
        )
    }
    @State private var isFinished = false

    var body: some View {
        TimelineView(.animation(paused: isFinished)) { context in
            Canvas { graphics, size in
                // LCD 是正方形、貼著上方，中心大約在 (寬/2, 寬/2)。
                let origin = CGPoint(x: size.width / 2, y: size.width / 2)
                let elapsed = context.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0, t < Self.lifetime else { continue }
                    // 一開始快、空氣阻力讓它慢下來，然後被重力往下拉。
                    let drag = (1 - exp(-2.2 * t)) / 2.2
                    let x = origin.x + piece.velocity.dx * drag
                    let y = origin.y + piece.velocity.dy * drag + 180 * t * t
                    var copy = graphics
                    copy.opacity = min(1, (Self.lifetime - t) / 0.8)
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .radians(piece.spin * t))
                    copy.scaleBy(x: cos(piece.flip * t), y: 1)
                    let rect = CGRect(origin: CGPoint(x: -piece.size.width / 2, y: -piece.size.height / 2), size: piece.size)
                    copy.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds(Self.lifetime + 0.5))
            isFinished = true
        }
    }
}
