# Walrus Indexer Protocol

A smart contract protocol for indexing data stored on Walrus with on-chain searchable metadata.

## 🚀 Live Deployment (Sui Testnet)

**Package**: `0x3b08d25ff1e59883a3cdc1b5f0aa8909104b0c8d28f7e6fbc667927d513f7a81`  
**Registry**: `0x4dda832ca5ab4e1964c7156f2950ad0f1f375e4d9a3cf9ac0b8107ffcef68b86`  
**Network**: Sui Testnet  
**Transaction**: `7TarTw1zhzCfmnfdswByr12coyfVo3rCwTguH4qMACGR`

### Live Demo Website
Check out the [interactive demo website](./website/) that stores its own content on Walrus!

**Website repo**: https://github.com/applytorque/walrus_indexer_site

**Hosting**: Deploy the static site from the repo above (Vercel/Netlify/etc.).
The app fetches content from Walrus using the blob IDs in `blob-registry.json`.

## Overview

Walrus Indexer provides on-chain indexing capabilities for blobs stored on the Walrus decentralized storage network. It allows users to:

- Register and index blobs with rich metadata (content type, tags, descriptions)
- Query blobs by owner, tags, or content type
- Update metadata while maintaining ownership controls
- Add custom key-value metadata pairs
- Maintain multiple indices for efficient lookups

## Architecture

### Core Components

1. **IndexEntry** - Stores metadata for a single blob
   - Blob ID and object reference
   - Content type (MIME type)
   - Tags (up to 20 per entry)
   - Owner, timestamp, description
   - Custom metadata key-value pairs

2. **IndexRegistry** - Shared object maintaining global indices
   - blob_id → IndexEntry mapping
   - owner → blob_ids mapping
   - tag → blob_ids mapping
   - content_type → blob_ids mapping

### Data Structures

Uses efficient Sui Move structures:
- `Table<K, V>` - For large key-value mappings
- `VecSet<T>` - For deduplicated collections
- Avoids `VecMap` to prevent object bloat

## Usage

### Initialization

The protocol initializes automatically on deployment, creating:
- A shared `IndexRegistry`
- An `RegistryAdmin` capability for the deployer

### Register and Index a New Blob

```move
use walrus_indexer::indexer;

// Register blob in Walrus and index it in one call
let blob = indexer::register_and_index(
    system,           // &mut System
    registry,         // &mut IndexRegistry
    storage,          // Storage resource
    blob_id,          // u256 - derived from content
    root_hash,        // u256 - merkle root
    size,             // u64 - unencoded size
    encoding_type,    // u8
    deletable,        // bool
    content_type,     // String - e.g. "image/png"
    tags,             // vector<String> - searchable tags
    description,      // String
    payment,          // &mut Coin<WAL>
    ctx,              // &mut TxContext
);
```

### Index an Existing Blob

```move
// If you already have a blob registered in Walrus
let entry = indexer::index_existing_blob(
    registry,
    blob,            // &Blob reference
    content_type,
    tags,
    description,
    ctx,
);
```

### Update Metadata

```move
// Only the owner can update
indexer::update_entry(
    registry,
    entry,
    option::some(new_content_type),  // Option<String>
    option::some(new_description),   // Option<String>
    ctx,
);
```

### Manage Tags

```move
// Add a tag
indexer::add_tag(registry, entry, tag, ctx);

// Remove a tag
indexer::remove_tag(registry, entry, &tag, ctx);
```

### Custom Metadata

```move
// Add custom key-value pairs
indexer::add_custom_metadata(entry, key, value, ctx);

// Retrieve custom metadata
let value = indexer::get_custom_metadata(entry, key);

// Remove custom metadata
let removed_value = indexer::remove_custom_metadata(entry, key, ctx);
```

### Query Operations

```move
// Get all blobs owned by an address
let blob_ids = indexer::get_blobs_by_owner(registry, owner);

// Get all blobs with a specific tag
let blob_ids = indexer::get_blobs_by_tag(registry, tag);

// Get all blobs of a content type
let blob_ids = indexer::get_blobs_by_content_type(registry, content_type);

// Check if a blob is indexed
let is_indexed = indexer::is_indexed(registry, blob_id);

// Get total indexed entries
let total = indexer::total_entries(registry);
```

## Use Cases

### Document Management System
```move
indexer::register_and_index(
    system, registry, storage,
    blob_id, root_hash, size, encoding_type, false,
    string::utf8(b"application/pdf"),
    vector[
        string::utf8(b"contract"),
        string::utf8(b"legal"),
        string::utf8(b"2026-Q1")
    ],
    string::utf8(b"Partnership Agreement v2.1"),
    payment, ctx
);
```

### NFT Metadata Storage
```move
let entry = indexer::index_existing_blob(
    registry, nft_blob,
    string::utf8(b"image/png"),
    vector[
        string::utf8(b"artwork"),
        string::utf8(b"collectible"),
        string::utf8(b"rare")
    ],
    string::utf8(b"Unique digital artwork #42"),
    ctx
);

// Add NFT-specific metadata
indexer::add_custom_metadata(entry, 
    string::utf8(b"artist"), 
    string::utf8(b"Alice"), 
    ctx
);
indexer::add_custom_metadata(entry,
    string::utf8(b"rarity"),
    string::utf8(b"legendary"),
    ctx
);
```

### Data Marketplace
```move
// Index a dataset
let entry = indexer::register_and_index(
    system, registry, storage,
    blob_id, root_hash, size, encoding_type, false,
    string::utf8(b"application/json"),
    vector[
        string::utf8(b"dataset"),
        string::utf8(b"machine-learning"),
        string::utf8(b"images")
    ],
    string::utf8(b"Image classification dataset - 10K samples"),
    payment, ctx
);

// Add marketplace metadata
indexer::add_custom_metadata(entry,
    string::utf8(b"price"),
    string::utf8(b"100000000"), // in MIST
    ctx
);
indexer::add_custom_metadata(entry,
    string::utf8(b"license"),
    string::utf8(b"CC-BY-4.0"),
    ctx
);
```

## Security & Access Control

- **Owner-Only Operations**: Only the entry owner can:
  - Update metadata
  - Add/remove tags
  - Add/remove custom metadata
  - Destroy the entry

- **Public Queries**: All query functions are public and read-only

- **Immutable Blob References**: Once indexed, the blob_id and blob_object_id cannot be changed

## Limitations

- Maximum 20 tags per entry (`MAX_TAGS = 20`)
- Custom metadata must be string key-value pairs
- On-chain storage costs scale with number of indices

## Building and Testing

```bash
# Build the package
sui move build

# Run tests
sui move test

# Run specific test
sui move test test_register_and_index
```

## Dependencies

- Sui Framework (testnet-v1.35.0)
- Walrus contracts (local dependency)
- WAL token contract (local dependency)

## License

Apache-2.0
