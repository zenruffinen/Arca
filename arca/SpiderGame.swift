//
//  SpiderGame.swift
//  Arca
//
//  Entwickler: Hans zen Ruffinen
//

import SwiftUI
import SpriteKit
import Combine

// MARK: - Notification bridge (SpriteKit → SwiftUI)

extension Notification.Name {
    static let spiderGameOver = Notification.Name("spiderGameOver")
}

// MARK: - Game Scene

final class SpiderGameScene: SKScene, SKPhysicsContactDelegate {

    private let kangarooCategory: UInt32 = 0x1 << 0
    private let spiderCategory:   UInt32 = 0x1 << 1
    private let wallCategory:     UInt32 = 0x1 << 2

    // Layout
    private let wallW:  CGFloat = 30
    private let floorH: CGFloat = 140   // tall enough to clear button overlay
    private var beamY:  CGFloat { size.height - 90 }

    private var kangaroo:      SKNode!
    private var kangarooLabel: SKLabelNode!
    private var scoreLabel:    SKLabelNode!

    private var isOnGround  = true
    private var movingLeft  = false
    private var movingRight = false
    private var dead        = false
    private var isHopping   = false
    private var score       = 0
    private var lastWallSide: Int = -1   // -1 = left, +1 = right

    // Parallel arrays: one thread shape per spider
    private var spiders:      [SKLabelNode]  = []
    private var spiderThreads:[SKShapeNode]  = []

    // MARK: Setup

    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -12)
        physicsWorld.contactDelegate = self
        backgroundColor = SKColor(red: 0.08, green: 0.06, blue: 0.14, alpha: 1)

        addRoom()
        addKangaroo()
        addScoreLabel()
        startSpiders()
    }

    private func addRoom() {
        // ── Floor ──────────────────────────────────────────────
        let floor = SKSpriteNode(
            color: SKColor(red: 0.20, green: 0.13, blue: 0.07, alpha: 1),
            size: CGSize(width: size.width, height: floorH)
        )
        floor.position = CGPoint(x: size.width / 2, y: floorH / 2)
        floor.physicsBody = SKPhysicsBody(rectangleOf: floor.size)
        floor.physicsBody?.isDynamic = false
        floor.physicsBody?.categoryBitMask = wallCategory
        floor.physicsBody?.friction = 0.6
        addChild(floor)

        let grass = SKLabelNode(text: String(repeating: "🌿", count: 12))
        grass.fontSize = 16
        grass.position = CGPoint(x: size.width / 2, y: floorH + 2)
        addChild(grass)

        // ── Left wall ─────────────────────────────────────────
        for (xAnchor, xPos) in [(0.5, wallW / 2), (0.5, size.width - wallW / 2)] {
            let wall = SKSpriteNode(
                color: SKColor(red: 0.16, green: 0.12, blue: 0.24, alpha: 1),
                size: CGSize(width: wallW, height: size.height)
            )
            wall.anchorPoint = CGPoint(x: xAnchor, y: 0.5)
            wall.position    = CGPoint(x: xPos, y: size.height / 2)
            wall.physicsBody = SKPhysicsBody(rectangleOf: wall.size)
            wall.physicsBody?.isDynamic = false
            wall.physicsBody?.categoryBitMask = wallCategory
            wall.physicsBody?.friction        = 0
            wall.physicsBody?.restitution     = 0
            addChild(wall)
        }

        // ── Ceiling (invisible) ───────────────────────────────
        let ceilNode = SKNode()
        ceilNode.position   = CGPoint(x: size.width / 2, y: size.height + 5)
        ceilNode.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width, height: 10))
        ceilNode.physicsBody?.isDynamic = false
        ceilNode.physicsBody?.categoryBitMask = wallCategory
        addChild(ceilNode)

        // ── Wooden beam ───────────────────────────────────────
        let beam = SKSpriteNode(
            color: SKColor(red: 0.40, green: 0.27, blue: 0.13, alpha: 1),
            size: CGSize(width: size.width - wallW * 2, height: 16)
        )
        beam.position = CGPoint(x: size.width / 2, y: beamY)
        addChild(beam)

        // Beam grain decoration
        for i in stride(from: wallW + 20, to: size.width - wallW - 20, by: 30) {
            let grain = SKSpriteNode(
                color: SKColor(red: 0.30, green: 0.20, blue: 0.09, alpha: 0.6),
                size: CGSize(width: 2, height: 10)
            )
            grain.position = CGPoint(x: i, y: beamY)
            addChild(grain)
        }

        // Some ambient dots on the walls
        for _ in 0..<20 {
            let dot = SKLabelNode(text: "·")
            dot.fontSize    = CGFloat.random(in: 8...16)
            dot.fontColor   = .white.withAlphaComponent(CGFloat.random(in: 0.05...0.25))
            dot.position    = CGPoint(
                x: CGFloat.random(in: (wallW + 5)...(size.width - wallW - 5)),
                y: CGFloat.random(in: (floorH + 10)...(beamY - 20))
            )
            addChild(dot)
        }
    }

    private func addKangaroo() {
        kangaroo = SKNode()
        kangaroo.position = CGPoint(x: wallW + 36, y: floorH + 28)

        kangarooLabel = SKLabelNode(text: "🦘")
        kangarooLabel.fontSize = 36
        kangarooLabel.verticalAlignmentMode   = .center
        kangarooLabel.horizontalAlignmentMode = .center
        kangaroo.addChild(kangarooLabel)

        let body = SKPhysicsBody(circleOfRadius: 17)
        body.categoryBitMask    = kangarooCategory
        body.contactTestBitMask = spiderCategory
        body.collisionBitMask   = wallCategory
        body.allowsRotation = false
        body.restitution    = 0
        body.friction       = 0.8
        kangaroo.physicsBody = body
        addChild(kangaroo)
    }

    private func addScoreLabel() {
        let title = SKLabelNode(text: "SPIDER")
        title.fontName  = "AvenirNext-Bold"
        title.fontSize  = 12
        title.fontColor = .white.withAlphaComponent(0.45)
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: size.width / 2, y: beamY + 44)
        addChild(title)

        scoreLabel = SKLabelNode(text: "0")
        scoreLabel.fontName  = "AvenirNext-Bold"
        scoreLabel.fontSize  = 32
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: size.width / 2, y: beamY + 14)
        addChild(scoreLabel)
    }

    // MARK: Spider Spawning

    private func startSpiders() {
        // Start with 2 spiders after short grace, then add one every ~8 s
        let grace  = SKAction.wait(forDuration: 1.5)
        let addTwo = SKAction.run { [weak self] in
            self?.addHangingSpider()
            self?.addHangingSpider()
        }
        let addOne  = SKAction.run  { [weak self] in self?.addHangingSpider() }
        let waitMore = SKAction.wait(forDuration: 8.0, withRange: 3.0)
        run(
            SKAction.sequence([
                grace, addTwo,
                SKAction.repeatForever(SKAction.sequence([waitMore, addOne]))
            ]),
            withKey: "spawner"
        )
    }

    private func addHangingSpider() {
        guard !dead else { return }

        let xMin = wallW + 24
        let xMax = size.width - wallW - 24
        let xPos = CGFloat.random(in: xMin...xMax)

        // Thread (drawn/updated each frame in update)
        let thread = SKShapeNode()
        thread.strokeColor = SKColor.white.withAlphaComponent(0.45)
        thread.lineWidth   = 1.5
        addChild(thread)
        spiderThreads.append(thread)

        // Spider emoji
        let spider = SKLabelNode(text: "🕷️")
        spider.fontSize = 26
        spider.verticalAlignmentMode   = .center
        spider.horizontalAlignmentMode = .center
        spider.name     = "spider"
        spider.position = CGPoint(x: xPos, y: beamY - 8)

        let pb = SKPhysicsBody(circleOfRadius: 13)
        pb.categoryBitMask    = spiderCategory
        pb.contactTestBitMask = kangarooCategory
        pb.collisionBitMask   = 0
        pb.isDynamic = false
        spider.physicsBody = pb
        addChild(spider)
        spiders.append(spider)

        // Drop animation: lower → hang → retract → pause → repeat
        // maxDrop reaches exactly down to kangaroo level (floorH + 45)
        let spiderStartY = beamY - 8
        let kangarooReachY = floorH + 45
        let maxDrop  = spiderStartY - kangarooReachY
        let minDrop  = (beamY - floorH) * 0.30
        let dropDist = CGFloat.random(in: minDrop...maxDrop)
        let dropT      = Double.random(in: 1.8...3.2)
        let hangT      = Double.random(in: 1.5...4.5)
        let retractT   = Double.random(in: 1.0...2.2)
        let pauseT     = Double.random(in: 0.4...1.8)

        spider.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: -dropDist, duration: dropT),
            SKAction.wait(forDuration: hangT),
            SKAction.moveBy(x: 0, y:  dropDist, duration: retractT),
            SKAction.wait(forDuration: pauseT)
        ])))

        // Small side-wobble for liveliness
        spider.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x:  2, y: 0, duration: 0.22),
            SKAction.moveBy(x: -2, y: 0, duration: 0.22)
        ])))
    }

    // MARK: Controls

    func setLeft(_ on: Bool)  { movingLeft  = on }
    func setRight(_ on: Bool) { movingRight = on }

    func jump() {
        guard isOnGround, !dead, kangaroo != nil, kangarooLabel != nil else { return }
        isOnGround = false
        kangaroo.physicsBody?.applyImpulse(CGVector(dx: 0, dy: 280))
        kangarooLabel.run(SKAction.sequence([
            SKAction.scale(to: 1.25, duration: 0.08),
            SKAction.scale(to: 1.0,  duration: 0.08)
        ]))
    }

    // MARK: Update

    override func update(_ currentTime: TimeInterval) {
        guard !dead else { return }

        // Movement
        let moveSpeed: CGFloat = 185
        if movingLeft {
            kangaroo.physicsBody?.velocity.dx = -moveSpeed
            kangarooLabel.xScale = 1    // emoji faces right = läuft vorwärts nach links
        } else if movingRight {
            kangaroo.physicsBody?.velocity.dx =  moveSpeed
            kangarooLabel.xScale = -1   // gespiegelt = läuft vorwärts nach rechts
        } else {
            kangaroo.physicsBody?.velocity.dx *= 0.7
        }

        // Ground detection
        if let vy = kangaroo.physicsBody?.velocity.dy, abs(vy) < 2 {
            isOnGround = true
        }

        // Hop animation while moving on ground
        let shouldHop = (movingLeft || movingRight) && isOnGround
        if shouldHop && !isHopping {
            isHopping = true
            let hop = SKAction.repeatForever(SKAction.sequence([
                SKAction.group([
                    SKAction.moveBy(x: 0, y: 10, duration: 0.12),
                    SKAction.scaleY(to: 1.2, duration: 0.12)
                ]),
                SKAction.group([
                    SKAction.moveBy(x: 0, y: -10, duration: 0.10),
                    SKAction.scaleY(to: 0.85, duration: 0.06)
                ]),
                SKAction.scaleY(to: 1.0, duration: 0.06)
            ]))
            kangarooLabel.run(hop, withKey: "hop")
        } else if !shouldHop && isHopping {
            isHopping = false
            kangarooLabel.removeAction(forKey: "hop")
            kangarooLabel.run(SKAction.group([
                SKAction.moveTo(y: 0, duration: 0.06),
                SKAction.scaleY(to: 1.0, duration: 0.06)
            ]))
        }

        // ── Kollision: Spinne trifft Känguru ─────────────────
        let kPos = kangaroo.position
        for spider in spiders {
            let dx = spider.position.x - kPos.x
            let dy = spider.position.y - kPos.y
            if (dx * dx + dy * dy) < (42 * 42) {
                triggerDeath()
                return
            }
        }

        // ── Scoring: Wand-zu-Wand ─────────────────────────────
        let leftBound  = wallW + 26.0
        let rightBound = size.width - wallW - 26.0

        if kangaroo.position.x <= leftBound, lastWallSide != -1 {
            lastWallSide = -1
            incrementScore()
        } else if kangaroo.position.x >= rightBound, lastWallSide != 1 {
            lastWallSide = 1
            incrementScore()
        }

        // ── Update spider threads ─────────────────────────────
        let beamBottom = beamY - 8.0
        for (spider, thread) in zip(spiders, spiderThreads) {
            guard spider.parent != nil else { continue }
            let path = CGMutablePath()
            path.move(to: CGPoint(x: spider.position.x, y: beamBottom))
            path.addLine(to: spider.position)
            thread.path = path
        }
    }

    private func incrementScore() {
        score += 1
        scoreLabel.text = "\(score)"
        scoreLabel.run(SKAction.sequence([
            SKAction.scale(to: 1.45, duration: 0.07),
            SKAction.scale(to: 1.0,  duration: 0.12)
        ]))
    }

    // MARK: Collision

    func didBegin(_ contact: SKPhysicsContact) {
        let isSpider = contact.bodyA.node?.name == "spider"
                    || contact.bodyB.node?.name == "spider"
        guard isSpider, !dead else { return }
        triggerDeath()
    }

    private func triggerDeath() {
        dead = true
        removeAction(forKey: "spawner")

        kangarooLabel.text = "💀"

        kangaroo.run(SKAction.repeat(SKAction.sequence([
            SKAction.moveBy(x: -6, y: 0, duration: 0.04),
            SKAction.moveBy(x:  6, y: 0, duration: 0.04)
        ]), count: 5))

        let flash = SKSpriteNode(color: .red.withAlphaComponent(0.3), size: size)
        flash.position  = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.zPosition = 10
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0, duration: 0.4),
            SKAction.removeFromParent()
        ]))

        let finalScore = score
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            NotificationCenter.default.post(name: .spiderGameOver, object: finalScore)
        }
    }
}

// MARK: - SwiftUI Wrapper

struct SpiderGameView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("spiderHighScore") private var highScore = 0

    @State private var scene:     SpiderGameScene? = nil
    @State private var gameOver   = false
    @State private var lastScore  = 0
    @State private var newRecord  = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                        .id(ObjectIdentifier(scene))
                }

                if !gameOver { controls }

                if gameOver {
                    gameOverOverlay
                        .transition(.scale.combined(with: .opacity))
                }

                // Schließen-Button
                VStack {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(color: .black.opacity(0.5), radius: 4)
                                .padding(.top, 56)
                                .padding(.trailing, 16)
                        }
                    }
                    Spacer()
                }
            }
            .onAppear { makeScene(size: geo.size) }
            .onReceive(
                NotificationCenter.default.publisher(for: .spiderGameOver)
            ) { notif in
                guard !gameOver, let score = notif.object as? Int else { return }
                lastScore = score
                newRecord = score > highScore
                if newRecord { highScore = score }
                withAnimation(.spring(response: 0.4)) { gameOver = true }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Controls

    private var controls: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                GameButton(icon: "arrow.left")          { scene?.setLeft($0) }
                Spacer()
                GameButton(icon: "arrow.up.circle.fill") { if $0 { scene?.jump() } }
                Spacer()
                GameButton(icon: "arrow.right")         { scene?.setRight($0) }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 44)
        }
    }

    // MARK: Game Over

    private var gameOverOverlay: some View {
        VStack(spacing: 18) {
            Text("💀")
                .font(.system(size: 64))
            Text("Game Over")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 6) {
                Text("\(lastScore) Punkte")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.yellow)

                if newRecord {
                    Text("🏆 Neuer Rekord!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.yellow)
                } else {
                    Text("Rekord: \(highScore) Pkt.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Button {
                withAnimation(.spring(response: 0.3)) {
                    gameOver  = false
                    newRecord = false
                }
                let size = scene?.size ?? .zero
                if size != .zero { makeScene(size: size) }
            } label: {
                Text("Nochmal 🦘")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(Color.green, in: Capsule())
            }
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding(32)
    }

    // MARK: Helpers

    private func makeScene(size: CGSize) {
        let s = SpiderGameScene(size: size)
        s.scaleMode = .aspectFill
        scene = s
    }
}

// MARK: - Joystick Button (press & hold)

private struct GameButton: View {
    let icon: String
    let onPress: (Bool) -> Void

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 74, height: 74)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress(true) }
                    .onEnded   { _ in onPress(false) }
            )
    }
}
