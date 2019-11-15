//
//  AppDelegate.swift
//  LSVT
//
//  Created by Matthew Meyer on 11/15/19.
//  Copyright © 2019 Matthew Meyer. All rights reserved.
//

import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var timer: DispatchSourceTimer?
    var queue: [Float] = []
    
    // # of Data points to track
    var dataPointsToTrack: Int = 100
    // Time period to update
    var timeFrameInMilliseconds: Int = 100
    
    // Sets queue to all zeros and setup recorder to listen and update queue
    func setup(audioRecorder: AVAudioRecorder) -> Void {
        for _ in 0...self.dataPointsToTrack {
            self.queue.append(0.0)
        }
        
        let queue = DispatchQueue(label: "io.segment.decibel", attributes: .concurrent)
        var i = 0
        timer = DispatchSource.makeTimerSource(flags: [], queue: queue)
        timer?.schedule(deadline: .now(), repeating: .milliseconds(timeFrameInMilliseconds), leeway: .milliseconds(10))
        timer?.setEventHandler { [weak self] in
            audioRecorder.updateMeters()
            let decibel = audioRecorder.peakPower(forChannel: 0)
            print(i, decibel)
            i = i + 1
            self?.addToQueue(data: decibel)
        }
        timer?.resume()
    }
    
    func addToQueue(data: Float) {
        self.queue.append(data)
        self.queue.removeFirst()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        let audioSession = AVAudioSession.sharedInstance()
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey:AVAudioQuality.high.rawValue
        ]
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            audioSession.requestRecordPermission({(granted: Bool) -> Void in
                if granted {
                    print("permission granted");
                } else {
                    print("permission denied")
                }
            })
            
            try audioSession.setActive(true)

            let tmpDirURL = FileManager.default.temporaryDirectory
            let audioRecorder = try AVAudioRecorder(url: tmpDirURL, settings: settings)
            audioRecorder.prepareToRecord()
            audioRecorder.record()
            try audioSession.setActive(true)
            audioRecorder.isMeteringEnabled = true
            setup(audioRecorder: audioRecorder)
            
        } catch let err {
            print("Unable start recording", err)
        }
        
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

}

