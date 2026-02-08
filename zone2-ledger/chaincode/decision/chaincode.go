package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type DecisionContract struct {
	contractapi.Contract
}

type DecisionRecord struct {
	ID          string `json:"id"`
	Payload     string `json:"payload"`
	AppHash     string `json:"appHash"`
	LedgerHash  string `json:"ledgerHash"`
	TxID        string `json:"txId"`
	TxTimestamp string `json:"txTimestamp"`
	Source      string `json:"source"`
}

func canonicalizeJSON(raw string) ([]byte, error) {
	var v any
	if err := json.Unmarshal([]byte(raw), &v); err != nil {
		return nil, fmt.Errorf("payload is not valid JSON: %w", err)
	}

	normalized, err := json.Marshal(v)
	if err != nil {
		return nil, fmt.Errorf("failed to normalize payload: %w", err)
	}

	return normalized, nil
}

func computeSHA256Hex(input []byte) string {
	sum := sha256.Sum256(input)
	return hex.EncodeToString(sum[:])
}

func txTimestampString(ctx contractapi.TransactionContextInterface) string {
	ts, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return ""
	}
	return fmt.Sprintf("%d.%09d", ts.Seconds, ts.Nanos)
}

func (c *DecisionContract) SubmitDecision(ctx contractapi.TransactionContextInterface, decisionID string, payload string, appHash string) error {
	decisionID = strings.TrimSpace(decisionID)
	appHash = strings.ToLower(strings.TrimSpace(appHash))

	if decisionID == "" {
		return fmt.Errorf("decisionID is required")
	}
	if payload == "" {
		return fmt.Errorf("payload is required")
	}
	if appHash == "" {
		return fmt.Errorf("appHash is required")
	}

	existing, err := ctx.GetStub().GetState(decisionID)
	if err != nil {
		return fmt.Errorf("failed reading existing state: %w", err)
	}
	if existing != nil {
		return fmt.Errorf("decision '%s' already exists", decisionID)
	}

	normalizedPayload, err := canonicalizeJSON(payload)
	if err != nil {
		return err
	}

	ledgerHash := computeSHA256Hex(normalizedPayload)
	if ledgerHash != appHash {
		return fmt.Errorf("hash mismatch: appHash=%s ledgerHash=%s", appHash, ledgerHash)
	}

	record := DecisionRecord{
		ID:          decisionID,
		Payload:     string(normalizedPayload),
		AppHash:     appHash,
		LedgerHash:  ledgerHash,
		TxID:        ctx.GetStub().GetTxID(),
		TxTimestamp: txTimestampString(ctx),
		Source:      "zone2-chaincode",
	}

	recordBytes, err := json.Marshal(record)
	if err != nil {
		return fmt.Errorf("failed to marshal decision record: %w", err)
	}

	if err := ctx.GetStub().PutState(decisionID, recordBytes); err != nil {
		return fmt.Errorf("failed to store decision '%s': %w", decisionID, err)
	}

	idxKey, err := ctx.GetStub().CreateCompositeKey("hash~id", []string{ledgerHash, decisionID})
	if err != nil {
		return fmt.Errorf("failed to create hash index key: %w", err)
	}
	if err := ctx.GetStub().PutState(idxKey, []byte{0}); err != nil {
		return fmt.Errorf("failed to store hash index: %w", err)
	}

	return nil
}

func (c *DecisionContract) QueryDecision(ctx contractapi.TransactionContextInterface, decisionID string) (*DecisionRecord, error) {
	decisionID = strings.TrimSpace(decisionID)
	if decisionID == "" {
		return nil, fmt.Errorf("decisionID is required")
	}

	decisionBytes, err := ctx.GetStub().GetState(decisionID)
	if err != nil {
		return nil, fmt.Errorf("failed to read decision '%s': %w", decisionID, err)
	}
	if decisionBytes == nil {
		return nil, fmt.Errorf("decision '%s' does not exist", decisionID)
	}

	var record DecisionRecord
	if err := json.Unmarshal(decisionBytes, &record); err != nil {
		return nil, fmt.Errorf("failed to unmarshal decision '%s': %w", decisionID, err)
	}

	return &record, nil
}

func (c *DecisionContract) QueryByHash(ctx contractapi.TransactionContextInterface, hash string) ([]*DecisionRecord, error) {
	hash = strings.ToLower(strings.TrimSpace(hash))
	if hash == "" {
		return nil, fmt.Errorf("hash is required")
	}

	iter, err := ctx.GetStub().GetStateByPartialCompositeKey("hash~id", []string{hash})
	if err != nil {
		return nil, fmt.Errorf("failed to query by hash index: %w", err)
	}
	defer iter.Close()

	results := make([]*DecisionRecord, 0)
	for iter.HasNext() {
		kv, err := iter.Next()
		if err != nil {
			return nil, fmt.Errorf("failed iterating hash index: %w", err)
		}

		_, attrs, err := ctx.GetStub().SplitCompositeKey(kv.Key)
		if err != nil {
			return nil, fmt.Errorf("failed parsing hash index key: %w", err)
		}
		if len(attrs) != 2 {
			continue
		}

		decisionID := attrs[1]
		record, err := c.QueryDecision(ctx, decisionID)
		if err != nil {
			return nil, err
		}
		results = append(results, record)
	}

	return results, nil
}

func (c *DecisionContract) ComputeLedgerHash(_ contractapi.TransactionContextInterface, payload string) (string, error) {
	if strings.TrimSpace(payload) == "" {
		return "", fmt.Errorf("payload is required")
	}

	normalizedPayload, err := canonicalizeJSON(payload)
	if err != nil {
		return "", err
	}

	return computeSHA256Hex(normalizedPayload), nil
}

func main() {
	chaincode, err := contractapi.NewChaincode(&DecisionContract{})
	if err != nil {
		panic(fmt.Sprintf("failed creating decision chaincode: %v", err))
	}

	if err := chaincode.Start(); err != nil {
		panic(fmt.Sprintf("failed starting decision chaincode: %v", err))
	}
}
