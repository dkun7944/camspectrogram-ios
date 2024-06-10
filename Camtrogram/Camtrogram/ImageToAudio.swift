//
//  ImageToAudio.swift
//  Camtrogram
//
//  Created by Daniel Kuntz on 6/8/24.
//

import UIKit
import Accelerate

struct ImageToAudio {
    static let FFT_SIZE = 4096

    private static var window: [Float] = {
        var window = [Float](repeating: 0, count: FFT_SIZE)
        vDSP_hann_window(&window, vDSP_Length(FFT_SIZE), Int32(vDSP_HANN_NORM))
        return window
    }()

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
        var real: [Float] = [Float](repeating: 0, count: FFT_SIZE / 2)
        var imag: [Float] = [Float](repeating: 0, count: FFT_SIZE / 2)
        var phases = [Float](repeating: 0, count: FFT_SIZE / 2)
        for i in 0..<phases.count {
            phases[i] = Float.random(in: (-2 * .pi)...(2 * .pi))
        }

        var outBuffer: ContiguousArray<Float> = []

        for x in stride(from: 0, to: width - 1, by: 2) {
            var column: [Float] = []
            for y in 0..<height {
                let byteIndex = (bytesPerRow * y) + x * bytesPerPixel
                let red = CGFloat(rawData[byteIndex]) / 255.0
                let green = CGFloat(rawData[byteIndex + 1]) / 255.0
                let blue = CGFloat(rawData[byteIndex + 2]) / 255.0
                let val = (red + green + blue) / 3.0
                column.append(pow(Float(val), 4))
            }

            let resizedColumn = Array(logRescale(resizeArray(column, to: FFT_SIZE / 8).reversed())) + [Float](repeating: 0.0, count: FFT_SIZE / 4)
            var unNormalizedMagnitudes = [Float](repeating: 0.0, count: FFT_SIZE / 4)

            // Multiply each normalized magnitude by the signal length
            vDSP_vsmul(resizedColumn, 1, [Float(FFT_SIZE / 32)], &unNormalizedMagnitudes, 1, vDSP_Length(FFT_SIZE / 4))

//            // Randomize phases
            for i in 0..<phases.count {
                phases[i] = Float.random(in: (-2 * .pi)...(2 * .pi))
            }

            fft.rectToPolar(&unNormalizedMagnitudes, &phases, &real, &imag)
            var out = fft.inverse(&real, &imag)

            vDSP_vmul(out, 1, window, 1, &out, 1, vDSP_Length(out.count))

            if outBuffer.isEmpty {
                outBuffer.append(contentsOf: out)
            } else {
                let windowSize = 3 * out.count / 4
                for i in 0..<windowSize {
                    outBuffer[outBuffer.count - windowSize + i] += out[i]
                }

                outBuffer.append(contentsOf: out[windowSize...(out.count - 1)])
            }
        }

        WavWriter.createWav(fromBuffer: outBuffer, filename: UUID().uuidString) { wavUrl in
            print(wavUrl)

            let activityVC = UIActivityViewController(activityItems: [wavUrl], applicationActivities: nil)
            UIApplication.shared.topViewController?.present(activityVC, animated: true)
        }

        return outBuffer
    }

    static func resizeArray(_ array: [Float], to targetSize: Int) -> [Float] {
        guard targetSize > 0 else { return [] }
        let stride = Float(array.count - 1) / Float(targetSize - 1)
        var result: [Float] = []
        for i in 0..<targetSize {
            let lowerIndex = Int(Float(i) * stride)
            let upperIndex = min(lowerIndex + 1, array.count - 1)
            let ratio = (Float(i) * stride).truncatingRemainder(dividingBy: 1)
            let interpolatedValue = array[lowerIndex] * (1 - ratio) + array[upperIndex] * ratio
            result.append(interpolatedValue)
        }
        return result
    }

    static func logRescale(_ array: [Float]) -> [Float] {
        var result: [Float] = []
        for i in 0..<array.count {
            let sqrtIdx = pow(Float(i) / Float(array.count), 0.4) * Float(array.count)
            let lowerIndex = Int(sqrtIdx)
            let upperIndex = min(lowerIndex + 1, array.count - 1)
            let ratio = sqrtIdx.truncatingRemainder(dividingBy: 1)
            let interpolatedValue = array[lowerIndex] * (1 - ratio) + array[upperIndex] * ratio
            result.append(interpolatedValue)
        }
        return result
    }
}
