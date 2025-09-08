//
//  AnimatedComponents.swift
//  DadaKnows
//
//  动画组件集合
//

import SwiftUI

// MARK: - Floating Animation

struct FloatingView<Content: View>: View {
    let content: Content
    let amplitude: CGFloat
    let frequency: Double
    
    @State private var animationOffset: CGFloat = 0
    
    init(amplitude: CGFloat = 10, frequency: Double = 2.0, @ViewBuilder content: () -> Content) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.content = content()
    }
    
    var body: some View {
        content
            .offset(y: animationOffset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: frequency)
                    .repeatForever(autoreverses: true)
                ) {
                    animationOffset = amplitude
                }
            }
    }
}

// MARK: - Pulse Animation

struct PulseView<Content: View>: View {
    let content: Content
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double
    
    @State private var isPulsing = false
    
    init(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05, duration: Double = 1.0, @ViewBuilder content: () -> Content) {
        self.minScale = minScale
        self.maxScale = maxScale
        self.duration = duration
        self.content = content()
    }
    
    var body: some View {
        content
            .scaleEffect(isPulsing ? maxScale : minScale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Shimmer Effect

struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    let gradient = LinearGradient(
        colors: [
            Color.clear,
            Color.white.opacity(0.3),
            Color.clear
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        gradient
            .scaleEffect(3)
            .rotationEffect(.degrees(70))
            .offset(x: phase)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 300
                }
            }
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var isShimmering = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(3)
                    .rotationEffect(.degrees(70))
                    .offset(x: isShimmering ? 300 : -300)
                    .animation(
                        .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                        value: isShimmering
                    )
                    .onAppear {
                        isShimmering = true
                    }
                    .allowsHitTesting(false)
            )
            .clipped()
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Bounce Animation

struct BounceView<Content: View>: View {
    let content: Content
    let trigger: Bool
    
    @State private var bounceScale: CGFloat = 1.0
    
    init(trigger: Bool, @ViewBuilder content: () -> Content) {
        self.trigger = trigger
        self.content = content()
    }
    
    var body: some View {
        content
            .scaleEffect(bounceScale)
            .onChange(of: trigger) { oldValue, newValue in
                if newValue != oldValue {
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                        bounceScale = 1.2
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                            bounceScale = 1.0
                        }
                    }
                }
            }
    }
}

// MARK: - Typing Animation

struct DotTypingIndicator: View {
    @State private var animationPhase = 0
    @State private var timer: Timer?
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .opacity(animationPhase == index ? 1.0 : 0.5)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Slide In Animation

struct SlideInView<Content: View>: View {
    let content: Content
    let edge: Edge
    let delay: Double
    
    @State private var isVisible = false
    
    init(from edge: Edge = .bottom, delay: Double = 0, @ViewBuilder content: () -> Content) {
        self.edge = edge
        self.delay = delay
        self.content = content()
    }
    
    var body: some View {
        content
            .offset(
                x: !isVisible && (edge == .leading || edge == .trailing) ? (edge == .leading ? -300 : 300) : 0,
                y: !isVisible && (edge == .top || edge == .bottom) ? (edge == .top ? -300 : 300) : 0
            )
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                        isVisible = true
                    }
                }
            }
    }
}

// MARK: - Particle Effect

struct ParticleView: View {
    @State private var particles: [Particle] = []
    @State private var timer: Timer?
    let particleCount: Int
    let colors: [Color]
    
    init(particleCount: Int = 20, colors: [Color] = [.vibrantOrange, .tenderYellow, .skyBlue]) {
        self.particleCount = particleCount
        self.colors = colors
    }
    
    var body: some View {
        ZStack {
            ForEach(particles, id: \.id) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .scaleEffect(particle.scale)
            }
        }
        .onAppear {
            generateParticles()
            animateParticles()
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func generateParticles() {
        particles = (0..<particleCount).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...300),
                    y: CGFloat.random(in: 0...300)
                ),
                color: colors.randomElement() ?? .vibrantOrange,
                size: CGFloat.random(in: 2...8),
                opacity: Double.random(in: 0.3...0.8),
                scale: CGFloat.random(in: 0.5...1.0)
            )
        }
    }
    
    private func animateParticles() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                for i in particles.indices {
                    particles[i].position.x += CGFloat.random(in: -2...2)
                    particles[i].position.y += CGFloat.random(in: -2...2)
                    particles[i].opacity = Double.random(in: 0.2...0.8)
                    particles[i].scale = CGFloat.random(in: 0.5...1.2)
                }
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double
    var scale: CGFloat
}

// MARK: - Success Animation

struct SuccessCheckmark: View {
    @State private var trimEnd: CGFloat = 0
    @State private var scale: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 60, height: 60)
                .scaleEffect(scale)
            
            Path { path in
                path.move(to: CGPoint(x: 20, y: 30))
                path.addLine(to: CGPoint(x: 28, y: 38))
                path.addLine(to: CGPoint(x: 40, y: 22))
            }
            .trim(from: 0, to: trimEnd)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: 60, height: 60)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    trimEnd = 1.0
                }
            }
        }
    }
}

// MARK: - Loading Spinner

struct CustomLoadingSpinner: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.7)
            .stroke(
                LinearGradient(
                    colors: [.vibrantOrange, .tenderYellow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .frame(width: 30, height: 30)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

#Preview {
    VStack(spacing: 30) {
        FloatingView {
            Text("浮动文字")
                .padding()
                .background(Color.tenderYellow)
                .cornerRadius(10)
        }
        
        PulseView {
            Circle()
                .fill(Color.vibrantOrange)
                .frame(width: 50, height: 50)
        }
        
        DotTypingIndicator()
        
        SuccessCheckmark()
        
        CustomLoadingSpinner()
    }
    .padding()
}
