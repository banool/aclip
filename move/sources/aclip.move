// If ever updating this version, also update:
// - driver/src/aptos_helper.rs
// - aptos_infinite_jukebox/lib/constants.dart
module aclip::RootV1 {
    use Std::ASCII;
    use Std::Signer;
    use Std::Vector;

    #[test_only]
    use Std::Errors;

    #[test_only]
    /// Used for assertions in tests.
    const E_TEST_FAILURE: u64 = 100;

    /// Top level module. This just contains the Inner struct, which actually
    /// holds all the interesting stuff. We do it this way so it's easy to
    /// grab a mutable reference to everything at once without running into
    /// issues from holding multiple references. This is acceptable for now.
    struct RootV1 has key {
        inner: Inner,
    }

    /// All the interesting stuff.
    struct Inner has store {
        /// List of links. We store them in a list because tables are such
        /// a pain in the ass to work with.
        links: vector<Link>,
    }

    struct Link has store {
        /// ASCII encoded URL.
        url: ASCII::String,

        /// Any arbitrary tags the user wants to add.
        tags: vector<ASCII::String>,
    }

    /// Initialize the list to the caller's account.
    public(script) fun initialize_list(account: &signer) {
        move_to(account, RootV1{inner: Inner{ links: Vector::empty()}});
    }

    /// Public wrapper around add, since you can't use structs nor ascii in external calls.
    public(script) fun add(account: &signer, url_raw: vector<u8>, tags_raw: vector<vector<u8>>) acquires RootV1 {
        let tags = Vector::empty();

        let i = 0;
        while (i < Vector::length(&tags_raw)) {
            Vector::push_back(&mut tags, ASCII::string(Vector::pop_back(&mut tags_raw)));
            i = i + 1;
        };

        let link = Link {url: ASCII::string(url_raw), tags: tags};

        add_internal(account, link);
    }

    /// Add a link to the list.
    fun add_internal(account: &signer, link: Link) acquires RootV1 {
        let addr = Signer::address_of(account);
        let inner = &mut borrow_global_mut<RootV1>(addr).inner;
        
        Vector::push_back(&mut inner.links, link);
    }

    /// Public wrapper around remove, since you can't use structs nor ascii in external calls.
    public(script) fun remove(account: &signer, url_raw: vector<u8>) acquires RootV1 {
        remove_internal(account, ASCII::string(url_raw));
    }

    /// Remove the first item from the list that has the given URL.
    fun remove_internal(account: &signer, url: ASCII::String) acquires RootV1 {
        let addr = Signer::address_of(account);
        let inner = &mut borrow_global_mut<RootV1>(addr).inner;

        let i = 0;
        let len = Vector::length(&inner.links); 
        while (i < len) {
            if (Vector::borrow(&inner.links, i).url == url) {
                break
            };
            i = i + 1;
        };

        if (i == len) {
            // We didn't find the item.
            return
        };

        // We did find the item. Swap it to the end.
        let end = len - 1;
        if (i != end) {
            Vector::swap(&mut inner.links, i, end);
        };

        // Remove the item.
        let link = Vector::pop_back(&mut inner.links);

        // Destructure it to destroy it.
        let Link{ url, tags } = link;
        (url, tags);
    }


    #[test(account = @0x123)]
    public(script) fun test_add_remove(account: signer) acquires RootV1 {
        let addr = Signer::address_of(&account);

        // Initialize a list on account.
        initialize_list(&account);
        assert!(exists<RootV1>(addr), Errors::internal(E_TEST_FAILURE));

        // Add a link.
        let url1 = b"https://google.com";
        add(&account, url1, Vector::empty());

        // Confirm that the link was added.
        let inner = &borrow_global<RootV1>(addr).inner;
        assert!(Vector::length(&inner.links) == 1, Errors::internal(E_TEST_FAILURE));

        // Add another link.
        let url2 = b"https://yahoo.com";
        add(&account, url2, Vector::empty());

        // Remove some random link we never added.
        remove(&account, b"fake");

        // Confirm that nothing changed.
        let inner = &borrow_global<RootV1>(addr).inner;
        assert!(Vector::length(&inner.links) == 2, Errors::internal(E_TEST_FAILURE));

        // Remove the link we added.
        remove(&account, url1);

        // Confirm that it is gone.
        let inner = &borrow_global<RootV1>(addr).inner;
        assert!(Vector::length(&inner.links) == 1, Errors::internal(E_TEST_FAILURE));

        // Confirm that the other link is still there.
        let inner = &borrow_global<RootV1>(addr).inner;
        assert!(Vector::borrow(&inner.links, 0).url == ASCII::string(url2), Errors::internal(E_TEST_FAILURE));
    }
}
