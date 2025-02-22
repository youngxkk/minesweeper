//
//  ArrowView.swift
//  DecibelMeter
//
//  Created by DEEP SEA on 2023/5/15.
//

import SwiftUI


struct ArrowView: View {
    @Binding var decibels: Float
    
    var body: some View {
        Image(systemName: "arrow.up.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .rotationEffect(Angle(degrees: Double(decibels - 60) * 1.5))
            .frame(width: 200, height: 200)
            .padding(.top, 50)
            .ignoresSafeArea()
    }
}
