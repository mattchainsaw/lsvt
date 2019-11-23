//
//  ContentView.swift
//  LSVT
//
//  Created by Matthew Meyer on 11/15/19.
//  Copyright © 2019 Matthew Meyer. All rights reserved.
//

import SwiftUI
import AVFoundation
import Charts

struct ContentView: View {
    var body: some View {
        GeometryReader { p in
            VStack {
                LineChartSwiftUI().frame(width: p.size.width, height: p.size.height, alignment: .center)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

class Decibel {
    
    var timer: DispatchSourceTimer?
    var queue: [Float] = []
    var lineChart = LineChartView()
    var line1: LineChartDataSet = LineChartDataSet()
    var line2: LineChartDataSet = LineChartDataSet()
    var line3: LineChartDataSet = LineChartDataSet()

    
    // # of Data points to track
    var dataPointsToTrack: Int = 30
    // Time period to update
    var timeFrameInMilliseconds: Int = 100
    var maxDecibel: Double = 120.0
    var targetMaxDecibel: Double = 80.0
    var targetMinDecibel: Double = 60.0
    
    func getData() -> LineChartData {
        var dataPoints: [ChartDataEntry] = []

        for count in (0..<dataPointsToTrack) {
            dataPoints.append(ChartDataEntry.init(x: Double(count), y: Double(self.queue[count])))
         }
        let set = LineChartDataSet(entries: dataPoints)
        set.lineWidth = 2.5
        set.drawCirclesEnabled = false
        set.setColor(UIColor.black)
        
        let dataSets = [set, line3, line2, line1]
        let data = LineChartData(dataSets: dataSets)
        data.setDrawValues(false)
        
        return data
    }
    
    public func getLineChart() -> LineChartView {
        return lineChart
    }
    
    static func dBFS_convertTo_dB (dBFSValue: Float) -> Float {
        var level:Float = 0.0
        let peak_bottom:Float = -60.0 // dBFS -> -160..0   so it can be -80 or -60

        if dBFSValue < peak_bottom {
            level = 0.0
        } else if dBFSValue >= 0.0 {
            level = 1.0
        } else {
            let root:Float              =   2.0
            let minAmp:Float            =   powf(10.0, 0.05 * peak_bottom)
            let inverseAmpRange:Float   =   1.0 / (1.0 - minAmp)
            let amp:Float               =   powf(10.0, 0.05 * dBFSValue)
            let adjAmp:Float            =   (amp - minAmp) * inverseAmpRange
            level = powf(adjAmp, 1.0 / root)
        }
        return level * 120
    }
    
    
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
            let decibel = Float(Decibel.dBFS_convertTo_dB(dBFSValue: audioRecorder.peakPower(forChannel: 0)))
            i = i + 1
            self?.addToQueue(data: decibel)
            DispatchQueue.main.async {
                self?.lineChart.data = self?.getData()
                self?.lineChart.notifyDataSetChanged()
            }
        }
        timer?.resume()
    }
    
    func addToQueue(data: Float) {
        self.queue.append(data)
        self.queue.removeFirst()
    }
    
    func initialize() {
        
        var linePoints1: [ChartDataEntry] = []
        var linePoints2: [ChartDataEntry] = []
        var linePoints3: [ChartDataEntry] = []

        for count in (0..<dataPointsToTrack) {
            linePoints1.append(ChartDataEntry.init(x: Double(count), y: targetMinDecibel))
            linePoints2.append(ChartDataEntry.init(x: Double(count), y: targetMaxDecibel))
            linePoints3.append(ChartDataEntry.init(x: Double(count), y: maxDecibel))
         }
        
        line1 = LineChartDataSet(linePoints1)
        line1.fillColor = UIColor.yellow
        line1.drawFilledEnabled = true
        line1.drawCirclesEnabled = false
        line1.setColor(UIColor.black)
        
        line2 = LineChartDataSet(linePoints2)
        line2.fillColor = UIColor.green
        line2.drawFilledEnabled = true
        line2.drawCirclesEnabled = false
        line2.setColor(UIColor.black)
        
        line3 = LineChartDataSet(linePoints3)
        line3.fillColor = UIColor.red
        line3.drawFilledEnabled = true
        line3.drawCirclesEnabled = false
        line3.setColor(UIColor.black)
        
        let settings = [
            AVSampleRateKey : NSNumber(value: Float(44100.0) as Float),
            AVFormatIDKey : NSNumber(value: Int32(kAudioFormatMPEG4AAC) as Int32),
            AVNumberOfChannelsKey : NSNumber(value: 1 as Int32),
            AVEncoderAudioQualityKey : NSNumber(value: Int32(AVAudioQuality.medium.rawValue) as Int32),
        ]
        
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord, mode: .default)
            try audioSession.setActive(true)

            audioSession.requestRecordPermission({(granted: Bool) -> Void in
                if granted {
                    print("permission granted");
                } else {
                    print("permission denied")
                }
            })

            let tmpDirURL = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
            let fileURL = tmpDirURL.appendingPathComponent("foo")
            let file = fileURL.appendingPathExtension("bar")
            let audioRecorder = try AVAudioRecorder(url: file, settings: settings)
            
            audioRecorder.prepareToRecord()
            audioRecorder.record()
            audioRecorder.isMeteringEnabled = true
            setup(audioRecorder: audioRecorder)
            
        } catch let err {
            print("Unable start recording", err)
        }
        
        lineChart.leftAxis.axisMaximum = 120
        lineChart.leftAxis.axisMinimum = 0
        lineChart.rightAxis.axisMinimum = 0
        lineChart.rightAxis.axisMaximum = 120
        lineChart.drawGridBackgroundEnabled = true
        lineChart.xAxis.drawGridLinesEnabled = false
        lineChart.xAxis.drawLabelsEnabled = false
        lineChart.rightAxis.drawLabelsEnabled = false
        lineChart.rightAxis.drawGridLinesEnabled = false
        lineChart.leftAxis.drawGridLinesEnabled = false
        lineChart.legend.enabled = false
    }
}

struct LineChartSwiftUI: UIViewRepresentable {
    let decibel = Decibel()

    func makeUIView(context: UIViewRepresentableContext<LineChartSwiftUI>) -> LineChartView {
        decibel.initialize()
        return decibel.getLineChart()
    }

    func updateUIView(_ uiView: LineChartView, context: UIViewRepresentableContext<LineChartSwiftUI>) {
    }
}
