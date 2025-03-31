import Foundation
import AVFoundation

class TVBoxPlayer {
    static let shared = TVBoxPlayer()
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playerLayer: AVPlayerLayer?
    
    private init() {}
    
    func setupPlayer(in view: UIView) {
        player = AVPlayer()
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = view.bounds
        playerLayer?.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer!)
    }
    
    func play(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player?.replaceCurrentItem(with: playerItem)
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func resume() {
        player?.play()
    }
    
    func seek(to time: CMTime) {
        player?.seek(to: time)
    }
    
    func getCurrentTime() -> CMTime {
        return player?.currentTime() ?? .zero
    }
    
    func getDuration() -> CMTime {
        return player?.currentItem?.duration ?? .zero
    }
    
    func addPeriodicTimeObserver(forInterval interval: CMTime, queue: DispatchQueue?, using block: @escaping (CMTime) -> Void) {
        player?.addPeriodicTimeObserver(forInterval: interval, queue: queue, using: block)
    }
} 