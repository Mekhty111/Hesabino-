//
//  ContentView.swift
//  Compositor
//
//  Created by Mekhty on 24.02.26.
//

import SwiftUI
import UIKit

// Простая модель "счетов" для одного игрока
struct AbacusPlayer {
    /// Количество активных бусинок на каждой планке
    var activePerRod: [Int]
}

enum MatchMode: String, CaseIterable, Identifiable, Codable {
    case pairs2
    case freeForAll4

    var id: String { rawValue }

    var playersCount: Int {
        switch self {
        case .pairs2: return 2
        case .freeForAll4: return 4
        }
    }
}

/// Режимы домино и "ценность" каждого ряда
enum GameMode: String, CaseIterable, Identifiable, Codable {
    case phone365 = "365"
    case oneOOne = "101"

    var id: String { rawValue }

    /// Множители для рядов, сверху вниз
    var rowMultipliers: [Int] {
        switch self {
        case .phone365:
            // 1-й ряд ×5, 2-й ×10, 3-й ×100
            return [5, 10, 100]
        case .oneOOne:
            // 1-й ряд ×1, 2-й ×10, 3-й ×100
            return [1, 10, 100]
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .phone365: return LocalizedStringKey("mode_phone365_title")
        case .oneOOne: return LocalizedStringKey("mode_101_title")
        }
    }

    var subtitleKey: LocalizedStringKey {
        switch self {
        case .phone365: return LocalizedStringKey("mode_phone365_subtitle")
        case .oneOOne: return LocalizedStringKey("mode_101_subtitle")
        }
    }
}

enum ScoreDisplayMode: String, CaseIterable, Identifiable, Codable {
    case perTeam
    case sharedBoard

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .perTeam:
            return LocalizedStringKey("score_display_per_team")
        case .sharedBoard:
            return LocalizedStringKey("score_display_shared")
        }
    }
}

struct GameHistoryEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let matchMode: MatchMode
    let gameMode: GameMode
    let scoreDisplayMode: ScoreDisplayMode
    let scores: [Int]
    let names: [String]?
    let winner: Int?  // индекс победителя (nil если нет победителя)
}

struct ContentView: View {
    // Используем 3 ряда под заданные множители
    private let rodsPerPlayer = 3

    @AppStorage("matchMode") private var matchModeRaw: String = ""
    @AppStorage("scoreDisplayMode") private var scoreDisplayModeRaw: String = ScoreDisplayMode.perTeam.rawValue
    @AppStorage("gameHistory") private var gameHistoryData: Data = Data()
    @State private var players: [AbacusPlayer] = []
    @State private var teamWins: [Int] = []
    @State private var customNames: [String] = []

    @State private var selectedPlayerIndex: Int = 0
    @State private var gameMode: GameMode = .phone365
    @State private var isSettingsPresented: Bool = false
    @State private var isSwitchingGameMode: Bool = false
    @State private var isHistoryPresented: Bool = false
    @State private var showEndGameConfirm: Bool = false
    @State private var isEditingNamesPresented: Bool = false

    // Настройки "счетов"
    private let beadsPerRod: Int = 10

    private var matchMode: MatchMode? {
        MatchMode(rawValue: matchModeRaw)
    }

    private var scoreDisplayMode: ScoreDisplayMode {
        ScoreDisplayMode(rawValue: scoreDisplayModeRaw) ?? .perTeam
    }

    private var historyEntries: [GameHistoryEntry] {
        guard !gameHistoryData.isEmpty else { return [] }
        return (try? JSONDecoder().decode([GameHistoryEntry].self, from: gameHistoryData)) ?? []
    }

    var body: some View {
        ZStack {
            // Фон
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.12),
                    Color(red: 0.12, green: 0.10, blue: 0.20),
                    Color(red: 0.06, green: 0.08, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                headerView

                playerSelector

                swipableAbacus

                swipeHint
                    .padding(.top, 12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        // Сильное встряхивание телефона → сбросить счёт
        .background(
            ShakeDetectorView {
                triggerResetAllByShake()
            }
            .frame(width: 0, height: 0)
        )
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(matchModeRaw: $matchModeRaw, scoreDisplayModeRaw: $scoreDisplayModeRaw)
        }
        .sheet(isPresented: $isHistoryPresented) {
            HistoryView(entries: historyEntries, onDelete: deleteHistoryEntry)
        }
        .sheet(isPresented: $isEditingNamesPresented) {
            RenameTeamView(
                team1Name: Binding(
                    get: { customName(for: 0) ?? "" },
                    set: { newValue in
                        ensureCustomNamesCapacity()
                        if customNames.indices.contains(0) {
                            customNames[0] = newValue
                        }
                    }
                ),
                team2Name: Binding(
                    get: { customName(for: 1) ?? "" },
                    set: { newValue in
                        ensureCustomNamesCapacity()
                        if customNames.indices.contains(1) {
                            customNames[1] = newValue
                        }
                    }
                ),
                onCancel: {
                    isEditingNamesPresented = false
                },
                onSave: {
                    isEditingNamesPresented = false
                }
            )
        }
        .fullScreenCover(isPresented: Binding(get: { matchMode == nil }, set: { _ in })) {
            ChooseMatchModeView { chosen in
                matchModeRaw = chosen.rawValue
                configurePlayersIfNeeded(for: chosen, resetScores: true)
            }
        }
        .onAppear {
            if let mode = matchMode {
                configurePlayersIfNeeded(for: mode, resetScores: false)
            }
        }
        .onChange(of: matchModeRaw) { _, newValue in
            guard let mode = MatchMode(rawValue: newValue) else { return }
            configurePlayersIfNeeded(for: mode, resetScores: true)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(spacing: 12) {
            Button {
                isHistoryPresented = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Button {
                guard !isSwitchingGameMode else { return }
                isSwitchingGameMode = true
                gameMode = (gameMode == .phone365) ? .oneOOne : .phone365
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isSwitchingGameMode = false
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.55),
                                        Color.purple.opacity(0.65)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        Image(systemName: "dial.low.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(gameMode.titleKey)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(gameMode.subtitleKey)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("settings_title"))
        }
    }

    private var swipableAbacus: some View {
        GeometryReader { geo in
            let width = geo.size.width

            ZStack {
                ZStack {
                    if gameMode == .phone365 {
                        abacusCard
                            .allowsHitTesting(!showEndGameConfirm)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                )
                            )
                    } else {
                        abacusCard
                            .allowsHitTesting(!showEndGameConfirm)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                )
                            )
                    }
                }
                .offset(y: showEndGameConfirm ? 70 : 0)
                .scaleEffect(showEndGameConfirm ? 0.98 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showEndGameConfirm)

                if showEndGameConfirm {
                    VStack {
                        endGameConfirmCard
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                }
            }
            .frame(width: width)
            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: gameMode)
            .contentShape(Rectangle()) // свайп по всей площади счётов
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        guard !isSwitchingGameMode else { return }
                        let threshold: CGFloat = 40
                        let translationX = value.translation.width
                        let translationY = value.translation.height
                        let absX = abs(translationX)
                        let absY = abs(translationY)

                        // Вертикальные свайпы для окна завершения игры
                        if absY > absX {
                            if translationY > threshold {
                                // Вниз — показать окно завершения
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    showEndGameConfirm = true
                                }
                                return
                            } else if translationY < -threshold, showEndGameConfirm {
                                // Вверх — спрятать окно (как «Нет, случайно»)
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    showEndGameConfirm = false
                                }
                                return
                            }
                        }

                        switch gameMode {
                        case .phone365:
                            // Только свайп влево, чтобы перейти к 101
                            if translationX < -threshold {
                                isSwitchingGameMode = true
                                gameMode = .oneOOne
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isSwitchingGameMode = false
                                }
                            }
                        case .oneOOne:
                            // Только свайп вправо, чтобы вернуться к телефону
                            if translationX > threshold {
                                isSwitchingGameMode = true
                                gameMode = .phone365
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isSwitchingGameMode = false
                                }
                            }
                        }
                    }
            )
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var swipeHint: some View {
        HStack(spacing: 6) {
            if gameMode == .phone365 {
                Image(systemName: "arrow.left")
                    .font(.system(size: 13, weight: .semibold))
                Text("swipe_hint_to_101")
                    .font(.system(.caption, design: .rounded))
            } else {
                Text("swipe_hint_to_365")
                    .font(.system(.caption, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .foregroundStyle(Color.white.opacity(0.8))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private var endGameConfirmCard: some View {
        VStack(spacing: 10) {
            Text("end_game_title")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("end_game_subtitle")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        showEndGameConfirm = false
                    }
                } label: {
                    Text("end_game_cancel")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    saveCurrentGameToHistory()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        showEndGameConfirm = false
                        resetAllPlayers()
                    }
                } label: {
                    Text("end_game_confirm")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red.opacity(0.7))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.10, blue: 0.16),
                            Color(red: 0.03, green: 0.04, blue: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 8)
    }

    private var playerSelector: some View {
        Group {
            if matchMode == .pairs2,
               scoreDisplayMode == .sharedBoard {
                EmptyView()
            } else if matchMode == .pairs2 && players.count == 2 {
                HStack(spacing: 16) {
                    playerChip(for: 0)
                    Spacer(minLength: 0)
                    playerChip(for: 1)
                }
                .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(players.indices, id: \.self) { index in
                            playerChip(for: index)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func playerChip(for index: Int) -> some View {
        let isSelected = index == selectedPlayerIndex
        let playerScore = score(for: players[index])
        let isWinner = isWinningScore(playerScore)
        let winnerTextColor = Color(red: 0.28, green: 0.85, blue: 0.48)
        let selectedColors: [Color] = isWinner
        ? [Color(red: 0.28, green: 0.85, blue: 0.48), Color(red: 0.10, green: 0.55, blue: 0.30)]
        : [Color(red: 0.38, green: 0.67, blue: 1.0), Color(red: 0.21, green: 0.39, blue: 0.86)]
        let unselectedColors: [Color] = isWinner
        ? [Color(red: 0.20, green: 0.70, blue: 0.38).opacity(0.32), Color.white.opacity(0.02)]
        : [Color.white.opacity(0.08), Color.white.opacity(0.02)]

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedPlayerIndex = index
            }
        } label: {
            VStack(spacing: 4) {
                if let custom = customName(for: index), matchMode == .pairs2 {
                    Text(custom)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(
                            isWinner
                            ? winnerTextColor
                            : (isSelected ? .white : .white.opacity(0.75))
                        )
                } else {
                    Text(playerNameKey(for: index))
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(
                            isWinner
                            ? winnerTextColor
                            : (isSelected ? .white : .white.opacity(0.75))
                        )
                }

                Text("\(playerScore)")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(
                        isWinner
                        ? winnerTextColor
                        : (isSelected ? .white : .white.opacity(0.9))
                    )
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25, dampingFraction: 0.82), value: playerScore)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isSelected ? selectedColors : unselectedColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(isSelected ? 0.32 : 0.12), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(isSelected ? 0.45 : 0.2),
                        radius: isSelected ? 18 : 8,
                        x: 0,
                        y: isSelected ? 12 : 4
                    )
            )
        }
        .buttonStyle(.plain)
        .highPriorityGesture(
            TapGesture(count: 2)
                .onEnded {
                    if matchMode == .pairs2 {
                        startEditingName(for: index)
                    }
                }
        )
    }

    private var abacusCard: some View {
        Group {
            if matchMode == .pairs2,
               scoreDisplayMode == .sharedBoard,
               players.count >= 2 {
                sharedAbacusCardContent()
            } else if players.indices.contains(selectedPlayerIndex) {
                abacusCardContent(playerIndex: selectedPlayerIndex)
            } else {
                ProgressView()
                    .tint(.white.opacity(0.85))
                    .padding(.vertical, 28)
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func abacusCardContent(playerIndex: Int) -> some View {
        let bindingPlayer = Binding(
            get: { players[playerIndex] },
            set: { players[playerIndex] = $0 }
        )

        let rowHeight: CGFloat = 74
        let rowSpacing: CGFloat = 10
        let innerPaddingV: CGFloat = 22
        let innerPaddingH: CGFloat = 18
        let frameHeight: CGFloat =
            CGFloat(rodsPerPlayer) * rowHeight
            + CGFloat(max(0, rodsPerPlayer - 1)) * rowSpacing
            + innerPaddingV * 2

        return VStack(spacing: 14) {
            HStack {
                Text("points_title")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()

                Text("\(score(for: bindingPlayer.wrappedValue))")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }

            ZStack {
                AbacusFrameBackground(
                    rows: rodsPerPlayer,
                    rowHeight: rowHeight,
                    rowSpacing: rowSpacing,
                    innerPaddingV: innerPaddingV,
                    innerPaddingH: innerPaddingH
                )

                VStack(spacing: rowSpacing) {
                    ForEach(0..<rodsPerPlayer, id: \.self) { rodIndex in
                        let multiplier = gameMode.rowMultipliers[rodIndex]
                        AbacusRodView(
                            activeCount: $players[playerIndex].activePerRod[rodIndex],
                            label: "×\(multiplier)",
                            onFull: {
                                performCarry(playerIndex: playerIndex, fromRod: rodIndex)
                            }
                        )
                        .frame(height: rowHeight)
                    }
                }
                .padding(.vertical, innerPaddingV)
                .padding(.horizontal, innerPaddingH)
            }
            .frame(height: frameHeight)
        }
        .padding(16)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }

    private func sharedAbacusCardContent() -> some View {
        let rowsCount = 8
        let rowHeight: CGFloat = 60
        let rowSpacing: CGFloat = 8
        let innerPaddingV: CGFloat = 18
        let innerPaddingH: CGFloat = 18
        let frameHeight: CGFloat =
            CGFloat(rowsCount) * rowHeight
            + CGFloat(max(0, rowsCount - 1)) * rowSpacing
            + innerPaddingV * 2

        let team1Score = players.indices.contains(0) ? score(for: players[0]) : 0
        let team2Score = players.indices.contains(1) ? score(for: players[1]) : 0
        let team1IsWinner = isWinningScore(team1Score)
        let team2IsWinner = isWinningScore(team2Score)
        let winnerTextColor = Color(red: 0.28, green: 0.85, blue: 0.48)
        let multipliers = gameMode.rowMultipliers

        return VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let custom = customName(for: 0) {
                        Text(custom)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(team1IsWinner ? winnerTextColor : .white.opacity(0.8))
                    } else {
                        Text("team_1")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(team1IsWinner ? winnerTextColor : .white.opacity(0.8))
                    }

                    Text("\(team1Score)")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(team1IsWinner ? winnerTextColor : .white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: team1Score)
                }
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            startEditingName(for: 0)
                        }
                )

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    if let custom = customName(for: 1) {
                        Text(custom)
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(team2IsWinner ? winnerTextColor : .white.opacity(0.8))
                    } else {
                        Text("team_2")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(team2IsWinner ? winnerTextColor : .white.opacity(0.8))
                    }

                    Text("\(team2Score)")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(team2IsWinner ? winnerTextColor : .white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: team2Score)
                }
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            startEditingName(for: 1)
                        }
                )
            }

            ZStack {
                AbacusFrameBackground(
                    rows: rowsCount,
                    rowHeight: rowHeight,
                    rowSpacing: rowSpacing,
                    innerPaddingV: innerPaddingV,
                    innerPaddingH: innerPaddingH
                )

                VStack(spacing: rowSpacing) {
                    // Команда 1: ряды по текущему режиму (например, 5, 10, 100 или 1, 10, 100)
                    AbacusRodView(
                        activeCount: Binding(
                            get: { players[0].activePerRod[0] },
                            set: { players[0].activePerRod[0] = $0 }
                        ),
                        label: "×\(multipliers[0])",
                        onFull: {
                            performCarry(playerIndex: 0, fromRod: 0)
                        }
                    )
                    .frame(height: rowHeight)

                    AbacusRodView(
                        activeCount: Binding(
                            get: { players[0].activePerRod[1] },
                            set: { players[0].activePerRod[1] = $0 }
                        ),
                        label: "×\(multipliers[1])",
                        onFull: {
                            performCarry(playerIndex: 0, fromRod: 1)
                        }
                    )
                    .frame(height: rowHeight)

                    AbacusRodView(
                        activeCount: Binding(
                            get: { players[0].activePerRod[2] },
                            set: { players[0].activePerRod[2] = $0 }
                        ),
                        label: "×\(multipliers[2])",
                        onFull: {
                            // верхний разряд для команды не переносим
                        }
                    )
                    .frame(height: rowHeight)

                    // Победы команд
                    AbacusRodView(
                        activeCount: Binding(
                            get: { teamWins.indices.contains(0) ? teamWins[0] : 0 },
                            set: { value in
                                if teamWins.indices.contains(0) {
                                    teamWins[0] = value
                                }
                            }
                        ),
                        label: NSLocalizedString("row_label_win_team_1", comment: ""),
                        onFull: {}
                    )
                    .frame(height: rowHeight)

                    AbacusRodView(
                        activeCount: Binding(
                            get: { teamWins.indices.contains(1) ? teamWins[1] : 0 },
                            set: { value in
                                if teamWins.indices.contains(1) {
                                    teamWins[1] = value
                                }
                            }
                        ),
                        label: NSLocalizedString("row_label_win_team_2", comment: ""),
                        onFull: {}
                    )
                    .frame(height: rowHeight)

                    // Команда 2: ряды 100, 10, 5 (снизу вверх 5, 10, 100)
                    AbacusRodView(
                        activeCount: Binding(
                            get: { players[1].activePerRod[2] },
                            set: { players[1].activePerRod[2] = $0 }
                        ),
                        label: "×\(multipliers[2])",
                        onFull: {
                            // верхний разряд для команды не переносим
                        }
                    )
                    .frame(height: rowHeight)

                    AbacusRodView(
                        activeCount: Binding(
                            get: { players[1].activePerRod[1] },
                            set: { players[1].activePerRod[1] = $0 }
                        ),
                        label: "×\(multipliers[1])",
                        onFull: {
                            performCarry(playerIndex: 1, fromRod: 1)
                        }
                    )
                    .frame(height: rowHeight)

                    AbacusRodView(
                        activeCount: Binding(
                            get: { players[1].activePerRod[0] },
                            set: { players[1].activePerRod[0] = $0 }
                        ),
                        label: "×\(multipliers[0])",
                        onFull: {
                            performCarry(playerIndex: 1, fromRod: 0)
                        }
                    )
                    .frame(height: rowHeight)
                }
                .padding(.vertical, innerPaddingV)
                .padding(.horizontal, innerPaddingH)
            }
            .frame(height: frameHeight)
        }
        .padding(16)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func score(for player: AbacusPlayer) -> Int {
        let multipliers = gameMode.rowMultipliers
        return zip(player.activePerRod, multipliers)
            .map { count, mult in count * mult }
            .reduce(0, +)
    }

    private func isWinningScore(_ score: Int) -> Bool {
        switch gameMode {
        case .phone365:
            return score > 365
        case .oneOOne:
            return score >= 101
        }
    }

    private func determineWinner() -> Int? {
        guard !players.isEmpty else { return nil }
        
        let scores = players.map { score(for: $0) }
        let winningScores = scores.enumerated().filter { isWinningScore($0.element) }
        
        // Если ни одна команда не набрала победный счет
        guard !winningScores.isEmpty else { return nil }
        
        // Если только одна команда набрала победный счет
        if winningScores.count == 1 {
            return winningScores.first!.offset
        }
        
        // Если несколько команд набрали победный счет, победитель - кто набрал больше очков
        let maxScore = winningScores.map { $0.element }.max()!
        let winnersWithMaxScore = winningScores.filter { $0.element == maxScore }
        
        // Если есть несколько команд с одинаковым максимальным счетом, выбираем первую
        return winnersWithMaxScore.first!.offset
    }

    private func resetCurrentPlayer() {
        guard players.indices.contains(selectedPlayerIndex) else { return }

        players[selectedPlayerIndex].activePerRod = Array(repeating: 0, count: rodsPerPlayer)

        if matchMode == .pairs2,
           scoreDisplayMode == .sharedBoard,
           teamWins.indices.contains(selectedPlayerIndex) {
            teamWins[selectedPlayerIndex] = 0
        }
        Haptics.impact(.medium)
    }

    private func resetAllPlayers() {
        for index in players.indices {
            players[index].activePerRod = Array(repeating: 0, count: rodsPerPlayer)
        }
        if matchMode == .pairs2,
           scoreDisplayMode == .sharedBoard {
            for index in teamWins.indices {
                teamWins[index] = 0
            }
        }
        Haptics.impact(.heavy)
    }

    private func triggerResetAllByShake() {
        guard !players.isEmpty else { return }
        
        // Определяем победителя перед сбросом
        let winnerIndex = determineWinner()
        
        // Если есть победитель, обновляем счетчик побед
        if let winner = winnerIndex, 
           matchMode == .pairs2,
           scoreDisplayMode == .sharedBoard,
           teamWins.indices.contains(winner) {
            teamWins[winner] += 1
        }
        
        // Сохраняем текущую игру в историю с информацией о победителе
        saveCurrentGameToHistory(winner: winnerIndex)
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            resetAllPlayers()
        }
    }

    private func makeCurrentHistoryEntry(winner: Int? = nil) -> GameHistoryEntry? {
        guard let mode = matchMode, !players.isEmpty else { return nil }
        let scores = players.map { score(for: $0) }
        let names: [String]?
        if mode == .pairs2 {
            ensureCustomNamesCapacity()
            names = Array(customNames.prefix(players.count))
        } else {
            names = nil
        }
        return GameHistoryEntry(
            id: UUID(),
            date: Date(),
            matchMode: mode,
            gameMode: gameMode,
            scoreDisplayMode: scoreDisplayMode,
            scores: scores,
            names: names,
            winner: winner
        )
    }

    private func saveCurrentGameToHistory(winner: Int? = nil) {
        guard let entry = makeCurrentHistoryEntry(winner: winner) else { return }
        var all = historyEntries
        all.append(entry)
        if let data = try? JSONEncoder().encode(all) {
            gameHistoryData = data
        }
    }

    private func deleteHistoryEntry(_ entry: GameHistoryEntry) {
        let remaining = historyEntries.filter { $0.id != entry.id }
        if let data = try? JSONEncoder().encode(remaining) {
            gameHistoryData = data
        }
    }

    private func ensureCustomNamesCapacity() {
        guard players.count > customNames.count else { return }
        customNames.append(contentsOf: Array(repeating: "", count: players.count - customNames.count))
    }

    private func customName(for index: Int) -> String? {
        guard index < customNames.count else { return nil }
        let name = customNames[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private func startEditingName(for index: Int) {
        // index сейчас нам не важен — в листе редактируем обе команды сразу
        isEditingNamesPresented = true
    }

    private func playerNameKey(for index: Int) -> LocalizedStringKey {
        if matchMode == .pairs2 {
            switch index {
            case 0: return LocalizedStringKey("team_1")
            case 1: return LocalizedStringKey("team_2")
            default: return LocalizedStringKey("team_1")
            }
        } else {
            switch index {
            case 0: return LocalizedStringKey("player_1")
            case 1: return LocalizedStringKey("player_2")
            case 2: return LocalizedStringKey("player_3")
            case 3: return LocalizedStringKey("player_4")
            default: return LocalizedStringKey("player_1")
            }
        }
    }

    private func configurePlayersIfNeeded(for mode: MatchMode, resetScores: Bool) {
        let desired = mode.playersCount

        if players.count != desired || resetScores {
            players = Array(repeating: AbacusPlayer(activePerRod: Array(repeating: 0, count: rodsPerPlayer)), count: desired)
        }

        if teamWins.count != desired || resetScores {
            teamWins = Array(repeating: 0, count: desired)
        }

        if selectedPlayerIndex >= desired {
            selectedPlayerIndex = 0
        }
    }

    /// Перенос "полной" палочки на следующий разряд
    private func performCarry(playerIndex: Int, fromRod: Int) {
        guard fromRod < rodsPerPlayer - 1 else { return } // последний разряд не переносим

        let multipliers = gameMode.rowMultipliers
        let fromMultiplier = multipliers[fromRod]
        let toMultiplier = multipliers[fromRod + 1]

        // Сколько бусинок нужно добавить на следующий разряд,
        // чтобы сохранить то же количество очков
        let beadsToMove = (beadsPerRod * fromMultiplier) / toMultiplier
        guard beadsToMove > 0 else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            // Обнуляем текущий разряд
            players[playerIndex].activePerRod[fromRod] = 0
            addBeadsWithCarry(playerIndex: playerIndex, rodIndex: fromRod + 1, beadsToAdd: beadsToMove)
        }
    }

    private func addBeadsWithCarry(playerIndex: Int, rodIndex: Int, beadsToAdd: Int) {
        guard beadsToAdd > 0 else { return }
        guard rodIndex < rodsPerPlayer else { return }

        let multipliers = gameMode.rowMultipliers
        var value = players[playerIndex].activePerRod[rodIndex] + beadsToAdd

        // Последний разряд: просто ограничим вместимостью UI (10 бусинок)
        if rodIndex == rodsPerPlayer - 1 {
            players[playerIndex].activePerRod[rodIndex] = min(beadsPerRod, value)
            return
        }

        // Сколько полных десятков набралось на этом разряде
        let overflow = value / beadsPerRod
        value = value % beadsPerRod
        players[playerIndex].activePerRod[rodIndex] = value

        if overflow > 0 {
            let carryUnit = (beadsPerRod * multipliers[rodIndex]) / multipliers[rodIndex + 1]
            let carryBeads = overflow * carryUnit
            addBeadsWithCarry(playerIndex: playerIndex, rodIndex: rodIndex + 1, beadsToAdd: carryBeads)
        }
    }
}

// MARK: - Rename teams sheet

private struct RenameTeamView: View {
    @Binding var team1Name: String
    @Binding var team2Name: String
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.07, blue: 0.12),
                        Color(red: 0.12, green: 0.10, blue: 0.20),
                        Color(red: 0.06, green: 0.08, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 22) {
                    Spacer(minLength: 40)

                    VStack(spacing: 18) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.38, green: 0.67, blue: 1.0),
                                                Color(red: 0.21, green: 0.39, blue: 0.86)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 40, height: 40)
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("rename_team_title")
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("rename_team_subtitle")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }

                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("team_1")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))

                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                                        )

                                    TextField("rename_team_placeholder", text: $team1Name)
                                        .textInputAutocapitalization(.words)
                                        .disableAutocorrection(true)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("team_2")
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.8))

                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                                        )

                                    TextField("rename_team_placeholder", text: $team2Name)
                                        .textInputAutocapitalization(.words)
                                        .disableAutocorrection(true)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                }
                            }
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                            .blur(radius: 0.3)
                    )
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("rename_team_cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("rename_team_save") {
                        onSave()
                    }
                }
            }
        }
    }
}

/// Одна планка "счетов" с бусинками
/// Одна планка "счётов" с бусинками
struct AbacusRodView: View {
    @Binding var activeCount: Int      // сколько бусинок переведено
    let label: String                  // подпись ×1 / ×5 / ×10
    let onFull: () -> Void             // вызывается, когда палка полностью заполнена

    private static let beadsCount: Int = 10

    @State private var draggingIndex: Int? = nil
    @State private var dragTranslation: CGFloat = 0

    private let inactiveBeadColor = Color(red: 0.86, green: 0.78, blue: 0.64)
    private let activeBeadGradient = LinearGradient(
        colors: [
            Color(red: 0.96, green: 0.80, blue: 0.40),
            Color(red: 0.98, green: 0.64, blue: 0.33)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            let beadDiameter: CGFloat = min(28, max(20, height - 32))
            let beadRadius = beadDiameter / 2
            let padding: CGFloat = 18
            let spacing: CGFloat = beadDiameter * 0.72

            let leftCount = max(0, min(Self.beadsCount, activeCount))
            let rightCount = Self.beadsCount - leftCount

            let leftStart = padding + beadRadius
            let rightStart = width - padding - beadRadius - CGFloat(max(0, rightCount - 1)) * spacing

            ZStack {
                // Нить/прут
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .frame(height: 4)
                    .padding(.horizontal, padding)

                // Подпись множителя внутри ряда — чтобы не было пустоты слева
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.22))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            )
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
                    .offset(y: -height * 0.28)

                // Бусинки (все стартуют с правого края; "считанные" переезжают влево)
                bead(index: 0, width: width, height: height, beadDiameter: beadDiameter, leftStart: leftStart, rightStart: rightStart, spacing: spacing, leftCount: leftCount)
                bead(index: 1, width: width, height: height, beadDiameter: beadDiameter, leftStart: leftStart, rightStart: rightStart, spacing: spacing, leftCount: leftCount)
                bead(index: 2, width: width, height: height, beadDiameter: beadDiameter, leftStart: leftStart, rightStart: rightStart, spacing: spacing, leftCount: leftCount)
                bead(index: 3, width: width, height: height, beadDiameter: beadDiameter, leftStart: leftStart, rightStart: rightStart, spacing: spacing, leftCount: leftCount)
                bead(index: 4, width: width, height: height, beadDiameter: beadDiameter, leftStart: leftStart, rightStart: rightStart, spacing: spacing, leftCount: leftCount)
                bead(index: 5, width: width, height: height, beadDiameter: beadDiameter, leftStart: leftStart, rightStart: rightStart, spacing: spacing, leftCount: leftCount)
                bead(index: 6, width: width, height: height, beadDiameter: beadDiameter, leftStart: leftStart, rightStart: rightStart, spacing: spacing, leftCount: leftCount)
                bead(index: 7, width: width, height: height, beadDiameter: beadDiameter, leftStart: leftStart, rightStart: rightStart, spacing: spacing, leftCount: leftCount)
                bead(index: 8, width: width, height: height, beadDiameter: beadDiameter, leftStart: leftStart, rightStart: rightStart, spacing: spacing, leftCount: leftCount)
                bead(index: 9, width: width, height: height, beadDiameter: beadDiameter, leftStart: leftStart, rightStart: rightStart, spacing: spacing, leftCount: leftCount)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func bead(
        index: Int,
        width: CGFloat,
        height: CGFloat,
        beadDiameter: CGFloat,
        leftStart: CGFloat,
        rightStart: CGFloat,
        spacing: CGFloat,
        leftCount: Int
    ) -> some View {
        let isCounted = index < leftCount
        let localIndex = isCounted ? index : (index - leftCount)
        let baseX = (isCounted ? leftStart : rightStart) + CGFloat(localIndex) * spacing
        let x = baseX + ((draggingIndex == index) ? dragTranslation : 0)

        return beadBody(isCounted: isCounted, beadDiameter: beadDiameter)
            .position(x: x, y: height / 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        draggingIndex = index
                        dragTranslation = value.translation.width
                    }
                    .onEnded { value in
                        let finalX = baseX + value.translation.width
                        let movedToLeftSide = finalX < width / 2

                        let newValue: Int
                        if movedToLeftSide {
                            newValue = max(activeCount, index + 1)
                        } else {
                            newValue = min(activeCount, index)
                        }

                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            activeCount = newValue
                        }

                        if newValue == Self.beadsCount {
                            onFull()
                        }

                        draggingIndex = nil
                        dragTranslation = 0
                    }
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: activeCount)
    }

    @ViewBuilder
    private func beadBody(isCounted: Bool, beadDiameter: CGFloat) -> some View {
        let base = RoundedRectangle(cornerRadius: beadDiameter / 2.2, style: .continuous)

        if isCounted {
            base
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.86, blue: 0.55),
                            Color(red: 0.92, green: 0.70, blue: 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: beadDiameter * 1.15, height: beadDiameter * 0.9)
                .overlay(
                    base
                        .inset(by: 1)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.55), radius: 5, x: 0, y: 3)
                .overlay(
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: beadDiameter * 0.5, height: beadDiameter * 0.35)
                        .offset(x: -beadDiameter * 0.15, y: -beadDiameter * 0.15),
                    alignment: .topLeading
                )
                .scaleEffect(1.04)
        } else {
            base
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.86, green: 0.78, blue: 0.64),
                            Color(red: 0.74, green: 0.64, blue: 0.50)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: beadDiameter * 1.08, height: beadDiameter * 0.85)
                .overlay(
                    base
                        .inset(by: 1)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 2)
        }
    }

    // Тап-логика больше не используется: теперь управление через свайп/перетаскивание бусинки.
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "ru"
    @Binding var matchModeRaw: String
    @Binding var scoreDisplayModeRaw: String

    private struct Language: Identifiable {
        let id: String
        let titleKey: LocalizedStringKey
    }

    private let languages: [Language] = [
        Language(id: "ru", titleKey: LocalizedStringKey("language_ru")),
        Language(id: "en", titleKey: LocalizedStringKey("language_en")),
        Language(id: "az", titleKey: LocalizedStringKey("language_az"))
    ]

    private var currentMatchMode: MatchMode? {
        MatchMode(rawValue: matchModeRaw)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $matchModeRaw) {
                        Text("match_mode_pairs").tag(MatchMode.pairs2.rawValue)
                        Text("match_mode_freeforall").tag(MatchMode.freeForAll4.rawValue)
                    } label: {
                        Text("match_mode_title")
                    }
                    .pickerStyle(.segmented)
                }

                if currentMatchMode == .pairs2 {
                    Section {
                        Picker(selection: $scoreDisplayModeRaw) {
                            Text("score_display_per_team").tag(ScoreDisplayMode.perTeam.rawValue)
                            Text("score_display_shared").tag(ScoreDisplayMode.sharedBoard.rawValue)
                        } label: {
                            Text("score_display_mode_title")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section {
                    Picker(selection: $appLanguage) {
                        ForEach(languages) { lang in
                            Text(lang.titleKey).tag(lang.id)
                        }
                    } label: {
                        Text("language_title")
                    }
                }
            }
            .navigationTitle(Text("settings_title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("done")
                    }
                }
            }
        }
    }
}

struct ChooseMatchModeView: View {
    let onChoose: (MatchMode) -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.12),
                    Color(red: 0.12, green: 0.10, blue: 0.20),
                    Color(red: 0.06, green: 0.08, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("choose_mode_title")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("choose_mode_subtitle")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 8)

                Button {
                    onChoose(.pairs2)
                } label: {
                    Text("mode_pairs_button")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onChoose(.freeForAll4)
                } label: {
                    Text("mode_freeforall_button")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.blue.opacity(0.55))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 40)
            .padding(.bottom, 20)
            .frame(maxWidth: 520)
        }
    }
}

// MARK: - Abacus frame styling

private struct AbacusFrameBackground: View {
    let rows: Int
    let rowHeight: CGFloat
    let rowSpacing: CGFloat
    let innerPaddingV: CGFloat
    let innerPaddingH: CGFloat

    private var woodGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.86, blue: 0.68),
                Color(red: 0.78, green: 0.63, blue: 0.40)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var innerWoodGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.90, green: 0.80, blue: 0.64),
                Color(red: 0.70, green: 0.57, blue: 0.38)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let corner: CGFloat = 12

            ZStack {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(woodGradient)
                    .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 8)

                // Внутренняя панель
                RoundedRectangle(cornerRadius: max(8, corner - 2), style: .continuous)
                    .fill(innerWoodGradient.opacity(0.9))
                    .padding(9)

                // Боковые стойки (как у настоящих счет)
                ZStack {
                    // Верхняя и нижняя перекладины
                    VStack(spacing: 0) {
                        horizontalRail
                        Spacer(minLength: 0)
                        horizontalRail
                    }
                    .padding(6)

                    // Левые и правые стойки
                    HStack(spacing: 0) {
                        sideRail
                        Spacer(minLength: 0)
                        sideRail
                    }
                    .padding(6)
                }

                // Отверстия/прорези между рядами
                ForEach(1..<max(1, rows), id: \.self) { i in
                    let y = innerPaddingV
                        + CGFloat(i) * rowHeight
                        + (CGFloat(i) - 0.5) * rowSpacing

                    // Тёмная канавка по центру (имитация "прута/отверстий")
                    Capsule()
                        .fill(Color.black.opacity(0.20))
                        .frame(width: size.width - 36, height: 10)
                        .position(x: size.width / 2, y: y)

                    // "Отверстия" возле боковых стоек
                    hole
                        .position(x: 22, y: y)
                    hole
                        .position(x: size.width - 22, y: y)
                }

                RoundedRectangle(cornerRadius: corner - 2, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.22), lineWidth: 1.3)
            }
        }
    }

    private var sideRail: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.67, green: 0.50, blue: 0.30),
                        Color(red: 0.48, green: 0.34, blue: 0.19)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 24)
            .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private var horizontalRail: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.67, green: 0.50, blue: 0.30),
                        Color(red: 0.48, green: 0.34, blue: 0.19)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 24)
            .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private var hole: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.28))
                .frame(width: 10, height: 10)
            Circle()
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: 10, height: 10)
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 3.5, height: 3.5)
                .offset(x: -1.5, y: -1.5)
        }
        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Shake detector (UIKit bridge)

private struct ShakeDetectorView: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectorViewController {
        let vc = ShakeDetectorViewController()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeDetectorViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

private final class ShakeDetectorViewController: UIViewController {
    var onShake: (() -> Void)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override var canBecomeFirstResponder: Bool { true }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        onShake?()
    }
}

// MARK: - Haptics

private enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }
}

// MARK: - Onboarding

private struct OnboardingPage: Identifiable {
    let id: Int
    let titleKey: LocalizedStringKey
    let subtitleKey: LocalizedStringKey
    let systemImageName: String
}

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var currentIndex: Int = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            titleKey: LocalizedStringKey("onboarding_page1_title"),
            subtitleKey: LocalizedStringKey("onboarding_page1_subtitle"),
            systemImageName: "circle.grid.3x3.fill"
        ),
        OnboardingPage(
            id: 1,
            titleKey: LocalizedStringKey("onboarding_page2_title"),
            subtitleKey: LocalizedStringKey("onboarding_page2_subtitle"),
            systemImageName: "square.split.2x2.fill"
        ),
        OnboardingPage(
            id: 2,
            titleKey: LocalizedStringKey("onboarding_page3_title"),
            subtitleKey: LocalizedStringKey("onboarding_page3_subtitle"),
            systemImageName: "hand.draw.fill"
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.07, blue: 0.12),
                    Color(red: 0.12, green: 0.10, blue: 0.20),
                    Color(red: 0.06, green: 0.08, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        onFinish()
                    } label: {
                        Text("onboarding_button_skip")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                TabView(selection: $currentIndex) {
                    ForEach(pages) { page in
                        VStack(spacing: 18) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.93, green: 0.84, blue: 0.64),
                                                Color(red: 0.78, green: 0.63, blue: 0.40)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 140, height: 140)
                                    .shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 10)

                                Image(systemName: page.systemImageName)
                                    .font(.system(size: 56, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.12, green: 0.07, blue: 0.03))
                            }
                            .padding(.bottom, 8)

                            Text(page.titleKey)
                                .font(.system(.title2, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            Text(page.subtitleKey)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 28)
                        }
                        .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Spacer(minLength: 0)

                Button {
                    if currentIndex < pages.count - 1 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            currentIndex += 1
                        }
                    } else {
                        onFinish()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(currentIndex == pages.count - 1 ? "onboarding_button_start" : "onboarding_button_next")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                        Image(systemName: currentIndex == pages.count - 1 ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.blue.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 10)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .preferredColorScheme(.dark)
}
