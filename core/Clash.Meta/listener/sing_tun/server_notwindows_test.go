//go:build !windows

package sing_tun

import (
	"errors"
	"os"
	"syscall"
	"testing"

	"github.com/metacubex/sing/common/buf"
)

type closedDarwinTun struct{}

func (closedDarwinTun) Read([]byte) (int, error)  { return 0, nil }
func (closedDarwinTun) Write([]byte) (int, error) { return 0, nil }
func (closedDarwinTun) Close() error              { return nil }

func (closedDarwinTun) BatchRead() ([]*buf.Buffer, error) {
	return nil, os.NewSyscallError("recvmsgx", syscall.ENOTSOCK)
}

func (closedDarwinTun) BatchWrite([]*buf.Buffer) error {
	return nil
}

func TestDarwinBatchReadTreatsENOTSOCKAsClosed(t *testing.T) {
	tunIf := &closedAwareDarwinTun{DarwinTUN: closedDarwinTun{}}
	_, err := tunIf.BatchRead()
	if !errors.Is(err, os.ErrClosed) {
		t.Fatalf("expected closed error, got %v", err)
	}
}
