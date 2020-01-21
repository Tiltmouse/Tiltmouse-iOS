//
//  FigureViewController.swift
//  Tiltmouse
//
//  Created by Aleksander Ivanin on 18.01.2020.
//

import CocoaAsyncSocket
import CoreMotion
import Starscream
import UIKit

class FigureViewController: UIViewController {
    private var socket: GCDAsyncUdpSocket?
    private let port: UInt16 = 5555
    private var motionManager = CMMotionManager()
    private var figureSocket: WebSocket?
    private var isFirstConnection = true

    override func viewDidLoad() {
        super.viewDidLoad()
        subscribeToEvents()
        performFigureSocketConnection(to: "ip:port")
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
        if case .none = socket {
            performConnection()
        }
        if figureSocket != nil {
            performFigureSocketConnection(to: "78.107.253.32:26199")
        }
    }

    @objc
    func onApplicationEnterBackground() {
        socket?.close()
        socket = nil
        guard let figureSocket = figureSocket else { return }
        figureSocket.disconnect()
    }
}

// MARK: - Network

extension FigureViewController: GCDAsyncUdpSocketDelegate {
    func performConnection() {
        socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        do {
            try socket?.enableBroadcast(true)
            try socket?.bind(toPort: port)
            try socket?.beginReceiving()
        } catch {
            print("Connection error: \(error)")
        }
    }

    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) { }

    func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) { }

    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        guard let receivedData = String(data: data, encoding: .utf8) else {
            print("Invalid received data: \(data)")
            return
        }
        print("Received data: \(receivedData)")
        performFigureSocketConnection(to: receivedData)
    }

    func performFigureSocketConnection(to address: String) {
        guard let url = URL(string: "ws://\(address)") else {
            print("Invalid socket address: \(address)")
            return
        }
        figureSocket = WebSocket(url: url, protocols: ["room161"])
        figureSocket?.delegate = self
        figureSocket?.connect()
        startMotionCapture()
    }
}

// MARK: - Socket delegate

extension FigureViewController: WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient) { }

    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) { }

    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        guard let roomId = text.split(separator: " ").last else { return }
        print(String(roomId))
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) { }
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
