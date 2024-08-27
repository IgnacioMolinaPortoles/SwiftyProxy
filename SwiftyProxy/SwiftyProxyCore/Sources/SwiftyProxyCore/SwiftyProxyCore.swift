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
    -----BEGIN CERTIFICATE-----
    MIIGADCCA+igAwIBAgIUa3a8ZZ3ckzC/cDxa+AjVvEzBpeYwDQYJKoZIhvcNAQEL
    BQAwYTELMAkGA1UEBhMCVVMxETAPBgNVBAgMCERlbGF3YXJlMRMwEQYDVQQHDApX
    aWxtaW5ndG9uMRIwEAYDVQQKDAlOYWNvbSBMTEMxFjAUBgNVBAMMDU5hY29tIFJv
    b3QgQ0EwHhcNMjQwODI0MTgyODEyWhcNMjYxMTI3MTgyODEyWjBhMQswCQYDVQQG
    EwJVUzERMA8GA1UECAwIRGVsYXdhcmUxEzARBgNVBAcMCldpbG1pbmd0b24xEjAQ
    BgNVBAoMCU5hY29tIExMQzEWMBQGA1UEAwwNKi5mbG93LmNvbS5hcjCCAiIwDQYJ
    KoZIhvcNAQEBBQADggIPADCCAgoCggIBAK4TCiLrRtVxg7ejW/Mwp6epTlWKmCxQ
    krBlSLjlEaUGP9RbPgLjX/42t2uilGUd1tt3T+YRbSH/eTS2PezgLKU0Ljlbd4tu
    6Ny85NLUbR11O3bodFLeU0B9EFxHHBOhNftA9mIdP8e8qy/iH/0y8Yxvoem7Sddp
    FtDixDpHIK1LefqHgZIncfmBkd/uJ7jb27pogTUOCqA9CJl1Y8SWMXVQxZ3Y+3G+
    LHK2ktDht7+9O9+w0HR59naj03NHcJI1EhDWKXpTnbIrMXKb7etdPq6dlU3qbRal
    O1YcHyRoQ7BmKfQ6t+u/Tugp4A6MtkC3tWp27U/U2LdCk4b3ps82nBO0ZKmvwBx7
    LaEcamQFp4GP+V8JKssOvXt+Y1XpiWw6+cM9ULL3QLyjCzixK340DYpq51Z2KiBc
    sM5ANW5qZNyBvSrgLbWsD1vOw7AAFAQOJ5CjLPEIXNeSh5Q5BW0ziUm5w6e3zWRg
    O4SVwJ2KS5U0OlxYYJ060jSvzqkAN+VDTB/e4pkWW+8GdZBZbjmsMFBIhP3RfUCQ
    RmIiJGK7DEDfNluVl7M0T5pdkj95+mXWbgNOhlpdmOa5dWhBNW02eO4AAJWXAf72
    VpFdmSy2wta3CF7eNoIlZja/3qUNLnSp12DuXl4+NEOkIrxcjfDFrXeT60lA0xRw
    s3+LUouz3+dJAgMBAAGjga8wgawwagYDVR0RBGMwYYINKi5mbG93LmNvbS5hcoIL
    Zmxvdy5jb20uYXKCFioubW5lZGdlLmN2YXR0di5jb20uYXKCFG1uZWRnZS5jdmF0
    dHYuY29tLmFyghVqc29ucy5hcHAuZmxvdy5jb20uYXIwHQYDVR0OBBYEFHC1Q1UE
    ZbDIZ+pk7HLrx7UWTGOCMB8GA1UdIwQYMBaAFPWqNG+H+3hs/l1BiJjv1XVbNA5L
    MA0GCSqGSIb3DQEBCwUAA4ICAQAGa37MLMvcjQhJh0XaxSh3iP9DyH5LpJnFNUOM
    N8z7guFZ5P+pXg9C8so4LSEGXKHivfnSuCvFStPh9GbVxtzub58q429ihDDEqvX5
    OMzTH+C2pgxQwx2TuGeCaLKUZ4VrHL2DeiaBoVC4fuViBbp1aQAx7s+x+NbcKpEg
    dP182SIxU5bj9Eqy7qqhcX/h+xOK6dJJrQSjjWxXigDY/+S5o/ADgpK1F42cni36
    RqohtC4is19Co3t3BWxepxQ+2kvrbpcuckgJ4wpV/qaE1zcOpSeECRqn1cXoqiW3
    P1JXJePUu+y+dexBv2uPwo7z9KquHj/Pg3oNO3FaXulLuXHrD6KHXhSYPnTSu7/F
    z3bAZ0h+0gl89b7bEVJuDicA/WkmaybdV11QvuDRC45tuSa+aL1ZD0HkY7xf6Wvc
    zJCnxec7pG7KHEt/MBSZYvi6w+FotxkYh/QVHKpadYpv5YzMY/EOYLb8aBmooOkB
    SM7HX9ZbZoVzyXKybqNY0Ef3PKet0n5zL1aBJLCtka90zX4h7NSTi61JblUJNk9Y
    J3pnXjgo5Qz6euI1Pm27YQQZW7AIjPnlGdNem9cDs0EkH8NI3MGycIFE6bacRvZc
    YIl8CPMnhDAyTa0/xb968d+y680Ejv6qp5b5HXxPH/wVpuhmdDvfzWqqmbkUi7zM
    QYvVnw==
    -----END CERTIFICATE-----

    """

let serverKeyPath = """
    -----BEGIN PRIVATE KEY-----
    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
    pixnZZ6tFPQlvYEhjj9mTKQ8ebj2aFE=
    -----END PRIVATE KEY-----

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

