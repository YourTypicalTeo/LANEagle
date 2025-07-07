//
//  PulseOnAppear.swift
//  LANShark
//
//  Created by Θοδωρης Σκονδρας on 7/7/25.
//


import SwiftUI

struct PulseOnAppear: ViewModifier {
    @State private var isPulsing = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.07 : 1)
            .opacity(isPulsing ? 1.0 : 0.85)
            .animation(.spring(response: 0.45, dampingFraction: 0.62), value: isPulsing)
            .onAppear {
                isPulsing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    isPulsing = false
                }
            }
    }
}