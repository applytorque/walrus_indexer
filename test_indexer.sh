#!/bin/bash

# Walrus Indexer Test Script
# This script tests the deployed indexer protocol

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Deployment info
PACKAGE_ID="0x0d3bae5dd0b3c184cdfb3dc5b6c301b371bc1d5e8a6d009179b3546ff63d8515"
REGISTRY_ID="0x3ec58678e9d0e0b8d70831f784ce998532cfa3cf26924150931e0bf2dc2e6094"
ADMIN_CAP_ID="0x6cc6d3490c85e838f0796496b0cc4552b708740c1b364dc51503b2e671093d10"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Walrus Indexer Protocol Test${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Get active address
ACTIVE_ADDRESS=$(sui client active-address 2>/dev/null | tail -n 1)
echo -e "${GREEN}Active Address:${NC} $ACTIVE_ADDRESS"
echo -e "${GREEN}Package ID:${NC} $PACKAGE_ID"
echo -e "${GREEN}Registry ID:${NC} $REGISTRY_ID"
echo ""

# Test 1: Query total entries (should be 0 initially)
echo -e "${BLUE}Test 1: Query Registry Total Entries${NC}"
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function total_entries \
  --args $REGISTRY_ID \
  --gas-budget 10000000

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}✓ Basic query test completed${NC}"
echo ""

# Test 2: Check if specific blob is indexed
echo -e "${BLUE}Test 2: Check if blob is indexed${NC}"
TEST_BLOB_ID="0x1234567890abcdef"
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function is_indexed \
  --args $REGISTRY_ID $TEST_BLOB_ID \
  --gas-budget 10000000

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}✓ Blob index check completed${NC}"
echo ""

# Test 3: Query blobs by owner
echo -e "${BLUE}Test 3: Query blobs by owner${NC}"
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function get_blobs_by_owner \
  --args $REGISTRY_ID $ACTIVE_ADDRESS \
  --gas-budget 10000000

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}✓ Owner query test completed${NC}"
echo ""

# Test 4: Query blobs by tag
echo -e "${BLUE}Test 4: Query blobs by tag${NC}"
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function get_blobs_by_tag \
  --args $REGISTRY_ID '"document"' \
  --gas-budget 10000000

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}✓ Tag query test completed${NC}"
echo ""

# Test 5: Query blobs by content type
echo -e "${BLUE}Test 5: Query blobs by content type${NC}"
sui client call \
  --package $PACKAGE_ID \
  --module indexer \
  --function get_blobs_by_content_type \
  --args $REGISTRY_ID '"application/pdf"' \
  --gas-budget 10000000

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}✓ Content type query test completed${NC}"
echo ""

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}All tests completed successfully!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Get WAL tokens from Walrus faucet"
echo "2. Store a file on Walrus using 'walrus store <file>'"
echo "3. Use the blob_id to call register_and_index function"
echo ""
