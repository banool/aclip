use super::*;
// Section: wire functions

#[no_mangle]
pub extern "C" fn wire_download_page(port_: i64, options: *mut wire_Options) {
    wire_download_page_impl(port_, options)
}

#[no_mangle]
pub extern "C" fn wire_platform(port_: i64) {
    wire_platform_impl(port_)
}

#[no_mangle]
pub extern "C" fn wire_rust_release_mode(port_: i64) {
    wire_rust_release_mode_impl(port_)
}

// Section: allocate functions

#[no_mangle]
pub extern "C" fn new_StringList_0(len: i32) -> *mut wire_StringList {
    let wrap = wire_StringList {
        ptr: support::new_leak_vec_ptr(<*mut wire_uint_8_list>::new_with_null_ptr(), len),
        len,
    };
    support::new_leak_box_ptr(wrap)
}

#[no_mangle]
pub extern "C" fn new_box_autoadd_options_0() -> *mut wire_Options {
    support::new_leak_box_ptr(wire_Options::new_with_null_ptr())
}

#[no_mangle]
pub extern "C" fn new_uint_8_list_0(len: i32) -> *mut wire_uint_8_list {
    let ans = wire_uint_8_list {
        ptr: support::new_leak_vec_ptr(Default::default(), len),
        len,
    };
    support::new_leak_box_ptr(ans)
}

// Section: related functions

// Section: impl Wire2Api

impl Wire2Api<String> for *mut wire_uint_8_list {
    fn wire2api(self) -> String {
        let vec: Vec<u8> = self.wire2api();
        String::from_utf8_lossy(&vec).into_owned()
    }
}
impl Wire2Api<Vec<String>> for *mut wire_StringList {
    fn wire2api(self) -> Vec<String> {
        let vec = unsafe {
            let wrap = support::box_from_leak_ptr(self);
            support::vec_from_leak_ptr(wrap.ptr, wrap.len)
        };
        vec.into_iter().map(Wire2Api::wire2api).collect()
    }
}

impl Wire2Api<Options> for *mut wire_Options {
    fn wire2api(self) -> Options {
        let wrap = unsafe { support::box_from_leak_ptr(self) };
        Wire2Api::<Options>::wire2api(*wrap).into()
    }
}

impl Wire2Api<Options> for wire_Options {
    fn wire2api(self) -> Options {
        Options {
            no_audio: self.no_audio.wire2api(),
            base_url: self.base_url.wire2api(),
            blacklist_domains: self.blacklist_domains.wire2api(),
            no_css: self.no_css.wire2api(),
            charset: self.charset.wire2api(),
            domains: self.domains.wire2api(),
            ignore_errors: self.ignore_errors.wire2api(),
            no_frames: self.no_frames.wire2api(),
            no_fonts: self.no_fonts.wire2api(),
            no_images: self.no_images.wire2api(),
            isolate: self.isolate.wire2api(),
            no_js: self.no_js.wire2api(),
            insecure: self.insecure.wire2api(),
            no_metadata: self.no_metadata.wire2api(),
            output: self.output.wire2api(),
            silent: self.silent.wire2api(),
            timeout: self.timeout.wire2api(),
            user_agent: self.user_agent.wire2api(),
            no_video: self.no_video.wire2api(),
            target: self.target.wire2api(),
            no_color: self.no_color.wire2api(),
            unwrap_noscript: self.unwrap_noscript.wire2api(),
        }
    }
}

impl Wire2Api<Vec<u8>> for *mut wire_uint_8_list {
    fn wire2api(self) -> Vec<u8> {
        unsafe {
            let wrap = support::box_from_leak_ptr(self);
            support::vec_from_leak_ptr(wrap.ptr, wrap.len)
        }
    }
}
// Section: wire structs

#[repr(C)]
#[derive(Clone)]
pub struct wire_StringList {
    ptr: *mut *mut wire_uint_8_list,
    len: i32,
}

#[repr(C)]
#[derive(Clone)]
pub struct wire_Options {
    no_audio: bool,
    base_url: *mut wire_uint_8_list,
    blacklist_domains: bool,
    no_css: bool,
    charset: *mut wire_uint_8_list,
    domains: *mut wire_StringList,
    ignore_errors: bool,
    no_frames: bool,
    no_fonts: bool,
    no_images: bool,
    isolate: bool,
    no_js: bool,
    insecure: bool,
    no_metadata: bool,
    output: *mut wire_uint_8_list,
    silent: bool,
    timeout: u64,
    user_agent: *mut wire_uint_8_list,
    no_video: bool,
    target: *mut wire_uint_8_list,
    no_color: bool,
    unwrap_noscript: bool,
}

#[repr(C)]
#[derive(Clone)]
pub struct wire_uint_8_list {
    ptr: *mut u8,
    len: i32,
}

// Section: impl NewWithNullPtr

pub trait NewWithNullPtr {
    fn new_with_null_ptr() -> Self;
}

impl<T> NewWithNullPtr for *mut T {
    fn new_with_null_ptr() -> Self {
        std::ptr::null_mut()
    }
}

impl NewWithNullPtr for wire_Options {
    fn new_with_null_ptr() -> Self {
        Self {
            no_audio: Default::default(),
            base_url: core::ptr::null_mut(),
            blacklist_domains: Default::default(),
            no_css: Default::default(),
            charset: core::ptr::null_mut(),
            domains: core::ptr::null_mut(),
            ignore_errors: Default::default(),
            no_frames: Default::default(),
            no_fonts: Default::default(),
            no_images: Default::default(),
            isolate: Default::default(),
            no_js: Default::default(),
            insecure: Default::default(),
            no_metadata: Default::default(),
            output: core::ptr::null_mut(),
            silent: Default::default(),
            timeout: Default::default(),
            user_agent: core::ptr::null_mut(),
            no_video: Default::default(),
            target: core::ptr::null_mut(),
            no_color: Default::default(),
            unwrap_noscript: Default::default(),
        }
    }
}

impl Default for wire_Options {
    fn default() -> Self {
        Self::new_with_null_ptr()
    }
}

// Section: sync execution mode utility

#[no_mangle]
pub extern "C" fn free_WireSyncReturn(ptr: support::WireSyncReturn) {
    unsafe {
        let _ = support::box_from_leak_ptr(ptr);
    };
}
