//
//  WifiProxyManager.swift
//  SwiftyProxy
//
//  Created by Ignacio Molina Portoles on 26/08/2024.
//

import Foundation

#warning("Esta implementacion requiere que la app no este en sandbox")
final class WifiProxyManager {
    let appleScriptStart = """
    do shell script "networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 443"
    """
    
    let appleScriptStop = """
    do shell script "networksetup -setsecurewebproxystate Wi-Fi off"
    """
    
    func setProxy(enabled: Bool) {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: !enabled ? appleScriptStart : appleScriptStop) {
            scriptObject.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            } else {
                print("Command executed successfully.")
            }
        }
    }
}
