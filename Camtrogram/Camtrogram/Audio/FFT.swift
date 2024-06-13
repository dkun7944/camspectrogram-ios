//
//  FFT.swift
//  Camtrogram
//
//  Created by Daniel Kuntz on 6/8/24.
//

import Foundation
import Accelerate

class FFT {
    let size: Int
    private let fft: vDSP.FFT<DSPSplitComplex>?

    init(size: Int) {
        self.size = size
        let log2Size = Int(log2f(Float(size)))
        fft = vDSP.FFT(log2n: vDSP_Length(log2Size),
                       radix: .radix2,
                       ofType: DSPSplitComplex.self)
    }

    func forward(_ signal: inout [Float],
                 _ outputReal: inout [Float],
                 _ outputImag: inout [Float]) {
        let halfN = Int(size / 2)
        var forwardInputReal = [Float](repeating: 0,
                                       count: halfN)
        var forwardInputImag = [Float](repeating: 0,
                                       count: halfN)

        // Forward FFT
        forwardInputReal.withUnsafeMutableBufferPointer { forwardInputRealPtr in
            forwardInputImag.withUnsafeMutableBufferPointer { forwardInputImagPtr in
                outputReal.withUnsafeMutableBufferPointer { forwardOutputRealPtr in
                    outputImag.withUnsafeMutableBufferPointer { forwardOutputImagPtr in

                        // Create a `DSPSplitComplex` to contain the signal.
                        var forwardInput = DSPSplitComplex(realp: forwardInputRealPtr.baseAddress!,
                                                           imagp: forwardInputImagPtr.baseAddress!)

                        // Convert the real values in `signal` to complex numbers.
                        signal.withUnsafeBytes {
                            vDSP.convert(interleavedComplexVector: [DSPComplex]($0.bindMemory(to: DSPComplex.self)),
                                         toSplitComplexVector: &forwardInput)
                        }

                        // Create a `DSPSplitComplex` to receive the FFT result.
                        var forwardOutput = DSPSplitComplex(realp: forwardOutputRealPtr.baseAddress!,
                                                            imagp: forwardOutputImagPtr.baseAddress!)

                        // Perform the forward FFT.
                        fft?.forward(input: forwardInput,
                                     output: &forwardOutput)
                    }
                }
            }
        }
    }

    func inverse(_ inputReal: inout [Float],
                 _ inputImag: inout [Float]) -> [Float] {
        var inverseOutputReal = [Float](repeating: 0,
                                        count: size)
        var inverseOutputImag = [Float](repeating: 0,
                                        count: size)

        return inputReal.withUnsafeMutableBufferPointer { forwardOutputRealPtr in
            inputImag.withUnsafeMutableBufferPointer { forwardOutputImagPtr in
                inverseOutputReal.withUnsafeMutableBufferPointer { inverseOutputRealPtr in
                    inverseOutputImag.withUnsafeMutableBufferPointer { inverseOutputImagPtr in

                        // Create a `DSPSplitComplex` that contains the frequency-domain data.
                        let forwardOutput = DSPSplitComplex(realp: forwardOutputRealPtr.baseAddress!,
                                                            imagp: forwardOutputImagPtr.baseAddress!)

                        // Create a `DSPSplitComplex` structure to receive the FFT result.
                        var inverseOutput = DSPSplitComplex(realp: inverseOutputRealPtr.baseAddress!,
                                                            imagp: inverseOutputImagPtr.baseAddress!)

                        // Perform the inverse FFT.
                        fft?.inverse(input: forwardOutput,
                                     output: &inverseOutput)

                        // Return an array of real values from the FFT result.
                        let scale = 1 / Float(size * 2)
                        return [Float](fromSplitComplex: inverseOutput,
                                       scale: scale,
                                       count: size)
                    }
                }
            }
        }
    }

    func polarToRect(_ real: inout [Float],
                     _ imag: inout [Float],
                     _ mags: inout [Float],
                     _ phases: inout [Float]) {
        let count = vDSP_Length(real.count)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var complexSignal = DSPSplitComplex(realp: realPtr.baseAddress!,
                                                    imagp: imagPtr.baseAddress!)
                vDSP_zvmags(&complexSignal, 1, &mags, 1, count)
                mags = mags.map { sqrt($0) }
                vDSP_zvphas(&complexSignal, 1, &phases, 1, count)
            }
        }
    }

    func rectToPolar(_ mags: inout [Float],
                     _ phases: inout [Float],
                     _ real: inout [Float],
                     _ imag: inout [Float]) {
//        var interleavedInput = (0..<min(mags.count, phases.count)).flatMap { [mags[$0], phases[$0]] }
//        var interleavedOutput = [Float](repeating: 0, count: interleavedInput.count)
//        vDSP_rect(&interleavedInput, vDSP_Stride(1), &interleavedOutput, vDSP_Stride(1), vDSP_Length(interleavedInput.count / 2))
//        real = stride(from: 0, to: interleavedOutput.count - 1, by: 2).map { interleavedOutput[$0] }
//        imag = stride(from: 1, to: interleavedOutput.count - 1, by: 2).map { interleavedOutput[$0] }

        for i in 0..<mags.count {
            // Convert back to real / imaginary
            real[i] = mags[i] * cos(phases[i])
            imag[i] = mags[i] * sin(phases[i])
        }
    }

    func polarToPhases(_ real: inout [Float],
                       _ imag: inout [Float],
                       _ phases: inout [Float]) {
        let count = vDSP_Length(real.count)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var complexSignal = DSPSplitComplex(realp: realPtr.baseAddress!,
                                                    imagp: imagPtr.baseAddress!)
                vDSP_zvphas(&complexSignal, 1, &phases, 1, count)
            }
        }
    }

    func polarToMags(_ real: inout [Float],
                     _ imag: inout [Float],
                     _ mags: inout [Float]) {
        let count = vDSP_Length(real.count)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var complexSignal = DSPSplitComplex(realp: realPtr.baseAddress!,
                                                    imagp: imagPtr.baseAddress!)
                vDSP_zvmags(&complexSignal, 1, &mags, 1, count)
                mags = mags.map { sqrt($0) }
            }
        }
    }
}
