//go:build !darwin

package dhcp

import (
	"context"
	"net/netip"
)

func resolveDNSFromSystem(context.Context, string) ([]netip.Addr, error) {
	return nil, ErrNotFound
}
