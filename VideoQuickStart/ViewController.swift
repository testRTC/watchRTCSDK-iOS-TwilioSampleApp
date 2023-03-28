//
//  ViewController.swift
//  VideoQuickStart
//
//  Copyright © 2016-2019 Twilio, Inc. All rights reserved.
//

import UIKit

import TwilioVideo

import WatchRTC_SDK

class ViewController: UIViewController {

    // MARK:- View Controller Members
    
    // Configure access token manually for testing, if desired! Create one manually in the console
    // at https://www.twilio.com/console/video/runtime/testing-tools
    var accessToken = "TWILIO_ACCESS_TOKEN"
  
    // Configure remote URL to fetch token from
    let tokenUrl = "http://localhost:8000/token.php"
    
    // Video SDK components
    var room: Room?
    var camera: CameraSource?
    var localVideoTrack: LocalVideoTrack?
    var localAudioTrack: LocalAudioTrack?
    var remoteParticipant: RemoteParticipant?
    var remoteView: VideoView?
    
    private var watchRtc: WatchRTC?
    
    // MARK:- UI Element Outlets and handles
    
    // `VideoView` created from a storyboard
    @IBOutlet weak var previewView: VideoView!

    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var roomTextField: UITextField!
    @IBOutlet weak var roomLine: UIView!
    @IBOutlet weak var roomLabel: UILabel!
    @IBOutlet weak var micButton: UIButton!
    
    deinit {
        // We are done with camera
        if let camera = self.camera {
            camera.stopCapture()
            self.camera = nil
        }
    }

    // MARK:- UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "QuickStart"
        self.messageLabel.adjustsFontSizeToFitWidth = true;
        self.messageLabel.minimumScaleFactor = 0.75;

        if PlatformUtils.isSimulator {
            self.previewView.removeFromSuperview()
        } else {
            // Preview our local camera track in the local video preview view.
            self.startPreview()
        }
        
        self.connectButton.adjustsImageWhenDisabled = true;
        
        // Disconnect and mic button will be displayed when the Client is connected to a Room.
        self.disconnectButton.isHidden = true
        self.micButton.isHidden = true
        
        self.roomTextField.autocapitalizationType = .none
        self.roomTextField.delegate = self
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(ViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        
        self.watchRtc = WatchRTC(dataProvider: self)
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return self.room != nil
    }
    
    func setupRemoteVideoView() {
        // Creating `VideoView` programmatically
        self.remoteView = VideoView(frame: CGRect.zero, delegate: self)

        self.view.insertSubview(self.remoteView!, at: 0)
        
        // `VideoView` supports scaleToFill, scaleAspectFill and scaleAspectFit
        // scaleAspectFit is the default mode when you create `VideoView` programmatically.
        self.remoteView!.contentMode = .scaleAspectFit;

        let centerX = NSLayoutConstraint(item: self.remoteView!,
                                         attribute: NSLayoutConstraint.Attribute.centerX,
                                         relatedBy: NSLayoutConstraint.Relation.equal,
                                         toItem: self.view,
                                         attribute: NSLayoutConstraint.Attribute.centerX,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerX)
        let centerY = NSLayoutConstraint(item: self.remoteView!,
                                         attribute: NSLayoutConstraint.Attribute.centerY,
                                         relatedBy: NSLayoutConstraint.Relation.equal,
                                         toItem: self.view,
                                         attribute: NSLayoutConstraint.Attribute.centerY,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerY)
        let width = NSLayoutConstraint(item: self.remoteView!,
                                       attribute: NSLayoutConstraint.Attribute.width,
                                       relatedBy: NSLayoutConstraint.Relation.equal,
                                       toItem: self.view,
                                       attribute: NSLayoutConstraint.Attribute.width,
                                       multiplier: 1,
                                       constant: 0);
        self.view.addConstraint(width)
        let height = NSLayoutConstraint(item: self.remoteView!,
                                        attribute: NSLayoutConstraint.Attribute.height,
                                        relatedBy: NSLayoutConstraint.Relation.equal,
                                        toItem: self.view,
                                        attribute: NSLayoutConstraint.Attribute.height,
                                        multiplier: 1,
                                        constant: 0);
        self.view.addConstraint(height)
    }
    
    func connectToARoom() {
        
        self.connectButton.isEnabled = true;
        // Prepare local media which we will share with Room Participants.
        self.prepareLocalMedia()
        
        // Preparing the connect options with the access token that we fetched (or hardcoded).
        let connectOptions = ConnectOptions(token: accessToken) { (builder) in
            
            // Use the local media that we prepared earlier.
            builder.audioTracks = self.localAudioTrack != nil ? [self.localAudioTrack!] : [LocalAudioTrack]()
            builder.videoTracks = self.localVideoTrack != nil ? [self.localVideoTrack!] : [LocalVideoTrack]()
            
            // Use the preferred audio codec
            if let preferredAudioCodec = Settings.shared.audioCodec {
                builder.preferredAudioCodecs = [preferredAudioCodec]
            }
            
            // Use Adpative Simulcast by setting builer.videoEncodingMode to .auto if preferredVideoCodec is .auto (default). The videoEncodingMode API is mutually exclusive with existing codec management APIs EncodingParameters.maxVideoBitrate and preferredVideoCodecs
            let preferredVideoCodec = Settings.shared.videoCodec
            if preferredVideoCodec == .auto {
                builder.videoEncodingMode = .auto
            } else if let codec = preferredVideoCodec.codec {
                builder.preferredVideoCodecs = [codec]
            }
            
            // Use the preferred encoding parameters
            if let encodingParameters = Settings.shared.getEncodingParameters() {
                builder.encodingParameters = encodingParameters
            }

            // Use the preferred signaling region
            if let signalingRegion = Settings.shared.signalingRegion {
                builder.region = signalingRegion
            }
            
            // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
            // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
            builder.roomName = self.roomTextField.text
        }
        
        // Connect to the Room using the options we provided.
        room = TwilioVideoSDK.connect(options: connectOptions, delegate: self)
        
        watchRtc?.addEvent(name: "connectToARoom",
                           type: EventType.global,
                           parameters: ["roomName" : self.roomTextField.text ?? ""])
        
        logMessage(messageText: "Attempting to connect to room \(String(describing: self.roomTextField.text))")
        
        self.showRoomUI(inRoom: true)
        self.dismissKeyboard()
    }

    // MARK:- IBActions
    @IBAction func connect(sender: AnyObject) {
        self.connectButton.isEnabled = false;
        // Configure access token either from server or manually.
        // If the default wasn't changed, try fetching from server.
        if (accessToken == "TWILIO_ACCESS_TOKEN") {
            TokenUtils.fetchToken(from: tokenUrl) { [weak self]
                (token, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        let message = "Failed to fetch access token:" + error.localizedDescription
                        self?.logMessage(messageText: message)
                        self?.connectButton.isEnabled = true;
                        return
                    }
                    self?.accessToken = token;
                    self?.connectToARoom()
                }
            }
        } else {
            self.connectToARoom()
        }
    }
    
    
    @IBAction func disconnect(sender: AnyObject) {
        self.room!.disconnect()
        
        watchRtc?.addEvent(name: "disconnectFromARoom",
                           type: EventType.global,
                           parameters: ["roomName" : room?.name ?? ""])
        logMessage(messageText: "Attempting to disconnect from room \(room!.name)")
    }
    
    @IBAction func toggleMic(sender: AnyObject) {
        if (self.localAudioTrack != nil) {
            self.localAudioTrack?.isEnabled = !(self.localAudioTrack?.isEnabled)!
            
            // Update the button title
            if (self.localAudioTrack?.isEnabled == true) {
                self.micButton.setTitle("Mute", for: .normal)
            } else {
                self.micButton.setTitle("Unmute", for: .normal)
            }
        }
    }

    // MARK:- Private
    func startPreview() {
        if PlatformUtils.isSimulator {
            return
        }

        let frontCamera = CameraSource.captureDevice(position: .front)
        let backCamera = CameraSource.captureDevice(position: .back)

        if (frontCamera != nil || backCamera != nil) {

            let options = CameraSourceOptions { (builder) in
                if #available(iOS 13.0, *) {
                    // Track UIWindowScene events for the key window's scene.
                    // The example app disables multi-window support in the .plist (see UIApplicationSceneManifestKey).
                    builder.orientationTracker = UserInterfaceTracker(scene: UIApplication.shared.keyWindow!.windowScene!)
                }
            }
            // Preview our local camera track in the local video preview view.
            camera = CameraSource(options: options, delegate: self)
            localVideoTrack = LocalVideoTrack(source: camera!, enabled: true, name: "Camera")

            // Add renderer to video track for local preview
            localVideoTrack!.addRenderer(self.previewView)
            logMessage(messageText: "Video track created")

            if (frontCamera != nil && backCamera != nil) {
                // We will flip camera on tap.
                let tap = UITapGestureRecognizer(target: self, action: #selector(ViewController.flipCamera))
                self.previewView.addGestureRecognizer(tap)
            }

            camera!.startCapture(device: frontCamera != nil ? frontCamera! : backCamera!) { (captureDevice, videoFormat, error) in
                if let error = error {
                    self.logMessage(messageText: "Capture failed with error.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                } else {
                    self.previewView.shouldMirror = (captureDevice.position == .front)
                }
            }
        }
        else {
            self.logMessage(messageText:"No front or back capture device found!")
        }
    }

    @objc func flipCamera() {
        var newDevice: AVCaptureDevice?

        if let camera = self.camera, let captureDevice = camera.device {
            if captureDevice.position == .front {
                newDevice = CameraSource.captureDevice(position: .back)
            } else {
                newDevice = CameraSource.captureDevice(position: .front)
            }

            if let newDevice = newDevice {
                camera.selectCaptureDevice(newDevice) { (captureDevice, videoFormat, error) in
                    if let error = error {
                        self.logMessage(messageText: "Error selecting capture device.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                    } else {
                        self.previewView.shouldMirror = (captureDevice.position == .front)
                    }
                }
            }
        }
    }

    func prepareLocalMedia() {

        // We will share local audio and video when we connect to the Room.

        // Create an audio track.
        if (localAudioTrack == nil) {
            localAudioTrack = LocalAudioTrack(options: nil, enabled: true, name: "Microphone")

            if (localAudioTrack == nil) {
                logMessage(messageText: "Failed to create audio track")
            }
        }

        // Create a video track which captures from the camera.
        if (localVideoTrack == nil) {
            self.startPreview()
        }
   }

    // Update our UI based upon if we are in a Room or not
    func showRoomUI(inRoom: Bool) {
        self.connectButton.isHidden = inRoom
        self.roomTextField.isHidden = inRoom
        self.roomLine.isHidden = inRoom
        self.roomLabel.isHidden = inRoom
        self.micButton.isHidden = !inRoom
        self.disconnectButton.isHidden = !inRoom
        self.navigationController?.setNavigationBarHidden(inRoom, animated: true)
        UIApplication.shared.isIdleTimerDisabled = inRoom

        // Show / hide the automatic home indicator on modern iPhones.
        self.setNeedsUpdateOfHomeIndicatorAutoHidden()
    }
    
    @objc func dismissKeyboard() {
        if (self.roomTextField.isFirstResponder) {
            self.roomTextField.resignFirstResponder()
        }
    }
    
    func logMessage(messageText: String) {
        NSLog(messageText)
        messageLabel.text = messageText
    }

    func renderRemoteParticipant(participant : RemoteParticipant) -> Bool {
        // This example renders the first subscribed RemoteVideoTrack from the RemoteParticipant.
        let videoPublications = participant.remoteVideoTracks
        for publication in videoPublications {
            if let subscribedVideoTrack = publication.remoteTrack,
                publication.isTrackSubscribed {
                setupRemoteVideoView()
                subscribedVideoTrack.addRenderer(self.remoteView!)
                self.remoteParticipant = participant
                return true
            }
        }
        return false
    }

    func renderRemoteParticipants(participants : Array<RemoteParticipant>) {
        for participant in participants {
            // Find the first renderable track.
            if participant.remoteVideoTracks.count > 0,
                renderRemoteParticipant(participant: participant) {
                break
            }
        }
    }

    func cleanupRemoteParticipant() {
        if self.remoteParticipant != nil {
            self.remoteView?.removeFromSuperview()
            self.remoteView = nil
            self.remoteParticipant = nil
        }
    }
}

// MARK:- UITextFieldDelegate
extension ViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.connect(sender: textField)
        return true
    }
}

// MARK:- RoomDelegate
extension ViewController : RoomDelegate {
    func roomDidConnect(room: Room) {
        do
        {
            let con: WatchRTCConfig = WatchRTCConfig(rtcApiKey: "staging:6d3873f0-f06e-4aea-9a25-1a959ab988cc", rtcRoomId: room.name, rtcPeerId: room.localParticipant?.identity ?? "YOUR_RTC_PEER_ID", keys: ["company":["YOUR_COMPANY_NAME"]])
            watchRtc?.setConfig(config: con)
            
            try watchRtc?.connect()
            watchRtc?.setUserRating(rating: 4, ratingComment: "Your rating value")
            watchRtc?.addEvent(name: "roomDidConnect",
                               type: EventType.global,
                               parameters: ["roomName" : room.name])
        } catch {
            debugPrint(error)
        }
        
        logMessage(messageText: "Connected to room \(room.name) as \(room.localParticipant?.identity ?? "")")

        // This example only renders 1 RemoteVideoTrack at a time. Listen for all events to decide which track to render.
        for remoteParticipant in room.remoteParticipants {
            remoteParticipant.delegate = self
        }
    }

    func roomDidDisconnect(room: Room, error: Error?) {
        watchRtc?.addEvent(name: "roomDidDisconnect",
                           type: EventType.global,
                           parameters: ["roomName" : room.name])
        
        watchRtc?.disconnect()
        
        logMessage(messageText: "Disconnected from room \(room.name), error = \(String(describing: error))")
        
        self.cleanupRemoteParticipant()
        self.room = nil
        
        self.showRoomUI(inRoom: false)
    }

    func roomDidFailToConnect(room: Room, error: Error) {
        watchRtc?.addEvent(name: "roomDidFailToConnect",
                           type: EventType.global,
                           parameters: ["roomName" : room.name,
                                        "error" : error.localizedDescription])
        logMessage(messageText: "Failed to connect to room with error = \(String(describing: error))")
        self.room = nil
        
        self.showRoomUI(inRoom: false)
    }

    func roomIsReconnecting(room: Room, error: Error) {
        watchRtc?.addEvent(name: "roomIsReconnecting",
                           type: EventType.global,
                           parameters: ["roomName" : room.name,
                                        "error" : error.localizedDescription])
        logMessage(messageText: "Reconnecting to room \(room.name), error = \(String(describing: error))")
    }

    func roomDidReconnect(room: Room) {
        watchRtc?.addEvent(name: "roomDidReconnect",
                           type: EventType.global,
                           parameters: ["roomName" : room.name])
        logMessage(messageText: "Reconnected to room \(room.name)")
    }

    func participantDidConnect(room: Room, participant: RemoteParticipant) {
        watchRtc?.addEvent(name: "participantDidConnect",
                           type: EventType.global,
                           parameters: ["roomName" : room.name])
        // Listen for events from all Participants to decide which RemoteVideoTrack to render.
        participant.delegate = self

        logMessage(messageText: "Participant \(participant.identity) connected with \(participant.remoteAudioTracks.count) audio and \(participant.remoteVideoTracks.count) video tracks")
    }

    func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        watchRtc?.addEvent(name: "participantDidDisconnect",
                           type: EventType.global,
                           parameters: ["roomName" : room.name])
        logMessage(messageText: "Room \(room.name), Participant \(participant.identity) disconnected")

        // Nothing to do in this example. Subscription events are used to add/remove renderers.
    }
}

// MARK:- RemoteParticipantDelegate
extension ViewController : RemoteParticipantDelegate {

    func remoteParticipantDidPublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has offered to share the video Track.
        
        watchRtc?.addEvent(name: "remoteParticipantDidPublishVideoTrack",
                                   type: EventType.global)
        
        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) video track")
    }

    func remoteParticipantDidUnpublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has stopped sharing the video Track.

        watchRtc?.addEvent(name: "remoteParticipantDidUnpublishVideoTrack",
                                   type: EventType.global)
        
        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) video track")
    }

    func remoteParticipantDidPublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has offered to share the audio Track.
        
        watchRtc?.addEvent(name: "remoteParticipantDidPublishAudioTrack",
                                   type: EventType.global)

        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) audio track")
    }

    func remoteParticipantDidUnpublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has stopped sharing the audio Track.

        watchRtc?.addEvent(name: "remoteParticipantDidUnpublishAudioTrack",
                                   type: EventType.global)
        
        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) audio track")
    }

    func didSubscribeToVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // The LocalParticipant is subscribed to the RemoteParticipant's video Track. Frames will begin to arrive now.

        watchRtc?.addEvent(name: "didSubscribeToVideoTrack",
                                   type: EventType.global)
        
        logMessage(messageText: "Subscribed to \(publication.trackName) video track for Participant \(participant.identity)")

        if (self.remoteParticipant == nil) {
            _ = renderRemoteParticipant(participant: participant)
        }
    }
    
    func didUnsubscribeFromVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
        // remote Participant's video.
        
        watchRtc?.addEvent(name: "didUnsubscribeFromVideoTrack",
                                   type: EventType.global)
        
        logMessage(messageText: "Unsubscribed from \(publication.trackName) video track for Participant \(participant.identity)")

        if self.remoteParticipant == participant {
            cleanupRemoteParticipant()

            // Find another Participant video to render, if possible.
            if var remainingParticipants = room?.remoteParticipants,
                let index = remainingParticipants.firstIndex(of: participant) {
                remainingParticipants.remove(at: index)
                renderRemoteParticipants(participants: remainingParticipants)
            }
        }
    }

    func didSubscribeToAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's audio now.
       
        watchRtc?.addEvent(name: "didSubscribeToAudioTrack",
                                   type: EventType.global)
        
        logMessage(messageText: "Subscribed to \(publication.trackName) audio track for Participant \(participant.identity)")
    }
    
    func didUnsubscribeFromAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
        // remote Participant's audio.
        
        watchRtc?.addEvent(name: "didUnsubscribeFromAudioTrack",
                                   type: EventType.global)
        
        logMessage(messageText: "Unsubscribed from \(publication.trackName) audio track for Participant \(participant.identity)")
    }

    func remoteParticipantDidEnableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        watchRtc?.addEvent(name: "remoteParticipantDidEnableVideoTrack",
                                   type: EventType.global)
        
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) video track")
    }

    func remoteParticipantDidDisableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        watchRtc?.addEvent(name: "remoteParticipantDidDisableVideoTrack",
                                   type: EventType.global)
        
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) video track")
    }

    func remoteParticipantDidEnableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        watchRtc?.addEvent(name: "remoteParticipantDidEnableAudioTrack",
                                   type: EventType.global)
        
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) audio track")
    }

    func remoteParticipantDidDisableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        watchRtc?.addEvent(name: "remoteParticipantDidDisableAudioTrack",
                                   type: EventType.global)
        
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) audio track")
    }

    func didFailToSubscribeToAudioTrack(publication: RemoteAudioTrackPublication, error: Error, participant: RemoteParticipant) {
        watchRtc?.addEvent(name: "didFailToSubscribeToAudioTrack",
                           type: EventType.global,
                           parameters: ["error" : error.localizedDescription])
        
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) audio track, error = \(String(describing: error))")
    }

    func didFailToSubscribeToVideoTrack(publication: RemoteVideoTrackPublication, error: Error, participant: RemoteParticipant) {
        watchRtc?.addEvent(name: "didFailToSubscribeToVideoTrack",
                           type: EventType.global,
                           parameters: ["error" : error.localizedDescription])
        
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) video track, error = \(String(describing: error))")
    }
}

// MARK:- VideoViewDelegate
extension ViewController : VideoViewDelegate {
    func videoViewDimensionsDidChange(view: VideoView, dimensions: CMVideoDimensions) {
        self.view.setNeedsLayout()
    }
}

// MARK:- CameraSourceDelegate
extension ViewController : CameraSourceDelegate {
    func cameraSourceDidFail(source: CameraSource, error: Error) {
        logMessage(messageText: "Camera source failed with error: \(error.localizedDescription)")
    }
}

extension ViewController: RtcDataProvider {
    func getStats(callback: @escaping (RTCStatsReport) -> Void) {
        
        self.room?.getStats({ twilioStatsReportArray in
            let rtcStatsReport = self.mapTwilioStatsReportToWatchRTC(twilioStatsReportArray)
            
            callback(rtcStatsReport)
        })
    }

    private func mapTwilioStatsReportToWatchRTC(_ twilioStatsReportArray: [StatsReport]) -> RTCStatsReport {
        var dict = [String: RTCStat]()
        
        for twilioReport in twilioStatsReportArray {
            // iceCandidatePairStats
            for iceCandidatePairStat in twilioReport.iceCandidatePairStats {
                guard let (transportId, statsDict) = mapIceCandidatePairStats(iceCandidatePairStat) else {
                    continue
                }
                
                let rtcStat = RTCStat(timestamp: Int64(Date().timeIntervalSince1970), properties: statsDict)
                dict[transportId] = rtcStat
            }
            
            // iceCandidateStats
            for iceCandidateStat in twilioReport.iceCandidateStats {
                guard let (transportId, statsDict) = mapIceCandidateStats(iceCandidateStat) else {
                    continue
                }
                
                let rtcStat = RTCStat(timestamp: Int64(Date().timeIntervalSince1970), properties: statsDict)
                dict[transportId] = rtcStat
            }
            
            // localVideoTracksStats
            for localVideoTrackStat in twilioReport.localVideoTrackStats {
                let dictionaries = mapLocalVideoTrackStats(localVideoTrackStat)
                for (key, value) in dictionaries {
                    let rtcStat = RTCStat(timestamp: Int64(Date().timeIntervalSince1970), properties: value)
                    dict[key] = rtcStat
                }
            }
            
            // localAudioTrackStats
            for localAudioTrackStat in twilioReport.localAudioTrackStats {
                let dictionaries = mapLocalAudioTrackStats(localAudioTrackStat)
                for (key, value) in dictionaries {
                    let rtcStat = RTCStat(timestamp: Int64(Date().timeIntervalSince1970), properties: value)
                    dict[key] = rtcStat
                }
            }
            
            // remoteVideoTrackStats
            for remoteVideoTrackStat in twilioReport.remoteVideoTrackStats {
                let dictionaries = mapRemoteVideoTrackStats(remoteVideoTrackStat)
                for (key, value) in dictionaries {
                    let rtcStat = RTCStat(timestamp: Int64(Date().timeIntervalSince1970), properties: value)
                    dict[key] = rtcStat
                }
            }
            
            // remoteAudioTrackStats
            for remoteAudioTrackStat in twilioReport.remoteAudioTrackStats {
                let dictionaries = mapRemoteAudioTrackStats(remoteAudioTrackStat)
                for (key, value) in dictionaries {
                    let rtcStat = RTCStat(timestamp: Int64(Date().timeIntervalSince1970), properties: value)
                    dict[key] = rtcStat
                }
            }
        }
        
        let rtcStatsReport = RTCStatsReport(report: dict, timestamp: Int64(Date().timeIntervalSince1970))
        
        return rtcStatsReport
    }
    
    private func mapIceCandidatePairStats(_ stats: IceCandidatePairStats) -> (String, [String: Any])? {
        guard let transportId = stats.transportId else {
            return nil
        }
        
        var iceCandidatePairStatsValues = [String: Any]()
        
        iceCandidatePairStatsValues["id"] = transportId
        iceCandidatePairStatsValues["type"] = "candidate-pair"
        
        var state: String = ""
        switch stats.state {
        case .succeeded:
            state = "succeeded"
        case .frozen:
            state = "frozen"
        case .waiting:
            state = "waiting"
        case .inProgress:
            state = "in-progress"
        case .failed:
            state = "failed"
        case .cancelled:
            state = "cancelled"
        case .unknown:
            state = "unknown"
        @unknown default:
            break
        }
        
        iceCandidatePairStatsValues["state"] = state
        
        iceCandidatePairStatsValues["activeCandidatePair"] = stats.isActiveCandidatePair
        iceCandidatePairStatsValues["relayProtocol"] = stats.relayProtocol
        iceCandidatePairStatsValues["localCandidateId"] = stats.localCandidateId
        iceCandidatePairStatsValues["localCandidateIp"] = stats.localCandidateIp
        iceCandidatePairStatsValues["remoteCandidateId"] = stats.remoteCandidateId
        iceCandidatePairStatsValues["remoteCandidateIp"] = stats.remoteCandidateIp
        iceCandidatePairStatsValues["priority"] = stats.priority
        iceCandidatePairStatsValues["isNominated"] = stats.isNominated
        iceCandidatePairStatsValues["isWritable"] = stats.isWritable
        iceCandidatePairStatsValues["isReadable"] = stats.isReadable
        iceCandidatePairStatsValues["bytesReceived"] = stats.bytesReceived
        iceCandidatePairStatsValues["totalRoundTripTime"] = stats.totalRoundTripTime
        iceCandidatePairStatsValues["currentRoundTripTime"] = stats.currentRoundTripTime
        iceCandidatePairStatsValues["availableOutgoingBitrate"] = stats.availableOutgoingBitrate
        iceCandidatePairStatsValues["availableIncomingBitrate"] = stats.availableIncomingBitrate
        iceCandidatePairStatsValues["requestsReceived"] = stats.requestsReceived
        iceCandidatePairStatsValues["bytesSent"] = stats.bytesSent
        iceCandidatePairStatsValues["requestsSent"] = stats.requestsSent
        iceCandidatePairStatsValues["responsesReceived"] = stats.responsesReceived
        iceCandidatePairStatsValues["responsesSent"] = stats.responsesSent
        iceCandidatePairStatsValues["retransmissionsReceived"] = stats.retransmissionsReceived
        iceCandidatePairStatsValues["retransmissionsSent"] = stats.retransmissionsSent
        iceCandidatePairStatsValues["consentRequestsReceived"] = stats.consentRequestsReceived
        iceCandidatePairStatsValues["consentRequestsSent"] = stats.consentRequestsSent
        iceCandidatePairStatsValues["consentResponsesReceived"] = stats.consentResponsesReceived
        iceCandidatePairStatsValues["consentResponsesSent"] = stats.consentResponsesSent
        
        return (transportId, iceCandidatePairStatsValues)
    }
    
    private func mapIceCandidateStats(_ stats: IceCandidateStats) -> (String, [String: Any])? {
        guard let transportId = stats.transportId else {
            return nil
        }
        
        var iceCandidateStatsValues = [String: Any]()
        
        iceCandidateStatsValues["id"] = transportId
        iceCandidateStatsValues["type"] = stats.isRemote ? "remote-candidate" : "local-candidate"
        
        if let candidateType = stats.candidateType {
            var candidateTypeMapped: String = ""
            switch candidateType {
            case "serverreflexive":
                candidateTypeMapped = "srflx"
            case "hostreflexive":
                candidateTypeMapped = "host"
            case "peerreflexive":
                candidateTypeMapped = "dprflx"
            default:
                candidateTypeMapped = candidateType
            }
            
            iceCandidateStatsValues["candidateType"] = candidateTypeMapped
        }
        
        iceCandidateStatsValues["isDeleted"] = stats.isDeleted
        iceCandidateStatsValues["ip"] = stats.ip
        iceCandidateStatsValues["isRemote"] = stats.isRemote
        iceCandidateStatsValues["port"] = stats.port
        iceCandidateStatsValues["priority"] = stats.priority
        iceCandidateStatsValues["protocol"] = stats.protocol
        iceCandidateStatsValues["url"] = stats.url
        
        return (transportId, iceCandidateStatsValues)
    }
    
    private func mapLocalVideoTrackStats(_ stats: LocalVideoTrackStats) -> [String: [String: Any]] {
        let ssrc = stats.ssrc
        let remoteId = "remote_\(ssrc)"
        let codecId = "codec_\(ssrc)"
        let mediaSourceId = "source_\(stats.trackSid)"
        
        var localVideoTrackStatsDictionaries = [String: [String: Any]]()
        
        var localVideoTrackStatsValues = [String: Any]()
        localVideoTrackStatsValues["id"] = ssrc
        localVideoTrackStatsValues["type"] = "outbound-rtp"
        localVideoTrackStatsValues["kind"] = "video"
        localVideoTrackStatsValues["mediaType"] = "video"
        localVideoTrackStatsValues["mediaSourceId"] = mediaSourceId
        localVideoTrackStatsValues["remoteId"] = remoteId
        localVideoTrackStatsValues["codecId"] = codecId
        localVideoTrackStatsValues["frameWidth"] = stats.dimensions.width
        localVideoTrackStatsValues["frameHeight"] = stats.dimensions.height
        localVideoTrackStatsValues["framesPerSecond"] = stats.frameRate
        localVideoTrackStatsValues["framesEncoded"] = stats.framesEncoded
        localVideoTrackStatsValues["bytesSent"] = stats.bytesSent
        localVideoTrackStatsValues["packetsSent"] = stats.packetsSent
        localVideoTrackStatsDictionaries[ssrc] = localVideoTrackStatsValues
        
        var remoteInboundRTPValues = [String: Any]()
        remoteInboundRTPValues["id"] = remoteId
        remoteInboundRTPValues["type"] = "remote-inbound-rtp"
        remoteInboundRTPValues["kind"] = "video"
        remoteInboundRTPValues["mediaType"] = "video"
        remoteInboundRTPValues["roundTripTime"] = Double(stats.roundTripTime) / 1000.0
        remoteInboundRTPValues["packetsLost"] = stats.packetsLost
        localVideoTrackStatsDictionaries[remoteId] = remoteInboundRTPValues
        
        var mediaSourceValues = [String: Any]()
        mediaSourceValues["id"] = mediaSourceId
        mediaSourceValues["frameWidth"] = stats.captureDimensions.width
        mediaSourceValues["frameHeight"] = stats.captureDimensions.height
        mediaSourceValues["framesPerSecond"] = stats.captureFrameRate
        mediaSourceValues["type"] = "media-source"
        mediaSourceValues["kind"] = "video"
        localVideoTrackStatsDictionaries[mediaSourceId] = mediaSourceValues
        
        var codecValues = [String: Any]()
        codecValues["id"] = codecId
        codecValues["type"] = "codec"
        codecValues["mimeType"] = "video/\(stats.codec)"
        codecValues["sdpFmtpLine"] = ""
        localVideoTrackStatsDictionaries[codecId] = codecValues
        
        return localVideoTrackStatsDictionaries
    }
    
    private func mapLocalAudioTrackStats(_ stats: LocalAudioTrackStats) -> [String: [String: Any]] {
        let ssrc = stats.ssrc
        let remoteId = "remote_\(ssrc)"
        let codecId = "codec_\(ssrc)"
        let mediaSourceId = "source_\(stats.trackSid)"
        
        var localAudioTrackStatsDictionaries = [String: [String: Any]]()
        
        var localAudioTrackStatsValues = [String: Any]()
        localAudioTrackStatsValues["id"] = ssrc
        localAudioTrackStatsValues["type"] = "outbound-rtp"
        localAudioTrackStatsValues["kind"] = "audio"
        localAudioTrackStatsValues["mediaType"] = "audio"
        localAudioTrackStatsValues["mediaSourceId"] = mediaSourceId
        localAudioTrackStatsValues["remoteId"] = remoteId
        localAudioTrackStatsValues["codecId"] = codecId
        localAudioTrackStatsValues["bytesSent"] = stats.bytesSent
        localAudioTrackStatsValues["packetsSent"] = stats.packetsSent
        
        localAudioTrackStatsDictionaries[ssrc] = localAudioTrackStatsValues
        
        var remoteInboundRTPValues = [String: Any]()
        remoteInboundRTPValues["id"] = remoteId
        remoteInboundRTPValues["type"] = "remote-inbound-rtp"
        remoteInboundRTPValues["kind"] = "audio"
        remoteInboundRTPValues["mediaType"] = "audio"
        remoteInboundRTPValues["jitter"] = Double(stats.jitter) / 1000.0
        remoteInboundRTPValues["roundTripTime"] = Double(stats.roundTripTime) / 1000.0
        remoteInboundRTPValues["packetsLost"] = stats.packetsLost
        localAudioTrackStatsDictionaries[remoteId] = remoteInboundRTPValues
        
        var mediaSourceValues = [String: Any]()
        mediaSourceValues["id"] = mediaSourceId
        mediaSourceValues["audioLevel"] = Double(stats.audioLevel) / 32767.0
        mediaSourceValues["type"] = "media-source"
        mediaSourceValues["kind"] = "audio"
        
        localAudioTrackStatsDictionaries[mediaSourceId] = mediaSourceValues
        
        var codecValues = [String: Any]()
        codecValues["id"] = codecId
        codecValues["type"] = "codec"
        codecValues["mimeType"] = "audio/\(stats.codec)"
        codecValues["sdpFmtpLine"] = ""
        localAudioTrackStatsDictionaries[codecId] = codecValues
        
        return localAudioTrackStatsDictionaries
    }
    
    private func mapRemoteVideoTrackStats(_ stats: RemoteVideoTrackStats) -> [String: [String: Any]] {
        let ssrc = stats.ssrc
        let remoteId = "remote_\(ssrc)"
        let codecId = "codec_\(ssrc)"
        
        var remoteVideoTrackStatsDictionaries = [String: [String: Any]]()
        
        var remoteVideoTrackStatsValues = [String: Any]()
        remoteVideoTrackStatsValues["id"] = ssrc
        remoteVideoTrackStatsValues["type"] = "inbound-rtp"
        remoteVideoTrackStatsValues["kind"] = "video"
        remoteVideoTrackStatsValues["mediaType"] = "video"
        remoteVideoTrackStatsValues["remoteId"] = remoteId
        remoteVideoTrackStatsValues["codecId"] = codecId
        remoteVideoTrackStatsValues["frameWidth"] = stats.dimensions.width
        remoteVideoTrackStatsValues["frameHeight"] = stats.dimensions.height
        remoteVideoTrackStatsValues["framesPerSecond"] = stats.frameRate
        remoteVideoTrackStatsValues["bytesReceived"] = stats.bytesReceived
        remoteVideoTrackStatsValues["packetsReceived"] = stats.packetsReceived
        remoteVideoTrackStatsValues["packetsLost"] = stats.packetsLost
        remoteVideoTrackStatsDictionaries[ssrc] = remoteVideoTrackStatsValues
        
        var remoteOutboundRTPValues = [String: Any]()
        remoteOutboundRTPValues["id"] = remoteId
        remoteOutboundRTPValues["type"] = "remote-outbound-rtp"
        remoteOutboundRTPValues["kind"] = "video"
        remoteOutboundRTPValues["mediaType"] = "video"
        remoteVideoTrackStatsDictionaries[remoteId] = remoteOutboundRTPValues
        
        var codecValues = [String: Any]()
        codecValues["id"] = codecId
        codecValues["type"] = "codec"
        codecValues["mimeType"] = "video/\(stats.codec)"
        codecValues["sdpFmtpLine"] = ""
        remoteVideoTrackStatsDictionaries[codecId] = codecValues
        
        return remoteVideoTrackStatsDictionaries
    }
    
    private func mapRemoteAudioTrackStats(_ stats: RemoteAudioTrackStats) -> [String: [String: Any]] {
        let ssrc = stats.ssrc
        let remoteId = "remote_\(ssrc)"
        let codecId = "codec_\(ssrc)"
        
        var remoteAudioTrackStatsDictionaries = [String: [String: Any]]()
        var remoteAudioTrackStatsValues = [String: Any]()
        remoteAudioTrackStatsValues["id"] = ssrc
        remoteAudioTrackStatsValues["type"] = "inbound-rtp"
        remoteAudioTrackStatsValues["kind"] = "audio"
        remoteAudioTrackStatsValues["mediaType"] = "audio"
        remoteAudioTrackStatsValues["remoteId"] = remoteId
        remoteAudioTrackStatsValues["codecId"] = codecId
        remoteAudioTrackStatsValues["jitter"] = Double(stats.jitter) / 1000.0
        remoteAudioTrackStatsValues["bytesReceived"] = stats.bytesReceived
        remoteAudioTrackStatsValues["packetsReceived"] = stats.packetsReceived
        remoteAudioTrackStatsValues["packetsLost"] = stats.packetsLost
        remoteAudioTrackStatsValues["audioLevel"] = Double(stats.audioLevel) / 32767.0
        remoteAudioTrackStatsDictionaries[ssrc] = remoteAudioTrackStatsValues
        
        var remoteOutboundRTPValues = [String: Any]()
        remoteOutboundRTPValues["id"] = remoteId
        remoteOutboundRTPValues["type"] = "remote-outbound-rtp"
        remoteOutboundRTPValues["kind"] = "audio"
        remoteOutboundRTPValues["mediaType"] = "audio"
        remoteAudioTrackStatsDictionaries[remoteId] = remoteOutboundRTPValues
        
        var codecValues = [String: Any]()
        codecValues["id"] = codecId
        codecValues["type"] = "codec"
        codecValues["mimeType"] = "audio/\(stats.codec)"
        codecValues["sdpFmtpLine"] = ""
        remoteAudioTrackStatsDictionaries[codecId] = codecValues
        
        return remoteAudioTrackStatsDictionaries
    }
}
