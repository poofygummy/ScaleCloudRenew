//
//  em_proxy.swift
//  SideStore
//
//  Created by Jackson Coxson on 10/26/22.
//
//  bridge for em_proxy static lib similar to minimuxer.swift
//

import Foundation

// C FFI declarations — avoids need for bridging header or module map
@_silgen_name("start_emotional_damage")
private func _start_emotional_damage(_ bind_addr: UnsafePointer<CChar>?) -> Int32

@_silgen_name("stop_emotional_damage")
private func _stop_emotional_damage()

public func start_em_proxy(bind_addr: String) {
    let host = NSString(string: bind_addr)
    let host_pointer = UnsafePointer<CChar>(host.utf8String)
    let _ = _start_emotional_damage(host_pointer)
}

public func stop_em_proxy() {
    _stop_emotional_damage()
}
