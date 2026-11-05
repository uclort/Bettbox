//go:build !darwin

package main

// flushSystemDNSCache 只在 macOS 需要：mDNSResponder 会缓存 Tailnet 域名的否定结果。
func flushSystemDNSCache() {}
