//
//  ProtocolNegotiationHandler.swift
//
//
//  Created by Ignacio Molina Portoles on 23/08/2024.
//

import Foundation
import NIOCore
import NIOHTTP1
import NIOHTTP2
import NIOPosix
import Combine
import NIOSSL
import AppKit
import Logging
import NetworkExtension
import SwiftBrotli

final class ProtocolNegotiationHandler: ChannelInboundHandler {
    typealias InboundIn = IOData
    typealias OutboundOut = IOData
    
    private var readCount = 0
    private var head: String? = ""
    
    var urisPublisher: PassthroughSubject<(String, String), Never>
    
    init(urisPublisher: PassthroughSubject<(String, String), Never>) {
        self.urisPublisher = urisPublisher
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        print("ProtocolNegotiationHandler channel read")
        
        switch frame {
        case .byteBuffer(let byteBuffer):
            let byteBufferString = byteBufferToString(byteBuffer)
            
            print(byteBufferString ?? "")
            readCount += 1
            if readCount == 2 {
                
                DispatchQueue.main.async { [weak self] in
                    self?.urisPublisher.send((String(self?.head ?? ""), String(byteBufferString ?? "")))
                }
                
                readCount = 0
                head = ""
            } else {
                head = byteBufferString
            }
            context.fireChannelRead(data)
        case .fileRegion(_):
            context.fireChannelRead(data)
        }
    }
    
    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
        context.fireChannelReadComplete()
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("Error caught in ProtocolNegotiationHandler: \(error)")
        context.close(promise: nil)
    }
    
    // Agregamos una implementación mínima para manejar el cierre del canal
    func channelInactive(context: ChannelHandlerContext) {
        print("Channel inactive in ProtocolNegotiationHandler")
        context.fireChannelInactive()
    }
    
    // HELPERS
    
    func byteBufferToString(_ buffer: ByteBuffer) -> String? {
        guard let bytes = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) else {
            print("Error: Unable to convert ByteBuffer to String")
            return nil
        }
        return bytes
    }
}
