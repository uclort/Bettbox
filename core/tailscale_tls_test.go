package main

import (
	"bytes"
	"net"
	"testing"
	"time"

	"github.com/metacubex/tls"
)

func TestTailscaleCurvePreferencesMatchesTailscaleHosts(t *testing.T) {
	for _, host := range []string{
		"controlplane.tailscale.com",
		"login.tailscale.com",
		"derp7.tailscale.com",
		"DERP7-ALL.Tailscale.com.",
		"tailscale.com",
		"log.tailscale.io",
	} {
		if got := tailscaleCurvePreferences(host); len(got) == 0 {
			t.Errorf("%s: want classic curves, got none", host)
		}
	}
	for _, host := range []string{"", "example.com", "nottailscale.com", "tailscale.com.evil.net", "rex.tailc7e14e.ts.net"} {
		if got := tailscaleCurvePreferences(host); len(got) != 0 {
			t.Errorf("%s: want default curves, got %v", host, got)
		}
	}
}

// captureClientHello 用指定配置发起握手，返回客户端写出的第一段数据（ClientHello 记录）。
func captureClientHello(t *testing.T, config *tls.Config) []byte {
	t.Helper()
	client, server := net.Pipe()
	defer server.Close()
	go func() {
		_ = client.SetDeadline(time.Now().Add(2 * time.Second))
		_ = tls.Client(client, config).Handshake()
		client.Close()
	}()
	_ = server.SetDeadline(time.Now().Add(2 * time.Second))
	buf := make([]byte, 16*1024)
	n, err := server.Read(buf)
	if err != nil {
		t.Fatal(err)
	}
	return buf[:n]
}

func TestTailscaleClientHelloOmitsMLKEM(t *testing.T) {
	// X25519MLKEM768 = 0x11ec，出现在 supported_groups 与 key_share 中。
	mlkem := []byte{0x11, 0xec}
	if hello := captureClientHello(t, &tls.Config{ServerName: "example.com"}); !bytes.Contains(hello, mlkem) {
		t.Fatal("non-Tailscale ClientHello should keep the default ML-KEM group")
	}
	if hello := captureClientHello(t, &tls.Config{ServerName: "controlplane.tailscale.com"}); bytes.Contains(hello, mlkem) {
		t.Fatal("Tailscale ClientHello must not offer X25519MLKEM768")
	}
	explicit := &tls.Config{ServerName: "controlplane.tailscale.com", CurvePreferences: []tls.CurveID{tls.X25519MLKEM768, tls.X25519}}
	if hello := captureClientHello(t, explicit); !bytes.Contains(hello, mlkem) {
		t.Fatal("explicit CurvePreferences must win over the hook")
	}
}
