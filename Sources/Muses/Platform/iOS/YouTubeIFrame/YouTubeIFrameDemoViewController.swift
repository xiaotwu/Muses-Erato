#if os(iOS)
import UIKit

enum YouTubeIFrameFactory {
    @MainActor static func make() -> YouTubeIFrameAdapter { YouTubeIFrameAdapter() }
}

/// P1 manual harness. Present from a temporary P4 route with two known embeddable IDs.
@MainActor
final class YouTubeIFrameDemoViewController: UIViewController {
    private let ids: [IFrameVideoID]
    private let adapter = YouTubeIFrameFactory.make()
    private let status = UILabel()
    private let openInYouTube = UIButton(type: .system)
    private var currentIndex = 0

    init(first: IFrameVideoID, next: IFrameVideoID) {
        ids = [first, next]
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(first:next:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        status.numberOfLines = 0
        status.text = "Loading…"
        let surface = adapter.view
        surface.translatesAutoresizingMaskIntoConstraints = false
        let controls = UIStackView(arrangedSubviews: [button("Play", #selector(play)),
                                                      button("Pause", #selector(pause)),
                                                      button("+10s", #selector(seek)),
                                                      button("Next", #selector(advance))])
        controls.distribution = .fillEqually
        controls.translatesAutoresizingMaskIntoConstraints = false
        status.translatesAutoresizingMaskIntoConstraints = false
        openInYouTube.setTitle("Open in YouTube", for: .normal)
        openInYouTube.addTarget(self, action: #selector(openVideo), for: .touchUpInside)
        openInYouTube.translatesAutoresizingMaskIntoConstraints = false
        openInYouTube.isHidden = true
        view.addSubview(surface)
        view.addSubview(controls)
        view.addSubview(status)
        view.addSubview(openInYouTube)
        let aspect = surface.heightAnchor.constraint(equalTo: surface.widthAnchor,
                                                      multiplier: 9.0 / 16.0)
        aspect.priority = .defaultHigh
        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            surface.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            surface.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            aspect,
            surface.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            controls.topAnchor.constraint(equalTo: surface.bottomAnchor, constant: 12),
            controls.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            status.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 12),
            status.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            openInYouTube.topAnchor.constraint(equalTo: status.bottomAnchor, constant: 8),
            openInYouTube.leadingAnchor.constraint(equalTo: surface.leadingAnchor)
        ])
        adapter.onEvent = { [weak self] event in
            self?.status.text = "\(event.videoID.rawValue) · \(event.generation) · \(event.kind)"
            self?.openInYouTube.isHidden = event.kind != .failed(.embeddingDisabled)
        }
        adapter.load(ids[0])
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        adapter.teardown()
    }

    private func button(_ title: String, _ action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func play() { try? adapter.play() }
    @objc private func pause() { adapter.pause() }
    @objc private func seek() { try? adapter.seek(to: 10) }
    @objc private func advance() {
        currentIndex = (currentIndex + 1) % ids.count
        openInYouTube.isHidden = true
        adapter.load(ids[currentIndex])
    }

    @objc private func openVideo() { UIApplication.shared.open(ids[currentIndex].watchURL) }
}
#endif
