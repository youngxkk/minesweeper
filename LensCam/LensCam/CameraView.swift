//
//  CameraView.swift
//  LensCam
//
//  Created by DEEP SEA on 2023/8/24.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @Binding var capturedImage: UIImage?
    @State private var image: UIImage?
    @State private var isCameraAvailable: Bool = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.isEmpty
    @Binding var isCaptureRequested: Bool
    @State private var captureRequested: Bool = false
    
    var body: some View {
        ZStack {
            if isCameraAvailable {
                Text("相机不可用")
            } else {
                CameraCaptureView(image: $capturedImage, isCaptureRequested: $captureRequested)

                VStack {
                    Spacer()
                    // 拍照按钮
                    Button(action: {
                        // 触发拍照操作
                        captureRequested = true
                        // 你可以在这里调用相机的捕获方法，或者使用之前的 UITapGestureRecognizer 方法
                    }) {
                        Circle()
                            .frame(width: 70, height: 70)
                            .foregroundColor(.white)
                            .overlay(
                                Circle().stroke(Color.gray, lineWidth: 5)
                            )
                            .padding(30)
                    }
                }
            }
        }
        .onAppear(perform: {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                if granted {
                    isCameraAvailable = false
                }
            })
        })
    }
}

//struct CameraView_Previews: PreviewProvider {
//    static var previews: some View {
//        CameraView(capturedImage: .constant(nil))
//    }
//}
