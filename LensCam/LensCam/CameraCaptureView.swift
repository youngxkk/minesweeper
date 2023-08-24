//
//  CameraCaptureView.swift
//  LensCam
//
//  Created by DEEP SEA on 2023/8/24.
//

import SwiftUI
import AVFoundation

struct CameraCaptureView: UIViewRepresentable {
    @Binding var image: UIImage?
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let photoSettings = AVCapturePhotoSettings()
    @Binding var isCaptureRequested: Bool // 新增的绑定属性
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVCapturePhotoCaptureDelegate {
        let parent: CameraCaptureView
        
        init(_ parent: CameraCaptureView) {
            self.parent = parent
        }
        
        @objc func capturePhoto() {
            parent.output.capturePhoto(with: parent.photoSettings, delegate: self)
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            if let imageData = photo.fileDataRepresentation(), let uiImage = UIImage(data: imageData) {
                // 使用 CoreGraphics 将水印添加到图像上
                let watermarkedImage = addWatermarkTo(image: uiImage)
                UIImageWriteToSavedPhotosAlbum(watermarkedImage, nil, nil, nil)
                parent.image = watermarkedImage
            }
        }
        
        private func addWatermarkTo(image: UIImage) -> UIImage {
            let imageSize = image.size
            let scale = image.scale
            let watermark = WatermarkView().snapshot(size: CGSize(width: imageSize.width/3, height: imageSize.height/5))
            
            UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)
            image.draw(in: CGRect(origin: .zero, size: imageSize))
            watermark?.draw(in: CGRect(x: 10, y: imageSize.height - (imageSize.height/5) - 10, width: imageSize.width/3, height: imageSize.height/5))
            
            let result = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            return result ?? image
        }
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return view }
        
        if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.frame
        view.layer.addSublayer(previewLayer)
        
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.capturePhoto))
        view.addGestureRecognizer(tap)
        
        session.startRunning()
        
        return view
    }

    
    func updateUIView(_ uiView: UIView, context: Context) {
        if isCaptureRequested {
            context.coordinator.capturePhoto()
            DispatchQueue.main.async {
                isCaptureRequested = false // Reset the request after capturing
            }
        }
    }

    
    typealias UIViewType = UIView
}


extension View {
    func snapshot(size: CGSize) -> UIImage? {
        let controller = UIHostingController(rootView: self)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        let snapshot = controller.view.snapshot()
        return snapshot
    }
}

extension UIView {
    func snapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, isOpaque, 0)
        drawHierarchy(in: bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
