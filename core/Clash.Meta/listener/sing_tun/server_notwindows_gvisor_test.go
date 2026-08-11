//go:build !windows && with_gvisor

package sing_tun

import (
	"testing"

	"github.com/metacubex/gvisor/pkg/tcpip/stack"
	tun "github.com/metacubex/sing-tun"
)

type gVisorDarwinTun struct {
	closedDarwinTun
}

func (gVisorDarwinTun) WritePacket(*stack.PacketBuffer) (int, error) {
	return 1, nil
}

func (gVisorDarwinTun) NewEndpoint() (stack.LinkEndpoint, stack.NICOptions, error) {
	return nil, stack.NICOptions{}, nil
}

func TestClosedAwareDarwinTunPreservesGVisorMethods(t *testing.T) {
	wrapped := &closedAwareDarwinTun{DarwinTUN: gVisorDarwinTun{}}
	gVisorTun, ok := any(wrapped).(tun.GVisorTun)
	if !ok {
		t.Fatal("closed-aware Darwin TUN lost the GVisor method set")
	}
	if n, err := gVisorTun.WritePacket(nil); err != nil || n != 1 {
		t.Fatalf("GVisor method was not delegated: n=%d err=%v", n, err)
	}
}
