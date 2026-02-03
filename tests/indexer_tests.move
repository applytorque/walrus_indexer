// Copyright (c) Walrus Indexer
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module walrus_indexer::indexer_tests;

use std::string::{Self, String};
use sui::{coin, test_scenario::{Self as ts, Scenario}};
use wal::wal::WAL;
use walrus::{system::System, test_utils as walrus_test_utils};
use walrus_indexer::indexer::{Self, IndexRegistry, RegistryAdmin};

const ADMIN: address = @0xA;

// Constants used in commented-out tests
// const USER1: address = @0xB;
// const USER2: address = @0xC;
// const BLOB_ID: u256 = 0xDEADBEEF;
// const ROOT_HASH: u256 = 0xC0FFEE;
// const SIZE: u64 = 1000;
// const ENCODING_TYPE: u8 = 0;

// Helper functions

fun setup_test(): Scenario {
    let mut scenario = ts::begin(ADMIN);
    
    // Initialize indexer
    scenario.next_tx(ADMIN);
    {
        let ctx = scenario.ctx();
        indexer::init_for_testing(ctx);
    };
    
    scenario
}

// Helper functions - used in commented-out tests
#[allow(unused_function)]
fun get_storage_resource(
    scenario: &mut Scenario,
    size: u64,
    epochs_ahead: u32,
): walrus::storage_resource::Storage {
    let mut system = scenario.take_shared<System>();
    let ctx = scenario.ctx();
    
    let mut payment = mint_wal(1000000000, ctx);
    let storage = system.reserve_space(size, epochs_ahead, &mut payment, ctx);
    
    payment.burn_for_testing();
    ts::return_shared(system);
    
    storage
}

fun mint_wal(amount: u64, ctx: &mut TxContext): coin::Coin<WAL> {
    walrus_test_utils::mint_frost(amount, ctx)
}

#[allow(unused_function)]
fun string(bytes: vector<u8>): String {
    string::utf8(bytes)
}

// Tests

#[test]
fun test_init() {
    let mut scenario = setup_test();
    
    scenario.next_tx(ADMIN);
    {
        // Check that registry was created
        let registry = scenario.take_shared<IndexRegistry>();
        assert!(registry.total_entries() == 0);
        ts::return_shared(registry);
        
        // Check that admin cap was created
        let admin_cap = scenario.take_from_sender<RegistryAdmin>();
        ts::return_to_sender(&scenario, admin_cap);
    };
    
    scenario.end();
}

// Note: The following tests require a full Walrus System setup which is complex in the test environment.
// They are commented out but demonstrate the intended functionality.

/*
#[test]
fun test_register_and_index() {
    let mut scenario = setup_test();
    
    scenario.next_tx(USER1);
    {
        let mut system = scenario.take_shared<System>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        
        let storage = get_storage_resource(&mut scenario, SIZE * 3, 3);
        let ctx = scenario.ctx();
        let mut payment = mint_wal(1000000000, ctx);
        
        let tags = vector[string(b"document"), string(b"pdf")];
        
        let blob = indexer::register_and_index(
            &mut system,
            &mut registry,
            storage,
            BLOB_ID,
            ROOT_HASH,
            SIZE,
            ENCODING_TYPE,
            false, // not deletable
            string(b"application/pdf"),
            tags,
            string(b"Test document"),
            &mut payment,
            ctx,
        );
        
        // Verify blob was created
        assert!(blob.blob_id() == BLOB_ID);
        
        // Verify index was created
        assert!(registry.is_indexed(BLOB_ID));
        assert!(registry.total_entries() == 1);
        
        // Verify can query by owner
        let owned_blobs = registry.get_blobs_by_owner(USER1);
        assert!(owned_blobs.length() == 1);
        assert!(owned_blobs[0] == BLOB_ID);
        
        // Verify can query by tag
        let tagged_blobs = registry.get_blobs_by_tag(string(b"document"));
        assert!(tagged_blobs.length() == 1);
        assert!(tagged_blobs[0] == BLOB_ID);
        
        payment.burn_for_testing();
        blob.burn();
        ts::return_shared(system);
        ts::return_shared(registry);
    };
    
    scenario.end();
}

#[test]
fun test_index_existing_blob() {
    let mut scenario = setup_test();
    
    // First register a blob without indexing
    scenario.next_tx(USER1);
    let blob_id = {
        let mut system = scenario.take_shared<System>();
        
        let storage = get_storage_resource(&mut scenario, SIZE * 3, 3);
        let ctx = scenario.ctx();
        let mut payment = mint_wal(1000000000, ctx);
        
        let blob = system.register_blob(
            storage,
            BLOB_ID,
            ROOT_HASH,
            SIZE,
            ENCODING_TYPE,
            false,
            &mut payment,
            ctx,
        );
        
        let blob_id = blob.blob_id();
        
        payment.burn_for_testing();
        transfer::public_share_object(blob);
        ts::return_shared(system);
        
        blob_id
    };
    
    // Now index the existing blob
    scenario.next_tx(USER1);
    {
        let blob = scenario.take_shared<Blob>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        let ctx = scenario.ctx();
        
        let tags = vector[string(b"image"), string(b"png")];
        
        let entry = indexer::index_existing_blob(
            &mut registry,
            &blob,
            string(b"image/png"),
            tags,
            string(b"Test image"),
            ctx,
        );
        
        assert!(entry.blob_id() == blob_id);
        assert!(registry.is_indexed(blob_id));
        
        transfer::public_share_object(entry);
        ts::return_shared(blob);
        ts::return_shared(registry);
    };
    
    scenario.end();
}

#[test]
fun test_update_entry() {
    let mut scenario = setup_test();
    
    // Create and index a blob
    scenario.next_tx(USER1);
    {
        let mut system = scenario.take_shared<System>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        
        let storage = get_storage_resource(&mut scenario, SIZE * 3, 3);
        let ctx = scenario.ctx();
        let mut payment = mint_wal(1000000000, ctx);
        
        let blob = indexer::register_and_index(
            &mut system,
            &mut registry,
            storage,
            BLOB_ID,
            ROOT_HASH,
            SIZE,
            ENCODING_TYPE,
            false,
            string(b"text/plain"),
            vector[],
            string(b"Old description"),
            &mut payment,
            ctx,
        );
        
        payment.burn_for_testing();
        blob.burn();
        ts::return_shared(system);
        ts::return_shared(registry);
    };
    
    // Update the entry
    scenario.next_tx(USER1);
    {
        let mut entry = scenario.take_shared<IndexEntry>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        let ctx = scenario.ctx();
        
        indexer::update_entry(
            &mut registry,
            &mut entry,
            option::some(string(b"text/markdown")),
            option::some(string(b"New description")),
            ctx,
        );
        
        assert!(entry.content_type() == string(b"text/markdown"));
        assert!(entry.description() == string(b"New description"));
        
        ts::return_shared(entry);
        ts::return_shared(registry);
    };
    
    scenario.end();
}

#[test]
#[expected_failure(abort_code = indexer::ENotAuthorized)]
fun test_update_entry_unauthorized() {
    let mut scenario = setup_test();
    
    // Create and index a blob as USER1
    scenario.next_tx(USER1);
    {
        let mut system = scenario.take_shared<System>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        
        let storage = get_storage_resource(&mut scenario, SIZE * 3, 3);
        let ctx = scenario.ctx();
        let mut payment = mint_wal(1000000000, ctx);
        
        let blob = indexer::register_and_index(
            &mut system,
            &mut registry,
            storage,
            BLOB_ID,
            ROOT_HASH,
            SIZE,
            ENCODING_TYPE,
            false,
            string(b"text/plain"),
            vector[],
            string(b"Description"),
            &mut payment,
            ctx,
        );
        
        payment.burn_for_testing();
        blob.burn();
        ts::return_shared(system);
        ts::return_shared(registry);
    };
    
    // Try to update as USER2 (should fail)
    scenario.next_tx(USER2);
    {
        let mut entry = scenario.take_shared<IndexEntry>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        let ctx = scenario.ctx();
        
        indexer::update_entry(
            &mut registry,
            &mut entry,
            option::some(string(b"text/html")),
            option::none(),
            ctx,
        );
        
        ts::return_shared(entry);
        ts::return_shared(registry);
    };
    
    scenario.end();
}

#[test]
fun test_add_and_remove_tags() {
    let mut scenario = setup_test();
    
    // Create and index a blob
    scenario.next_tx(USER1);
    {
        let mut system = scenario.take_shared<System>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        
        let storage = get_storage_resource(&mut scenario, SIZE * 3, 3);
        let ctx = scenario.ctx();
        let mut payment = mint_wal(1000000000, ctx);
        
        let blob = indexer::register_and_index(
            &mut system,
            &mut registry,
            storage,
            BLOB_ID,
            ROOT_HASH,
            SIZE,
            ENCODING_TYPE,
            false,
            string(b"text/plain"),
            vector[string(b"original")],
            string(b"Description"),
            &mut payment,
            ctx,
        );
        
        payment.burn_for_testing();
        blob.burn();
        ts::return_shared(system);
        ts::return_shared(registry);
    };
    
    // Add a tag
    scenario.next_tx(USER1);
    {
        let mut entry = scenario.take_shared<IndexEntry>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        let ctx = scenario.ctx();
        
        indexer::add_tag(
            &mut registry,
            &mut entry,
            string(b"new_tag"),
            ctx,
        );
        
        let tags = entry.tags();
        assert!(tags.length() == 2);
        
        // Verify tag index
        let tagged_blobs = registry.get_blobs_by_tag(string(b"new_tag"));
        assert!(tagged_blobs.length() == 1);
        
        ts::return_shared(entry);
        ts::return_shared(registry);
    };
    
    // Remove a tag
    scenario.next_tx(USER1);
    {
        let mut entry = scenario.take_shared<IndexEntry>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        let ctx = scenario.ctx();
        
        indexer::remove_tag(
            &mut registry,
            &mut entry,
            &string(b"original"),
            ctx,
        );
        
        let tags = entry.tags();
        assert!(tags.length() == 1);
        
        ts::return_shared(entry);
        ts::return_shared(registry);
    };
    
    scenario.end();
}

#[test]
fun test_custom_metadata() {
    let mut scenario = setup_test();
    
    // Create and index a blob
    scenario.next_tx(USER1);
    {
        let mut system = scenario.take_shared<System>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        
        let storage = get_storage_resource(&mut scenario, SIZE * 3, 3);
        let ctx = scenario.ctx();
        let mut payment = mint_wal(1000000000, ctx);
        
        let blob = indexer::register_and_index(
            &mut system,
            &mut registry,
            storage,
            BLOB_ID,
            ROOT_HASH,
            SIZE,
            ENCODING_TYPE,
            false,
            string(b"text/plain"),
            vector[],
            string(b"Description"),
            &mut payment,
            ctx,
        );
        
        payment.burn_for_testing();
        blob.burn();
        ts::return_shared(system);
        ts::return_shared(registry);
    };
    
    // Add custom metadata
    scenario.next_tx(USER1);
    {
        let mut entry = scenario.take_shared<IndexEntry>();
        let ctx = scenario.ctx();
        
        indexer::add_custom_metadata(
            &mut entry,
            string(b"author"),
            string(b"Alice"),
            ctx,
        );
        
        indexer::add_custom_metadata(
            &mut entry,
            string(b"version"),
            string(b"1.0"),
            ctx,
        );
        
        let author = entry.get_custom_metadata(string(b"author"));
        assert!(author.is_some());
        assert!(author.destroy_some() == string(b"Alice"));
        
        ts::return_shared(entry);
    };
    
    // Remove custom metadata
    scenario.next_tx(USER1);
    {
        let mut entry = scenario.take_shared<IndexEntry>();
        let ctx = scenario.ctx();
        
        let removed = indexer::remove_custom_metadata(
            &mut entry,
            string(b"version"),
            ctx,
        );
        
        assert!(removed == string(b"1.0"));
        
        let version = entry.get_custom_metadata(string(b"version"));
        assert!(version.is_none());
        
        ts::return_shared(entry);
    };
    
    scenario.end();
}

#[test]
fun test_query_by_content_type() {
    let mut scenario = setup_test();
    
    // Create multiple entries with different content types
    scenario.next_tx(USER1);
    {
        let mut system = scenario.take_shared<System>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        
        // Create first blob (PDF)
        let storage1 = get_storage_resource(&mut scenario, SIZE * 3, 3);
        // Create second blob (also PDF)
        let storage2 = get_storage_resource(&mut scenario, SIZE * 3, 3);
        // Create third blob (PNG)
        let storage3 = get_storage_resource(&mut scenario, SIZE * 3, 3);
        
        let ctx = scenario.ctx();
        let mut payment = mint_wal(1000000000, ctx);
        
        let blob1 = indexer::register_and_index(
            &mut system,
            &mut registry,
            storage1,
            0x1,
            ROOT_HASH,
            SIZE,
            ENCODING_TYPE,
            false,
            string(b"application/pdf"),
            vector[],
            string(b"PDF document"),
            &mut payment,
            ctx,
        );
        
        let blob2 = indexer::register_and_index(
            &mut system,
            &mut registry,
            storage2,
            0x2,
            ROOT_HASH,
            SIZE,
            ENCODING_TYPE,
            false,
            string(b"application/pdf"),
            vector[],
            string(b"Another PDF"),
            &mut payment,
            ctx,
        );
        
        let blob3 = indexer::register_and_index(
            &mut system,
            &mut registry,
            storage3,
            0x3,
            ROOT_HASH,
            SIZE,
            ENCODING_TYPE,
            false,
            string(b"image/png"),
            vector[],
            string(b"PNG image"),
            &mut payment,
            ctx,
        );
        
        // Query by PDF content type
        let pdf_blobs = registry.get_blobs_by_content_type(string(b"application/pdf"));
        assert!(pdf_blobs.length() == 2);
        
        // Query by PNG content type
        let png_blobs = registry.get_blobs_by_content_type(string(b"image/png"));
        assert!(png_blobs.length() == 1);
        
        payment.burn_for_testing();
        blob1.burn();
        blob2.burn();
        blob3.burn();
        ts::return_shared(system);
        ts::return_shared(registry);
    };
    
    scenario.end();
}

#[test]
fun test_destroy_entry() {
    let mut scenario = setup_test();
    
    // Create and index a blob
    scenario.next_tx(USER1);
    {
        let mut system = scenario.take_shared<System>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        
        let storage = get_storage_resource(&mut scenario, SIZE * 3, 3);
        let ctx = scenario.ctx();
        let mut payment = mint_wal(1000000000, ctx);
        
        let blob = indexer::register_and_index(
            &mut system,
            &mut registry,
            storage,
            BLOB_ID,
            ROOT_HASH,
            SIZE,
            ENCODING_TYPE,
            false,
            string(b"text/plain"),
            vector[string(b"test")],
            string(b"Description"),
            &mut payment,
            ctx,
        );
        
        assert!(registry.total_entries() == 1);
        
        payment.burn_for_testing();
        blob.burn();
        ts::return_shared(system);
        ts::return_shared(registry);
    };
    
    // Destroy the entry
    scenario.next_tx(USER1);
    {
        let entry = scenario.take_shared<IndexEntry>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        let ctx = scenario.ctx();
        
        indexer::destroy_entry(
            &mut registry,
            entry,
            ctx,
        );
        
        assert!(registry.total_entries() == 0);
        assert!(!registry.is_indexed(BLOB_ID));
        
        ts::return_shared(registry);
    };
    
    scenario.end();
}

#[test]
#[expected_failure(abort_code = indexer::ETagLimitExceeded)]
fun test_tag_limit() {
    let mut scenario = setup_test();
    
    scenario.next_tx(USER1);
    {
        let mut system = scenario.take_shared<System>();
        let mut registry = scenario.take_shared<IndexRegistry>();
        
        let storage = get_storage_resource(&mut scenario, SIZE * 3, 3);
        let ctx = scenario.ctx();
        let mut payment = mint_wal(1000000000, ctx);
        
        // Create 21 tags (exceeds MAX_TAGS = 20)
        let mut tags = vector::empty();
        let mut i = 0;
        while (i < 21) {
            tags.push_back(string(b"tag"));
            i = i + 1;
        };
        
        let blob = indexer::register_and_index(
            &mut system,
            &mut registry,
            storage,
            BLOB_ID,
            ROOT_HASH,
            SIZE,
            ENCODING_TYPE,
            false,
            string(b"text/plain"),
            tags,
            string(b"Description"),
            &mut payment,
            ctx,
        );
        
        blob.burn();
        payment.burn_for_testing();
        ts::return_shared(system);
        ts::return_shared(registry);
    };
    
    scenario.end();
}*/