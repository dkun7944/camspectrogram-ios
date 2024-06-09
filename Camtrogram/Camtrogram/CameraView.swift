//
//  CameraView.swift
//  Camtrogram
//
//  Created by Daniel Kuntz on 6/8/24.
//

import SwiftUI
import UIKit
import AVFoundation
import MetalKit
import PureLayout

struct CameraView: UIViewControllerRepresentable {
    var photoOutput: AVCapturePhotoOutput!

    func makeUIViewController(context: Context) -> AVCaptureViewController {
        let vc = AVCaptureViewController()
        vc.photoOutput = photoOutput
        return vc
    }

    func updateUIViewController(_ uiViewController: AVCaptureViewController, context: Context) {}
}

class AVCaptureViewController: UIViewController {
    var photoOutput: AVCapturePhotoOutput?
    var previewView: PreviewMetalView!

    private var ciContext: CIContext!
    private var filter = EdgesCIRenderer()

    override func viewDidLoad() {
        super.viewDidLoad()

        if let photoOutput = photoOutput {
            if CaptureSessionManager.shared.captureSession.canAddOutput(photoOutput) {
                CaptureSessionManager.shared.captureSession.addOutput(photoOutput)
            }
        }

        previewView = PreviewMetalView(frame: .zero)
        view.addSubview(previewView)
        previewView.autoPinEdgesToSuperviewEdges()

        CaptureSessionManager.shared.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        ciContext = CIContext()

        if let unwrappedVideoDataOutputConnection = CaptureSessionManager.shared.videoOutput.connection(with: .video) {
            let videoDevicePosition = CaptureSessionManager.shared.videoInput.device.position
            let interfaceOrientation = UIApplication.shared.statusBarOrientation
            let rotation = PreviewMetalView.Rotation(with: interfaceOrientation,
                                                     videoOrientation: unwrappedVideoDataOutputConnection.videoOrientation,
                                                     cameraPosition: videoDevicePosition)
            self.previewView.mirroring = (videoDevicePosition == .front)
            if let rotation = rotation {
                self.previewView.rotation = rotation
            }
        }
    }

    deinit {
        view.layer.removeObserver(self, forKeyPath: "bounds")
    }
}

extension AVCaptureViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return
        }

        if !filter.isPrepared {
            filter.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
        }

        guard let filteredBuffer = filter.render(pixelBuffer: videoPixelBuffer) else {
            return
        }

        previewView.pixelBuffer = filteredBuffer
    }
}

class CaptureSessionManager {
    static let shared = CaptureSessionManager()

    private(set) var captureSession: AVCaptureSession
    private(set) var videoInput: AVCaptureDeviceInput!
    private(set) var videoOutput: AVCaptureVideoDataOutput!
    private(set) var isSetup: Bool = false

    init() {
        captureSession = AVCaptureSession()
        startSession()
    }

    func startSession() {
        guard !captureSession.isRunning else {
            return
        }

        if !isSetup {
            guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                                   for: .video,
                                                                   position: .back) else { return }

            do {
                videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            } catch {
                return
            }

            if (captureSession.canAddInput(videoInput)) {
                captureSession.addInput(videoInput)
            }

            videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

            if (captureSession.canAddOutput(videoOutput)) {
                captureSession.addOutput(videoOutput)
            } else {
                return
            }
            
            isSetup = true
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    func stopSession() {
        guard captureSession.isRunning else {
            return
        }

        DispatchQueue.global(qos: .background).async {
            self.captureSession.stopRunning()
        }
    }
}

#Preview {
    CameraView()
        .ignoresSafeArea()
}
