//
//  Extensions.swift
//  Camtrogram
//
//  Created by Daniel Kuntz on 6/9/24.
//

import UIKit

extension UIApplication {
    var topViewController: UIViewController? {
        let keyWindow = UIApplication.shared.windows.filter { $0.isKeyWindow }.first

        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }

            return topController
        }

        return nil
    }

    var versionAndBuildNumber: String {
        let appVersionString: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
        let buildNumber: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        return "\(appVersionString) (\(buildNumber))"
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension Float {
    func rounded(toPlaces places: Int) -> Float {
        let divisor = powf(10.0, Float(places))
        return (self * divisor).rounded() / divisor
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
