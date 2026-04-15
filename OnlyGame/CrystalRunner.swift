import SwiftUI
import Combine
import SceneKit

final class CrystalRunnerController: NSObject, ObservableObject, SCNPhysicsContactDelegate {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private let playerNode = SCNNode()
    private let lanePositions: [CGFloat] = [-2.2, 0.0, 2.2]
    private var currentLaneIndex = 1
    private var spawnTimer: Timer?
    private var gameLoopTimer: Timer?
    private let obstacleSpeed: Float = 24
    private let crystalSpeed: Float = 26
    private let jumpDuration: TimeInterval = 0.44
    private let jumpHeight: CGFloat = 1.6
    private var isJumping = false
    private let playerBaseY: CGFloat = -0.25
    @Published var isGameOver = false

    private enum PhysicsCategory {
        static let player = 1 << 0
        static let obstacle = 1 << 1
        static let crystal = 1 << 2
    }

    @Published var score: Int = 0
    @Published var statusText: String = "Mine Runner"

    override init() {
        super.init()
        setupScene()
        startSpawning()
        startGameLoop()
    }

    deinit {
        spawnTimer?.invalidate()
        gameLoopTimer?.invalidate()
    }

    private func setupScene() {
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        scene.background.contents = NSColor(calibratedRed: 0.05, green: 0.03, blue: 0.12, alpha: 1.0)
        scene.fogStartDistance = 18
        scene.fogEndDistance = 72
        scene.fogColor = NSColor(calibratedRed: 0.07, green: 0.05, blue: 0.07, alpha: 1.0)
        scene.physicsWorld.gravity = SCNVector3Zero
        scene.physicsWorld.contactDelegate = self

        let camera = SCNCamera()
        camera.fieldOfView = 70
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 6, 14)
        cameraNode.eulerAngles = SCNVector3(-0.45, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = NSColor(white: 0.45, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        let omni = SCNNode()
        omni.light = SCNLight()
        omni.light?.type = .omni
        omni.light?.color = NSColor.white
        omni.position = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(omni)

        let floor = SCNFloor()
        floor.reflectivity = 0
        floor.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.10, alpha: 1.0)
        floor.firstMaterial?.specular.contents = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -1.1, 0)
        floorNode.physicsBody = SCNPhysicsBody.static()
        scene.rootNode.addChildNode(floorNode)

        let tunnelBack = SCNTube(innerRadius: 3.5, outerRadius: 6.4, height: 1.2)
        tunnelBack.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.12, green: 0.08, blue: 0.07, alpha: 1.0)
        let tunnelBackNode = SCNNode(geometry: tunnelBack)
        tunnelBackNode.eulerAngles = SCNVector3(Double.pi / 2, 0, 0)
        tunnelBackNode.position = SCNVector3(0, 1.2, -68)
        scene.rootNode.addChildNode(tunnelBackNode)

        // Mine walls
        let wallMaterial = SCNMaterial()
        wallMaterial.diffuse.contents = NSColor(calibratedWhite: 0.12, alpha: 1.0)

        for side in [-1, 1] {
            let wall = SCNBox(width: 2.0, height: 6.0, length: 90, chamferRadius: 0)
            wall.materials = [wallMaterial]
            let wallNode = SCNNode(geometry: wall)
            wallNode.position = SCNVector3(Float(side) * 5.5, 1.5, -25)
            scene.rootNode.addChildNode(wallNode)
        }

        // Warm mine torches / lights
        for side in [-1, 1] {
            for z in stride(from: -6, through: -74, by: -14) {
                let torchGlow = SCNSphere(radius: 0.35)
                torchGlow.firstMaterial?.diffuse.contents = NSColor.orange.withAlphaComponent(0.95)
                torchGlow.firstMaterial?.emission.contents = NSColor.orange.withAlphaComponent(0.85)
                torchGlow.firstMaterial?.lightingModel = .constant

                let torchNode = SCNNode(geometry: torchGlow)
                torchNode.position = SCNVector3(Float(side) * 4.35, 1.5, Float(z))
                scene.rootNode.addChildNode(torchNode)

                let lightNode = SCNNode()
                lightNode.light = SCNLight()
                lightNode.light?.type = .omni
                lightNode.light?.color = NSColor.orange
                lightNode.light?.intensity = 650
                lightNode.position = torchNode.position
                scene.rootNode.addChildNode(lightNode)

                let torchPulseUp = SCNAction.fadeOpacity(to: 1.0, duration: 0.12)
                let torchPulseDown = SCNAction.fadeOpacity(to: 0.72, duration: 0.12)
                torchNode.runAction(.repeatForever(.sequence([torchPulseUp, torchPulseDown])))

                let flicker = SCNAction.repeatForever(
                    SCNAction.sequence([
                        SCNAction.run { _ in
                            lightNode.light?.intensity = CGFloat.random(in: 520...760)
                        },
                        SCNAction.wait(duration: 0.08)
                    ])
                )
                lightNode.runAction(flicker)
            }
        }


        for x in lanePositions {
            let railLeft = SCNBox(width: 0.08, height: 0.08, length: 90, chamferRadius: 0.02)
            railLeft.firstMaterial?.diffuse.contents = NSColor.lightGray
            let railLeftNode = SCNNode(geometry: railLeft)
            railLeftNode.position = SCNVector3(x - 0.38, -0.92, -25)
            scene.rootNode.addChildNode(railLeftNode)

            let railRight = SCNBox(width: 0.08, height: 0.08, length: 90, chamferRadius: 0.02)
            railRight.firstMaterial?.diffuse.contents = NSColor.lightGray
            let railRightNode = SCNNode(geometry: railRight)
            railRightNode.position = SCNVector3(x + 0.38, -0.92, -25)
            scene.rootNode.addChildNode(railRightNode)

            for z in stride(from: -70, through: 18, by: 2) {
                let tie = SCNBox(width: 0.95, height: 0.04, length: 0.22, chamferRadius: 0.01)
                tie.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.28, green: 0.18, blue: 0.10, alpha: 1.0)
                let tieNode = SCNNode(geometry: tie)
                tieNode.position = SCNVector3(x, -0.97, CGFloat(z))
                scene.rootNode.addChildNode(tieNode)
            }
        }

        let tunnelGlow = SCNSphere(radius: 2.8)
        tunnelGlow.firstMaterial?.diffuse.contents = NSColor.orange.withAlphaComponent(0.10)
        tunnelGlow.firstMaterial?.lightingModel = .constant
        let glowNode = SCNNode(geometry: tunnelGlow)
        glowNode.position = SCNVector3(0, 4.8, -16)
        scene.rootNode.addChildNode(glowNode)

        let cartBody = SCNBox(width: 1.55, height: 0.65, length: 2.15, chamferRadius: 0.08)
        cartBody.firstMaterial?.diffuse.contents = NSColor(calibratedWhite: 0.20, alpha: 1.0)
        cartBody.firstMaterial?.metalness.contents = 0.35
        cartBody.firstMaterial?.roughness.contents = 0.55

        playerNode.geometry = cartBody
        playerNode.name = "player"
        playerNode.position = SCNVector3(lanePositions[currentLaneIndex], playerBaseY, 6)
        isJumping = false
        isGameOver = false
        playerNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(geometry: cartBody, options: nil))
        playerNode.physicsBody?.categoryBitMask = PhysicsCategory.player
        playerNode.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.crystal
        playerNode.physicsBody?.collisionBitMask = 0
        scene.rootNode.addChildNode(playerNode)

        let rimMaterial = SCNMaterial()
        rimMaterial.diffuse.contents = NSColor.black

        let wheelOffsets: [SCNVector3] = [
            SCNVector3(-0.62, -0.38, 0.78),
            SCNVector3(0.62, -0.38, 0.78),
            SCNVector3(-0.62, -0.38, -0.78),
            SCNVector3(0.62, -0.38, -0.78)
        ]

        for offset in wheelOffsets {
            let wheel = SCNCylinder(radius: 0.22, height: 0.16)
            wheel.materials = [rimMaterial]
            let wheelNode = SCNNode(geometry: wheel)
            wheelNode.eulerAngles = SCNVector3(Double.pi / 2, 0, 0)
            wheelNode.position = offset
            playerNode.addChildNode(wheelNode)

            let spin = SCNAction.repeatForever(
                SCNAction.rotateBy(x: CGFloat.pi * 2, y: 0, z: 0, duration: 0.4)
            )
            wheelNode.runAction(spin)
        }

        let cartGlow = SCNBox(width: 1.0, height: 0.14, length: 1.3, chamferRadius: 0.04)
        cartGlow.firstMaterial?.diffuse.contents = NSColor.orange.withAlphaComponent(0.75)
        cartGlow.firstMaterial?.emission.contents = NSColor.orange.withAlphaComponent(0.55)
        let cartGlowNode = SCNNode(geometry: cartGlow)
        cartGlowNode.position = SCNVector3(0, 0.05, 0)
        playerNode.addChildNode(cartGlowNode)
    }

    func moveLeft() {
        guard !isGameOver else { return }
        guard currentLaneIndex > 0 else { return }
        currentLaneIndex -= 1
        movePlayerToCurrentLane()
    }

    func moveRight() {
        guard !isGameOver else { return }
        guard currentLaneIndex < lanePositions.count - 1 else { return }
        currentLaneIndex += 1
        movePlayerToCurrentLane()
    }

    func jump() {
        guard !isGameOver else { return }
        guard !isJumping else { return }

        isJumping = true
        playerNode.removeAction(forKey: "jumpMove")

        let startY = CGFloat(playerNode.presentation.position.y)
        let peakY = playerBaseY + jumpHeight

        let jumpUp = SCNAction.customAction(duration: jumpDuration / 2) { [weak self] node, elapsed in
            guard let self else { return }
            let progress = CGFloat(elapsed) / CGFloat(self.jumpDuration / 2)
            let eased = 1 - pow(1 - progress, 2)
            let newY = startY + (peakY - startY) * eased
            node.position = SCNVector3Make(node.position.x, newY, node.position.z)
        }

        let jumpDown = SCNAction.customAction(duration: jumpDuration / 2) { [weak self] node, elapsed in
            guard let self else { return }
            let progress = CGFloat(elapsed) / CGFloat(self.jumpDuration / 2)
            let eased = progress * progress
            let newY = peakY + (self.playerBaseY - peakY) * eased
            node.position = SCNVector3Make(node.position.x, newY, node.position.z)
        }

        let finish = SCNAction.run { [weak self] _ in
            guard let self else { return }
            self.playerNode.position = SCNVector3Make(
                self.playerNode.position.x,
                self.playerBaseY,
                self.playerNode.position.z
            )
            self.isJumping = false
        }

        playerNode.runAction(.sequence([jumpUp, jumpDown, finish]), forKey: "jumpMove")
    }

    private func movePlayerToCurrentLane() {
        let targetX = lanePositions[currentLaneIndex]
        let currentY = playerNode.presentation.position.y
        let currentZ = playerNode.presentation.position.z
        let targetPosition = SCNVector3Make(targetX, currentY, currentZ)
        let move = SCNAction.move(to: targetPosition, duration: 0.16)
        move.timingMode = SCNActionTimingMode.easeOut
        playerNode.removeAction(forKey: "laneMove")
        playerNode.runAction(move, forKey: "laneMove")
    }

    private func startGameLoop() {
        gameLoopTimer?.invalidate()
        gameLoopTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateWorld()
        }
    }

    private func updateWorld() {
        for node in scene.rootNode.childNodes {
            guard let name = node.name, name == "obstacle" || name == "crystal" else { continue }

            if node.presentation.position.z > 14 {
                if name == "obstacle" {
                    DispatchQueue.main.async {
                        self.score += 1
                    }
                }
                node.removeFromParentNode()
            }
        }
    }

    private func startSpawning() {
        spawnTimer?.invalidate()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.spawnRandomObject()
        }
    }

    private func spawnRandomObject() {
        let crystalChance = Int.random(in: 0...4) == 0
        crystalChance ? spawnCrystal() : spawnObstacle()
    }

    private func spawnObstacle() {
        let geometry = SCNCone(topRadius: 0.08, bottomRadius: 0.72, height: 1.15)
        geometry.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.30, green: 0.24, blue: 0.20, alpha: 1.0)
        geometry.firstMaterial?.roughness.contents = 1.0

        let node = SCNNode(geometry: geometry)
        let lane = lanePositions.randomElement() ?? lanePositions[1]
        node.name = "obstacle"
        node.position = SCNVector3(lane, -0.3, -42)
        node.eulerAngles = SCNVector3(0, 0, 0.2)
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
        node.physicsBody?.isAffectedByGravity = false
        node.physicsBody?.damping = 0
        node.physicsBody?.angularDamping = 0
        node.physicsBody?.categoryBitMask = PhysicsCategory.obstacle
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.velocity = SCNVector3(0, 0, obstacleSpeed)
        scene.rootNode.addChildNode(node)
    }

    private func spawnCrystal() {
        let geometry = SCNOctahedron(radius: 0.6)
        geometry.firstMaterial?.diffuse.contents = NSColor.cyan
        geometry.firstMaterial?.emission.contents = NSColor.cyan.withAlphaComponent(0.5)
        geometry.firstMaterial?.lightingModel = .blinn

        let node = SCNNode(geometry: geometry)
        let lane = lanePositions.randomElement() ?? lanePositions[1]
        node.name = "crystal"
        node.position = SCNVector3(lane, 0.2, -42)
        let diamondGlow = SCNSphere(radius: 0.42)
        diamondGlow.firstMaterial?.diffuse.contents = NSColor.cyan.withAlphaComponent(0.16)
        diamondGlow.firstMaterial?.lightingModel = .constant
        let glowNode = SCNNode(geometry: diamondGlow)
        node.addChildNode(glowNode)
        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geometry, options: nil))
        node.physicsBody?.isAffectedByGravity = false
        node.physicsBody?.damping = 0
        node.physicsBody?.angularDamping = 0
        node.physicsBody?.categoryBitMask = PhysicsCategory.crystal
        node.physicsBody?.contactTestBitMask = PhysicsCategory.player
        node.physicsBody?.collisionBitMask = 0
        node.physicsBody?.velocity = SCNVector3(0, 0, crystalSpeed)
        node.physicsBody?.angularVelocity = SCNVector4(0, 1, 0, CGFloat.pi * 2)
        scene.rootNode.addChildNode(node)
    }

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB

        let player: SCNNode?
        let other: SCNNode?

        if nodeA.name == "player" {
            player = nodeA
            other = nodeB
        } else if nodeB.name == "player" {
            player = nodeB
            other = nodeA
        } else {
            player = nil
            other = nil
        }

        guard player != nil, let hitNode = other else { return }
        guard hitNode.name == "obstacle" || hitNode.name == "crystal" else { return }

        let hitName = hitNode.name ?? ""
        hitNode.physicsBody?.velocity = SCNVector3Zero

        if hitName == "obstacle" {
            DispatchQueue.main.async {
                self.isGameOver = true
                self.statusText = "Crashed! Press Restart"
                self.spawnTimer?.invalidate()
                self.gameLoopTimer?.invalidate()
            }

            let flashUp = SCNAction.scale(to: 1.18, duration: 0.08)
            let flashDown = SCNAction.scale(to: 1.0, duration: 0.12)
            playerNode.runAction(.sequence([flashUp, flashDown]))

            let camLeft = SCNAction.moveBy(x: -0.18, y: 0, z: 0, duration: 0.03)
            let camRight = SCNAction.moveBy(x: 0.36, y: 0, z: 0, duration: 0.05)
            let camCenter = SCNAction.moveBy(x: -0.18, y: 0, z: 0, duration: 0.03)
            cameraNode.runAction(.sequence([camLeft, camRight, camCenter]))
        } else if hitName == "crystal" {
            hitNode.name = "resolved_crystal"

            DispatchQueue.main.async {
                self.score += 10
                self.statusText = "Diamond collected!"
            }

            let pulseUp = SCNAction.scale(to: 1.28, duration: 0.08)
            let pulseDown = SCNAction.scale(to: 1.0, duration: 0.12)
            playerNode.runAction(.sequence([pulseUp, pulseDown]))

            let particles = SCNParticleSystem()
            particles.birthRate = 420
            particles.particleLifeSpan = 0.32
            particles.particleLifeSpanVariation = 0.12
            particles.particleSize = 0.06
            particles.particleVelocity = 1.4
            particles.particleVelocityVariation = 0.8
            particles.spreadingAngle = 180
            particles.emitterShape = SCNSphere(radius: 0.18)
            particles.particleColor = NSColor.cyan
            particles.loops = false
            particles.blendMode = .additive
            particles.isAffectedByGravity = false
            hitNode.addParticleSystem(particles)

            let remove = SCNAction.sequence([
                SCNAction.wait(duration: 0.06),
                SCNAction.removeFromParentNode()
            ])
            hitNode.runAction(remove)
        }
    }

    func restartGame() {
        score = 0
        statusText = "Back in the run"
        currentLaneIndex = 1
        isJumping = false
        spawnTimer?.invalidate()
        gameLoopTimer?.invalidate()
        setupScene()
        startSpawning()
        startGameLoop()
    }
}

final class SCNOctahedron: SCNGeometry {
    convenience init(radius: CGFloat) {
        let r = Float(radius)
        let vertices: [SCNVector3] = [
            SCNVector3(0, r, 0),
            SCNVector3(r, 0, 0),
            SCNVector3(0, 0, r),
            SCNVector3(-r, 0, 0),
            SCNVector3(0, 0, -r),
            SCNVector3(0, -r, 0)
        ]

        let indices: [Int32] = [
            0, 1, 2,
            0, 2, 3,
            0, 3, 4,
            0, 4, 1,
            5, 2, 1,
            5, 3, 2,
            5, 4, 3,
            5, 1, 4
        ]

        let vertexSource = SCNGeometrySource(vertices: vertices)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: 8,
            bytesPerIndex: MemoryLayout<Int32>.size
        )
        self.init(sources: [vertexSource], elements: [element])
    }
}

struct CrystalRunnerKeyboardHandler: NSViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void
    let onJump: () -> Void

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onLeft = onLeft
        view.onRight = onRight
        view.onJump = onJump
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {
        nsView.onLeft = onLeft
        nsView.onRight = onRight
        nsView.onJump = onJump
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class KeyCatcherView: NSView {
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?
    var onJump: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 0:
            onLeft?()      // A
        case 2:
            onRight?()     // D
        case 49:
            onJump?()      // Space
        default:
            super.keyDown(with: event)
        }
    }
}

struct CrystalRunnerView: View {
    @StateObject private var controller = CrystalRunnerController()
    @FocusState private var keyboardFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            SceneView(
                scene: controller.scene,
                pointOfView: controller.cameraNode,
                options: [],
                preferredFramesPerSecond: 60,
                antialiasingMode: .multisampling4X,
                delegate: nil,
                technique: nil
            )
            .background(Color.black)
            .ignoresSafeArea()
            .focusable()
            .focused($keyboardFocused)
            .onAppear {
                keyboardFocused = true
            }
            .onTapGesture {
                keyboardFocused = true
            }
            .onMoveCommand { direction in
                switch direction {
                case .left:
                    controller.moveLeft()
                case .right:
                    controller.moveRight()
                default:
                    break
                }
            }

            VStack(spacing: 14) {
                HStack(spacing: 18) {
                    Label("\(controller.score)", systemImage: "diamond.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())

                    Text(controller.statusText)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }

                HStack(spacing: 18) {
                    Button {
                        controller.moveLeft()
                    } label: {
                        Label("Left (A)", systemImage: "arrow.left")
                            .frame(width: 130)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)

                    Button {
                        controller.jump()
                    } label: {
                        Label("Jump", systemImage: "arrow.up")
                            .frame(width: 130)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button {
                        controller.moveRight()
                    } label: {
                        Label("Right (D)", systemImage: "arrow.right")
                            .frame(width: 130)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }

                HStack(spacing: 16) {
                    Text("Keyboard: A = left, D = right, Space = jump")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))

                    if controller.isGameOver {
                        Button("Restart") {
                            controller.restartGame()
                            keyboardFocused = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(.bottom, 18)
            }
        }
        .background(
            CrystalRunnerKeyboardHandler(
                onLeft: { controller.moveLeft() },
                onRight: { controller.moveRight() },
                onJump: { controller.jump() }
            )
            .frame(width: 0, height: 0)
        )
    }
}

