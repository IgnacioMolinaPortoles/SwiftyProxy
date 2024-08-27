//
//  HomeView.swift
//  SwiftyProxy
//
//  Created by Ignacio Molina Portoles on 26/08/2024.
//

import SwiftUI
import SwiftyProxyCore
import Combine
import SwiftBrotli

final class MainViewModel {
    let testMain: TestMain
    let wifiProxyManager = WifiProxyManager()
    let publisher = PassthroughSubject<(String, String), Never>()
    
    init() {
        self.testMain = TestMain(urisPublisher: publisher)
    }
    
    func startServer() {
        testMain.start()
    }
    
    func shutDownServer() {
        #warning("Implementar mensaje de error cuando falla el shutdown")
        let _ = testMain.shutDown()
    }
    
    func setProxyOnNetwork() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.wifiProxyManager.setProxy(enabled: true)
        }
    }
    
    func removeProxyFromNetwork() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.wifiProxyManager.setProxy(enabled: false)
        }
    }
}

struct ContentView: View {
    @State var isProxyOpen: Bool = false
    @State var isNetworkProxySetted: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    let mainVM = MainViewModel()
    
    var body: some View {
        VStack {
            Text("Proxy server: \(isProxyOpen ? "on ✅": "off ⛔️")")
            
            Button(isProxyOpen ? "Shut down server" : "Start server") {
                isProxyOpen ? mainVM.shutDownServer() : mainVM.startServer()
                isProxyOpen.toggle()
            }
            
            Text("Wi-Fi proxy status: \(isNetworkProxySetted ? "on ✅" : "off ⛔️")")
            Button("\(isNetworkProxySetted ? "Remove" : "Set")") {
                isNetworkProxySetted ? mainVM.setProxyOnNetwork() : mainVM.removeProxyFromNetwork()
                isNetworkProxySetted.toggle()
            }
            
            
            PublisherListView(publisher: mainVM.publisher.eraseToAnyPublisher())
        }
        .padding(.top, 20)
        
    }
}

struct TupleItem: Identifiable {
    let id = UUID()
    let head: String
    let body: String
}

struct PublisherListView: View {
    @State private var items: [TupleItem] = []
    private var cancellables = Set<AnyCancellable>()
    @State private var isPresentingEditor = false
    @State private var selectedText: String = ""
    
    
    let publisher: AnyPublisher<(String, String), Never>
    
    init(publisher: AnyPublisher<(String, String), Never>) {
        self.publisher = publisher
    }
    
    var body: some View {
        VStack {
            Button("Clear requests") {
                self.items.removeAll()
            }
            .padding(.bottom, 20)
            .padding(.top, 10)
            
            List(items, id: \.id) { item in
                if let url = item.head.extractURI(),
                    let statusCode = item.body.extractHTTPStatusCode(){
                    HStack {
                        StatusCircleView(statusCode: statusCode)
                        Text("\(statusCode)")
                        Text("\(item.head.extractHTTPVerb() ?? "")")
                        Text(url)
                            .onTapGesture {
                                selectedText = item.body.decodeHTTPResponseBody() ?? ""
                                isPresentingEditor = true
                            }
                    }
                }
            }
            .onReceive(publisher) { newItem in
                items.append(TupleItem(head: newItem.0, body: newItem.1))
            }
        }.popover(isPresented: $isPresentingEditor) {
            TextEditor(text: $selectedText)
                .disableAutocorrection(true)
                .padding()
                .border(Color.gray, width: 1)
                .frame(width: 500, height: 500)
            
        }
    }
}

struct StatusCircleView: View {
    var statusCode: Int
    
    var body: some View {
        Circle()
            .fill(colorForStatusCode(statusCode))
            .frame(width: 10, height: 10)
    }
    
    func colorForStatusCode(_ code: Int) -> Color {
        switch code {
        case 200..<300:
            return .green
        case 300..<400:
            return .blue
        case 400..<500:
            return .yellow
        case 500..<600:
            return .red
        default:
            return .gray
        }
    }
}

extension String {
    func decodeHTTPResponseBody() -> String? {
        
        guard let headerEndIndex = self.range(of: "\r\n\r\n")?.upperBound else {
            print("No se encontró la separación entre cabeceras y cuerpo")
            return nil
        }
        
        let headers = self[..<headerEndIndex]
        let oldBody = self[headerEndIndex...]
        
        let result: Result<String, Error> = BrotliJSONDecoder().decode(data: oldBody.data(using: .utf8)!)
        
        switch result {
        case .success(let decodedBody):
            return headers + decodedBody
        default:
            return self
        }
    }
    
    func extractURI() -> String? {
        let lines = self.components(separatedBy: "\r\n")
        
        guard let requestLine = lines.first(where: { 
            $0.starts(with: "GET") ||
            $0.starts(with: "POST") ||
            $0.starts(with: "PUT") ||
            $0.starts(with: "DELETE") }) else {
            return nil
        }
        
        guard let hostLine = lines.first(where: { $0.starts(with: "Host:") }) else {
            return nil
        }
        
        let host = hostLine.replacingOccurrences(of: "Host: ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let requestPath = requestLine
            .components(separatedBy: " ")
            .dropFirst(1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        return "\(host)\(requestPath)"
    }
    
    func extractHTTPStatusCode() -> Int? {
        let lines = self.components(separatedBy: "\r\n")
        
        // La primera línea debe ser la línea de estado HTTP
        guard let statusLine = lines.first else { return nil }
        
        // Separar la línea de estado por espacios
        let components = statusLine.components(separatedBy: " ")
        
        // El código de estado es el segundo componente
        if components.count > 1, let statusCode = Int(components[1]) {
            return statusCode
        }
        
        return nil
    }
    
    func extractHTTPVerb() -> String? {
        let lines = self.components(separatedBy: "\r\n")
        
        // La primera línea debe ser la línea de solicitud HTTP
        guard let requestLine = lines.first else { return nil }
        
        // Separar la línea de solicitud por espacios
        let components = requestLine.components(separatedBy: " ")
        
        // El verbo HTTP es el primer componente
        if components.count > 0 {
            return components[0]
        }
        
        return nil
    }
}

#Preview {
    ContentView()
}
