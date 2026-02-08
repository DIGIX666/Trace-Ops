package main

import "testing"

func TestCanonicalizeJSONDeterministic(t *testing.T) {
	inputA := `{"b":2,"a":1}`
	inputB := `{"a":1,"b":2}`

	normA, err := canonicalizeJSON(inputA)
	if err != nil {
		t.Fatalf("canonicalizeJSON(inputA) returned error: %v", err)
	}

	normB, err := canonicalizeJSON(inputB)
	if err != nil {
		t.Fatalf("canonicalizeJSON(inputB) returned error: %v", err)
	}

	if string(normA) != string(normB) {
		t.Fatalf("canonical JSON mismatch: %s vs %s", string(normA), string(normB))
	}
}

func TestComputeLedgerHashMatchesCanonicalPayload(t *testing.T) {
	c := &DecisionContract{}
	payload := `{"b":2,"a":1}`

	got, err := c.ComputeLedgerHash(nil, payload)
	if err != nil {
		t.Fatalf("ComputeLedgerHash returned error: %v", err)
	}

	norm, err := canonicalizeJSON(`{"a":1,"b":2}`)
	if err != nil {
		t.Fatalf("canonicalizeJSON for expected value returned error: %v", err)
	}
	want := computeSHA256Hex(norm)

	if got != want {
		t.Fatalf("hash mismatch: got %s, want %s", got, want)
	}
}

func TestComputeLedgerHashRejectsInvalidJSON(t *testing.T) {
	c := &DecisionContract{}

	_, err := c.ComputeLedgerHash(nil, `{"a":1`)
	if err == nil {
		t.Fatalf("expected error for invalid JSON payload")
	}
}

func TestComputeLedgerHashRejectsEmptyPayload(t *testing.T) {
	c := &DecisionContract{}

	_, err := c.ComputeLedgerHash(nil, "   ")
	if err == nil {
		t.Fatalf("expected error for empty payload")
	}
}
