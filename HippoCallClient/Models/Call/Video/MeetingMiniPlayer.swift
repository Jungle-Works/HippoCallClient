//
//  MeetingMiniPlayer.swift
//  HippoCallClient
//
//  Small floating call shown while the user is using the rest of the app.
//

import UIKit
import WebRTC

final class MeetingMiniPlayer: NSObject {
    private static let size = CGSize(width: 110, height: 150)
    private static let margin: CGFloat = 12

    private let window: UIWindow
    private let rootController = UIViewController()
    private let initialsLabel = UILabel()
    private let nameLabel = UILabel()
    private var videoView: RTCMTLVideoView?
    private var videoTrack: RTCVideoTrack?
    private let onTap: () -> Void
    private var originBeforeKeyboard: CGPoint?

    var isHidden: Bool { window.isHidden }

    init(title: String, videoTrack: RTCVideoTrack?, onTap: @escaping () -> Void) {
        self.onTap = onTap
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }
        super.init()
        configureViews()
        update(title: title, videoTrack: videoTrack)
    }

    func show() {
        let bounds = window.screen.bounds
        let insets = Self.safeAreaInsets
        window.frame = CGRect(x: bounds.maxX - Self.size.width - insets.right - Self.margin,
                              y: bounds.maxY - Self.size.height - insets.bottom - 100,
                              width: Self.size.width,
                              height: Self.size.height)
        window.isHidden = false
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    func remove() {
        NotificationCenter.default.removeObserver(self)
        update(title: "", videoTrack: nil)
        window.isHidden = true
    }

    func setHidden(_ hidden: Bool) {
        window.isHidden = hidden
    }

    func update(title: String, videoTrack newTrack: RTCVideoTrack?) {
        nameLabel.text = title.components(separatedBy: " ").first
        initialsLabel.text = Self.initials(from: title)
        guard newTrack !== videoTrack else { return }
        if let videoView = videoView {
            videoTrack?.remove(videoView)
        }
        videoTrack = newTrack
        guard let track = newTrack else {
            videoView?.isHidden = true
            return
        }
        let view = videoView ?? makeVideoView()
        view.isHidden = false
        track.add(view)
    }

    static func snappedOrigin(for frame: CGRect, in bounds: CGRect, insets: UIEdgeInsets) -> CGPoint {
        let minX = bounds.minX + insets.left + margin
        let maxX = bounds.maxX - insets.right - margin - frame.width
        let minY = bounds.minY + insets.top + margin
        let maxY = bounds.maxY - insets.bottom - margin - frame.height
        let x = frame.midX < bounds.midX ? minX : maxX
        return CGPoint(x: x, y: min(max(frame.minY, minY), maxY))
    }

    private static var safeAreaInsets: UIEdgeInsets {
        UIApplication.shared.windows.first?.safeAreaInsets ?? .zero
    }

    private static func initials(from name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first?.uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }

    private func configureViews() {
        window.windowLevel = .normal + 1
        window.backgroundColor = .clear
        window.rootViewController = rootController

        let content = rootController.view!
        content.backgroundColor = UIColor(red: 0.18, green: 0.19, blue: 0.27, alpha: 1)
        content.layer.cornerRadius = 12
        content.layer.masksToBounds = true
        content.isAccessibilityElement = true
        content.accessibilityLabel = "Return to call"
        content.accessibilityTraits = .button

        initialsLabel.font = .boldSystemFont(ofSize: 24)
        initialsLabel.textColor = .white
        initialsLabel.textAlignment = .center
        nameLabel.font = .systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center

        [initialsLabel, nameLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview($0)
        }
        NSLayoutConstraint.activate([
            initialsLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: -8),
            nameLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -6),
            nameLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8)
        ])

        content.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
        content.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(didPan(_:))))
    }

    private func makeVideoView() -> RTCMTLVideoView {
        let view = RTCMTLVideoView(frame: rootController.view.bounds)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.videoContentMode = .scaleAspectFill
        view.isUserInteractionEnabled = false
        rootController.view.insertSubview(view, at: 0)
        videoView = view
        return view
    }

    @objc private func didTap() {
        onTap()
    }

    @objc private func didPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: nil)
        window.frame.origin.x += translation.x
        window.frame.origin.y += translation.y
        gesture.setTranslation(.zero, in: nil)
        guard gesture.state == .ended || gesture.state == .cancelled else { return }
        originBeforeKeyboard = nil
        let origin = Self.snappedOrigin(for: window.frame, in: window.screen.bounds, insets: Self.safeAreaInsets)
        UIView.animate(withDuration: 0.2) { self.window.frame.origin = origin }
    }

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let keyboard = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let screen = window.screen.bounds
        var origin = window.frame.origin
        if keyboard.minY < screen.maxY {
            let highestAllowedBottom = keyboard.minY - Self.margin
            if window.frame.maxY > highestAllowedBottom {
                if originBeforeKeyboard == nil { originBeforeKeyboard = origin }
                origin.y = max(Self.safeAreaInsets.top + Self.margin, highestAllowedBottom - window.frame.height)
            }
        } else if let original = originBeforeKeyboard {
            origin = original
            originBeforeKeyboard = nil
        }
        UIView.animate(withDuration: 0.25) { self.window.frame.origin = origin }
    }
}
