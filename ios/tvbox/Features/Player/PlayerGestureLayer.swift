import SwiftUI

/// 双击的位置：左右三分之一快退快进，中间暂停
enum PlayerTapZone {
    case left, center, right

    init(x: CGFloat, width: CGFloat) {
        if x < width / 3 {
            self = .left
        } else if x > width * 2 / 3 {
            self = .right
        } else {
            self = .center
        }
    }
}

/// 滑动手势的进行状态
enum PlayerPan {
    /// 横向滑动，参数是滑动距离占宽度的比例
    case seek(CGFloat)
    /// 左半屏竖滑，参数是调整后的屏幕亮度 0...1
    case brightness(CGFloat)
    /// 右半屏竖滑，参数是调整后的系统音量 0...1
    case volume(Float)
    case ended
}

/// 播放画面上的手势，和 Android BaseController 一样：
/// 单击显示/隐藏控制层，双击左右快退快进、中间暂停，长按 3 倍速，
/// 横滑调进度，左半屏竖滑调亮度、右半屏调音量。锁屏后只响应单击。
struct PlayerGestureLayer: View {
    var isLocked: Bool
    var onTap: () -> Void
    var onDoubleTap: (PlayerTapZone) -> Void
    var onLongPress: (Bool) -> Void
    var onPan: (PlayerPan) -> Void

    var body: some View {
        #if canImport(UIKit)
        PlayerGestureView(
            isLocked: isLocked,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress,
            onPan: onPan
        )
        #else
        // 原生 macOS 只用鼠标点击，进度和音量用控制条和键盘
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2, coordinateSpace: .local) { location in
                    onDoubleTap(PlayerTapZone(x: location.x, width: geometry.size.width))
                }
                .onTapGesture(perform: onTap)
        }
        #endif
    }
}

#if canImport(UIKit)
import MediaPlayer

private struct PlayerGestureView: UIViewRepresentable {
    var isLocked: Bool
    var onTap: () -> Void
    var onDoubleTap: (PlayerTapZone) -> Void
    var onLongPress: (Bool) -> Void
    var onPan: (PlayerPan) -> Void

    func makeUIView(context _: Context) -> PlayerGestureUIView {
        let view = PlayerGestureUIView()
        update(view)
        return view
    }

    func updateUIView(_ view: PlayerGestureUIView, context _: Context) {
        update(view)
    }

    private func update(_ view: PlayerGestureUIView) {
        view.isLocked = isLocked
        view.onTap = onTap
        view.onDoubleTap = onDoubleTap
        view.onLongPress = onLongPress
        view.onPan = onPan
    }
}

private final class PlayerGestureUIView: UIView {
    var onTap: () -> Void = {}
    var onDoubleTap: (PlayerTapZone) -> Void = { _ in }
    var onLongPress: (Bool) -> Void = { _ in }
    var onPan: (PlayerPan) -> Void = { _ in }

    var isLocked = false {
        didSet {
            doubleTap.isEnabled = !isLocked
            longPress.isEnabled = !isLocked
            pan.isEnabled = !isLocked
        }
    }

    private lazy var singleTap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    private lazy var doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
    private lazy var longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))

    private enum PanMode { case seek, brightness, volume }
    private var panMode: PanMode?
    private var panStartLevel: CGFloat = 0
    /// 进入播放页前的屏幕亮度，离开时恢复
    private var originalBrightness: CGFloat?

    /// 系统音量只能通过 MPVolumeView 里的滑块改，放在屏幕外，同时也挡住系统的音量提示
    private let volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 100, height: 40))

    /// Mac 上调不了屏幕亮度和系统音量
    private static let supportsLevelPan = !ProcessInfo.processInfo.isMacCatalystApp && !ProcessInfo.processInfo.isiOSAppOnMac

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        doubleTap.numberOfTapsRequired = 2
        singleTap.require(toFail: doubleTap)
        longPress.minimumPressDuration = 0.5
        [singleTap, doubleTap, longPress, pan].forEach(addGestureRecognizer)
        if Self.supportsLevelPan {
            addSubview(volumeView)
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil, let originalBrightness {
            window?.windowScene?.screen.brightness = originalBrightness
            self.originalBrightness = nil
        }
    }

    @objc private func handleTap() {
        onTap()
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        onDoubleTap(PlayerTapZone(x: gesture.location(in: self).x, width: bounds.width))
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began: onLongPress(true)
        case .ended, .cancelled, .failed: onLongPress(false)
        default: break
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        switch gesture.state {
        case .began:
            let velocity = gesture.velocity(in: self)
            if abs(velocity.x) >= abs(velocity.y) {
                panMode = .seek
            } else if !Self.supportsLevelPan {
                panMode = nil
            } else if gesture.location(in: self).x > bounds.width / 2 {
                panMode = .volume
                panStartLevel = CGFloat(AVAudioSession.sharedInstance().outputVolume)
            } else {
                panMode = .brightness
                panStartLevel = window?.windowScene?.screen.brightness ?? 0.5
            }
        case .changed:
            guard let panMode, bounds.width > 0, bounds.height > 0 else { return }
            // 和 Android 一样，滑过半个屏幕高度从最暗调到最亮
            let level = min(max(panStartLevel - translation.y * 2 / bounds.height, 0), 1)
            switch panMode {
            case .seek:
                onPan(.seek(translation.x / bounds.width))
            case .brightness:
                guard let screen = window?.windowScene?.screen else { return }
                if originalBrightness == nil {
                    originalBrightness = screen.brightness
                }
                screen.brightness = level
                onPan(.brightness(level))
            case .volume:
                volumeView.subviews.compactMap { $0 as? UISlider }.first?.value = Float(level)
                onPan(.volume(Float(level)))
            }
        case .ended, .cancelled, .failed:
            if panMode != nil {
                onPan(.ended)
            }
            panMode = nil
        default:
            break
        }
    }
}
#endif
