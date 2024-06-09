//
//  ImageToAudio.swift
//  Camtrogram
//
//  Created by Daniel Kuntz on 6/8/24.
//

import UIKit
import Accelerate

struct ImageToAudio {
    static let FFT_SIZE = 2048

    static func run(_ image: UIImage) -> ContiguousArray<Float> {
        guard let cgImage = image.cgImage else { return [] }
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
        defer { rawData.deallocate() }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8

        let context = CGContext(data: rawData, 
                                width: width,
                                height: height,
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let fft = FFT(size: FFT_SIZE)
        var real: [Float] = [Float](repeating: 0, count: FFT_SIZE)
        var imag: [Float] = [Float](repeating: 0, count: FFT_SIZE)
        var phases = [Float](repeating: 0, count: FFT_SIZE)
        for i in 0..<phases.count {
            phases[i] = Float.random(in: (-2 * .pi)...(2 * .pi))
        }

        var outBuffer: ContiguousArray<Float> = []

        for x in 0..<width {
            var column: [Float] = []
            for y in 0..<height {
                let byteIndex = (bytesPerRow * y) + x * bytesPerPixel
                let red = CGFloat(rawData[byteIndex]) / 255.0
                let green = CGFloat(rawData[byteIndex + 1]) / 255.0
                let blue = CGFloat(rawData[byteIndex + 2]) / 255.0
                let val = (red + green + blue) / 3.0
                column.append(Float(val))
            }

            let resizedColumn = resizeArray(column, to: FFT_SIZE)
            var unNormalizedMagnitudes = [Float](repeating: 0.0, count: FFT_SIZE)

            // Multiply each normalized magnitude by the signal length
            vDSP_vsmul(resizedColumn, 1, [Float(FFT_SIZE / 8)], &unNormalizedMagnitudes, 1, vDSP_Length(FFT_SIZE))
            fft.rectToPolar(&unNormalizedMagnitudes, &phases, &real, &imag)
            let out = fft.inverse(&real, &imag)

            if outBuffer.isEmpty {
                outBuffer.append(contentsOf: out)
            } else {
                let halfSize = out.count / 2
                for i in 0..<halfSize {
                    outBuffer[outBuffer.count - halfSize + i] = out[i]
                }

                outBuffer.append(contentsOf: out[halfSize...(out.count - 1)])
            }
        }

        WavWriter.createWav(fromBuffer: outBuffer, filename: UUID().uuidString) { wavUrl in
            print(wavUrl)

            let activityVC = UIActivityViewController(activityItems: [wavUrl], applicationActivities: nil)
            UIApplication.shared.topViewController?.present(activityVC, animated: true)
        }

        return outBuffer
    }

    static func resizeArray<T>(_ array: [T], to targetSize: Int) -> [T] {
        guard targetSize > 0 else { return [] }
        let stride = Double(array.count) / Double(targetSize)
        var result: [T] = []
        for i in 0..<targetSize {
            let index = Int(Double(i) * stride)
            result.append(array[index])
        }
        return result
    }
}
