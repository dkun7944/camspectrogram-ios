//
//  EdgeCIRenderer.swift
//  Camtrogram
//
//  Created by Daniel Kuntz on 6/8/24.
//

import CoreMedia
import CoreVideo
import CoreImage

class EdgesCIRenderer: FilterRenderer {

    var description: String = "CIEdges (Core Image)"

    var isPrepared = false

    private var ciContext: CIContext?

    private var edgesFilter: CIFilter?

    private var outputColorSpace: CGColorSpace?

    private var outputPixelBufferPool: CVPixelBufferPool?

    private(set) var outputFormatDescription: CMFormatDescription?

    private(set) var inputFormatDescription: CMFormatDescription?

    func prepare(with formatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int) {
        reset()

        (outputPixelBufferPool,
         outputColorSpace,
         outputFormatDescription) = allocateOutputBufferPool(with: formatDescription,
                                                             outputRetainedBufferCountHint: outputRetainedBufferCountHint)
        if outputPixelBufferPool == nil {
            return
        }
        inputFormatDescription = formatDescription
        ciContext = CIContext()
        edgesFilter = CIFilter(name: "CIEdges")
        isPrepared = true
    }

    func reset() {
        ciContext = nil
        edgesFilter = nil
        outputColorSpace = nil
        outputPixelBufferPool = nil
        outputFormatDescription = nil
        inputFormatDescription = nil
        isPrepared = false
    }

    func render(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        guard let edgesFilter = edgesFilter,
              let ciContext = ciContext,
              isPrepared else {
            assertionFailure("Invalid state: Not prepared")
            return nil
        }

        let sourceImage = CIImage(cvImageBuffer: pixelBuffer)
        edgesFilter.setValue(sourceImage, forKey: kCIInputImageKey)

        guard let filteredImage = edgesFilter.value(forKey: kCIOutputImageKey) as? CIImage else {
            print("CIFilter failed to render image")
            return nil
        }

        var pbuf: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, outputPixelBufferPool!, &pbuf)
        guard let outputPixelBuffer = pbuf else {
            print("Allocation failure")
            return nil
        }

        ciContext.render(filteredImage, to: outputPixelBuffer, bounds: filteredImage.extent, colorSpace: outputColorSpace)
        return outputPixelBuffer
    }
}
