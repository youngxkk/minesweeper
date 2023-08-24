//
//  WatermarkView.swift
//  LensCam
//
//  Created by DEEP SEA on 2023/8/24.
//

import SwiftUI

struct WatermarkView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("watermark_1")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
            
            Text(Date(), style: .time)
                .font(.headline)
        }
        .padding()
    }
}

struct WatermarkView_Previews: PreviewProvider {
    static var previews: some View {
        WatermarkView()
    }
}
