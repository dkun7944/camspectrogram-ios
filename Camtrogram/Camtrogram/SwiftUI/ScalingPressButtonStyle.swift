//
//  ScalingPressButtonStyle.swift
//  Camtrogram
//
//  Created by Daniel Kuntz on 6/13/24.
//

import SwiftUI

struct ScalingPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(x: configuration.isPressed ? 0.95 : 1,
                         y: configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) {
                if !configuration.isPressed {
                    playHapticFeedback()
                }
            }
    }

    private func playHapticFeedback() {
        let impactMed = UIImpactFeedbackGenerator(style: .medium)
        impactMed.impactOccurred()
    }
}
