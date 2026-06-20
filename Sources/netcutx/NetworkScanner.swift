import Foundation

struct ScanResult {
    let devices: [DeviceInfo]
}

func scanNetwork(bpf: NetcutxBPF, ourMAC: MACAddr, ourIP: String, gatewayIP: String) throws -> ScanResult {
    let subnet = getSubnet(ourIP)
    guard subnet != "" else { return ScanResult(devices: []) }

    status("Scanning \(subnet).0/24...")

    var ipsToScan: [String] = []
    for i in 1...254 {
        ipsToScan.append("\(subnet).\(i)")
    }

    for ip in ipsToScan {
        if isSelfIP(ip, ourIP) { continue }
        let req = ARPFrame.buildRequest(srcMAC: ourMAC, srcIP: ourIP, targetIP: ip)
        try? bpf.send(frame: Data(req.bytes))
    }

    Thread.sleep(forTimeInterval: 2.0)

    var seen = Set<String>()
    var devices: [DeviceInfo] = []

    let startIP = ourIP
    let gw = gatewayIP

    while true {
        guard let packet = try bpf.receive(timeout: 0.1) else { break }
        guard let frame = ARPFrame(from: packet.data) else { continue }
        guard frame.isReply, let sip = frame.senderIP, let smac = frame.senderMAC else { continue }
        guard !seen.contains(sip) else { continue }
        guard !isSelfIP(sip, startIP) else { continue }

        seen.insert(sip)
        let hostname = resolveHostname(sip)
        devices.append(DeviceInfo(
            ip: sip,
            mac: macToString(smac),
            hostname: hostname,
            isGateway: sip == gw,
            isSelf: false
        ))
    }

    devices.sort { d1, d2 in
        if d1.isGateway { return true }
        if d2.isGateway { return false }
        return d1.ip.localizedStandardCompare(d2.ip) == .orderedAscending
    }

    return ScanResult(devices: devices)
}

func quickScanARPTable(gatewayIP: String, ourIP: String) -> [DeviceInfo] {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/arp")
    task.arguments = ["-a"]
    let out = Pipe()
    task.standardOutput = out
    guard (try? task.run()) != nil else { return [] }
    task.waitUntilExit()
    let data = out.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else { return [] }

    var devices: [DeviceInfo] = []
    var seen = Set<String>()

    for line in output.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("?") || trimmed.first?.isLetter == true else { continue }

        let parts = trimmed.split(separator: " ").map(String.init)
        guard parts.count >= 4 else { continue }

        var ip = ""
        var mac = ""

        if trimmed.contains("(") {
            if let ipStart = trimmed.firstIndex(of: "("),
               let ipEnd = trimmed.firstIndex(of: ")") {
                ip = String(trimmed[trimmed.index(after: ipStart)..<ipEnd])
            }
        } else {
            ip = parts[1]
        }

        let macPart = parts.first { $0.contains(":") && $0.count == 17 }
        if let m = macPart { mac = m }

        guard ip != "", mac != "", !seen.contains(ip) else { continue }
        guard !isSelfIP(ip, ourIP) else { continue }

        seen.insert(ip)
        devices.append(DeviceInfo(
            ip: ip, mac: mac, hostname: "",
            isGateway: ip == gatewayIP, isSelf: false
        ))
    }

    return devices.sorted { d1, d2 in
        if d1.isGateway { return true }
        if d2.isGateway { return false }
        return d1.ip.localizedStandardCompare(d2.ip) == .orderedAscending
    }
}

private func getSubnet(_ ip: String) -> String {
    let parts = ip.split(separator: ".")
    guard parts.count == 4 else { return "" }
    return "\(parts[0]).\(parts[1]).\(parts[2])"
}

private func isSelfIP(_ ip: String, _ ourIP: String) -> Bool {
    ip == ourIP
}

func resolveHostname(_ ip: String) -> String {
    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    var addr = in_addr()
    inet_pton(AF_INET, ip, &addr)
    let sa = sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size),
                          sin_family: sa_family_t(AF_INET),
                          sin_port: 0, sin_addr: addr,
                          sin_zero: (0,0,0,0,0,0,0,0))
    let result = withUnsafePointer(to: sa) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            getnameinfo($0, socklen_t(MemoryLayout<sockaddr_in>.size),
                       &host, socklen_t(NI_MAXHOST),
                       nil, 0, NI_NAMEREQD)
        }
    }
    if result == 0 {
        return String(cString: host)
    }
    return ""
}
