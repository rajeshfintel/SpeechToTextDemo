
import UIKit
import Speech

protocol SpeechControllerProtocol: class {
    func recognitionDidFinish(with text: String)
    func speechServiceNotAvailable(msg: String)
    func speechServiceStopped(msg: String)
}

extension SpeechControllerProtocol{
    func speechServiceStopped(msg: String){
        
    }
}

class SpeechController: UIViewController {
    
    // MARK:- Variables -
    weak var delegate : SpeechControllerProtocol?
    private var speechRecognizer : SFSpeechRecognizer? = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine : AVAudioEngine?
    private var lastTranscript = ""
    
    deinit {
        self.stop()
    }
    
    @IBAction func startSpeech(_ sender: Any) {
        self.startRecognition()
    }
}

// MARK:- Speech Recognizer Delegates -
extension SpeechController: SFSpeechRecognitionTaskDelegate, SFSpeechRecognizerDelegate {
    
    // Called for all recognitions, including non-final hypothesis
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        self.transcriptHandeling(transcription)
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.start), object: nil)
        if !self.isAlreadyStopped {
            self.perform(#selector(self.start), with: nil, afterDelay: 2)
        }
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        print("Service Stop")
        self.delegate?.speechServiceStopped(msg: "")
        //        self.transcriptHandeling(recognitionResult.bestTranscription)
    }
    
    /// Transcript Handeling
    private func transcriptHandeling(_ transcript: SFTranscription) {
        let script = transcript.formattedString.replacingOccurrences(of: self.lastTranscript, with: "")
        self.lastTranscript = transcript.formattedString
        self.delegate?.recognitionDidFinish(with: script)
    }
    
    /// Availability Did Change
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print(#function)
    }
}

// MARK:- Private Functions -
extension SpeechController {
    
    /// Start Audio Engine
    private func startAudioEngine() {
        if self.audioEngine == nil {
            self.audioEngine = AVAudioEngine()
        }
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)

        } catch {
            print("audioSession properties weren't set because of an error.")
        }
    }
    
    /// Create Request to Start Recognizer
    private func createRequestToStartRecognizer(){
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine!.inputNode
        
        guard let recognitionRequest = self.recognitionRequest else {
            self.delegate?.speechServiceNotAvailable(msg: #function)
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        print("interactionIdentifier=========")
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.interactionIdentifier = "test"
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            if result != nil {
                print("output respons ===",result?.bestTranscription.formattedString as Any)
                isFinal = (result?.isFinal)!
            }
            
            print("number of inputs ===",inputNode.numberOfInputs)
            if error != nil || isFinal {
                self.audioEngine!.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
            }
        })
        
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine?.prepare()
        do {
            try audioEngine?.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
    }
    
    /// Start Recognizer
    @objc private func start() {
        self.stop()
        
        guard let recognizer = self.speechRecognizer, recognizer.isAvailable else {
            self.delegate?.speechServiceNotAvailable(msg: "Not Available")
            return
        }
        
        self.startAudioEngine()
        self.createRequestToStartRecognizer()
        if let request = self.recognitionRequest {
            recognizer.recognitionTask(with: request, delegate: self)
        }
    }
    
    /// Stop Recognizer
    private func stop() {
        
        self.audioEngine?.stop()
        self.audioEngine?.inputNode.removeTap(onBus: 0)
        self.recognitionRequest?.endAudio()
        self.recognitionTask?.finish()
        self.recognitionRequest = nil
        self.recognitionTask = nil
    }
    
    /// Check already stopped
    private var isAlreadyStopped: Bool {
        return !(self.audioEngine?.isRunning ?? true) || recognitionRequest == nil || self.recognitionTask == nil
    }
}

// MARK:- Public Functions -
extension SpeechController {
    
    /// Start Recognition
    func startRecognition() {
        self.checkAuthorization { (success) in
            if success {
                self.start()
            }
        }
    }
    
    /// Stop Recognition
    func stopRecognition() {
        self.stop()
    }
    
    /// Check Speech API Authorization
    func checkAuthorization(_ completion: @escaping ((_ success: Bool) -> Void)) {
        SFSpeechRecognizer.requestAuthorization { (status) in
            switch(status) {
            case .authorized:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                completion(false)
            case .restricted:
                completion(false)
            }
        }
    }
}
