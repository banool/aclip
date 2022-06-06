// If ever updating this version, also update:
// - frontend/lib/constants.dart
module aclip::RootV4 {
    use Std::ASCII;
    use Std::Errors;
    use Std::Option;
    use Std::Signer;
    use Std::Vector;
    use maptable::MapTable;

    const E_NOT_INITIALIZED: u64 = 1;

    #[test_only]
    /// Used for assertions in tests.
    const E_TEST_FAILURE: u64 = 100;

    /// Top level module. This just contains the Inner struct, which actually
    /// holds all the interesting stuff. We do it this way so it's easy to
    /// grab a mutable reference to everything at once without running into
    /// issues from holding multiple references. This is acceptable for now.
    struct RootV4 has key {
        inner: Inner,
    }

    /// All the interesting stuff.
    struct Inner has store {
        /// Table of links, where the key is the ascii encoded / escaped URL.
        links: MapTable::MapTable<ASCII::String, LinkData>,

        /// As above, but the key is encrypted using the private key and the
        /// value is an encrypted version of LinkData.
        secret_links: MapTable::MapTable<vector<u8>, vector<u8>>,

        /// Any link the user has chosen to archive.
        archived_links: MapTable::MapTable<ASCII::String, LinkData>,

        /// Any secret link the user has chosen to archive.
        archived_secret_links: MapTable::MapTable<vector<u8>, vector<u8>>,
    }

    struct LinkData has drop, store {
        /// Any arbitrary tags the user wants to add.
        tags: vector<ASCII::String>,
    }

    /// Initialize the list to the caller's account.
    public(script) fun initialize_list(account: &signer) {
        let inner = Inner {
            links: MapTable::new(),
            secret_links: MapTable::new(),
            archived_links: MapTable::new(),
            archived_secret_links: MapTable::new(),
        };
        move_to(account, RootV4{inner: inner });
    }

    /// Delete everything, even there are still items. Use with extreme caution.
    public(script) fun obliterate(account: &signer) acquires RootV4 {
        let addr = Signer::address_of(account);
        assert!(exists<RootV4>(addr), Errors::not_published(E_NOT_INITIALIZED));

        let root = move_from<RootV4>(addr);
        let RootV4 { inner } = root;
        let Inner { links, secret_links, archived_links, archived_secret_links } = inner;
        dump_list(links);
        dump_list(secret_links);
        dump_list(archived_links);
        dump_list(archived_secret_links);
    }

    fun dump_list<K: copy + store + drop, V: drop + store>(list: MapTable::MapTable<K, V>) {
        let key = MapTable::head_key(&list);
        loop {
            if (Option::is_none(&key)) {
                break
            };
            let (_v, _prev, next) = MapTable::remove_iter(&mut list, Option::extract(&mut key));
            key = next;
        };
        MapTable::destroy_empty(list);
    }

    /// Add a link to links. We don't bother handling collisions, we would just
    /// make it throw an error anyway.
    public(script) fun add(account: &signer, url_raw: vector<u8>, tags_raw: vector<vector<u8>>, add_to_archive: bool) acquires RootV4 {
        let addr = Signer::address_of(account);
        assert!(exists<RootV4>(addr), Errors::not_published(E_NOT_INITIALIZED));

        let tags = Vector::empty();

        let i = 0;
        while (i < Vector::length(&tags_raw)) {
            Vector::push_back(&mut tags, ASCII::string(Vector::pop_back(&mut tags_raw)));
            i = i + 1;
        };

        let link_data = LinkData {tags: tags};

        let inner = &mut borrow_global_mut<RootV4>(addr).inner;

        if (add_to_archive) {
            MapTable::add(&mut inner.archived_links, ASCII::string(url_raw), link_data);
        } else {
            MapTable::add(&mut inner.links, ASCII::string(url_raw), link_data);
        };
    }

    /// This is just a helper for testing mostly.
    public(script) fun add_simple(account: &signer, url_raw: vector<u8>) acquires RootV4 {
        add(account, url_raw, Vector::empty(), false);
    }

    /// Add a link to secret_links. As above, we don't bother with collisions.
    public(script) fun add_secret(account: &signer, url: vector<u8>, link_data: vector<u8>, add_to_archive: bool) acquires RootV4 {
        let addr = Signer::address_of(account);
        assert!(exists<RootV4>(addr), Errors::not_published(E_NOT_INITIALIZED));

        let addr = Signer::address_of(account);
        let inner = &mut borrow_global_mut<RootV4>(addr).inner;

        if (add_to_archive) {
            MapTable::add(&mut inner.archived_secret_links, url, link_data);
        } else {
            MapTable::add(&mut inner.secret_links, url, link_data);
        };
    }

    /// Remove an item with the given key. We trust the user isn't trying to remove
    /// a key that isn't in their list. We opt to be cheeky here and use this function
    /// for all 4 different lists.
    public(script) fun remove(account: &signer, url_raw: vector<u8>, from_archive: bool, from_secrets: bool) acquires RootV4 {
        let addr = Signer::address_of(account);
        assert!(exists<RootV4>(addr), Errors::not_published(E_NOT_INITIALIZED));

        let inner = &mut borrow_global_mut<RootV4>(addr).inner;

        if (from_secrets) {
            if (from_archive) {
                MapTable::remove(&mut inner.archived_secret_links, url_raw);
            } else {
                MapTable::remove(&mut inner.secret_links, url_raw);
            }
        } else {
            let url = ASCII::string(url_raw);
            if (from_archive) {
                MapTable::remove(&mut inner.archived_links, url);
            } else {
                MapTable::remove(&mut inner.links, url);
            }
        };
    }

    /// Move an item to / from the archived version of that list.
    public(script) fun set_archived(account: &signer, url_raw: vector<u8>, make_archived: bool, is_secret: bool) acquires RootV4 {
        let addr = Signer::address_of(account);
        assert!(exists<RootV4>(addr), Errors::not_published(E_NOT_INITIALIZED));

        let inner = &mut borrow_global_mut<RootV4>(addr).inner;

        if (is_secret) {
            if (make_archived) {
                let item = MapTable::remove(&mut inner.secret_links, url_raw);
                MapTable::add(&mut inner.archived_secret_links, url_raw, item);
            } else {
                let item = MapTable::remove(&mut inner.archived_secret_links, url_raw);
                MapTable::add(&mut inner.secret_links, url_raw, item);
            }
        } else {
            let url = ASCII::string(url_raw);
            if (make_archived) {
                let item = MapTable::remove(&mut inner.links, url);
                MapTable::add(&mut inner.archived_links, url, item);
            } else {
                let item = MapTable::remove(&mut inner.archived_links, url);
                MapTable::add(&mut inner.links, url, item);
            }
        };
    }

    #[test(account = @0x123)]
    public(script) fun test_add_remove_archive(account: signer) acquires RootV4 {
        let addr = Signer::address_of(&account);

        // Initialize a list on account.
        initialize_list(&account);
        assert!(exists<RootV4>(addr), Errors::internal(E_TEST_FAILURE));

        // Add a link.
        let url1 = b"https://google.com";
        add(&account, url1, Vector::empty(), false);

        // Confirm that the link was added.
        let inner = &borrow_global<RootV4>(addr).inner;
        assert!(MapTable::length(&inner.links) == 1, Errors::internal(E_TEST_FAILURE));

        // Add another link.
        let url2 = b"https://yahoo.com";
        add(&account, url2, Vector::empty(), false);

        // Confirm that there are two links now.
        let inner = &borrow_global<RootV4>(addr).inner;
        assert!(MapTable::length(&inner.links) == 2, Errors::internal(E_TEST_FAILURE));

        // Mark the second link as archived.
        set_archived(&account, url2, true, false);

        // Remove the link we added.
        remove(&account, url1, false, false);

        // Confirm that the standard list of links is now empty.
        let inner = &borrow_global<RootV4>(addr).inner;
        assert!(MapTable::length(&inner.links) == 0, Errors::internal(E_TEST_FAILURE));

        // Confirm that the other link is still there in the archived list.
        let inner = &borrow_global<RootV4>(addr).inner;
        assert!(MapTable::contains(&inner.archived_links, ASCII::string(url2)), Errors::internal(E_TEST_FAILURE));

        // Confirm that even if there are items, we can destroy everything.
        obliterate(&account);
    }
}
