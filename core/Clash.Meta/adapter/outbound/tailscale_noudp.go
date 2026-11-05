//go:build with_gvisor && !no_tailscale

package outbound

import (
	"net"
	"sync"
	"time"
)

// BETTBOX-CUSTOM: dialer-proxy 指向的代理建不了 UDP（节点不支持 UDP、UDP 被禁用或建立失败）时，
// 给 magicsock 一个读阻塞、写丢弃的 UDP 套接字，节点照常启动，流量全部经 DERP（走代理的 TCP）中继。
// 否则 magicsock 绑定失败会让 tsnet 启动报「Rebind IPv4 failed: failed to bind any ports」。
type tailscaleNoUDPConn struct {
	mu     sync.Mutex
	cond   *sync.Cond
	closed bool
	local  *net.UDPAddr
}

func newTailscaleNoUDPConn(network string) *tailscaleNoUDPConn {
	local := &net.UDPAddr{IP: net.IPv4zero}
	if network == "udp6" {
		local.IP = net.IPv6zero
	}
	c := &tailscaleNoUDPConn{local: local}
	c.cond = sync.NewCond(&c.mu)
	return c
}

func (c *tailscaleNoUDPConn) ReadFrom(p []byte) (int, net.Addr, error) {
	c.mu.Lock()
	for !c.closed {
		c.cond.Wait()
	}
	c.mu.Unlock()
	return 0, nil, net.ErrClosed
}

func (c *tailscaleNoUDPConn) WriteTo(p []byte, addr net.Addr) (int, error) {
	c.mu.Lock()
	closed := c.closed
	c.mu.Unlock()
	if closed {
		return 0, net.ErrClosed
	}
	return len(p), nil
}

func (c *tailscaleNoUDPConn) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.closed {
		return net.ErrClosed
	}
	c.closed = true
	c.cond.Broadcast()
	return nil
}

func (c *tailscaleNoUDPConn) LocalAddr() net.Addr                { return c.local }
func (c *tailscaleNoUDPConn) SetDeadline(t time.Time) error      { return nil }
func (c *tailscaleNoUDPConn) SetReadDeadline(t time.Time) error  { return nil }
func (c *tailscaleNoUDPConn) SetWriteDeadline(t time.Time) error { return nil }
