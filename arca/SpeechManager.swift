import Foundation
import SwiftUI
import Combine
import Speech
import AVFoundation

final class SpeechManager: ObservableObject {
    @Published var isRecording = false
    @Published var permissionGranted = false

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Letzten guten Text merken – verhindert Überschreiben mit leerem Ergebnis beim Stoppen
    private var lastRecognized: String = ""
    private var prefix: String = ""
    var onTextUpdate: ((String) -> Void)?

    private var timeoutTimer: Timer?
    private var silenceTimer: Timer?
    private let maxRecordingDuration: TimeInterval = 30
    private let silenceTimeout: TimeInterval = 5

    init() {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
        requestPermission()
    }

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                self.permissionGranted = (status == .authorized)
            }
        }
    }

    func startRecording(prefix: String) {
        guard !isRecording, permissionGranted else { return }
        self.prefix = prefix
        self.lastRecognized = ""

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                // Nur updaten wenn Text nicht leer ist
                if !text.isEmpty {
                    self.lastRecognized = text
                    DispatchQueue.main.async {
                        self.onTextUpdate?(self.prefix + text)
                        self.resetSilenceTimer()
                    }
                }
            }
            if result?.isFinal == true {
                self.stopRecording()
            }
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        DispatchQueue.main.async { self.isRecording = true }

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
            self?.stopRecording()
        }
        resetSilenceTimer()
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            self?.stopRecording()
        }
    }

    func stopRecording() {
        guard isRecording || audioEngine.isRunning else { return }

        timeoutTimer?.invalidate()
        timeoutTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false)

        // Letzten guten Text sicherstellen
        let finalText = prefix + lastRecognized
        DispatchQueue.main.async {
            if !self.lastRecognized.isEmpty {
                self.onTextUpdate?(finalText)
            }
            self.isRecording = false
        }
    }

    func toggle(appendingTo currentText: String, onUpdate: @escaping (String) -> Void) {
        onTextUpdate = onUpdate
        if isRecording {
            stopRecording()
        } else {
            let pre = currentText.isEmpty ? "" : currentText + " "
            startRecording(prefix: pre)
        }
    }
}
