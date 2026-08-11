//go:build !windows && with_gvisor

package sing_tun

import (
	"github.com/metacubex/gvisor/pkg/tcpip/stack"
	tun "github.com/metacubex/sing-tun"
)

var _ tun.GVisorTun = (*closedAwareDarwinTun)(nil)

func (t *closedAwareDarwinTun) WritePacket(packet *stack.PacketBuffer) (int, error) {
	return t.DarwinTUN.(tun.GVisorTun).WritePacket(packet)
}

func (t *closedAwareDarwinTun) NewEndpoint() (stack.LinkEndpoint, stack.NICOptions, error) {
	return t.DarwinTUN.(tun.GVisorTun).NewEndpoint()
}
