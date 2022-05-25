//
//  AlphaVideoView.swift
//  AlphaVideoSwift
//
//  Created by lvpengwei on 2022/5/25.
//  Copyright © 2022 kou. All rights reserved.
//

import AVFoundation
import UIKit

public enum AlphaVedioPlayerState: Int {
    /// 播放失败
    case failed
    /// 缓冲中
    case buffering
    /// 将要播放
    case readyToPlay
    /// 播放中
    case playing
    /// 暂停播放
    case stopped
    /// 播放完毕
    case finished
    /// 未知
    case unknown
}

public protocol AlphaVedioPlayerDelegate: NSObjectProtocol {
    /// 播放失败的代理方法
    func vedioPlayerFailed(state: AlphaVedioPlayerState, vedioPlayer: AlphaVideoView)
    /// 准备播放的代理方法
    func vedioPlayerReady(state: AlphaVedioPlayerState, vedioPlayer: AlphaVideoView)
    /// 播放完毕的代理方法
    func playerFinished(vedioPlayer: AlphaVideoView)
}

private var PlayViewStatusObservationContext = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
public class AlphaVideoView: UIView {
    public var axis: NSLayoutConstraint.Axis = .vertical

    private(set) var state: AlphaVedioPlayerState = .unknown
    private var loopCount:Int = 0
    public var loops:Int = 0

    public var delegate: AlphaVedioPlayerDelegate?

    deinit {
        self.playerItem = nil
    }

    override public class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer { return layer as! AVPlayerLayer }
    private var player: AVPlayer? { return playerLayer.player }

    /// 网络地址 或者本地名称
   public var urlStr: String = "" {
        didSet {
            loadVideo()
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    public func play() {
        player?.play()
    }

    public func pause() {
        player?.pause()
    }

    private func commonInit() {
        playerLayer.pixelBufferAttributes = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        playerLayer.player = AVPlayer()
      
    }


    private var asset: AVAsset?
    private func loadVideo() {
        guard let videoURL = urlStr.hasPrefix("http") ? URL(string: urlStr) : Bundle.main.url(forResource: urlStr, withExtension: "mp4") else { return }
        asset = AVURLAsset(url: videoURL)
        asset?.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) { [weak self] in
            guard let self = self, let asset = self.asset else { return }
            DispatchQueue.main.async {
                self.playerItem = AVPlayerItem(asset: asset)
            }
        }
    }

    private var playerItem: AVPlayerItem? {
        willSet {
            if playerItem == newValue {
                return
            }
            if playerItem != nil {
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
                playerItem?.removeObserver(self, forKeyPath: "status")
                playerItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
                playerItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty")
                playerItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
            }
            loopCount = 0
            player?.pause()
        }
        didSet {
            if playerItem != nil {
                NotificationCenter.default.addObserver(self, selector: #selector(moviePlayDidEnd(_:)), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
                playerItem?.addObserver(self, forKeyPath: "status", context: PlayViewStatusObservationContext)
                playerItem?.addObserver(self, forKeyPath: "loadedTimeRanges", context: PlayViewStatusObservationContext)
                playerItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", context: PlayViewStatusObservationContext)
                playerItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", context: PlayViewStatusObservationContext)
            }
            player?.seek(to: CMTime.zero)
            setupPlayerItem()
            player?.replaceCurrentItem(with: playerItem)
        }
    }
    
    public func resetPlay(){
        player?.seek(to: CMTime.zero) { _ in
            self.player?.play()
        }
    }

    @objc
    func moviePlayDidEnd(_ notification: Notification) {
        if loops == 0 {
            resetPlay()
        }else if loops > 0 && loops > loopCount + 1{
            resetPlay()
            loopCount += 1
        }else{
            playerItem = nil
            self.delegate?.playerFinished(vedioPlayer: self)
        }
    }

    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if context == PlayViewStatusObservationContext {
            if keyPath == "status" {
                let status: AVPlayer.Status = AVPlayer.Status(rawValue: (change?[.kindKey]) as? Int ?? 0) ?? .unknown
                switch status {
                case .unknown:
                    state = .buffering
                    break
                case .readyToPlay:
                    state = .readyToPlay
                    delegate?.vedioPlayerReady(state: .readyToPlay, vedioPlayer: self)
                    break
                case .failed:
                    state = .failed
                    delegate?.vedioPlayerReady(state: .failed, vedioPlayer: self)
                    break
                @unknown default:
                    break
                }
            } else if keyPath == "loadedTimeRanges" {
                let timeInterval = availableDuration()
                let duration = playerItem?.duration ?? .zero
                let totalDuration = CMTimeGetSeconds(duration)
                print("缓冲进度 \(timeInterval)  \(totalDuration)")
            } else if keyPath == "playbackBufferEmpty" {//缓冲区为空的时候
                if self.playerItem?.isPlaybackBufferEmpty ?? false {
                    state = .buffering
                    
                }
            } else if keyPath == "playbackLikelyToKeepUp" {
                if self.playerItem?.isPlaybackLikelyToKeepUp ?? false && self.state == .buffering {
                    self.state = .playing
                }
            }
        }
    }


    private func setupPlayerItem() {
        guard let playerItem = playerItem else { return }
        let tracks = playerItem.asset.tracks
        guard tracks.count > 0 else {
            print("no tracks")
            return
        }
        var videoSize: CGSize = .zero
        if axis == .vertical {
            videoSize = CGSize(width: tracks[0].naturalSize.width, height: tracks[0].naturalSize.height * 0.5)
        } else {
            videoSize = CGSize(width: tracks[0].naturalSize.width * 0.5, height: tracks[0].naturalSize.height)
        }

        guard videoSize.width > 0 && videoSize.height > 0 else {
            print("video size is zero")
            return
        }
        let composition = AVMutableVideoComposition(asset: playerItem.asset, applyingCIFiltersWithHandler: { [weak self] request in
            let sourceRect = CGRect(origin: .zero, size: videoSize)

            let filter = AlphaFrameFilter()
            if self?.axis == .vertical {
                let alphaRect = sourceRect.offsetBy(dx: 0, dy: sourceRect.height)
                filter.inputImage = request.sourceImage.cropped(to: alphaRect)
                    .transformed(by: CGAffineTransform(translationX: 0, y: -sourceRect.height))
            } else {
                let alphaRect = sourceRect.offsetBy(dx: sourceRect.width, dy: 0)
                filter.inputImage = request.sourceImage.cropped(to: alphaRect)
                    .transformed(by: CGAffineTransform(translationX: -sourceRect.width, y: 0))
            }

            filter.maskImage = request.sourceImage.cropped(to: sourceRect)
            return request.finish(with: filter.outputImage!, context: nil)
        })

        composition.renderSize = videoSize
        playerItem.videoComposition = composition
        playerItem.seekingWaitsForVideoCompositionRendering = true
    }

    ///缓冲进度
    func availableDuration() -> TimeInterval {
        guard let loadedTimeRanges = playerItem?.loadedTimeRanges,
              let timeRange = loadedTimeRanges.first?.timeRangeValue
        else {
            return 0
        }

        let startSeconds = CMTimeGetSeconds(timeRange.start)
        let durationSeconds = CMTimeGetSeconds(timeRange.duration)

        let result = startSeconds + durationSeconds

        return result
    }
}
