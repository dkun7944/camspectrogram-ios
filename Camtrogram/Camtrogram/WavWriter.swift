//
//  WavWriter.swift
//  Camtrogram
//
//  Created by Daniel Kuntz on 6/9/24.
//

import AVFoundation

final class WavWriter {

    private static var outputFormatSettings: [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVSampleRateKey: Float64(44100),
            AVNumberOfChannelsKey: 2
        ] as [String: Any]
    }

    static func createWav(fromBuffer buffer: ContiguousArray<Float32>,
                          filename: String,
                          completion: @escaping (_ wavUrl: URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = self.writeWav(fromBuffer: buffer, filename: filename)
            DispatchQueue.main.async {
                completion(url)
            }
        }
    }

    static func createWav(fromBuffer buffer: ContiguousArray<Float32>,
                          filename: String,
                          rootDirectory: String,
                          completion: @escaping (_ wavUrl: URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = self.writeWav(fromBuffer: buffer, filename: filename, rootDirectory: rootDirectory)
            DispatchQueue.main.async {
                completion(url)
            }
        }
    }

    static func writeWav(fromBuffer buffer: ContiguousArray<Float32>,
                         path: String,
                         completion: @escaping (_ wavUrl: URL?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = self.writeWav(fromBuffer: buffer, path: path)
            DispatchQueue.main.async {
                completion(url)
            }
        }
    }

    private static func writeWav(fromBuffer buffer: ContiguousArray<Float32>,
                                 filename: String,
                                 rootDirectory: String = NSTemporaryDirectory()) -> URL? {
        let filenameWithoutSlashes = filename.replacingOccurrences(of: "/", with: "-")
        let fileName = "\(filenameWithoutSlashes).wav"
        let fileUrl = URL(fileURLWithPath: rootDirectory).appendingPathComponent(fileName, isDirectory: false)
        let audioFile = try? AVAudioFile(forWriting: fileUrl,
                                         settings: outputFormatSettings,
                                         commonFormat: AVAudioCommonFormat.pcmFormatFloat32,
                                         interleaved: true)
        let bufferFormat = AVAudioFormat(settings: outputFormatSettings)!
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: bufferFormat, frameCapacity: AVAudioFrameCount(buffer.count / 2))!
        for i in 0..<buffer.count {
            outputBuffer.floatChannelData?.pointee[i] = Float(buffer[i])
        }
        outputBuffer.frameLength = AVAudioFrameCount(buffer.count / 2)

        do {
            try audioFile?.write(from: outputBuffer)
            return fileUrl
        } catch let error as NSError {
            print("error:", error.localizedDescription)
        }

        return nil
    }

    private static func writeWav(fromBuffer buffer: ContiguousArray<Float32>, path: String) -> URL? {
        let fileUrl = URL(fileURLWithPath: path)
        let audioFile = try? AVAudioFile(forWriting: fileUrl,
                                         settings: outputFormatSettings,
                                         commonFormat: AVAudioCommonFormat.pcmFormatFloat32,
                                         interleaved: true)
        let bufferFormat = AVAudioFormat(settings: outputFormatSettings)!
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: bufferFormat, frameCapacity: AVAudioFrameCount(buffer.count / 2))!
        for i in 0..<buffer.count {
            outputBuffer.floatChannelData?.pointee[i] = Float(buffer[i])
        }
        outputBuffer.frameLength = AVAudioFrameCount(buffer.count / 2)

        do {
            try audioFile?.write(from: outputBuffer)
            return fileUrl
        } catch let error as NSError {
            print("error:", error.localizedDescription)
        }

        return nil
    }
}
