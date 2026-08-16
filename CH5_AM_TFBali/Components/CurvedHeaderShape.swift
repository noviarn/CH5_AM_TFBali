//
//  SwiftUIView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 16/08/26.
//

import SwiftUI

struct CurvedHeaderShape: Shape {
    func path(in rect: CGRect) -> Path {
            var path = Path()

            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.55))

            path.addCurve(
                to: CGPoint(x: 0, y: rect.height * 0.65),
                control1: CGPoint(x: rect.width * 0.6, y: rect.height * 1.15),
                control2: CGPoint(x: rect.width * 0.25, y: rect.height * 0.55)
            )

            path.closeSubpath()
            return path
        }
}

#Preview {
    CurvedHeaderShape()
}
