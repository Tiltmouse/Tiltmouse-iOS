//
//  FigureViewController.swift
//  Tiltmouse
//
//  Created by Aleksander Ivanin on 18.01.2020.
//

import CoreMotion
import Starscream
import UIKit

class FigureViewController: UIViewController {
    private var udpBroadcastConnection: UDPBroadcastConnection?
    private let port: UInt16 = 5555
    private var motionManager = CMMotionManager()
    private var figureSocket: WebSocket?
    private var isFirstConnection = true

    override func viewDidLoad() {
        super.viewDidLoad()
        subscribeToEvents()
        performConnection()
        view.backgroundColor = UIColor.white
    }
}

// MARK: - Events

private extension FigureViewController {
    func subscribeToEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(onApplicationEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onApplicationEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @objc
    func onApplicationEnterForeground() {
        if case .none = udpBroadcastConnection {
            performConnection()
        }
    }

    @objc
    func onApplicationEnterBackground() {
        closeUDPSocket()
        figureSocket?.disconnect()
    }
}

// MARK: - Network

extension FigureViewController {
    func performConnection() {
        do {
            udpBroadcastConnection = try UDPBroadcastConnection(port: port, bindIt: true, handler: { [weak self] (ip, port, data) in
                let socketPort = UInt16(bigEndian: data.withUnsafeBytes { $0.pointee })
                self?.performFigureSocketConnection(to: "\(ip):\(socketPort)")
            }, errorHandler: { (error) in
                print("Connection error: \(error)")
            })
        } catch {
            print("Connection error: \(error)")
        }
    }

    func performFigureSocketConnection(to address: String) {
        guard let url = URL(string: "ws://\(address)") else {
            print("Invalid socket address: \(address)")
            return
        }
        figureSocket = WebSocket(url: url, protocols: ["room161"])
        figureSocket?.delegate = self
        figureSocket?.request.setValue(nil, forHTTPHeaderField: "Origin")
        figureSocket?.connect()
        closeUDPSocket()
    }

    func closeUDPSocket() {
        udpBroadcastConnection?.closeConnection()
        udpBroadcastConnection = nil
    }
}

// MARK: - Socket delegate

extension FigureViewController: WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient) {
        figureSocket?.write(string: "room131")
        startMotionCapture()
    }

    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("Socket connection error: \(String(describing: error))")
    }

    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print("Received message: \(text)")
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("Received data: \(data)")
        print("Received data (string): \(String(describing: String(data: data, encoding: .utf8)))")
    }
}

// MARK: - Motion detection

extension FigureViewController {
    func startMotionCapture() {
        guard motionManager.isDeviceMotionAvailable else {
            return
        }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.showsDeviceMovementDisplay = true
        motionManager.startDeviceMotionUpdates()
        motionManager.startDeviceMotionUpdates(to: OperationQueue.current!) { [weak self] (motion, error) in
            self?.processDeviceMotion(with: motion)
        }
    }

    func processDeviceMotion(with motion: CMDeviceMotion?) {
        guard let motion = motion else { return }

        let id: Float32 = isFirstConnection ? 0 : 1
        let orientation: [Float32] = [
            Float32(motion.attitude.pitch),
            Float32(motion.attitude.roll),
            Float32(motion.attitude.yaw),
        ]
        let totalAcceleration = CMAcceleration(
            x: motion.userAcceleration.x + motion.gravity.x,
            y: motion.userAcceleration.y + motion.gravity.y,
            z: motion.userAcceleration.z + motion.gravity.z
        )
        let tilt: [Float32] = [
            Float32(totalAcceleration.x),
            Float32(totalAcceleration.y),
            Float32(totalAcceleration.z),
        ]

        var message = "\(id)"
        orientation.forEach {
            message.append(" ")
            message.append(String($0))
        }
        tilt.forEach {
            message.append(" ")
            message.append(String($0))
        }
        figureSocket?.write(string: message)
        isFirstConnection = false
        print(message)
    }
}
