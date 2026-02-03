#!/bin/bash

# Mock Demo - Test indexer with simulated Walrus blob
# Since we don't have Walrus CLI setup, this demonstrates the indexer functionality

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

PACKAGE_ID="0x0d3bae5dd0b3c184cdfb3dc5b6c301b371bc1d5e8a6d009179b3546ff63d8515"
REGISTRY_ID="0x3ec58678e9d0e0b8d70831f784ce998532cfa3cf26924150931e0bf2dc2e6094"
MY_ADDRESS=$(sui client active-address 2>/dev/null | tail -n 1)

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Walrus Indexer - Mock Demo (Without Walrus CLI)   ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Create sample file to demonstrate
echo -e "${BLUE}Creating sample files to demonstrate...${NC}"
cat > demo_document.json << 'EOF'
{
  "title": "Blockchain Research Paper",
  "author": "Research Team",
  "date": "2026-02-03",
  "abstract": "This paper explores decentralized storage solutions.",
  "tags": ["blockchain", "storage", "research"]
}
EOF

cat > demo_image_metadata.json << 'EOF'
{
  "filename": "sunset.jpg",
  "resolution": "1920x1080",
  "format": "JPEG",
  "tags": ["nature", "sunset", "photography"]
}
EOF

echo -e "${GREEN}✓ Created demo files${NC}"
echo ""

# Simulate blob storage
MOCK_BLOB_ID_1="0x$(openssl rand -hex 32)"
MOCK_BLOB_ID_2="0x$(openssl rand -hex 32)"

echo -e "${BLUE}Simulated Walrus Storage:${NC}"
echo -e "  Document Blob ID: ${GREEN}${MOCK_BLOB_ID_1}${NC}"
echo -e "  Image Blob ID:    ${GREEN}${MOCK_BLOB_ID_2}${NC}"
echo ""

# Test 1: Query current state
echo -e "${BLUE}Test 1: Check current registry state${NC}"
echo "----------------------------------------"
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function total_entries \
  --args $REGISTRY_ID \
  --gas-budget 10000000 2>&1 | grep -A 5 "Status:"

echo ""

# Test 2: Check if mock blob exists
echo -e "${BLUE}Test 2: Check if mock blob is indexed${NC}"
echo "----------------------------------------"
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function is_indexed \
  --args $REGISTRY_ID $MOCK_BLOB_ID_1 \
  --gas-budget 10000000 2>&1 | grep -A 5 "Status:"

echo ""

# Test 3: Query by your address
echo -e "${BLUE}Test 3: Query blobs owned by you${NC}"
echo "----------------------------------------"
echo -e "Your address: ${YELLOW}${MY_ADDRESS}${NC}"
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function get_blobs_by_owner \
  --args $REGISTRY_ID $MY_ADDRESS \
  --gas-budget 10000000 2>&1 | grep -A 5 "Status:"

echo ""

# Test 4: Query by tag
echo -e "${BLUE}Test 4: Query blobs by tag 'research'${NC}"
echo "----------------------------------------"
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function get_blobs_by_tag \
  --args $REGISTRY_ID '"research"' \
  --gas-budget 10000000 2>&1 | grep -A 5 "Status:"

echo ""

# Test 5: Query by content type
echo -e "${BLUE}Test 5: Query blobs by content type${NC}"
echo "----------------------------------------"
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function get_blobs_by_content_type \
  --args $REGISTRY_ID '"application/json"' \
  --gas-budget 10000000 2>&1 | grep -A 5 "Status:"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}         ✓ All Query Tests Completed                  ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Instructions for real usage
echo -e "${BLUE}To use with real Walrus data:${NC}"
echo ""
echo "1. Install Walrus CLI:"
echo "   curl -fLJO https://github.com/MystenLabs/walrus-docs/releases/download/latest/walrus-testnet-latest-macos-arm64"
echo "   chmod +x walrus-testnet-latest-macos-arm64"
echo "   sudo mv walrus-testnet-latest-macos-arm64 /usr/local/bin/walrus"
echo ""
echo "2. Store a file:"
echo "   walrus store demo_document.json"
echo ""
echo "3. Get the blob_id from the output"
echo ""
echo "4. Index it (you'll need WAL tokens and storage):"
echo "   sui client call \\"
echo "     --package $PACKAGE_ID \\"
echo "     --module indexer \\"
echo "     --function index_existing_blob \\"
echo "     --args \\"
echo "       $REGISTRY_ID \\"
echo "       <BLOB_OBJECT_ID> \\"
echo "       '\"application/json\"' \\"
echo "       '[\"research\",\"demo\"]' \\"
echo "       '\"My Research Document\"' \\"
echo "     --gas-budget 50000000"
echo ""
echo -e "${YELLOW}Note: The registry is currently empty (0 entries)${NC}"
echo -e "${YELLOW}Once you index blobs, queries will return results${NC}"
echo ""

# Create a README for reference
cat > INDEXER_USAGE.md << 'USAGE'
# Walrus Indexer Usage Guide

## Deployed Contracts

- **Package ID**: `0x0d3bae5dd0b3c184cdfb3dc5b6c301b371bc1d5e8a6d009179b3546ff63d8515`
- **Registry ID**: `0x3ec58678e9d0e0b8d70831f784ce998532cfa3cf26924150931e0bf2dc2e6094`

## Quick Start

### 1. Store File on Walrus

```bash
walrus store myfile.pdf
# Save the blob_id from output
```

### 2. Index the Blob

```bash
sui client call \
  --package 0x0d3bae5dd0b3c184cdfb3dc5b6c301b371bc1d5e8a6d009179b3546ff63d8515 \
  --module indexer \
  --function index_existing_blob \
  --args \
    0x3ec58678e9d0e0b8d70831f784ce998532cfa3cf26924150931e0bf2dc2e6094 \
    <BLOB_OBJECT_ID> \
    '"application/pdf"' \
    '["document","legal","2026"]' \
    '"My Important Document"' \
  --gas-budget 50000000
```

### 3. Query Your Data

**By Owner:**
```bash
sui client call \
  --package 0x0d3bae5dd0b3c184cdfb3dc5b6c301b371bc1d5e8a6d009179b3546ff63d8515 \
  --module indexer \
  --function get_blobs_by_owner \
  --args \
    0x3ec58678e9d0e0b8d70831f784ce998532cfa3cf26924150931e0bf2dc2e6094 \
    <YOUR_ADDRESS> \
  --gas-budget 10000000
```

**By Tag:**
```bash
sui client call \
  --package 0x0d3bae5dd0b3c184cdfb3dc5b6c301b371bc1d5e8a6d009179b3546ff63d8515 \
  --module indexer \
  --function get_blobs_by_tag \
  --args \
    0x3ec58678e9d0e0b8d70831f784ce998532cfa3cf26924150931e0bf2dc2e6094 \
    '"document"' \
  --gas-budget 10000000
```

**By Content Type:**
```bash
sui client call \
  --package 0x0d3bae5dd0b3c184cdfb3dc5b6c301b371bc1d5e8a6d009179b3546ff63d8515 \
  --module indexer \
  --function get_blobs_by_content_type \
  --args \
    0x3ec58678e9d0e0b8d70831f784ce998532cfa3cf26924150931e0bf2dc2e6094 \
    '"application/pdf"' \
  --gas-budget 10000000
```

## Available Functions

### Indexing
- `register_and_index()` - Register new blob in Walrus and index
- `index_existing_blob()` - Index an already stored Walrus blob

### Updating
- `update_entry()` - Update content type and description
- `add_tag()` - Add a tag to entry
- `remove_tag()` - Remove a tag from entry
- `add_custom_metadata()` - Add custom key-value metadata
- `remove_custom_metadata()` - Remove custom metadata

### Querying
- `total_entries()` - Get total number of indexed blobs
- `is_indexed()` - Check if blob_id is indexed
- `get_blobs_by_owner()` - Get all blobs owned by address
- `get_blobs_by_tag()` - Get all blobs with specific tag
- `get_blobs_by_content_type()` - Get all blobs of content type

### Management
- `destroy_entry()` - Remove entry from index (owner only)

## Notes

- Maximum 20 tags per entry
- Custom metadata stored as key-value pairs
- Owner controls all updates to their entries
- Registry is a shared object - anyone can query
USAGE

echo -e "${GREEN}✓ Created INDEXER_USAGE.md for reference${NC}"
echo ""
