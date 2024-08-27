import NIOCore
import NIOHTTP1
import NIOHTTP2
import NIOPosix
import Combine
import NIOSSL
import AppKit
import Logging
import NetworkExtension

let serverCertPath = """
    """

let serverKeyPath = """
    """

struct OpenProxyConfig {
    var hostname: String
    var port: Int
}

public class TestMain {
    private var logger: Logger
    private var configuration: OpenProxyConfig
    
    private var channel: Channel?
    private var group: MultiThreadedEventLoopGroup?
    public var urisPublisher: PassthroughSubject<(String, String), Never>
    
    public init(urisPublisher: PassthroughSubject<(String, String), Never>) {
        self.logger = Logger(label: "com.apple.nio-connect-proxy.ConnectHandler")
        self.configuration = OpenProxyConfig(hostname: "0.0.0.0", port: 443)
        self.urisPublisher = urisPublisher
    }
    
    public func start() {
        startLocalProxy()
    }
    
    public func shutDown() -> Bool {
        do {
            self.logger.info("Shutdown server on \(String(describing: self.channel?.localAddress)) \n")
            try channel?.eventLoop.close()
            try group?.syncShutdownGracefully()
            return true
        } catch {
            return false
        }
    }
    
    private func startLocalProxy() {
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
        let clientConfiguration = TLSConfiguration.makeClientConfiguration()

        serverConfiguration.applicationProtocols = NIOHTTP2SupportedALPNProtocols
        
        do {
            let serverContext = try NIOSSLContext(configuration: serverConfiguration)
            let clientContext = try NIOSSLContext(configuration: clientConfiguration)
            
            self.startBasicProxy(serverContext: serverContext, clientContext: clientContext)
        } catch {
            self.logger.error("Could not make server/client context")
        }
    }
    
    
    private func startBasicProxy(serverContext: NIOSSLContext, clientContext: NIOSSLContext) {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        
        guard let group = self.group else { return }
        
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)), name: "http-request-decoder")
                    .flatMap { channel.pipeline.addHandler(HTTPResponseEncoder(), name: "http-response-encoder") }
                    .flatMap { channel.pipeline.addHandler(ConnectHandler(logger: self.logger,
                                                                          serverContext: serverContext,
                                                                          clientContext: clientContext,
                                                                          protocolNegotiationHandler: ProtocolNegotiationHandler(urisPublisher: self.urisPublisher)
                                                                         ), name: "connect-handler") }
            }
        
        bootstrap.bind(host: configuration.hostname, port: configuration.port).whenComplete{ result in
            // Need to create this here for thread-safety purposes
            switch result {
            case .success(let channel):
                self.channel = channel
                self.logger.info("Listening on \(String(describing: channel.localAddress)) \n")
                self.startTunnel()
            case .failure(let error):
                self.logger.error("Failed to bind 127.0.0.1:443, \(error)\n")
            }
        }
        
        
    }
    
    private func startTunnel() {
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        
        let proxySettings = NEProxySettings()
        proxySettings.httpServer = NEProxyServer(
            address: configuration.hostname,
            port: Int(configuration.port)
        )
        proxySettings.httpsServer = NEProxyServer(
            address: configuration.hostname,
            port: Int(configuration.port)
        )
        proxySettings.autoProxyConfigurationEnabled = false
        proxySettings.httpEnabled = true
        proxySettings.httpsEnabled = true
        proxySettings.matchDomains = [""]
        tunnelSettings.proxySettings = proxySettings
        
        let ipv4Settings = NEIPv4Settings(
            addresses: [tunnelSettings.tunnelRemoteAddress],
            subnetMasks: ["255.255.255.0"]
        )
        tunnelSettings.ipv4Settings = ipv4Settings
        
        tunnelSettings.mtu = 1500
        
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        dnsSettings.matchDomains = [""]
        dnsSettings.matchDomainsNoSearch = false
        tunnelSettings.dnsSettings = dnsSettings
        
        // Set our tunnel settings
        //setTunnelNetworkSettings(dnsSettings)
    }
}

