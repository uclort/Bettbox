// Copyright 2024 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package tls

import (
	"crypto/hmac"
	"hash"
)

// tls12PRF implements the TLS 1.2 pseudo-random function, as defined in RFC 5246,
// Section 5 and allowed by SP 800-135, Revision 1, Section 4.2.2.
func tls12PRF[H hash.Hash](hash func() H, secret []byte, label string, seed []byte, keyLen int) []byte {
	labelAndSeed := make([]byte, len(label)+len(seed))
	copy(labelAndSeed, label)
	copy(labelAndSeed[len(label):], seed)

	result := make([]byte, keyLen)
	tls12pHash(hash, result, secret, labelAndSeed)
	return result
}

// tls12pHash implements the P_hash function, as defined in RFC 5246, Section 5.
func tls12pHash[H hash.Hash](hash_ func() H, result, secret, seed []byte) {
	h := hmac.New(func() hash.Hash { return hash_() }, secret)
	h.Write(seed)
	a := h.Sum(nil)

	for len(result) > 0 {
		h.Reset()
		h.Write(a)
		h.Write(seed)
		b := h.Sum(nil)
		n := copy(result, b)
		result = result[n:]

		h.Reset()
		h.Write(a)
		a = h.Sum(nil)
	}
}

//const masterSecretLength = 48
//const extendedMasterSecretLabel = "extended master secret"

// tls12MasterSecret implements the TLS 1.2 extended master secret derivation, as
// defined in RFC 7627 and allowed by SP 800-135, Revision 1, Section 4.2.2.
func tls12MasterSecret[H hash.Hash](hash func() H, preMasterSecret, transcript []byte) []byte {
	return tls12PRF(hash, preMasterSecret, extendedMasterSecretLabel, transcript, masterSecretLength)
}
