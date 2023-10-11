// Copyright: 2021, Ableton AG, Berlin. All rights reserved.

import AVFAudio
import CoreAudio
import Foundation
import SwiftUI
import Starscream

func parse(message: String) -> [String: Double] {
    let terms = message.split(separator: " ")
    var data: [String: Double] = [:]

    for i in stride(from: 0, to: terms.count, by: 2) {
        let key = String(terms[i])
        let value = String(terms[i + 1])
        data[key] = Double(value)
    }
    return data
}

class AudioEngineController: ObservableObject, WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .text(let message):
            let data = parse(message:message)
            if (data["tempo"] != nil) {
                self.tempo = data["tempo"]!
            }
            if (data["Q"] != nil) {
                self.quantum = data["Q"]!
            }
        default:
            break
        }
    }
    
  @Published var isPlaying = false {
    didSet {
      if isPlaying {
        audioEngine?.requestTransportStart()
      } else {
        audioEngine?.requestTransportStop()
      }
    }
  }

  @Published private(set) var beatTime = 0.0

  @Published var tempo = 120.0 {
    didSet {
      audioEngine?.proposeTempo(tempo)
    }
  }

  @Published var quantum = 4.0 {
    didSet {
      audioEngine?.setQuantum(quantum)
    }
  }

  var link: ABLLinkRef? {
    audioEngine?.linkRef()
  }

  func startAudioEngine() {
    audioEngine?.start()
  }

  func stopAudioEngine() {
    audioEngine?.stop()
  }

  private let audioEngine = AudioEngine.init(tempo: 120)
  private var timer: Timer?
    private var socket: WebSocket!
    
  init() {
      var request = URLRequest(url: URL(string: "https://link.chee.party/salad-nocup")!)
      request.timeoutInterval = 5
      self.socket = WebSocket(request: request)
      socket.delegate = self
      socket.connect()
    // Set ABLLink Callbacks to update `tempo` and `isPlaying` when those properties change in Link
    ABLLinkSetSessionTempoCallback(
      audioEngine?.linkRef(),
      { tempo, context in
        Unmanaged<AudioEngineController>.fromOpaque(context!).takeUnretainedValue().tempo = tempo
      },
      Unmanaged.passUnretained(self).toOpaque()
    )

    ABLLinkSetStartStopCallback(
      audioEngine?.linkRef(),
      { isPlaying, context in
        Unmanaged<AudioEngineController>.fromOpaque(context!).takeUnretainedValue().isPlaying =
          isPlaying
      },
      Unmanaged.passUnretained(self).toOpaque()
    )

    // Regularly update the beat time to be displayed in the UI
    timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
      let sessionState = ABLLinkCaptureAppSessionState(self.audioEngine?.linkRef())
      self.beatTime = ABLLinkBeatAtTime(sessionState, mach_absolute_time(), self.quantum)
    }
  }
}
