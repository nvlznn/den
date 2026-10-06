import SwiftData
import SwiftUI

/// 唯一的主畫面：上半部是 LCD，下半部是計時。
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(FocusTimer.self) private var timer
    @Query private var sessions: [FocusSession]

    @AppStorage("timerMode") private var modeKind = TimerMode.Kind.stopwatch
    @AppStorage("countdownMinutes") private var countdownMinutes = 25

    @State private var happySince: Date?
    @State private var levelFlashSince: Date?
    @State private var sessionToConfirm: FinishedSession?

    // Haptic 觸發器
    @State private var petTaps = 0
    @State private var celebrations = 0
    @State private var starts = 0
    @State private var stops = 0

    private var totalSeconds: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    private var level: Level {
        Level(totalSeconds: totalSeconds)
    }

    var body: some View {
        GeometryReader { proxy in
            let screenHeight = max(240, proxy.size.height * 0.6)
            let spacing: CGFloat = 24

            ScrollView {
                VStack(spacing: spacing) {
                    LCDScreenView(
                        level: level.number,
                        pet: PetState(isTiming: timer.isRunning, happySince: happySince),
                        levelFlashSince: levelFlashSince,
                        onPetTap: petTapped
                    )
                    .frame(height: screenHeight)

                    Group {
                        if let active = timer.active {
                            RunningTime(session: active)
                        } else {
                            idleControls
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: max(0, proxy.size.height - screenHeight - spacing - 8))
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            primaryButton
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color(.systemBackground))
        }
        .animation(.default, value: timer.isRunning)
        .animation(.default, value: modeKind)
        .sheet(item: $sessionToConfirm) { session in
            EndSessionSheet(session: session, onSave: saveConfirmed, onDiscard: discardStopwatch)
        }
        .task(id: timer.active) {
            await waitForCountdownEnd()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            timer.restore()
            if timer.isRunning {
                finishExpiredCountdown()
            } else {
                LiveActivityController.end()
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: petTaps)
        .sensoryFeedback(.success, trigger: celebrations)
        .sensoryFeedback(.start, trigger: starts)
        .sensoryFeedback(.stop, trigger: stops)
    }

    // MARK: 下半部

    private var idleControls: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: level.progressToNext)
                    .accessibilityLabel("距離 Lv \(level.number + 1) 的進度")
                Text("累積 \(DurationText.hoursAndMinutes(totalSeconds))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Picker("模式", selection: $modeKind) {
                Text("正計時").tag(TimerMode.Kind.stopwatch)
                Text("倒數").tag(TimerMode.Kind.countdown)
            }
            .pickerStyle(.segmented)

            if modeKind == .countdown {
                DurationPicker(minutes: $countdownMinutes)
            }
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if timer.isRunning {
            // 結束不是破壞性操作，用次要樣式，不用紅色。
            Button(action: endTapped) {
                Text("結束")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        } else {
            Button(action: start) {
                Text("開始專注")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: 動作

    private func start() {
        let mode: TimerMode = switch modeKind {
        case .stopwatch: .stopwatch
        case .countdown: .countdown(planned: TimeInterval(countdownMinutes * 60))
        }
        timer.start(mode)
        starts += 1

        guard let active = timer.active else { return }
        LiveActivityController.start(for: active)
        if case .countdown(let planned) = mode, let end = active.plannedEnd {
            Task {
                await CountdownNotifier.shared.schedule(at: end, planned: planned)
            }
        }
    }

    private func endTapped() {
        guard let active = timer.active else { return }
        stops += 1

        switch active.mode {
        case .stopwatch:
            let finished = active.finished(at: .now)
            if finished.isWorthKeeping {
                sessionToConfirm = finished
            } else {
                discardStopwatch()
            }

        case .countdown:
            // 提早結束：已經過的時間照樣存，不確認、不評論。寵物直接回到待機。
            CountdownNotifier.shared.cancel()
            LiveActivityController.end()
            if let finished = timer.end() {
                record(finished)
            }
        }
    }

    private func saveConfirmed(_ session: FinishedSession) {
        sessionToConfirm = nil
        timer.clear()
        LiveActivityController.end()
        record(session)
    }

    private func discardStopwatch() {
        sessionToConfirm = nil
        timer.clear()
        LiveActivityController.end()
    }

    private func waitForCountdownEnd() async {
        guard let end = timer.active?.plannedEnd else { return }
        let delay = end.timeIntervalSinceNow
        if delay > 0 {
            do {
                try await Task.sleep(for: .seconds(delay + 0.05))
            } catch {
                return
            }
        }
        finishExpiredCountdown()
    }

    /// 倒數時間到：以「開始 + 預定時長」存檔，不跳確認視窗。
    /// 使用者在時間到之後才打開 app 也一樣。
    private func finishExpiredCountdown() {
        guard let finished = timer.completeIfExpired() else { return }
        CountdownNotifier.shared.cancel()
        LiveActivityController.end()
        record(finished)
        happySince = .now
        celebrations += 1
    }

    private func petTapped() {
        happySince = .now
        petTaps += 1
    }

    /// 不到 1 分鐘的直接丟掉，不顯示任何訊息。
    private func record(_ finished: FinishedSession) {
        guard finished.isWorthKeeping else { return }
        let before = level
        modelContext.insert(FocusSession(startedAt: finished.startedAt, endedAt: finished.endedAt))
        try? modelContext.save()

        let after = Level(totalSeconds: before.totalSeconds + finished.duration)
        if after.number > before.number {
            // 升級：寵物開心、Lv 閃兩下。不彈窗、不撒彩帶。
            happySince = .now
            levelFlashSince = .now
            celebrations += 1
        }
    }
}

extension FinishedSession: Identifiable {
    var id: Date { startedAt }
}

/// 專注中的大數字。正計時顯示經過時間，倒數顯示剩餘時間。
private struct RunningTime: View {
    let session: ActiveSession

    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = 76

    var body: some View {
        TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
            let seconds = session.displayedSeconds(at: context.date)
            Text(DurationText.clock(seconds))
                .font(.system(size: fontSize, weight: .light))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .accessibilityLabel(accessibilityText(seconds))
        }
    }

    private func accessibilityText(_ seconds: Int) -> String {
        let text = DurationText.hoursAndMinutes(TimeInterval(seconds))
        return session.plannedEnd == nil ? "已專注 \(text)" : "還剩 \(text)"
    }
}

#Preview {
    HomeView()
        .environment(FocusTimer(defaults: UserDefaults(suiteName: "preview")!))
        .modelContainer(for: FocusSession.self, inMemory: true)
}
