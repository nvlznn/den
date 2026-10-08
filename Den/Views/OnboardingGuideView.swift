import SwiftUI

/// 選好第一顆蛋之後的全螢幕導覽：上面是大 LCD，每一頁播一段功能的動畫；看完是歡迎畫面。
/// Shown after the first egg is chosen; the pending flag survives an interrupted launch.
struct OnboardingGuideView: View {
    let eggColor: EggColor
    let onDone: () -> Void
    @State private var step = 0
    /// 這一頁開始的時間，LCD 的動畫從這裡算起。
    @State private var stepStart = Date.now
    @State private var happySince: Date?
    @State private var showsWelcome = false
    /// 這一頁的動畫播完一輪才能按 Next。
    @State private var canAdvance = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let titles = [String(localized: "Focus together"), String(localized: "Surprise inside!"), String(localized: "Start collecting your friends!")]
    private let captions = [
        String(localized: "Study with your little friend."),
        String(localized: "Focus for 10 hours to hatch a new friend."),
        String(localized: "Every egg brings a new friend."),
    ]

    /// 孵化那頁：蛋先看書，然後孵出來跳舞、煙火放個不停，再從蛋重來。
    private static let hatchDelay: TimeInterval = 1.5
    private static let hatchLoop: TimeInterval = 3.8
    /// 收集那頁：每隻角色出場的時間，和各自的等級（每隻各自升級）。
    private static let paradeInterval: TimeInterval = 1
    private static let paradeLevels = [3, 5, 1, 4, 2, 6]

    var body: some View {
        ZStack {
            if showsWelcome {
                WelcomeView(onDone: onDone)
                    .transition(.opacity)
            } else {
                guide
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showsWelcome)
    }

    private var guide: some View {
        VStack(spacing: 20) {
            TimelineView(.animation(minimumInterval: 0.1)) { context in
                screen(at: context.date)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // 不能滑動換頁：每頁的動畫要播完才能往下。
            ScrollView {
                VStack(spacing: 12) {
                    Text(titles[step])
                        .font(.title2.bold())
                    Text(captions[step])
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 290)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .id(step)
                .transition(.push(from: .trailing))
            }
            .scrollBounceBehavior(.basedOnSize)

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
                    showsWelcome = true
                } else {
                    withAnimation(reduceMotion ? nil : .easeInOut) { step += 1 }
                }
            } label: {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            .disabled(!canAdvance)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .task(id: step) {
            stepStart = .now
            happySince = nil
            canAdvance = false
            try? await Task.sleep(for: .seconds(playTime(of: step)))
            withAnimation { canAdvance = true }
        }
    }

    /// 這一頁的動畫完整播一輪要多久；每頁都不超過 4 秒。
    private func playTime(of step: Int) -> TimeInterval {
        switch step {
        case 0: PetState.frameInterval * 4
        case 1: Self.hatchLoop
        // 六隻都輪完要 6 秒，太久；看過幾隻就能往下，剩下的繼續輪播。
        default: 3.5
        }
    }

    /// 依這一頁和經過的時間，決定 LCD 上是誰、幾級、在做什麼。
    private func screen(at date: Date) -> some View {
        let egg = PetSprites.character(id: eggColor.spriteID)
        let elapsed = max(0, date.timeIntervalSince(stepStart))
        var character = egg
        var level = 0
        var activity: PetActivity?
        var levelUpSince: Date?

        switch step {
        case 0:
            // 跟你一起看書；點一下會開心地跳。
            break
        case 1:
            let loopStart = stepStart.addingTimeInterval((elapsed / Self.hatchLoop).rounded(.down) * Self.hatchLoop)
            let hatchedAt = loopStart.addingTimeInterval(Self.hatchDelay)
            if date < hatchedAt {
                activity = .studying
            } else {
                character = PetSprites.character(id: eggColor == .white ? "mochi" : "doudou")
                level = 1
                activity = .dancing
                levelUpSince = hatchedAt
            }
        default:
            let index = Int(elapsed / Self.paradeInterval) % PetSprites.characters.count
            character = PetSprites.characters[index]
            level = Self.paradeLevels[index % Self.paradeLevels.count]
            activity = .dancing
        }

        return LCDScreenView(
            character: character,
            level: level,
            pet: PetState(isTiming: true, happySince: happySince),
            levelUpSince: levelUpSince,
            activityOverride: activity,
            keepsCelebrating: true,
            onPetTap: { happySince = .now }
        )
    }
}

/// 導覽的最後：滿滿的角色和蛋一起跳起來歡迎你。
private struct WelcomeView: View {
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    /// 大家都出場了才能按 Let's focus!。
    @State private var canFinish = false

    /// 四排、每排四個，上下各兩排，相鄰的盡量不一樣。
    private static let crowd: [[String]] = [
        ["fangfang", "egg.white", "cloud", "doudou"],
        ["orb", "mochi", "egg.black", "drop"],
        ["egg.black", "drop", "fangfang", "egg.white"],
        ["mochi", "doudou", "orb", "cloud"],
    ]

    var body: some View {
        VStack(spacing: 0) {
            crowdRows(0..<2)
            Spacer(minLength: 16)
            Text("Welcome to Den")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(LCDPalette.pixelOn)
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(duration: 0.6, bounce: 0.5).delay(0.3), value: appeared)
            Spacer(minLength: 16)
            crowdRows(2..<4)
            Spacer(minLength: 24)
            Button(action: onDone) {
                Text("Let’s focus!")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            .tint(LCDPalette.pixelOn)
            .disabled(!canFinish)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LCDPalette.background)
        .preferredColorScheme(.light)
        .task {
            appeared = true
            // 最後一隻在 0.75 秒開始彈、0.5 秒彈完，標題 0.9 秒到位。
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { canFinish = true }
        }
        .sensoryFeedback(.success, trigger: appeared)
    }

    private func crowdRows(_ rows: Range<Int>) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            VStack(spacing: 12) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(Self.crowd[row].indices, id: \.self) { column in
                            let index = row * 4 + column
                            jumper(id: Self.crowd[row][column], index: index, time: time)
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// 一隻一隻彈出來，然後各跳各的：每隻的節奏錯開一點，看起來才熱鬧。
    private func jumper(id: String, index: Int, time: TimeInterval) -> some View {
        let period = 0.6 + Double(index % 3) * 0.08
        let phase = Double(index) * 0.37
        let hop = reduceMotion ? 0 : abs(sin(.pi * (time / period + phase))) * 18
        return PixelSprite(pixels: PetSprites.character(id: id).happy)
            .fill(LCDPalette.pixelOn)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .offset(y: -hop)
            .scaleEffect(appeared ? 1 : 0)
            .animation(.spring(duration: 0.5, bounce: 0.6).delay(Double(index) * 0.05), value: appeared)
    }
}
