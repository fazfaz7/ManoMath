import AVFoundation

@MainActor
final class SoundManager {
    static let shared = SoundManager()

    private var correctPlayer: AVAudioPlayer?
    private var incorrectPlayer: AVAudioPlayer?

    private init() {
        correctPlayer = loadPlayer(name: "correct", ext: "mp3")
        incorrectPlayer = loadPlayer(name: "not_correct", ext: "wav")
    }

    private func loadPlayer(name: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        return player
    }

    private func ensureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient)
        try? session.setActive(true)
    }

    /// Call during loading screen to warm up audio — plays at zero volume so sounds are instant later
    func warmUp() {
        ensureAudioSession()
        correctPlayer?.volume = 0
        correctPlayer?.play()
        correctPlayer?.stop()
        correctPlayer?.volume = 1
        incorrectPlayer?.volume = 0
        incorrectPlayer?.play()
        incorrectPlayer?.stop()
        incorrectPlayer?.volume = 1
    }

    func playCorrect() {
        ensureAudioSession()
        correctPlayer?.currentTime = 0
        correctPlayer?.play()
    }

    func playIncorrect() {
        ensureAudioSession()
        incorrectPlayer?.currentTime = 0
        incorrectPlayer?.play()
    }
}
