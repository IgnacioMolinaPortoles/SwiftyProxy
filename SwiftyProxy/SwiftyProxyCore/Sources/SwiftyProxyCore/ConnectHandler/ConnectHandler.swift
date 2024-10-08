//
//  ConnectHandler.swift
//
//
//  Created by Ignacio Molina Portoles on 23/08/2024.
//

import NIOCore
import NIOHTTP1
import NIOHTTP2
import NIOPosix
import Combine
import NIOSSL
import AppKit
import Logging
import NetworkExtension

final class ConnectHandler {
    private var upgradeState: State
    
    private var logger: Logger
    private var serverContext: NIOSSLContext
    private var clientContext: NIOSSLContext
    private var protocolNegotiationHandler: ProtocolNegotiationHandler
    
    init(logger: Logger,
         serverContext: NIOSSLContext,
         clientContext: NIOSSLContext,
         protocolNegotiationHandler: ProtocolNegotiationHandler) {
        self.upgradeState = .idle
        self.logger = logger
        self.serverContext = serverContext
        self.clientContext = clientContext
        self.protocolNegotiationHandler = protocolNegotiationHandler
    }
}


extension ConnectHandler {
    fileprivate enum State {
        case idle
        case beganConnecting
        case awaitingEnd(connectResult: Channel)
        case awaitingConnection(pendingBytes: [NIOAny])
        case upgradeComplete(pendingBytes: [NIOAny])
        case upgradeFailed
    }
}


extension ConnectHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch self.upgradeState {
        case .idle:
            self.handleInitialMessage(context: context, data: self.unwrapInboundIn(data))
            
        case .beganConnecting:
            // We got .end, we're still waiting on the connection
            if case .end = self.unwrapInboundIn(data) {
                self.upgradeState = .awaitingConnection(pendingBytes: [])
                self.removeDecoder(context: context)
            }
            
        case .awaitingEnd(let peerChannel):
            if case .end = self.unwrapInboundIn(data) {
                // Upgrade has completed!
                self.upgradeState = .upgradeComplete(pendingBytes: [])
                self.removeDecoder(context: context)
                self.glue(peerChannel, context: context)
            }
            
        case .awaitingConnection(var pendingBytes):
            // We've seen end, this must not be HTTP anymore. Danger, Will Robinson! Do not unwrap.
            self.upgradeState = .awaitingConnection(pendingBytes: [])
            pendingBytes.append(data)
            self.upgradeState = .awaitingConnection(pendingBytes: pendingBytes)
            
        case .upgradeComplete(pendingBytes: var pendingBytes):
            // We're currently delivering data, keep doing so.
            self.upgradeState = .upgradeComplete(pendingBytes: [])
            pendingBytes.append(data)
            self.upgradeState = .upgradeComplete(pendingBytes: pendingBytes)
            
        case .upgradeFailed:
            break
        }
    }
}


extension ConnectHandler: RemovableChannelHandler {
    func removeHandler(context: ChannelHandlerContext, removalToken: ChannelHandlerContext.RemovalToken) {
        var didRead = false
        
        // We are being removed, and need to deliver any pending bytes we may have if we're upgrading.
        while case .upgradeComplete(var pendingBytes) = self.upgradeState, pendingBytes.count > 0 {
            // Avoid a CoW while we pull some data out.
            self.upgradeState = .upgradeComplete(pendingBytes: [])
            let nextRead = pendingBytes.removeFirst()
            self.upgradeState = .upgradeComplete(pendingBytes: pendingBytes)
            
            context.fireChannelRead(nextRead)
            didRead = true
        }
        
        if didRead {
            context.fireChannelReadComplete()
        }
        
        self.logger.debug("Removing \(self) from pipeline")
        context.leavePipeline(removalToken: removalToken)
    }
}

extension ConnectHandler {
    private func handleInitialMessage(context: ChannelHandlerContext, data: InboundIn) {
        guard case .head(let head) = data else {
            self.logger.error("Invalid HTTP message type \(data)")
            self.httpErrorAndClose(context: context)
            return
        }
        
        self.logger.info("\(head.method) \(head.uri) \(head.version)")
        
        guard head.method == .CONNECT else {
            self.logger.error("Invalid HTTP method: \(head.method)")
            self.httpErrorAndClose(context: context)
            return
        }
        
        let components = head.uri.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let host = components.first!  // There will always be a first.
        let port = components.last.flatMap { Int($0, radix: 10) } ?? 80  // Port 80 if not specified
        
        self.upgradeState = .beganConnecting
        self.connectTo(host: String(host), port: port, context: context)
    }
    
    private func connectTo(host: String, port: Int, context: ChannelHandlerContext) {
        self.logger.info("NWEXTLOG: Connecting to \(host):\(port)")
        
        let certificateData = serverCertPath.data(using: .utf8)!
        
        // Convertir Data a [UInt8]
        let certificateBytes = [UInt8](certificateData)
        
        // Crear certificados y claves desde datos en memoria
        let certificate = try! NIOSSLCertificate(bytes: certificateBytes, format: .pem)
        
        var tlsConfig = TLSConfiguration.makeClientConfiguration()
        tlsConfig.certificateVerification = .none
        tlsConfig.trustRoots = .certificates([certificate])
        let sslContext = try! NIOSSLContext(configuration: tlsConfig)
        
        let channelFuture = ClientBootstrap(group: context.eventLoop)
            .channelInitializer { channel in
                channel.pipeline.addHandler(try! NIOSSLClientHandler(context: sslContext, serverHostname: host))
                    .flatMap{ channel.pipeline.addHandler(self.protocolNegotiationHandler)}
                    .flatMap{ channel.pipeline.addHTTPClientHandlers() }
            }
            .connect(host: host, port: port)
        
        channelFuture.whenSuccess { channel in
            self.connectSucceeded(channel: channel, context: context)
        }
        channelFuture.whenFailure { error in
            self.connectFailed(error: error, context: context)
        }
    }
    
    private func connectSucceeded(channel: Channel, context: ChannelHandlerContext) {
        self.logger.info("Connected to \(String(describing: channel.remoteAddress))")
        
        switch self.upgradeState {
        case .beganConnecting:
            // Ok, we have a channel, let's wait for end.
            self.upgradeState = .awaitingEnd(connectResult: channel)
            
        case .awaitingConnection(pendingBytes: let pendingBytes):
            // Upgrade complete! Begin gluing the connection together.
            self.upgradeState = .upgradeComplete(pendingBytes: pendingBytes)
            self.glue(channel, context: context)
            
        case .awaitingEnd(let peerChannel):
            // This case is a logic error, close already connected peer channel.
            peerChannel.close(mode: .all, promise: nil)
            context.close(promise: nil)
            
        case .idle, .upgradeFailed, .upgradeComplete:
            // These cases are logic errors, but let's be careful and just shut the connection.
            context.close(promise: nil)
        }
    }
    
    private func connectFailed(error: Error, context: ChannelHandlerContext) {
        self.logger.error("Connect failed: \(error)")
        
        switch self.upgradeState {
        case .beganConnecting, .awaitingConnection:
            // We still have a somewhat active connection here in HTTP mode, and can report failure.
            self.httpErrorAndClose(context: context)
            
        case .awaitingEnd(let peerChannel):
            // This case is a logic error, close already connected peer channel.
            peerChannel.close(mode: .all, promise: nil)
            context.close(promise: nil)
            
        case .idle, .upgradeFailed, .upgradeComplete:
            // Most of these cases are logic errors, but let's be careful and just shut the connection.
            context.close(promise: nil)
        }
        
        context.fireErrorCaught(error)
    }
    
    private func glue(_ peerChannel: Channel, context: ChannelHandlerContext) {
        self.logger.debug("Gluing together \(ObjectIdentifier(context.channel)) and \(ObjectIdentifier(peerChannel))")
        
        // Ok, upgrade has completed! We now need to begin the upgrade process.
        // First, send the 200 message.
        // This content-length header is MUST NOT, but we need to workaround NIO's insistence that we set one.
        let headers = HTTPHeaders([("Content-Length", "0")])
        let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: headers)
        context.write(self.wrapOutboundOut(.head(head)), promise: nil)
        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        
        // Now remove the HTTP encoder.
        self.removeEncoder(context: context)
        let _ = context.pipeline.removeHandler(self, promise: nil)
        
        let certificateData = serverCertPath.data(using: .utf8)!
        let privateKeyData = serverKeyPath.data(using: .utf8)!
        
        // Convertir Data a [UInt8]
        let certificateBytes = [UInt8](certificateData)
        let privateKeyBytes = [UInt8](privateKeyData)
        
        // Crear certificados y claves desde datos en memoria
        let certificate = try! NIOSSLCertificate(bytes: certificateBytes, format: .pem)
        let privateKey = try! NIOSSLPrivateKey(bytes: privateKeyBytes, format: .pem, passphraseCallback: { providePassword in
            providePassword("nacho".utf8)
        })
        
        var serverConfiguration = TLSConfiguration.makeServerConfiguration( certificateChain: [NIOSSLCertificateSource.certificate(certificate)],
                                                                            privateKey: .privateKey(privateKey))
        
        serverConfiguration.certificateVerification = .none
        
        let serverContext = try! NIOSSLContext(configuration: serverConfiguration)
        
        let tlsHandler = NIOSSLServerHandler(context: serverContext)
        context.channel.pipeline.addHandler(tlsHandler, name: "ssl-handler").whenComplete {result1 in
            context.channel.pipeline.addHandler(self.protocolNegotiationHandler).whenComplete { _ in
                context.channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).whenComplete { _ in
                    let (localGlue, peerGlue) = GlueHandler.matchedPair()
                    context.channel.pipeline.addHandler(localGlue, name: "local-glue")
                        .and(peerChannel.pipeline.addHandler(peerGlue, name: "peer-glue"))
                }
                
            }
        }
    }
    
    private func httpErrorAndClose(context: ChannelHandlerContext) {
        self.upgradeState = .upgradeFailed
        
        let headers = HTTPHeaders([("Content-Length", "0"), ("Connection", "close")])
        let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: .badRequest, headers: headers)
        context.write(self.wrapOutboundOut(.head(head)), promise: nil)
        context.writeAndFlush(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
            context.close(mode: .output, promise: nil)
        }
    }
    
    private func removeDecoder(context: ChannelHandlerContext) {
        // We drop the future on the floor here as these handlers must all be in our own pipeline, and this should
        // therefore succeed fast.
        context.pipeline.context(handlerType: ByteToMessageHandler<HTTPRequestDecoder>.self).whenSuccess {
            context.pipeline.removeHandler(context: $0, promise: nil)
        }
    }
    
    private func removeEncoder(context: ChannelHandlerContext) {
        context.pipeline.context(handlerType: HTTPResponseEncoder.self).whenSuccess {
            context.pipeline.removeHandler(context: $0, promise: nil)
        }
    }
}

