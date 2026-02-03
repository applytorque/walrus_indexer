#!/bin/bash

# Complete Walrus Indexer Demo Workflow
# This demonstrates storing a file on Walrus and indexing it

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Deployment info
PACKAGE_ID="0x0d3bae5dd0b3c184cdfb3dc5b6c301b371bc1d5e8a6d009179b3546ff63d8515"
REGISTRY_ID="0x3ec58678e9d0e0b8d70831f784ce998532cfa3cf26924150931e0bf2dc2e6094"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Walrus Indexer - Complete Demo Workflow              ║${NC}"
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo ""

# Check if Walrus CLI is installed
if ! command -v walrus &> /dev/null; then
    echo -e "${RED}✗ Walrus CLI not found${NC}"
    echo ""
    echo -e "${YELLOW}Please install Walrus CLI:${NC}"
    echo "  1. Visit: https://docs.walrus.site/usage/setup.html"
    echo "  2. Download the CLI for your platform"
    echo "  3. Add it to your PATH"
    echo ""
    echo -e "${YELLOW}Quick install (if available):${NC}"
    echo "  curl -fLJO https://github.com/MystenLabs/walrus-docs/releases/download/latest/walrus-testnet-latest-macos-arm64"
    echo "  chmod +x walrus-testnet-latest-macos-arm64"
    echo "  sudo mv walrus-testnet-latest-macos-arm64 /usr/local/bin/walrus"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Walrus CLI found${NC}"
echo ""

# Step 1: Create a sample file
echo -e "${BLUE}Step 1: Creating sample file...${NC}"
cat > sample_document.txt << 'EOF'
Walrus Indexer Demo Document
============================

This is a sample document stored on Walrus decentralized storage
and indexed using the Walrus Indexer protocol on Sui blockchain.

Document Metadata:
- Type: Technical Documentation
- Category: Demo
- Date: 2026-02-03
- Tags: walrus, sui, blockchain, decentralized-storage

Content:
This demonstrates the integration between Walrus storage and 
on-chain indexing for easy content discovery and management.
EOF

echo -e "${GREEN}✓ Created sample_document.txt${NC}"
cat sample_document.txt
echo ""

# Step 2: Store file on Walrus
echo -e "${BLUE}Step 2: Storing file on Walrus...${NC}"
echo -e "${YELLOW}Running: walrus store sample_document.txt${NC}"
STORE_OUTPUT=$(walrus store sample_document.txt 2>&1)
echo "$STORE_OUTPUT"

# Extract blob_id from output
BLOB_ID=$(echo "$STORE_OUTPUT" | grep -oE "Blob ID: 0x[a-fA-F0-9]+" | cut -d' ' -f3 || echo "")
if [ -z "$BLOB_ID" ]; then
    BLOB_ID=$(echo "$STORE_OUTPUT" | grep -oE "blob_id.*0x[a-fA-F0-9]+" | grep -oE "0x[a-fA-F0-9]+" || echo "")
fi

if [ -z "$BLOB_ID" ]; then
    echo -e "${RED}✗ Could not extract blob_id from Walrus output${NC}"
    echo -e "${YELLOW}Please check the output above and manually extract the blob_id${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ File stored on Walrus${NC}"
echo -e "${GREEN}  Blob ID: ${BLOB_ID}${NC}"
echo ""

# Step 3: Get Walrus Storage object and system
echo -e "${BLUE}Step 3: Preparing to index on Sui...${NC}"
echo -e "${YELLOW}Note: You need a Walrus Storage object and WAL tokens${NC}"
echo ""

# Get user's Sui objects
echo "Checking your Sui objects..."
sui client objects --json > /tmp/sui_objects.json 2>/dev/null

# Look for WAL tokens
WAL_COIN=$(cat /tmp/sui_objects.json | jq -r '.[] | select(.type | contains("WAL")) | .objectId' | head -n 1)
if [ -z "$WAL_COIN" ]; then
    echo -e "${YELLOW}No WAL tokens found in your wallet${NC}"
    echo ""
    echo "To get WAL tokens:"
    echo "  1. Visit Walrus faucet (check Walrus docs)"
    echo "  2. Or exchange SUI for WAL on testnet"
    echo ""
fi

# Try to find Walrus System object
SYSTEM_ID=$(sui client objects --json 2>/dev/null | jq -r '.[] | select(.type | contains("System")) | .objectId' | head -n 1)

# Step 4: Create example indexing command
echo -e "${BLUE}Step 4: Example command to index the blob:${NC}"
echo ""
echo -e "${YELLOW}Once you have WAL tokens and storage, run:${NC}"
echo ""
cat << INDEXCMD
sui client call \\
  --package $PACKAGE_ID \\
  --module indexer \\
  --function register_and_index \\
  --args \\
    <SYSTEM_OBJECT_ID> \\
    $REGISTRY_ID \\
    <STORAGE_OBJECT_ID> \\
    $BLOB_ID \\
    <ROOT_HASH> \\
    <SIZE> \\
    <ENCODING_TYPE> \\
    false \\
    '"text/plain"' \\
    '["demo","documentation","walrus"]' \\
    '"Walrus Indexer Demo Document"' \\
    <WAL_COIN_ID> \\
  --gas-budget 50000000
INDEXCMD

echo ""
echo -e "${BLUE}Step 5: After indexing, query your data:${NC}"
echo ""

# Create a query script
cat > query_indexed_blob.sh << 'QUERYSCRIPT'
#!/bin/bash
PACKAGE_ID="0x0d3bae5dd0b3c184cdfb3dc5b6c301b371bc1d5e8a6d009179b3546ff63d8515"
REGISTRY_ID="0x3ec58678e9d0e0b8d70831f784ce998532cfa3cf26924150931e0bf2dc2e6094"
MY_ADDRESS=$(sui client active-address 2>/dev/null | tail -n 1)

echo "Querying your indexed blobs..."
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function get_blobs_by_owner \
  --args $REGISTRY_ID $MY_ADDRESS \
  --gas-budget 10000000

echo ""
echo "Querying blobs tagged 'demo'..."
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function get_blobs_by_tag \
  --args $REGISTRY_ID '"demo"' \
  --gas-budget 10000000
QUERYSCRIPT

chmod +x query_indexed_blob.sh

echo -e "${GREEN}Created query_indexed_blob.sh to query your indexed data${NC}"
echo ""

# Summary
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Summary                               ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ Sample file created: sample_document.txt${NC}"
echo -e "${GREEN}✓ File stored on Walrus${NC}"
echo -e "${GREEN}  Blob ID: ${BLOB_ID}${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Get WAL tokens from Walrus faucet"
echo "  2. Reserve storage space on Walrus"
echo "  3. Use the command above to index your blob"
echo "  4. Run ./query_indexed_blob.sh to query your data"
echo ""
echo -e "${BLUE}Useful Resources:${NC}"
echo "  - Walrus Docs: https://docs.walrus.site"
echo "  - Sui Explorer: https://testnet.suivision.xyz/"
echo "  - Package: https://testnet.suivision.xyz/package/$PACKAGE_ID"
echo ""
