package tls

import (
	"crypto"
	"io"
)

type cryptoMessageSigner interface {
	crypto.Signer
	SignMessage(rand io.Reader, msg []byte, opts crypto.SignerOpts) (signature []byte, err error)
}

func cryptoSignMessage(signer crypto.Signer, rand io.Reader, msg []byte, opts crypto.SignerOpts) (signature []byte, err error) {
	if ms, ok := signer.(cryptoMessageSigner); ok {
		return ms.SignMessage(rand, msg, opts)
	}
	if opts.HashFunc() != 0 {
		h := opts.HashFunc().New()
		h.Write(msg)
		msg = h.Sum(nil)
	}
	return signer.Sign(rand, msg, opts)
}
