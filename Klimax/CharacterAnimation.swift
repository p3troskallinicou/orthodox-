//
//  CharacterAnimation.swift
//  Klimax
//

import SwiftUI
import UIKit

@MainActor
final class CharacterAnimationController: ObservableObject {
    @Published private(set) var currentState: CharacterAnimationState = .idle
    @Published private(set) var isPlayingActionAnimation = false
    @Published private(set) var isPaused = false

    private var resetTask: Task<Void, Never>?

    func play(_ state: CharacterAnimationState, duration: Double? = nil) {
        guard !isPaused else { return }
        guard canInterrupt(with: state) else { return }

        resetTask?.cancel()
        currentState = state
        isPlayingActionAnimation = !Self.loopingStates.contains(state)

        if isPlayingActionAnimation {
            let delay = duration ?? Self.defaultDuration(for: state)
            resetTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                await self?.returnToIdle()
            }
        }
    }

    func playIfAvailable(_ state: CharacterAnimationState, hasFrames: Bool) {
        if hasFrames || state != .idle {
            play(state)
        }
    }

    func returnToIdle() {
        resetTask?.cancel()
        resetTask = nil
        currentState = .idle
        isPlayingActionAnimation = false
    }

    func pause() {
        isPaused = true
        resetTask?.cancel()
    }

    func resume() {
        isPaused = false
        if currentState != .idle && isPlayingActionAnimation {
            returnToIdle()
        }
    }

    private func canInterrupt(with next: CharacterAnimationState) -> Bool {
        Self.priority(next) >= Self.priority(currentState) || !isPlayingActionAnimation
    }

    private static let loopingStates: Set<CharacterAnimationState> = [.idle, .breathing, .walking, .running, .locked]

    private static func priority(_ state: CharacterAnimationState) -> Int {
        switch state {
        case .evolving:
            return 80
        case .unlocked:
            return 70
        case .skinPurchased:
            return 60
        case .victory:
            return 55
        case .tapped:
            return 45
        case .selected:
            return 40
        case .walking, .running:
            return 30
        case .locked:
            return 20
        case .idle, .breathing:
            return 10
        }
    }

    private static func defaultDuration(for state: CharacterAnimationState) -> Double {
        switch state {
        case .evolving:
            return 1.5
        case .unlocked, .skinPurchased, .victory:
            return 1.0
        case .selected, .tapped:
            return 0.55
        default:
            return 0.7
        }
    }
}

struct AnimatedCharacterView: View {
    let character: GameCharacter
    let evolutionLevel: Int
    let equippedSkinID: String
    let animationState: CharacterAnimationState
    let size: CGSize
    var isLocked: Bool = false
    var allowsTapReaction: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var controller = CharacterAnimationController()
    @State private var breathing = false
    @State private var sparkle = false
    @State private var appeared = false

    private var progress: PlayerCharacterProgress {
        PlayerCharacterProgress(
            characterID: character.id,
            isUnlocked: !isLocked,
            currentEvolutionLevel: evolutionLevel,
            characterXP: 0,
            ownedSkinIDs: [equippedSkinID],
            equippedSkinID: equippedSkinID
        )
    }

    private var artwork: CharacterResolvedArtwork {
        CharacterArtworkResolver.resolve(character: character, progress: progress)
    }

    var body: some View {
        ZStack {
            shadow
            characterBody
            effectLayer
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(staticScale)
        .rotationEffect(.degrees(staticRotation))
        .offset(y: staticYOffset)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.94)
        .saturation(isLocked ? 0.05 : 1)
        .contrast(isLocked ? 0.72 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            appeared = true
            controller.resume()
            startAmbientAnimation()
        }
        .onDisappear {
            controller.pause()
        }
        .onChange(of: animationState) { _, newState in
            controller.play(newState)
            triggerEffect(for: newState)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.resume() } else { controller.pause() }
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                guard allowsTapReaction, !isLocked else { return }
                controller.play(.tapped)
                triggerEffect(for: .tapped)
                CharacterFeedback.selection()
            }
        )
    }

    @ViewBuilder
    private var characterBody: some View {
        if artwork.configuration.supportsLayeredAnimation && CharacterAssetLoader.hasLayeredAssets(for: character.id) {
            LayeredCharacterView(
                characterID: character.id,
                state: controller.currentState,
                reduceMotion: reduceMotion
            )
        } else {
            CharacterFrameAnimationView(
                artwork: artwork,
                state: controller.currentState,
                reduceMotion: reduceMotion,
                size: size
            )
        }
    }

    private var effectLayer: some View {
        ZStack {
            if sparkle && !reduceMotion {
                ForEach(0..<10, id: \.self) { index in
                    Image(systemName: "sparkle")
                        .font(.system(size: index.isMultiple(of: 2) ? 11 : 8, weight: .semibold))
                        .foregroundStyle(Gild.gold.opacity(0.82))
                        .offset(x: sparkleOffset(index).x, y: sparkleOffset(index).y)
                        .opacity(sparkle ? 0 : 1)
                        .scaleEffect(sparkle ? 1.6 : 0.4)
                        .animation(.easeOut(duration: 0.85).delay(Double(index) * 0.025), value: sparkle)
                }
            }
        }
    }

    private var shadow: some View {
        Ellipse()
            .fill(Color.black.opacity(isLocked ? 0.10 : 0.16))
            .frame(width: size.width * (breathing ? 0.54 : 0.49), height: max(8, size.height * 0.055))
            .blur(radius: 6)
            .offset(y: size.height * 0.41)
            .opacity(reduceMotion ? 0.10 : 1)
    }

    private var staticScale: CGFloat {
        guard !reduceMotion else { return 1 }
        switch controller.currentState {
        case .tapped:
            return 1.07
        case .selected, .victory:
            return 1.05
        case .unlocked, .skinPurchased:
            return sparkle ? 1.06 : 1
        case .evolving:
            return sparkle ? 1.09 : 1
        case .locked:
            return 0.98
        default:
            return breathing ? 1.018 : 0.992
        }
    }

    private var staticRotation: Double {
        guard !reduceMotion else { return 0 }
        switch controller.currentState {
        case .walking:
            return breathing ? 1.5 : -1.5
        case .running:
            return breathing ? 2.2 : -2.2
        case .tapped:
            return -2
        default:
            return breathing ? 0.7 : -0.7
        }
    }

    private var staticYOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        switch controller.currentState {
        case .walking:
            return breathing ? -5 : 2
        case .running:
            return breathing ? -8 : 3
        case .locked:
            return 3
        default:
            return breathing ? -4 : 2
        }
    }

    private var accessibilityLabel: String {
        if isLocked {
            return "\(character.name), locked"
        }
        return "\(character.name), evolution level \(evolutionLevel)"
    }

    private func startAmbientAnimation() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.7).repeatForever(autoreverses: true)) {
            breathing = true
        }
    }

    private func triggerEffect(for state: CharacterAnimationState) {
        guard [.unlocked, .evolving, .skinPurchased, .victory, .selected, .tapped].contains(state) else { return }
        sparkle = false
        withAnimation(.easeOut(duration: reduceMotion ? 0.18 : 0.85)) {
            sparkle = true
        }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            sparkle = false
        }
    }

    private func sparkleOffset(_ index: Int) -> CGPoint {
        let angles = [0, 37, 71, 112, 151, 202, 244, 281, 318, 344].map(Double.init)
        let angle = angles[index % angles.count] * .pi / 180
        let radius = min(size.width, size.height) * (0.26 + CGFloat(index % 4) * 0.045)
        return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius - size.height * 0.05)
    }
}

private struct CharacterFrameAnimationView: View {
    let artwork: CharacterResolvedArtwork
    let state: CharacterAnimationState
    let reduceMotion: Bool
    let size: CGSize

    @State private var frameIndex = 0

    private var frames: [UIImage] {
        CharacterAssetLoader.frames(for: artwork.configuration, state: state)
    }

    var body: some View {
        Group {
            if !reduceMotion, let image = frames[safe: frameIndex] {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let image = CharacterAssetLoader.image(named: artwork.assetName) ??
                        CharacterAssetLoader.image(named: artwork.configuration.staticFallbackAssetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                CharacterMissingAssetPlaceholder()
            }
        }
        .frame(width: size.width, height: size.height)
        .id("\(artwork.assetName)-\(state.rawValue)")
        .task(id: "\(artwork.assetName)-\(state.rawValue)-\(frames.count)-\(reduceMotion)") {
            await playFrames()
        }
    }

    private func playFrames() async {
        frameIndex = 0
        guard !reduceMotion, frames.count > 1 else { return }

        let duration = artwork.configuration.frameDuration(for: state)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(duration))
            if Task.isCancelled { break }
            frameIndex = (frameIndex + 1) % frames.count
        }
    }
}

private struct LayeredCharacterView: View {
    let characterID: String
    let state: CharacterAnimationState
    let reduceMotion: Bool

    @State private var swing = false
    @State private var blink = false

    var body: some View {
        ZStack {
            layer("body")
            layer("left_leg").rotationEffect(.degrees(swing ? -3 : 3), anchor: .top)
            layer("right_leg").rotationEffect(.degrees(swing ? 3 : -3), anchor: .top)
            layer("left_arm").rotationEffect(.degrees(armAngle), anchor: .topTrailing)
            layer("right_arm").rotationEffect(.degrees(-armAngle), anchor: .topLeading)
            layer("head").offset(y: swing ? -2 : 1)
            layer(blink ? "eyes_closed" : "eyes_open")
            layer("mouth")
            layer("hair")
            layer("accessory")
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                swing = true
            }
            Task { await blinkLoop() }
        }
    }

    @ViewBuilder
    private func layer(_ part: String) -> some View {
        if let image = CharacterAssetLoader.image(named: "character_\(characterID)_\(part)") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }

    private var armAngle: Double {
        switch state {
        case .victory, .unlocked, .skinPurchased:
            return swing ? -8 : -18
        case .walking, .running:
            return swing ? 8 : -8
        case .tapped, .selected:
            return -10
        default:
            return swing ? 2 : -2
        }
    }

    private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3.8))
            blink = true
            try? await Task.sleep(for: .milliseconds(140))
            blink = false
        }
    }
}

private struct CharacterMissingAssetPlaceholder: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Gild.gold.opacity(0.16))
            Circle()
                .strokeBorder(Gild.gold.opacity(0.65), lineWidth: 2)
            Image(systemName: "figure.walk.diamond.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Gild.gold)
        }
        .padding(16)
    }
}

enum CharacterAssetLoader {
    static func image(named name: String) -> UIImage? {
        guard !name.isEmpty else { return nil }
        return UIImage(named: name)
    }

    static func hasImage(named name: String) -> Bool {
        image(named: name) != nil
    }

    static func frames(for configuration: CharacterAnimationConfiguration, state: CharacterAnimationState) -> [UIImage] {
        configuration.frames(for: state).compactMap { image(named: $0) }
    }

    static func hasLayeredAssets(for characterID: String) -> Bool {
        ["body", "head"].allSatisfy { hasImage(named: "character_\(characterID)_\($0)") }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
