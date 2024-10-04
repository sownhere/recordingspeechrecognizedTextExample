//
//  VoiceAudioViewController.swift
//  RecordingExample
//
//  Created by SownFrenky on 10/4/24.
//

import UIKit
import Speech

class VoiceAudioViewController: UIViewController, ObservableObject, SFSpeechRecognizerDelegate {
    
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioSession: AVAudioSession?
    
    @Published var recognizedText: String? {
        didSet {
            DispatchQueue.main.async {
                self.recognizedTextLabel.text = self.recognizedText
            }
        }
    }
    
    @Published var isProcessing: Bool = false
    
    // Add a UILabel to display recognized text
    private let recognizedTextLabel: UILabel = {
        let label = UILabel()
        label.text = "Recognized text will appear here"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        // Add tap gesture recognizer
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        tapGR.delegate = self
        tapGR.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGR)
        
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))

        setupUI()
        requestTranscribePermissions()
    }
    
    // Setup UI method to configure UILabel
    private func setupUI() {
        self.view.addSubview(recognizedTextLabel)
        
        // Set constraints for recognizedTextLabel
        NSLayoutConstraint.activate([
            recognizedTextLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recognizedTextLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            recognizedTextLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            recognizedTextLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }

    func requestTranscribePermissions() {
        SFSpeechRecognizer.requestAuthorization { [unowned self] authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    print("Good to go!")
                    self.start()
                } else {
                    print("Transcription permission was declined.")
                }
            }
        }
    }
    
    func start() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession?.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Couldn't configure the audio session properly")
        }
        
        inputNode = audioEngine.inputNode
        
        speechRecognizer = SFSpeechRecognizer()
        print("Supports on device recognition: \(speechRecognizer?.supportsOnDeviceRecognition == true ? "✅" : "🔴")")
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable,
              let recognitionRequest = recognitionRequest,
              let inputNode = inputNode else {
            assertionFailure("Unable to start the speech recognition!")
            return
        }
        
        speechRecognizer.delegate = self
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            recognitionRequest.append(buffer)
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result = result {
                self?.recognizedText = result.bestTranscription.formattedString
            }
            
            guard error != nil || result?.isFinal == true else { return }
            self?.stop()
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isProcessing = true
        } catch {
            print("Couldn't start audio engine!")
            stop()
        }
    }
    
    func stop() {
        print("### Stop")
        
        recognitionTask?.cancel()
        
        audioEngine.stop()
        
        inputNode?.removeTap(onBus: 0)
        try? audioSession?.setActive(false)
        audioSession = nil
        inputNode = nil
        
        isProcessing = false
        
        recognitionRequest = nil
        recognitionTask = nil
        speechRecognizer = nil
    }
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            print("✅ Available")
        } else {
            print("🔴 Unavailable")
            recognizedText = "Text recognition unavailable. Sorry!"
            stop()
        }
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        self.dismiss(animated: false)
    }
}

extension VoiceAudioViewController: UIGestureRecognizerDelegate { }
