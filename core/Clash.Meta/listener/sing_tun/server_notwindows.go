//go:build !windows

package sing_tun

import (
	"errors"
	"os"
	"runtime"
	"syscall"

	tun "github.com/metacubex/sing-tun"
	"github.com/metacubex/sing/common/buf"
)

func tunNew(options tun.Options) (tun.Tun, error) {
	tunIf, err := tun.New(options)
	if err != nil || runtime.GOOS != "darwin" {
		return tunIf, err
	}
	darwinTun, ok := tunIf.(tun.DarwinTUN)
	if !ok {
		return tunIf, nil
	}
	return &closedAwareDarwinTun{DarwinTUN: darwinTun}, nil
}

type closedAwareDarwinTun struct {
	tun.DarwinTUN
}

func (t *closedAwareDarwinTun) BatchRead() ([]*buf.Buffer, error) {
	buffers, err := t.DarwinTUN.BatchRead()
	if errors.Is(err, syscall.ENOTSOCK) {
		return nil, os.ErrClosed
	}
	return buffers, err
}
