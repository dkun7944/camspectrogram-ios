//
//  MainView.swift
//  Camtrogram
//
//  Created by Daniel Kuntz on 6/8/24.
//

import SwiftUI
import AVFoundation

struct MainView: View {
    @StateObject var model: MainViewModel = MainViewModel()

    var body: some View {
        CameraView(photoOutput: model.photoOutput)
            .ignoresSafeArea()
    }
}

class MainViewModel: NSObject, ObservableObject {
    var photoOutput: AVCapturePhotoOutput

    private var ciContext: CIContext = CIContext()

    override init() {
        self.photoOutput = AVCapturePhotoOutput()
    }

    func capturePhoto() {
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
}

extension MainViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let photoData = photo.fileDataRepresentation() else {
            return
        }

        guard let ciImage = CIImage(data: photoData) else { return }

        let filter = CIFilter(name: "CIEdges")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(10.0, forKey: kCIInputIntensityKey) // Adjust the intensity as needed

        guard let outputImage = filter?.outputImage else { return }

        let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent)
        let filteredImage = UIImage(cgImage: cgImage!)
    }
}

#Preview {
    MainView()
}
