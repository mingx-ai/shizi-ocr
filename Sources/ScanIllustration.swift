import SwiftUI

/// A little specimen sheet under a pair of selection guides.
struct ScanIllustration: View {
    let dark: Bool

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 356, y: size.height / 173)
            let ink = dark ? Color(red: 0.55, green: 0.87, blue: 0.72) : Color(red: 0.12, green: 0.38, blue: 0.30)
            let paper = dark ? Color(red: 0.20, green: 0.24, blue: 0.21) : Color(red: 1, green: 1, blue: 0.98)
            let mint = dark ? Color(red: 0.22, green: 0.34, blue: 0.28) : Color(red: 0.82, green: 0.90, blue: 0.81)

            // A fading registration grid holds the floating sheets together.
            for y in stride(from: 10, through: 170, by: 10) {
                for x in stride(from: 8, through: 348, by: 10) {
                    let dx = (Double(x) - 178) / 178
                    let dy = (Double(y) - 87) / 100
                    let strength = max(0, 1 - dx * dx - dy * dy)
                    let point = CGRect(x: CGFloat(x), y: CGFloat(y), width: 1.35, height: 1.35)
                    context.fill(Path(ellipseIn: point), with: .color(ink.opacity(strength * 0.38)))
                }
            }

            // Rotate each sheet around its own centre, using local page coordinates.
            var back = context
            back.translateBy(x: 169, y: 89)
            back.rotate(by: .degrees(-15))
            let backPage = Path(roundedRect: CGRect(x: -73, y: -51, width: 146, height: 102), cornerRadius: 6)
            back.fill(backPage, with: .color(mint))
            back.stroke(backPage, with: .color(ink.opacity(0.32)), lineWidth: 1.1)
            for y in stride(from: -37, through: 36, by: 9) {
                var rule = Path()
                rule.move(to: CGPoint(x: -62, y: y))
                rule.addLine(to: CGPoint(x: 59, y: y))
                back.stroke(rule, with: .color(ink.opacity(0.16)), lineWidth: 0.8)
            }

            var page = context
            page.translateBy(x: 181, y: 88)
            page.rotate(by: .degrees(-5))
            let front = Path(roundedRect: CGRect(x: -77, y: -53, width: 154, height: 106), cornerRadius: 6)
            page.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(dark ? 0.14 : 0.09), radius: 3.5, x: 0, y: 3))
                layer.fill(front, with: .color(paper))
            }
            page.stroke(front, with: .color(ink.opacity(0.46)), lineWidth: 1.1)

            let titleRules = [CGRect(x: -62, y: -39, width: 29, height: 3),
                              CGRect(x: -28, y: -39, width: 13, height: 3)]
            for line in titleRules {
                page.fill(Path(roundedRect: line, cornerRadius: 1.3), with: .color(ink.opacity(0.43)))
            }
            var headerRule = Path()
            headerRule.move(to: CGPoint(x: -62, y: -29))
            headerRule.addLine(to: CGPoint(x: 62, y: -29))
            page.stroke(headerRule, with: .color(ink.opacity(0.20)), lineWidth: 0.8)

            let target = CGRect(x: -62, y: -17, width: 54, height: 52)
            page.fill(Path(roundedRect: target, cornerRadius: 2), with: .color(mint.opacity(0.76)))
            page.draw(Text("字").font(.custom("Songti SC", fixedSize: 39).weight(.bold)).foregroundColor(ink),
                      at: CGPoint(x: target.midX, y: target.midY - 0.5))
            var corners = Path()
            let length: CGFloat = 9
            for (x, directionX) in [(target.minX, CGFloat(1)), (target.maxX, CGFloat(-1))] {
                for (y, directionY) in [(target.minY, CGFloat(1)), (target.maxY, CGFloat(-1))] {
                    corners.move(to: CGPoint(x: x + length * directionX, y: y))
                    corners.addLine(to: CGPoint(x: x, y: y))
                    corners.addLine(to: CGPoint(x: x, y: y + length * directionY))
                }
            }
            page.stroke(corners, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))

            for (index, width) in [50, 61, 43, 51].enumerated() {
                let rect = CGRect(x: 3, y: -10 + index * 11, width: width, height: 3)
                page.fill(Path(roundedRect: rect, cornerRadius: 1.4),
                          with: .color(ink.opacity(index == 0 ? 0.59 : 0.25)))
            }

            // The pointer sits outside the sheet, overlapping its lower border.
            var pointerContext = context
            pointerContext.translateBy(x: 237, y: 115)
            pointerContext.rotate(by: .degrees(-9))
            var pointer = Path()
            pointer.move(to: .zero)
            for point in [CGPoint(x: 20, y: 14), CGPoint(x: 11.5, y: 15.5), CGPoint(x: 15, y: 23),
                          CGPoint(x: 10, y: 25), CGPoint(x: 6.5, y: 17), CGPoint(x: 1, y: 23)] {
                pointer.addLine(to: point)
            }
            pointer.closeSubpath()
            pointerContext.stroke(pointer, with: .color(paper), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
            pointerContext.fill(pointer, with: .color(ink))

            for (x, y, length) in [(85, 49, 3), (268, 58, 4)] {
                var mark = Path()
                mark.move(to: CGPoint(x: x - length, y: y))
                mark.addLine(to: CGPoint(x: x + length, y: y))
                mark.move(to: CGPoint(x: x, y: y - length))
                mark.addLine(to: CGPoint(x: x, y: y + length))
                context.stroke(mark, with: .color(ink.opacity(0.44)), lineWidth: 1)
            }
        }
    }
}
