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
        ZStack {
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
                CameraView(photoOutput: model.photoOutput)
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }

            if let capturedImage = model.capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            }

            VStack {
                Spacer()

                Button {
                    model.capturePhoto()
                } label: {
                    Circle()
                }
                .frame(width: 60.0, height: 60.0)
                .foregroundStyle(Color.white)
            }
        }
        .background(Color.black)
        .frame(maxWidth: .infinity)
    }
}

class MainViewModel: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
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
        let filteredImage = UIImage(cgImage: cgImage!).rotate90Degrees()

        print(filteredImage)

        guard let filteredImage = filteredImage else {
            return
        }
        self.capturedImage = filteredImage
        _ = ImageToAudio.run(filteredImage)
    }
}

extension UIImage {
    func rotate90Degrees() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        let contextSize = CGSize(width: self.size.height, height: self.size.width)

        UIGraphicsBeginImageContext(contextSize)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        context.translateBy(x: contextSize.width / 2, y: contextSize.height / 2)
        context.rotate(by: .pi / 2)
        context.translateBy(x: -self.size.width / 2, y: -self.size.height / 2)

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rotatedImage
    }
}

#Preview {
    MainView()
}
