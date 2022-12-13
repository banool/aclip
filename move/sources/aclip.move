// If ever updating this version, also update:
// - frontend/lib/constants.dart
module addr::aclip {
    use std::string;
    use std::error;
    use std::signer;
    use std::vector;
    use aptos_framework::timestamp;
    use aptos_std::simple_map;

    const E_NOT_INITIALIZED: u64 = 1;

    #[test_only]
    /// Used for assertions in tests.
    const E_TEST_FAILURE: u64 = 100;

    /// Top level module. This just contains the Inner struct, which actually
    /// holds all the interesting stuff. We do it this way so it's easy to
    /// grab a mutable reference to everything at once without running into
    /// issues from holding multiple references. This is acceptable for now.
    struct Root has key {
        inner: Inner,
    }

    /// All the interesting stuff.
    struct Inner has store {
        /// Table of links, where the key is the escaped URL.
        links: simple_map::SimpleMap<string::String, LinkData>,

        /// As above, but the key is encrypted using the private key and the
        /// value is an encrypted version of LinkData.
        secret_links: simple_map::SimpleMap<vector<u8>, EncryptedLinkData>,

        /// Any link the user has chosen to archive.
        archived_links: simple_map::SimpleMap<string::String, LinkData>,

        /// Any secret link the user has chosen to archive.
        archived_secret_links: simple_map::SimpleMap<vector<u8>, EncryptedLinkData>,
    }

    struct EncryptedLinkData has drop, store {
        // LinkData (as JSON) encrypted.
        link_data: vector<u8>,

        // The nonce used for the encryption of `link_Data` and the accompanying key (URL).
        nonce: u64,
    }

    struct LinkData has drop, store {
        /// When the item was added.
        added_at_microseconds: u64,

        /// Any arbitrary tags the user wants to add.
        tags: vector<string::String>,
    }

    /// Initialize the list to the caller's account.
    public entry fun initialize_list(account: &signer) {
        let inner = Inner {
            links: simple_map::create(),
            secret_links: simple_map::create(),
            archived_links: simple_map::create(),
            archived_secret_links: simple_map::create(),
        };
        move_to(account, Root{inner: inner });
    }

    /*
    /// Delete everything, even there are still items. Use with extreme caution.
    public entry fun obliterate(account: &signer) acquires Root {
        let addr = signer::address_of(account);
        assert!(exists<Root>(addr), error::invalid_state(E_NOT_INITIALIZED));

        let root = move_from<Root>(addr);
        let Root { inner } = root;
        let Inner { links, secret_links, archived_links, archived_secret_links } = inner;
        dump_list(links);
        dump_list(secret_links);
        dump_list(archived_links);
        dump_list(archived_secret_links);
    }

    fun dump_list<K: copy + store + drop, V: drop + store>(list: simple_map::SimpleMap<K, V>) {
        let key = simple_map::head_key(&list);
        loop {
            if (option::is_none(&key)) {
                break
            };
            let (_v, _prev, next) = simple_map::remove_iter(&mut list, option::extract(&mut key));
            key = next;
        };
        simple_map::destroy_empty(list);
    }
    */

    /// Add a link to links. We don't bother handling collisions, we would just
    /// make it throw an error anyway.
    public entry fun add(account: &signer, url_raw: vector<u8>, tags_raw: vector<vector<u8>>, add_to_archive: bool) acquires Root {
        let addr = signer::address_of(account);
        assert!(exists<Root>(addr), error::invalid_state(E_NOT_INITIALIZED));

        let tags = vector::empty();

        let i = 0;
        while (i < vector::length(&tags_raw)) {
            vector::push_back(&mut tags, string::utf8(vector::pop_back(&mut tags_raw)));
            i = i + 1;
        };

        let link_data = LinkData {
            added_at_microseconds: timestamp::now_microseconds(),
            tags: tags,
        };

        let inner = &mut borrow_global_mut<Root>(addr).inner;

        if (add_to_archive) {
            simple_map::add(&mut inner.archived_links, string::utf8(url_raw), link_data);
        } else {
            simple_map::add(&mut inner.links, string::utf8(url_raw), link_data);
        };
    }

    /// This is just a helper for external testing mostly.
    public entry fun add_simple(account: &signer, url_raw: vector<u8>) acquires Root {
        add(account, url_raw, vector::empty(), false);
    }

    /// Add a link to secret_links. As above, we don't bother with collisions.
    public entry fun add_secret(account: &signer, url: vector<u8>, link_data: vector<u8>, nonce: u64, add_to_archive: bool) acquires Root {
        let addr = signer::address_of(account);
        assert!(exists<Root>(addr), error::invalid_state(E_NOT_INITIALIZED));

        let addr = signer::address_of(account);
        let inner = &mut borrow_global_mut<Root>(addr).inner;

        let encrypted_link_data = EncryptedLinkData {
            link_data: link_data,
            nonce: nonce,
        };

        if (add_to_archive) {
            simple_map::add(&mut inner.archived_secret_links, url, encrypted_link_data);
        } else {
            simple_map::add(&mut inner.secret_links, url, encrypted_link_data);
        };
    }

    /// Remove an item with the given key. We trust the user isn't trying to remove
    /// a key that isn't in their list. We opt to be cheeky here and use this function
    /// for all 4 different lists. In the secret case, `url_raw` is the encrypted URL.
    public entry fun remove(account: &signer, url_raw: vector<u8>, from_archive: bool, from_secrets: bool) acquires Root {
        let addr = signer::address_of(account);
        assert!(exists<Root>(addr), error::invalid_state(E_NOT_INITIALIZED));

        let inner = &mut borrow_global_mut<Root>(addr).inner;

        if (from_secrets) {
            if (from_archive) {
                simple_map::remove(&mut inner.archived_secret_links, &url_raw);
            } else {
                simple_map::remove(&mut inner.secret_links, &url_raw);
            }
        } else {
            let url = string::utf8(url_raw);
            if (from_archive) {
                simple_map::remove(&mut inner.archived_links, &url);
            } else {
                simple_map::remove(&mut inner.links, &url);
            }
        };
    }

    /// Move an item to / from the archived version of that list.
    public entry fun set_archived(account: &signer, url_raw: vector<u8>, make_archived: bool, is_secret: bool) acquires Root {
        let addr = signer::address_of(account);
        assert!(exists<Root>(addr), error::invalid_state(E_NOT_INITIALIZED));

        let inner = &mut borrow_global_mut<Root>(addr).inner;

        if (is_secret) {
            if (make_archived) {
                let (key, item) = simple_map::remove(&mut inner.secret_links, &url_raw);
                simple_map::add(&mut inner.archived_secret_links, key, item);
            } else {
                let (key, item) = simple_map::remove(&mut inner.archived_secret_links, &url_raw);
                simple_map::add(&mut inner.secret_links, key, item);
            }
        } else {
            let url = string::utf8(url_raw);
            if (make_archived) {
                let (key, item) = simple_map::remove(&mut inner.links, &url);
                simple_map::add(&mut inner.archived_links, key, item);
            } else {
                let (key, item) = simple_map::remove(&mut inner.archived_links, &url);
                simple_map::add(&mut inner.links, key, item);
            }
        };
    }

    #[test(aptos_framework = @aptos_framework, account = @0x123)]
    public entry fun test_add_remove_archive(aptos_framework: &signer, account: signer) acquires Root {
        timestamp::set_time_has_started_for_testing(aptos_framework);

        let addr = signer::address_of(&account);

        // Initialize a list on account.
        initialize_list(&account);
        assert!(exists<Root>(addr), error::internal(E_TEST_FAILURE));

        // Add a link.
        let url1 = b"https://google.com";
        add(&account, url1, vector::empty(), false);

        // Confirm that the link was added.
        let inner = &borrow_global<Root>(addr).inner;
        assert!(simple_map::length(&inner.links) == 1, error::internal(E_TEST_FAILURE));

        // Add another link.
        let url2 = b"https://yahoo.com";
        add(&account, url2, vector::empty(), false);

        // Confirm that there are two links now.
        let inner = &borrow_global<Root>(addr).inner;
        assert!(simple_map::length(&inner.links) == 2, error::internal(E_TEST_FAILURE));

        // Mark the second link as archived.
        set_archived(&account, url2, true, false);

        // Remove the link we added.
        remove(&account, url1, false, false);

        // Confirm that the standard list of links is now empty.
        let inner = &borrow_global<Root>(addr).inner;
        assert!(simple_map::length(&inner.links) == 0, error::internal(E_TEST_FAILURE));

        // Confirm that the other link is still there in the archived list.
        let inner = &borrow_global<Root>(addr).inner;
        assert!(simple_map::contains_key(&inner.archived_links, &string::utf8(url2)), error::internal(E_TEST_FAILURE));

        // Confirm that even if there are items, we can destroy everything.
        // obliterate(&account);
    }
}
