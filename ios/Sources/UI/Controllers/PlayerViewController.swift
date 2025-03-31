import UIKit
import AVFoundation

class PlayerViewController: UIViewController {
    
    private let video: Video
    private let playerView = UIView()
    private var player: TVBoxPlayer?
    
    init(video: Video) {
        self.video = video
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPlayer()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        title = video.title
        
        view.addSubview(playerView)
        playerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.equalToSuperview()
            make.height.equalTo(playerView.snp.width).multipliedBy(0.5625)
        }
    }
    
    private func setupPlayer() {
        player = TVBoxPlayer.shared
        player?.setupPlayer(in: playerView)
        
        if let url = URL(string: video.videoURL) {
            player?.play(url: url)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
} 