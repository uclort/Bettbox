//go:build with_gvisor && !no_tailscale

package outbound

import (
	"errors"
	"net"
	"testing"
	"time"
)

// BETTBOX-CUSTOM: 代理建不了 UDP 时的替代套接字：写入丢弃、读阻塞到关闭，关闭后读写都返回 ErrClosed。
func TestTailscaleNoUDPConn(t *testing.T) {
	for _, network := range []string{"udp4", "udp6"} {
		c := newTailscaleNoUDPConn(network)
		if _, ok := c.LocalAddr().(*net.UDPAddr); !ok {
			t.Fatalf("%s LocalAddr 不是 *net.UDPAddr: %T", network, c.LocalAddr())
		}
		if n, err := c.WriteTo([]byte("stun"), &net.UDPAddr{IP: net.IPv4(1, 1, 1, 1), Port: 3478}); n != 4 || err != nil {
			t.Fatalf("%s 写入应丢弃成功，got n=%d err=%v", network, n, err)
		}
		done := make(chan error, 1)
		go func() {
			_, _, err := c.ReadFrom(make([]byte, 16))
			done <- err
		}()
		select {
		case err := <-done:
			t.Fatalf("%s 关闭前读不应返回: %v", network, err)
		case <-time.After(50 * time.Millisecond):
		}
		if err := c.Close(); err != nil {
			t.Fatalf("%s 关闭失败: %v", network, err)
		}
		select {
		case err := <-done:
			if !errors.Is(err, net.ErrClosed) {
				t.Fatalf("%s 关闭后读应返回 ErrClosed: %v", network, err)
			}
		case <-time.After(time.Second):
			t.Fatalf("%s 关闭后读没有返回", network)
		}
		if _, err := c.WriteTo([]byte("x"), nil); !errors.Is(err, net.ErrClosed) {
			t.Fatalf("%s 关闭后写应返回 ErrClosed: %v", network, err)
		}
	}
}
