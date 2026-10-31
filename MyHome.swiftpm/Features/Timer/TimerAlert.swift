import AudioToolbox

/// タイマーが終わった時の音（アプリを開いている間だけ鳴る。消音スイッチや音量の設定に従う）。
enum TimerAlert {
    static func play() {
        AudioServicesPlaySystemSound(SystemSoundID(1005))
    }
}
