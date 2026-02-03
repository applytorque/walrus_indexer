// Copyright (c) Walrus Indexer
// SPDX-License-Identifier: Apache-2.0

/// Core indexing module for Walrus data storage
/// Provides on-chain indexing capabilities for blobs stored on Walrus
module walrus_indexer::indexer;

use std::string::String;
use sui::{coin::Coin, table::{Self, Table}, vec_set::{Self, VecSet}};
use wal::wal::WAL;
use walrus::{blob::Blob, storage_resource::Storage, system::System};

// Error codes
/// The index entry already exists
const EIndexEntryExists: u64 = 0;
/// Not authorized to perform this action
const ENotAuthorized: u64 = 2;
/// Tag limit exceeded
const ETagLimitExceeded: u64 = 3;

/// Maximum number of tags per entry
const MAX_TAGS: u64 = 20;

// === Object definitions ===

/// Individual index entry that stores metadata about a blob
public struct IndexEntry has key, store {
    id: UID,
    /// The Walrus blob ID (u256 hash)
    blob_id: u256,
    /// Reference to the actual Blob object
    blob_object_id: ID,
    /// MIME type or content type
    content_type: String,
    /// Searchable tags
    tags: VecSet<String>,
    /// Owner of this entry
    owner: address,
    /// Unix timestamp in milliseconds
    created_at: u64,
    /// Optional description
    description: String,
    /// Custom metadata as key-value pairs
    custom_metadata: Table<String, String>,
}

/// Global registry for all indexed data
/// This is a shared object that maintains all indices
public struct IndexRegistry has key {
    id: UID,
    /// Map blob_id to IndexEntry object ID
    blob_to_entry: Table<u256, ID>,
    /// Map owner address to list of their blob_ids
    owner_index: Table<address, VecSet<u256>>,
    /// Map tag to list of blob_ids with that tag
    tag_index: Table<String, VecSet<u256>>,
    /// Map content_type to list of blob_ids
    content_type_index: Table<String, VecSet<u256>>,
    /// Total number of indexed entries
    total_entries: u64,
}

/// Capability for managing the registry
public struct RegistryAdmin has key, store {
    id: UID,
}

// === Events ===

/// Emitted when a new blob is indexed
public struct BlobIndexed has copy, drop {
    blob_id: u256,
    blob_object_id: ID,
    entry_id: ID,
    owner: address,
    content_type: String,
    tags: vector<String>,
    created_at: u64,
}

/// Emitted when an index entry is updated
public struct BlobIndexUpdated has copy, drop {
    blob_id: u256,
    entry_id: ID,
    updated_by: address,
}

/// Emitted when an index entry is removed
public struct BlobIndexRemoved has copy, drop {
    blob_id: u256,
    entry_id: ID,
    removed_by: address,
}

// === Public functions ===

/// Initialize the indexer registry (call once)
fun init(ctx: &mut TxContext) {
    let registry = IndexRegistry {
        id: object::new(ctx),
        blob_to_entry: table::new(ctx),
        owner_index: table::new(ctx),
        tag_index: table::new(ctx),
        content_type_index: table::new(ctx),
        total_entries: 0,
    };
    transfer::share_object(registry);

    // Create admin capability
    let admin = RegistryAdmin {
        id: object::new(ctx),
    };
    transfer::transfer(admin, ctx.sender());
}

/// Register a new blob in Walrus and index it
/// Returns the Blob object which should be stored or shared by the caller
#[allow(lint(self_transfer))]
public fun register_and_index(
    system: &mut System,
    registry: &mut IndexRegistry,
    storage: Storage,
    blob_id: u256,
    root_hash: u256,
    size: u64,
    encoding_type: u8,
    deletable: bool,
    content_type: String,
    tags: vector<String>,
    description: String,
    payment: &mut Coin<WAL>,
    ctx: &mut TxContext,
): Blob {
    // Validate tags
    assert!(tags.length() <= MAX_TAGS, ETagLimitExceeded);

    // Register blob in Walrus
    let blob = system.register_blob(
        storage,
        blob_id,
        root_hash,
        size,
        encoding_type,
        deletable,
        payment,
        ctx,
    );

    let blob_object_id = object::id(&blob);

    // Create index entry
    let entry = create_index_entry(
        blob_id,
        blob_object_id,
        content_type,
        tags,
        description,
        ctx,
    );

    // Add to registry
    add_to_registry(registry, &entry, ctx);

    // Transfer the entry to the sender
    transfer::transfer(entry, ctx.sender());

    blob
}

/// Index an existing blob (if blob was registered elsewhere)
public fun index_existing_blob(
    registry: &mut IndexRegistry,
    blob: &Blob,
    content_type: String,
    tags: vector<String>,
    description: String,
    ctx: &mut TxContext,
): IndexEntry {
    // Validate tags
    assert!(tags.length() <= MAX_TAGS, ETagLimitExceeded);

    let blob_id = blob.blob_id();
    let blob_object_id = object::id(blob);

    // Check if already indexed
    assert!(!registry.blob_to_entry.contains(blob_id), EIndexEntryExists);

    // Create index entry
    let entry = create_index_entry(
        blob_id,
        blob_object_id,
        content_type,
        tags,
        description,
        ctx,
    );

    // Add to registry
    add_to_registry(registry, &entry, ctx);

    entry
}

/// Update metadata of an existing index entry (only owner can update)
public fun update_entry(
    registry: &mut IndexRegistry,
    entry: &mut IndexEntry,
    new_content_type: option::Option<String>,
    new_description: option::Option<String>,
    ctx: &TxContext,
) {
    // Only owner can update
    assert!(entry.owner == ctx.sender(), ENotAuthorized);

    let blob_id = entry.blob_id;

    // Update content type index if changed
    if (new_content_type.is_some()) {
        let new_type = new_content_type.destroy_some();
        
        // Remove from old content type index
        if (registry.content_type_index.contains(entry.content_type)) {
            let blob_set = &mut registry.content_type_index[entry.content_type];
            blob_set.remove(&blob_id);
        };

        // Add to new content type index
        if (!registry.content_type_index.contains(new_type)) {
            registry.content_type_index.add(new_type, vec_set::empty());
        };
        registry.content_type_index[new_type].insert(blob_id);

        entry.content_type = new_type;
    };

    // Update description
    if (new_description.is_some()) {
        entry.description = new_description.destroy_some();
    };

    sui::event::emit(BlobIndexUpdated {
        blob_id,
        entry_id: object::id(entry),
        updated_by: ctx.sender(),
    });
}

/// Add a tag to an index entry (only owner can add)
public fun add_tag(
    registry: &mut IndexRegistry,
    entry: &mut IndexEntry,
    tag: String,
    ctx: &TxContext,
) {
    // Only owner can add tags
    assert!(entry.owner == ctx.sender(), ENotAuthorized);
    assert!(entry.tags.length() < MAX_TAGS, ETagLimitExceeded);

    let blob_id = entry.blob_id;

    // Add tag to entry
    entry.tags.insert(tag);

    // Add to tag index
    if (!registry.tag_index.contains(tag)) {
        registry.tag_index.add(tag, vec_set::empty());
    };
    registry.tag_index[tag].insert(blob_id);

    sui::event::emit(BlobIndexUpdated {
        blob_id,
        entry_id: object::id(entry),
        updated_by: ctx.sender(),
    });
}

/// Remove a tag from an index entry (only owner can remove)
public fun remove_tag(
    registry: &mut IndexRegistry,
    entry: &mut IndexEntry,
    tag: &String,
    ctx: &TxContext,
) {
    // Only owner can remove tags
    assert!(entry.owner == ctx.sender(), ENotAuthorized);

    let blob_id = entry.blob_id;

    // Remove tag from entry
    entry.tags.remove(tag);

    // Remove from tag index
    if (registry.tag_index.contains(*tag)) {
        let blob_set = &mut registry.tag_index[*tag];
        blob_set.remove(&blob_id);
    };

    sui::event::emit(BlobIndexUpdated {
        blob_id,
        entry_id: object::id(entry),
        updated_by: ctx.sender(),
    });
}

/// Add custom metadata key-value pair (only owner can add)
public fun add_custom_metadata(
    entry: &mut IndexEntry,
    key: String,
    value: String,
    ctx: &TxContext,
) {
    // Only owner can add metadata
    assert!(entry.owner == ctx.sender(), ENotAuthorized);

    if (entry.custom_metadata.contains(key)) {
        entry.custom_metadata.remove(key);
    };
    entry.custom_metadata.add(key, value);
}

/// Remove custom metadata (only owner can remove)
public fun remove_custom_metadata(
    entry: &mut IndexEntry,
    key: String,
    ctx: &TxContext,
): String {
    // Only owner can remove metadata
    assert!(entry.owner == ctx.sender(), ENotAuthorized);
    entry.custom_metadata.remove(key)
}

/// Destroy an index entry and remove from registry (only owner)
public fun destroy_entry(
    registry: &mut IndexRegistry,
    entry: IndexEntry,
    ctx: &TxContext,
) {
    // Only owner can destroy
    assert!(entry.owner == ctx.sender(), ENotAuthorized);

    let blob_id = entry.blob_id;
    let entry_id = object::id(&entry);

    // Remove from all indices
    remove_from_registry(registry, &entry);

    // Destroy the entry
    let IndexEntry {
        id,
        blob_id: _,
        blob_object_id: _,
        content_type: _,
        tags: _,
        owner: _,
        created_at: _,
        description: _,
        custom_metadata,
    } = entry;

    custom_metadata.destroy_empty();
    id.delete();

    sui::event::emit(BlobIndexRemoved {
        blob_id,
        entry_id,
        removed_by: ctx.sender(),
    });
}

// === Query functions (view only) ===

/// Get all blob IDs owned by an address
public fun get_blobs_by_owner(
    registry: &IndexRegistry,
    owner: address,
): vector<u256> {
    if (registry.owner_index.contains(owner)) {
        registry.owner_index[owner].into_keys()
    } else {
        vector::empty()
    }
}

/// Get all blob IDs with a specific tag
public fun get_blobs_by_tag(
    registry: &IndexRegistry,
    tag: String,
): vector<u256> {
    if (registry.tag_index.contains(tag)) {
        registry.tag_index[tag].into_keys()
    } else {
        vector::empty()
    }
}

/// Get all blob IDs with a specific content type
public fun get_blobs_by_content_type(
    registry: &IndexRegistry,
    content_type: String,
): vector<u256> {
    if (registry.content_type_index.contains(content_type)) {
        registry.content_type_index[content_type].into_keys()
    } else {
        vector::empty()
    }
}

/// Check if a blob is indexed
public fun is_indexed(registry: &IndexRegistry, blob_id: u256): bool {
    registry.blob_to_entry.contains(blob_id)
}

/// Get the entry ID for a blob
public fun get_entry_id(registry: &IndexRegistry, blob_id: u256): option::Option<ID> {
    if (registry.blob_to_entry.contains(blob_id)) {
        option::some(registry.blob_to_entry[blob_id])
    } else {
        option::none()
    }
}

/// Get total number of indexed entries
public fun total_entries(registry: &IndexRegistry): u64 {
    registry.total_entries
}

// === IndexEntry accessors ===

public fun blob_id(entry: &IndexEntry): u256 {
    entry.blob_id
}

public fun blob_object_id(entry: &IndexEntry): ID {
    entry.blob_object_id
}

public fun content_type(entry: &IndexEntry): String {
    entry.content_type
}

public fun tags(entry: &IndexEntry): vector<String> {
    entry.tags.into_keys()
}

public fun owner(entry: &IndexEntry): address {
    entry.owner
}

public fun created_at(entry: &IndexEntry): u64 {
    entry.created_at
}

public fun description(entry: &IndexEntry): String {
    entry.description
}

public fun get_custom_metadata(entry: &IndexEntry, key: String): option::Option<String> {
    if (entry.custom_metadata.contains(key)) {
        option::some(entry.custom_metadata[key])
    } else {
        option::none()
    }
}

// === Private helper functions ===

/// Create a new index entry
fun create_index_entry(
    blob_id: u256,
    blob_object_id: ID,
    content_type: String,
    tags: vector<String>,
    description: String,
    ctx: &mut TxContext,
): IndexEntry {
    let mut tag_set = vec_set::empty();
    tags.do_ref!(|tag| {
        tag_set.insert(*tag);
    });

    let entry = IndexEntry {
        id: object::new(ctx),
        blob_id,
        blob_object_id,
        content_type,
        tags: tag_set,
        owner: ctx.sender(),
        created_at: ctx.epoch_timestamp_ms(),
        description,
        custom_metadata: table::new(ctx),
    };

    entry
}

/// Add entry to all registry indices
fun add_to_registry(
    registry: &mut IndexRegistry,
    entry: &IndexEntry,
    ctx: &TxContext,
) {
    let blob_id = entry.blob_id;
    let entry_id = object::id(entry);
    let owner = ctx.sender();

    // Check if already exists
    assert!(!registry.blob_to_entry.contains(blob_id), EIndexEntryExists);

    // Add to main index
    registry.blob_to_entry.add(blob_id, entry_id);

    // Add to owner index
    if (!registry.owner_index.contains(owner)) {
        registry.owner_index.add(owner, vec_set::empty());
    };
    registry.owner_index[owner].insert(blob_id);

    // Add to tag index
    entry.tags.into_keys().do_ref!(|tag| {
        if (!registry.tag_index.contains(*tag)) {
            registry.tag_index.add(*tag, vec_set::empty());
        };
        registry.tag_index[*tag].insert(blob_id);
    });

    // Add to content type index
    if (!registry.content_type_index.contains(entry.content_type)) {
        registry.content_type_index.add(entry.content_type, vec_set::empty());
    };
    registry.content_type_index[entry.content_type].insert(blob_id);

    // Increment counter
    registry.total_entries = registry.total_entries + 1;

    // Emit event
    sui::event::emit(BlobIndexed {
        blob_id,
        blob_object_id: entry.blob_object_id,
        entry_id,
        owner,
        content_type: entry.content_type,
        tags: entry.tags.into_keys(),
        created_at: entry.created_at,
    });
}

/// Remove entry from all registry indices
fun remove_from_registry(
    registry: &mut IndexRegistry,
    entry: &IndexEntry,
) {
    let blob_id = entry.blob_id;

    // Remove from main index
    registry.blob_to_entry.remove(blob_id);

    // Remove from owner index
    if (registry.owner_index.contains(entry.owner)) {
        let blob_set = &mut registry.owner_index[entry.owner];
        blob_set.remove(&blob_id);
    };

    // Remove from tag index
    entry.tags.into_keys().do_ref!(|tag| {
        if (registry.tag_index.contains(*tag)) {
            let blob_set = &mut registry.tag_index[*tag];
            blob_set.remove(&blob_id);
        };
    });

    // Remove from content type index
    if (registry.content_type_index.contains(entry.content_type)) {
        let blob_set = &mut registry.content_type_index[entry.content_type];
        blob_set.remove(&blob_id);
    };

    // Decrement counter
    registry.total_entries = registry.total_entries - 1;
}

// === Test-only functions ===

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
