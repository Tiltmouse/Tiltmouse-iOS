//
//  AppDelegate.swift
//  Tiltmouse
//
//  Created by Aleksander Ivanin on 18.01.2020.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = FigureViewController()
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
        return true
    }

}
