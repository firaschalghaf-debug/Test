import SwiftUI
import Combine
import SceneKit

final class CrystalRunnerController: NSObject, ObservableObject, SCNPhysicsContactDelegate {
    let scene      = SCNScene()
    let cameraNode = SCNNode()

    private let playerNode    = SCNNode()
    private let lanePositions = AppConfig.CrystalRun.lanePositions
    private var currentLaneIndex  = 1
    private var spawnTimer: Timer?
    private var gameLoopTimer: Timer?
    private var isJumping         = false
    private let playerBaseY: CGFloat = -0.25

    @Published var isGameOver = false
    @Published var score: Int = 0
    @Published var statusText = "Mine Runner"

    private enum PhysicsCategory {
        static let player   = 1 << 0
        static let obstacle = 1 << 1
        static let crystal  = 1 << 2
    }

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

    // MARK: - Scene setup

    private func setupScene() {
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        scene.background.contents = NSColor(calibratedRed: 0.05, green: 0.03, blue: 0.12, alpha: 1.0)
        scene.fogStartDistance = 18
        scene.fogEndDistance   = 72
        scene.fogColor         = NSColor(calibratedRed: 0.07, green: 0.05, blue: 0.07, alpha: 1.0)
        scene.physicsWorld.gravity         = SCNVector3Zero
        scene.physicsWorld.contactDelegate = self

        addCamera()
        addLighting()
        addFloor()
        addTunnel()
        addWalls()
        addTorches()
        addRails()
        addTunnelGlow()
        addPlayerCart()
    }

    private func addCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 70
        cameraNode.camera      = camera
        cameraNode.position    = SCNVector3(0, 6, 14)
        cameraNode.eulerAngles = SCNVector3(-0.45, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
    }

    private func addLighting() {
        let ambient = SCNNode()
        ambient.light       = SCNLight()
        ambient.light?.type  = .ambient
        ambient.light?.color = NSColor(white: 0.45, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        let omni = SCNNode()
        omni.light       = SCNLight()
        omni.light?.type  = .omni
        omni.light?.color = NSColor.white
        omni.position     = SCNVector3(0, 10, 10)
        scene.rootNode.addChildNode(omni)
    }

    private func addFloor() {
        let floor = SCNFloor()
        floor.reflectivity = 0
        floor.firstMaterial?.diffuse.contents  = NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.10, alpha: 1.0)
        floor.firstMaterial?.specular.contents = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        let node = SCNNode(geometry: floor)
        node.position    = SCNVector3(0, -1.1, 0)
        node.physicsBody = SCNPhysicsBody.static()
        scene.rootNode.addChildNode(node)
    }

    private func addTunnel() {
        let geo = SCNTube(innerRadius: 3.5, outerRadius: 6.4, height: 1.2)
        geo.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.12, green: 0.08, blue: 0.07, alpha: 1.0)
        let node = SCNNode(geometry: geo)
        node.eulerAngles = SCNVector3(Double.pi / 2, 0, 0)
        node.position    = SCNVector3(0, 1.2, -68)
        scene.rootNode.addChildNode(node)
    }

    private func addWalls() {
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(calibratedWhite: 0.12, alpha: 1.0)
        for side in [-1, 1] {
            let wall = SCNBox(width: 2.0, height: 6.0, length: 90, chamferRadius: 0)
            wall.materials = [mat]
            let node = SCNNode(geometry: wall)
            node.position = SCNVector3(Float(side) * 5.5, 1.5, -25)
            scene.rootNode.addChildNode(node)
        }
    }

    private func addTorches() {
        for side in [-1, 1] {
            for z in stride(from: -6, through: -74, by: -14) {
                let sphere = SCNSphere(radius: 0.35)
                sphere.firstMaterial?.diffuse.contents  = NSColor.orange.withAlphaComponent(0.95)
                sphere.firstMaterial?.emission.contents = NSColor.orange.withAlphaComponent(0.85)
                sphere.firstMaterial?.lightingModel     = .constant

                let torchNode = SCNNode(geometry: sphere)
                torchNode.position = SCNVector3(Float(side) * 4.35, 1.5, Float(z))
                scene.rootNode.addChildNode(torchNode)

                let lightNode = SCNNode()
                lightNode.light           = SCNLight()
                lightNode.light?.type     = .omni
                lightNode.light?.color    = NSColor.orange
                lightNode.light?.intensity = 650
                lightNode.position        = torchNode.position
                scene.rootNode.addChildNode(lightNode)

                torchNode.runAction(.repeatForever(.sequence([
                    SCNAction.fadeOpacity(to: 1.0, duration: 0.12),
                    SCNAction.fadeOpacity(to: 0.72, duration: 0.12)
                ])))

                lightNode.runAction(.repeatForever(.sequence([
                    SCNAction.run { _ in lightNode.light?.intensity = CGFloat.random(in: 520...760) },
                    SCNAction.wait(duration: 0.08)
                ])))
            }
        }
    }

    private func addRails() {
        for x in lanePositions {
            for offset in [-0.38, 0.38] as [CGFloat] {
                let rail = SCNBox(width: 0.08, height: 0.08, length: 90, chamferRadius: 0.02)
                rail.firstMaterial?.diffuse.contents = NSColor.lightGray
                let node = SCNNode(geometry: rail)
                node.position = SCNVector3(x + offset, -0.92, -25)
                scene.rootNode.addChildNode(node)
            }

            for z in stride(from: -70, through: 18, by: 2) {
                let tie = SCNBox(width: 0.95, height: 0.04, length: 0.22, chamferRadius: 0.01)
                tie.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.28, green: 0.18, blue: 0.10, alpha: 1.0)
                let node = SCNNode(geometry: tie)
                node.position = SCNVector3(x, -0.97, CGFloat(z))
                scene.rootNode.addChildNode(node)
            }
        }
    }

    private func addTunnelGlow() {
        let glow = SCNSphere(radius: 2.8)
        glow.firstMaterial?.diffuse.contents = NSColor.orange.withAlphaComponent(0.10)
        glow.firstMaterial?.lightingModel    = .constant
        let node = SCNNode(geometry: glow)
        node.position = SCNVector3(0, 4.8, -16)
        scene.rootNode.addChildNode(node)
    }

    private func addPlayerCart() {
        let body = SCNBox(width: 1.55, height: 0.65, length: 2.15, chamferRadius: 0.08)
        body.firstMaterial?.diffuse.contents  = NSColor(calibratedWhite: 0.20, alpha: 1.0)
        body.firstMaterial?.metalness.contents = 0.35
        body.firstMaterial?.roughness.contents = 0.55

        playerNode.geometry = body
        playerNode.name     = "player"
        playerNode.position = SCNVector3(lanePositions[currentLaneIndex], playerBaseY, 6)
        isJumping  = false
        isGameOver = false

        let shape = SCNPhysicsShape(geometry: body, options: nil)
        playerNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: shape)
        playerNode.physicsBody?.categoryBitMask    = PhysicsCategory.player
        playerNode.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.crystal
        playerNode.physicsBody?.collisionBitMask   = 0
        scene.rootNode.addChildNode(playerNode)

        let rimMat = SCNMaterial()
        rimMat.diffuse.contents = NSColor.black

        let wheelOffsets: [SCNVector3] = [
            SCNVector3(-0.62, -0.38, 0.78),  SCNVector3(0.62, -0.38, 0.78),
            SCNVector3(-0.62, -0.38, -0.78), SCNVector3(0.62, -0.38, -0.78)
        ]
        for offset in wheelOffsets {
            let wheel = SCNCylinder(radius: 0.22, height: 0.16)
            wheel.materials = [rimMat]
            let node = SCNNode(geometry: wheel)
            node.eulerAngles = SCNVector3(Double.pi / 2, 0, 0)
            node.position    = offset
            node.runAction(.repeatForever(.rotateBy(x: CGFloat.pi * 2, y: 0, z: 0, duration: 0.4)))
            playerNode.addChildNode(node)
        }

        let glow = SCNBox(width: 1.0, height: 0.14, length: 1.3, chamferRadius: 0.04)
        glow.firstMaterial?.diffuse.contents  = NSColor.orange.withAlphaComponent(0.75)
        glow.firstMaterial?.emission.contents = NSColor.orange.withAlphaComponent(0.55)
        let glowNode = SCNNode(geometry: glow)
        glowNode.position = SCNVector3(0, 0.05, 0)
        playerNode.addChildNode(glowNode)
    }

    // MARK: - Player controls

    func moveLeft() {
        guard !isGameOver, currentLaneIndex > 0 else { return }
        currentLaneIndex -= 1
        movePlayerToLane()
    }

    func moveRight() {
        guard !isGameOver, currentLaneIndex < lanePositions.count - 1 else { return }
        currentLaneIndex += 1
        movePlayerToLane()
    }

    func jump() {
        guard !isGameOver, !isJumping else { return }
        isJumping = true
        playerNode.removeAction(forKey: "jump")

        let startY = CGFloat(playerNode.presentation.position.y)
        let peakY  = playerBaseY + AppConfig.CrystalRun.jumpHeight

        let up = SCNAction.customAction(duration: AppConfig.CrystalRun.jumpDuration / 2) { [weak self] node, elapsed in
            guard let self else { return }
            let t   = CGFloat(elapsed) / CGFloat(AppConfig.CrystalRun.jumpDuration / 2)
            let eas = 1 - pow(1 - t, 2)
            node.position = SCNVector3Make(node.position.x, startY + (peakY - startY) * eas, node.position.z)
        }
        let down = SCNAction.customAction(duration: AppConfig.CrystalRun.jumpDuration / 2) { [weak self] node, elapsed in
            guard let self else { return }
            let t   = CGFloat(elapsed) / CGFloat(AppConfig.CrystalRun.jumpDuration / 2)
            let eas = t * t
            node.position = SCNVector3Make(node.position.x, peakY + (self.playerBaseY - peakY) * eas, node.position.z)
        }
        let land = SCNAction.run { [weak self] _ in
            guard let self else { return }
            self.playerNode.position = SCNVector3Make(self.playerNode.position.x, self.playerBaseY, self.playerNode.position.z)
            self.isJumping = false
        }
        playerNode.runAction(.sequence([up, down, land]), forKey: "jump")
    }

    private func movePlayerToLane() {
        let target = SCNVector3Make(
            lanePositions[currentLaneIndex],
            CGFloat(playerNode.presentation.position.y),
            CGFloat(playerNode.presentation.position.z)
        )
        let move = SCNAction.move(to: target, duration: 0.16)
        move.timingMode = .easeOut
        playerNode.removeAction(forKey: "lane")
        playerNode.runAction(move, forKey: "lane")
    }

    // MARK: - Game loop

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
                if name == "obstacle" { DispatchQueue.main.async { self.score += 1 } }
                node.removeFromParentNode()
            }
        }
    }

    private func startSpawning() {
        spawnTimer?.invalidate()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.CrystalRun.spawnInterval, repeats: true) { [weak self] _ in
            self?.spawnRandomObject()
        }
    }

    private func spawnRandomObject() {
        Int.random(in: 0..<AppConfig.CrystalRun.crystalRarity) == 0 ? spawnCrystal() : spawnObstacle()
    }

    private func spawnObstacle() {
        let geo = SCNCone(topRadius: 0.08, bottomRadius: 0.72, height: 1.15)
        geo.firstMaterial?.diffuse.contents   = NSColor(calibratedRed: 0.30, green: 0.24, blue: 0.20, alpha: 1.0)
        geo.firstMaterial?.roughness.contents = 1.0

        let node = SCNNode(geometry: geo)
        node.name         = "obstacle"
        node.position     = SCNVector3(lanePositions.randomElement() ?? lanePositions[1], -0.3, -42)
        node.eulerAngles  = SCNVector3(0, 0, 0.2)
        node.physicsBody  = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geo, options: nil))
        node.physicsBody?.isAffectedByGravity = false
        node.physicsBody?.damping             = 0
        node.physicsBody?.angularDamping      = 0
        node.physicsBody?.categoryBitMask     = PhysicsCategory.obstacle
        node.physicsBody?.contactTestBitMask  = PhysicsCategory.player
        node.physicsBody?.collisionBitMask    = 0
        node.physicsBody?.velocity            = SCNVector3(0, 0, AppConfig.CrystalRun.obstacleSpeed)
        scene.rootNode.addChildNode(node)
    }

    private func spawnCrystal() {
        let geo = SCNOctahedron(radius: 0.6)
        geo.firstMaterial?.diffuse.contents  = NSColor.cyan
        geo.firstMaterial?.emission.contents = NSColor.cyan.withAlphaComponent(0.5)
        geo.firstMaterial?.lightingModel     = .blinn

        let node = SCNNode(geometry: geo)
        node.name    = "crystal"
        node.position = SCNVector3(lanePositions.randomElement() ?? lanePositions[1], 0.2, -42)

        let halo = SCNSphere(radius: 0.42)
        halo.firstMaterial?.diffuse.contents = NSColor.cyan.withAlphaComponent(0.16)
        halo.firstMaterial?.lightingModel    = .constant
        node.addChildNode(SCNNode(geometry: halo))

        node.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: geo, options: nil))
        node.physicsBody?.isAffectedByGravity = false
        node.physicsBody?.damping             = 0
        node.physicsBody?.angularDamping      = 0
        node.physicsBody?.categoryBitMask     = PhysicsCategory.crystal
        node.physicsBody?.contactTestBitMask  = PhysicsCategory.player
        node.physicsBody?.collisionBitMask    = 0
        node.physicsBody?.velocity            = SCNVector3(0, 0, AppConfig.CrystalRun.crystalSpeed)
        node.physicsBody?.angularVelocity     = SCNVector4(0, 1, 0, CGFloat.pi * 2)
        scene.rootNode.addChildNode(node)
    }

    // MARK: - Collision delegate

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        let (playerNode, hitNode): (SCNNode?, SCNNode?) = {
            if contact.nodeA.name == "player" { return (contact.nodeA, contact.nodeB) }
            if contact.nodeB.name == "player" { return (contact.nodeB, contact.nodeA) }
            return (nil, nil)
        }()
        guard playerNode != nil, let hit = hitNode,
              hit.name == "obstacle" || hit.name == "crystal" else { return }

        hit.physicsBody?.velocity = SCNVector3Zero

        if hit.name == "obstacle" {
            DispatchQueue.main.async {
                self.isGameOver = true
                self.statusText = "Crashed! Press Restart"
                self.spawnTimer?.invalidate()
                self.gameLoopTimer?.invalidate()
            }
            self.playerNode.runAction(.sequence([.scale(to: 1.18, duration: 0.08), .scale(to: 1.0, duration: 0.12)]))
            cameraNode.runAction(.sequence([
                .moveBy(x: -0.18, y: 0, z: 0, duration: 0.03),
                .moveBy(x:  0.36, y: 0, z: 0, duration: 0.05),
                .moveBy(x: -0.18, y: 0, z: 0, duration: 0.03)
            ]))

        } else if hit.name == "crystal" {
            hit.name = "resolved_crystal"
            DispatchQueue.main.async {
                self.score     += 10
                self.statusText = "Diamond collected!"
            }
            self.playerNode.runAction(.sequence([.scale(to: 1.28, duration: 0.08), .scale(to: 1.0, duration: 0.12)]))

            let particles = SCNParticleSystem()
            particles.birthRate              = 420
            particles.particleLifeSpan       = 0.32
            particles.particleLifeSpanVariation = 0.12
            particles.particleSize           = 0.06
            particles.particleVelocity       = 1.4
            particles.particleVelocityVariation = 0.8
            particles.spreadingAngle         = 180
            particles.emitterShape           = SCNSphere(radius: 0.18)
            particles.particleColor          = NSColor.cyan
            particles.loops                  = false
            particles.blendMode              = .additive
            particles.isAffectedByGravity    = false
            hit.addParticleSystem(particles)
            hit.runAction(.sequence([.wait(duration: 0.06), .removeFromParentNode()]))
        }
    }

    // MARK: - Restart

    func restartGame() {
        score      = 0
        statusText = "Back in the run"
        currentLaneIndex = 1
        isJumping  = false
        spawnTimer?.invalidate()
        gameLoopTimer?.invalidate()
        setupScene()
        startSpawning()
        startGameLoop()
    }
}

// MARK: - Octahedron geometry

final class SCNOctahedron: SCNGeometry {
    convenience init(radius: CGFloat) {
        let r = Float(radius)
        let verts: [SCNVector3] = [
            SCNVector3(0, r, 0), SCNVector3(r, 0, 0), SCNVector3(0, 0, r),
            SCNVector3(-r, 0, 0), SCNVector3(0, 0, -r), SCNVector3(0, -r, 0)
        ]
        let indices: [Int32] = [
            0,1,2, 0,2,3, 0,3,4, 0,4,1,
            5,2,1, 5,3,2, 5,4,3, 5,1,4
        ]
        let data = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.size)
        self.init(
            sources: [SCNGeometrySource(vertices: verts)],
            elements: [SCNGeometryElement(data: data, primitiveType: .triangles, primitiveCount: 8, bytesPerIndex: MemoryLayout<Int32>.size)]
        )
    }
}

// MARK: - Keyboard handler (macOS)

struct CrystalRunnerKeyboardHandler: NSViewRepresentable {
    let onLeft: () -> Void
    let onRight: () -> Void
    let onJump: () -> Void

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onLeft = onLeft; view.onRight = onRight; view.onJump = onJump
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: KeyCatcherView, context: Context) {
        nsView.onLeft = onLeft; nsView.onRight = onRight; nsView.onJump = onJump
        DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) }
    }
}

final class KeyCatcherView: NSView {
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?
    var onJump: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 0:  onLeft?()   // A
        case 2:  onRight?()  // D
        case 49: onJump?()   // Space
        default: super.keyDown(with: event)
        }
    }
}

// MARK: - SwiftUI view

struct CrystalRunnerView: View {
    @StateObject private var controller = CrystalRunnerController()
    @FocusState  private var focused: Bool

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
            .focused($focused)
            .onAppear { focused = true }
            .onTapGesture { focused = true }
            .onMoveCommand { dir in
                switch dir {
                case .left:  controller.moveLeft()
                case .right: controller.moveRight()
                default: break
                }
            }

            gameHUD
        }
        .background(
            CrystalRunnerKeyboardHandler(
                onLeft:  { controller.moveLeft() },
                onRight: { controller.moveRight() },
                onJump:  { controller.jump() }
            )
            .frame(width: 0, height: 0)
        )
    }

    private var gameHUD: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                hudPill { Label("\(controller.score)", systemImage: "diamond.fill") }
                hudPill { Text(controller.statusText) }
            }

            HStack(spacing: 18) {
                gameButton("Left (A)",  icon: "arrow.left",  tint: .purple) { controller.moveLeft()  }
                gameButton("Jump",      icon: "arrow.up",    tint: .orange) { controller.jump()       }
                gameButton("Right (D)", icon: "arrow.right", tint: .cyan)   { controller.moveRight() }
            }

            HStack(spacing: 16) {
                Text("Keyboard: A = left, D = right, Space = jump")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))

                if controller.isGameOver {
                    Button("Restart") {
                        controller.restartGame()
                        focused = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(.bottom, 18)
        }
    }

    private func hudPill<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    private func gameButton(_ label: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            Label(label, systemImage: icon).frame(width: 130)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}
