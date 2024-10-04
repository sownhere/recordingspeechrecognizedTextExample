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
        
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showLanguageSelection()
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

    // Show a language selection dialog for the user to choose
    private func showLanguageSelection() {
        let alert = UIAlertController(title: "Select Language", message: "Please choose a language for speech recognition", preferredStyle: .actionSheet)
        
        // Tiếng Việt
        alert.addAction(UIAlertAction(title: "Tiếng Việt", style: .default, handler: { _ in
            self.setSpeechRecognizerLocale(localeIdentifier: "vi_VN")
        }))
        
        // English (US)
        alert.addAction(UIAlertAction(title: "English (US)", style: .default, handler: { _ in
            self.setSpeechRecognizerLocale(localeIdentifier: "en_US")
        }))
        
        // English (UK)
        alert.addAction(UIAlertAction(title: "English (UK)", style: .default, handler: { _ in
            self.setSpeechRecognizerLocale(localeIdentifier: "en_GB")
        }))
        
        // Deutsch (Germany)
        alert.addAction(UIAlertAction(title: "Deutsch (DE)", style: .default, handler: { _ in
            self.setSpeechRecognizerLocale(localeIdentifier: "de_DE")
        }))
        
        // Cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    // Set the SFSpeechRecognizer locale and start recognition process
    private func setSpeechRecognizerLocale(localeIdentifier: String) {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        
        // Check if speech recognizer is available for the selected locale
        guard let speechRecognizer = self.speechRecognizer, speechRecognizer.isAvailable else {
            self.recognizedText = "Speech recognition is not available for the selected language."
            return
        }
        
        requestTranscribePermissions()
    }
    
    func requestTranscribePermissions() {
        SFSpeechRecognizer.requestAuthorization { [unowned self] authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    print("Permission granted")
                    self.start()
                } else {
                    print("Permission denied")
                    self.recognizedText = "Speech recognition permission was declined."
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
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable,
              let recognitionRequest = recognitionRequest,
              let inputNode = inputNode else {
            assertionFailure("Unable to start the speech recognition!")
            return
        }
        
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

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        self.dismiss(animated: false)
    }
}

extension VoiceAudioViewController: UIGestureRecognizerDelegate { }
