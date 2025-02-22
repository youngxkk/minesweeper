//
//  CameraView.swift
//  DecibelMeter
//
//  Created by DEEP SEA on 2023/5/16.
//

import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
    // 声明一个闭包，当拍照完成时调用
    var didFinishPicking: ((UIImage) -> Void)

    // 创建用于显示相机视图的UIViewController
    func makeUIViewController(context: UIViewControllerRepresentableContext<CameraView>) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    // 更新UIViewController
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<CameraView>) {}

    // 创建一个协调器，用于处理相机视图的委托方法
    func makeCoordinator() -> Coordinator {
        return Coordinator(didFinishPicking: didFinishPicking)
    }

    // 协调器类，用于处理相机视图的委托方法
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var didFinishPicking: ((UIImage) -> Void)

        init(didFinishPicking: @escaping ((UIImage) -> Void)) {
            self.didFinishPicking = didFinishPicking
        }

        // 当用户完成拍照时调用
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // 获取拍摄的照片
            guard let image = info[.originalImage] as? UIImage else {
                return
            }

            // 将照片保存到系统相册
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)

            // 调用闭包，传递照片
            didFinishPicking(image)

            // 关闭相机视图
            picker.dismiss(animated: true, completion: nil)
        }

        // 当照片保存完成时调用
        @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
            if let error = error {
                print("保存照片失败：\(error.localizedDescription)")
            } else {
                print("照片已保存到系统相册")
            }
        }
    }
}
