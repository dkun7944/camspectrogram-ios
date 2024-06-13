//
//  AudioEngine.swift
//  Camtrogram
//
//  Created by Daniel Kuntz on 6/13/24.
//

import AVFoundation

var sampleRate: Int {
    return 44_100
}

class AudioEngine: NSObject, ObservableObject {

    static let shared = AudioEngine()

    // MARK: - Variables

    private let engine = AVAudioEngine()
    let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)

    private var semitones: Float = 0
    private var cents: Float = 0

    @Published var playheadProgress: Float = 0.0

    var sound: Sound? {
        didSet {
            soundPlayhead = 0
        }
    }

    var playing: Bool {
        return isPlaying
    }

    var scrubbing: Bool {
        get {
            return isScrubbing
        }

        set {
            isScrubbing = newValue
            if newValue {
                if scrubResynthesis == nil, let sound = sound {
                    scrubResynthesis = ScrubbingResynthesis(sound: sound,
                                                            playhead: soundPlayhead)
                }
            }
        }
    }

    var frozen: Bool {
        get {
            return isFrozen
        }

        set {
            isFrozen = newValue
            scrubbing = frozen
            if isPlaying && isFrozen {
                stopPlaying()
            }
        }
    }

    @objc class func sharedInstance() -> AudioEngine {
        return AudioEngine.shared
    }

    override init() {
        super.init()
        start()
    }

    func start() {
        engine.attach(srcNode)
        engine.connect(srcNode, to: engine.outputNode, format: format)

        do {
            try engine.start()
        } catch {
            print(error.localizedDescription)
        }

        // Configure AVAudioSession
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                            mode: .default,
                                                            options: [.allowAirPlay,
                                                                      .allowBluetoothA2DP,
                                                                      .mixWithOthers])
            let duration = 128 / Double(sampleRate)
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(duration)
            try AVAudioSession.sharedInstance().setPreferredSampleRate(Double(sampleRate))
            try AVAudioSession.sharedInstance().setActive(true, options: [])
        } catch let error {
            print("Error starting AVAudioSession: \(error.localizedDescription)")
        }
    }

    func reset() {
        stopPlaying()
        scrubbing = false
        frozen = false
        sound = nil
        scrubFade = 0
        playPauseFade = 0
        loopingEnabled = false
        loopRange = nil
        scrubResynthesis = nil
    }

    func startPlaying() {
        if soundPlayhead == (sound?.bufferL.count ?? 0) {
            soundPlayhead = 0
        }
        isPlaying = true
        isScrubbing = false
    }

    func stopPlaying() {
        isPlaying = false
    }

    func setLoopProgressRange(_ range: ClosedRange<Float>) {
        guard let sound = sound else {
            return
        }

        let lowerSamp = Int(range.lowerBound * Float(sound.bufferL.count))
        let upperSamp = Int(range.upperBound * Float(sound.bufferL.count))
        loopRange = lowerSamp...upperSamp
    }

    func enableLooping() {
        loopingEnabled = true
    }

    func disableLooping() {
        loopingEnabled = false
    }

    func seek(offset: TimeInterval) {
        let sampleOffset = Int(round(offset * Double(sampleRate)))
        let bufferCount = sound?.bufferL.count ?? 1
        soundPlayhead = (soundPlayhead + sampleOffset).clamped(to: 0...(bufferCount-1))
        playheadProgress = Float(soundPlayhead) / Float(bufferCount)
    }

    func scrub(toProgress progress: Float) {
        if isPlaying {
            stopPlaying()
        }

        guard let sound = sound else {
            return
        }

        if !isPlaying && playPauseFade <= 0.0 {
            soundPlayhead = Int(progress * Float(sound.bufferL.count))
        }
        scrubResynthesis?.setPlayheadPosition(soundPlayhead)
    }
}

private(set) var soundPlayhead: Int = 0
private(set) var loopRange: ClosedRange<Int>?
private(set) var loopingEnabled: Bool = false
private(set) var isPlaying: Bool = false
private(set) var isScrubbing: Bool = false
private(set) var isFrozen: Bool = false
private(set) var scrubResynthesis: ScrubbingResynthesis?
private(set) var scrubFade: Float = 0.0
private(set) var playPauseFade: Float = 0.0

private let FADE_AMT: Int = 512

private let srcNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
    let engine = AudioEngine.shared

    let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
    let leftPointer: UnsafeMutableBufferPointer<Float32> = UnsafeMutableBufferPointer(abl[0])
    let rightPointer: UnsafeMutableBufferPointer<Float32> = UnsafeMutableBufferPointer(abl[1])
    let frameCountInt = Int(frameCount)

    guard let sound = engine.sound,
          soundPlayhead + 1 < sound.bufferL.count else {
        return populateWithEmpty(leftPointer: leftPointer,
                                 rightPointer: rightPointer,
                                 frameCount: frameCountInt)
    }

    if scrubFade <= 0.0 && !isScrubbing {
        scrubResynthesis = nil
    }

    if let scrubResynthesis = scrubResynthesis, playPauseFade <= 0.0 {
        for i in 0..<frameCountInt {
            if isScrubbing && scrubFade < 1.0 {
                scrubFade = (scrubFade + (1.0 / Float(FADE_AMT)))
            } else if !isScrubbing && scrubFade > 0.0 {
                scrubFade = (scrubFade - (1.0 / Float(FADE_AMT)))
            }

            var out = scrubResynthesis.popNextSample()

            leftPointer[i] = out.0 * scrubFade
            rightPointer[i] = out.1 * scrubFade
        }

        return noErr
    }

    if !isPlaying && playPauseFade <= 0.0 {
        return populateWithEmpty(leftPointer: leftPointer,
                                 rightPointer: rightPointer,
                                 frameCount: frameCountInt)
    }

    for i in 0..<frameCountInt {
        if isPlaying && playPauseFade < 1.0 {
            playPauseFade = (playPauseFade + (1.0 / Float(FADE_AMT)))
        } else if !isPlaying && playPauseFade > 0.0 {
            playPauseFade = (playPauseFade - (1.0 / Float(FADE_AMT)))
        }

        if soundPlayhead >= sound.bufferL.count {
            let progress = Float(soundPlayhead) / Float(sound.bufferL.count)
            engine.playheadProgress = progress
            isPlaying = false
            playPauseFade = 0.0
            return noErr
        }

        if loopingEnabled,
            let loopRange = loopRange,
           soundPlayhead > loopRange.upperBound {
            soundPlayhead = loopRange.lowerBound
        }

        let rawL = sound.bufferL[soundPlayhead] * playPauseFade
        let rawR = sound.bufferR[soundPlayhead] * playPauseFade

        leftPointer[i] = rawL
        rightPointer[i] = rawR

        soundPlayhead += 1
    }

    if isPlaying {
        let progress = Float(soundPlayhead) / Float(sound.bufferL.count)
        engine.playheadProgress = progress
    }

    return noErr
}

private func populateWithEmpty(leftPointer: UnsafeMutableBufferPointer<Float32>,
                               rightPointer: UnsafeMutableBufferPointer<Float32>,
                               frameCount: Int) -> OSStatus {
    for i in 0..<frameCount {
        leftPointer[i] = 0
        rightPointer[i] = 0
    }
    return noErr
}
