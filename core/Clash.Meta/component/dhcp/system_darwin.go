//go:build darwin

package dhcp

import (
	"bufio"
	"context"
	"net"
	"net/netip"
	"os/exec"
	"strconv"
	"strings"
)

func resolveDNSFromSystem(ctx context.Context, ifaceName string) ([]netip.Addr, error) {
	iface, err := net.InterfaceByName(ifaceName)
	if err != nil {
		return nil, err
	}

	output, err := exec.CommandContext(ctx, "/usr/sbin/scutil", "--dns").Output()
	if err != nil {
		return nil, err
	}

	servers := parseScopedDNS(string(output), iface.Index)
	if len(servers) == 0 {
		return nil, ErrNotFound
	}
	return servers, nil
}

func parseScopedDNS(output string, interfaceIndex int) []netip.Addr {
	type resolverBlock struct {
		interfaceIndex int
		scoped         bool
		servers        []netip.Addr
	}

	var (
		block   resolverBlock
		servers []netip.Addr
		seen    = map[netip.Addr]struct{}{}
	)
	flush := func() {
		if block.interfaceIndex != interfaceIndex || !block.scoped {
			return
		}
		for _, server := range block.servers {
			if _, exists := seen[server]; exists {
				continue
			}
			seen[server] = struct{}{}
			servers = append(servers, server)
		}
	}

	scanner := bufio.NewScanner(strings.NewReader(output))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		switch {
		case strings.HasPrefix(line, "resolver #"):
			flush()
			block = resolverBlock{}
		case strings.HasPrefix(line, "nameserver["):
			if _, value, ok := strings.Cut(line, ":"); ok {
				if server, err := netip.ParseAddr(strings.TrimSpace(value)); err == nil {
					block.servers = append(block.servers, server.Unmap())
				}
			}
		case strings.HasPrefix(line, "if_index"):
			if _, value, ok := strings.Cut(line, ":"); ok {
				if fields := strings.Fields(value); len(fields) > 0 {
					index, _ := strconv.Atoi(fields[0])
					block.interfaceIndex = index
				}
			}
		case strings.HasPrefix(line, "flags"):
			block.scoped = strings.Contains(line, "Scoped")
		}
	}
	flush()

	return servers
}
