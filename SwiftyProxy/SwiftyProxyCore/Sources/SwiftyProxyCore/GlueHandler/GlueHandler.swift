//
//  GlueHandler.swift
//
//
//  Created by Ignacio Molina Portoles on 23/08/2024.
//

import Foundation
import NIOCore
import NIOHTTP1

final class GlueHandler {
    
    private var partner: GlueHandler?
    
    private var context: ChannelHandlerContext?
    
    private var pendingRead: Bool = false
    private var server: Bool
    
    private init(server: Bool) {
        self.server = server
    }
}


extension GlueHandler {
    static func matchedPair() -> (GlueHandler, GlueHandler) {
        let server = GlueHandler(server: true)
        let client = GlueHandler(server: false)
        
        server.partner = client
        client.partner = server
        
        return (server, client)
    }
}


extension GlueHandler {
    private func partnerWrite(_ data: NIOAny) {
        self.context?.write(data, promise: nil)
    }
    
    private func partnerFlush() {
        self.context?.flush()
    }
    
    private func partnerWriteEOF() {
        self.context?.close(mode: .output, promise: nil)
    }
    
    private func partnerCloseFull() {
        self.context?.close(promise: nil)
    }
    
    private func partnerBecameWritable() {
        if self.pendingRead {
            self.pendingRead = false
            self.context?.read()
        }
    }
    
    private var partnerWritable: Bool {
        self.context?.channel.isWritable ?? false
    }
}


extension GlueHandler: ChannelDuplexHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias InboundOut = HTTPClientRequestPart
    typealias OutboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPServerResponsePart
    
    func handlerAdded(context: ChannelHandlerContext) {
        self.context = context
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        self.context = nil
        self.partner = nil
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        if server == true {
            switch self.unwrapInboundIn(data) {
            case .head(let head):
                self.partner?.partnerWrite(self.wrapInboundOut(.head(head)))
            case .body(let body):
                self.partner?.partnerWrite(self.wrapInboundOut(.body(.byteBuffer(body))))
            case .end(let trailers):
                self.partner?.partnerWrite(self.wrapInboundOut(.end(trailers)))
            }
        } else {
            switch self.unwrapOutboundIn(data) {
            case .head(let head):
                self.partner?.partnerWrite(self.wrapOutboundOut(.head(head)))
            case .body(let body):
                self.partner?.partnerWrite(self.wrapOutboundOut(.body(.byteBuffer(body))))
            case .end(let trailers):
                self.partner?.partnerWrite(self.wrapOutboundOut(.end(trailers)))
            }
        }
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        self.partner?.partnerFlush()
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        self.partner?.partnerCloseFull()
    }
    
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let event = event as? ChannelEvent, case .inputClosed = event {
            // We have read EOF.
            self.partner?.partnerWriteEOF()
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        self.partner?.partnerCloseFull()
    }
    
    func channelWritabilityChanged(context: ChannelHandlerContext) {
        if context.channel.isWritable {
            self.partner?.partnerBecameWritable()
        }
    }
    
    func read(context: ChannelHandlerContext) {
        if let partner = self.partner, partner.partnerWritable {
            context.read()
        } else {
            self.pendingRead = true
        }
    }
}
