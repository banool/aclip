use super::*;
// Section: wire functions

#[wasm_bindgen]
pub fn wire_download_page(port_: MessagePort, options: JsValue) {
    wire_download_page_impl(port_, options)
}

#[wasm_bindgen]
pub fn wire_platform(port_: MessagePort) {
    wire_platform_impl(port_)
}

#[wasm_bindgen]
pub fn wire_rust_release_mode(port_: MessagePort) {
    wire_rust_release_mode_impl(port_)
}

// Section: allocate functions

// Section: impl Wire2Api

impl Wire2Api<String> for String {
    fn wire2api(self) -> String {
        self
    }
}

impl Wire2Api<Option<String>> for Option<String> {
    fn wire2api(self) -> Option<String> {
        self.map(Wire2Api::wire2api)
    }
}
impl Wire2Api<Options> for JsValue {
    fn wire2api(self) -> Options {
        let self_ = self.dyn_into::<JsArray>().unwrap();
        assert_eq!(
            self_.length(),
            20,
            "Expected 20 elements, got {}",
            self_.length()
        );
        Options {
            no_audio: self_.get(0).wire2api(),
            base_url: self_.get(1).wire2api(),
            no_css: self_.get(2).wire2api(),
            charset: self_.get(3).wire2api(),
            ignore_errors: self_.get(4).wire2api(),
            no_frames: self_.get(5).wire2api(),
            no_fonts: self_.get(6).wire2api(),
            no_images: self_.get(7).wire2api(),
            isolate: self_.get(8).wire2api(),
            no_js: self_.get(9).wire2api(),
            insecure: self_.get(10).wire2api(),
            no_metadata: self_.get(11).wire2api(),
            output: self_.get(12).wire2api(),
            silent: self_.get(13).wire2api(),
            timeout: self_.get(14).wire2api(),
            user_agent: self_.get(15).wire2api(),
            no_video: self_.get(16).wire2api(),
            target: self_.get(17).wire2api(),
            no_color: self_.get(18).wire2api(),
            unwrap_noscript: self_.get(19).wire2api(),
        }
    }
}

impl Wire2Api<Vec<u8>> for Box<[u8]> {
    fn wire2api(self) -> Vec<u8> {
        self.into_vec()
    }
}
// Section: impl Wire2Api for JsValue

impl Wire2Api<String> for JsValue {
    fn wire2api(self) -> String {
        self.as_string().expect("non-UTF-8 string, or not a string")
    }
}
impl Wire2Api<bool> for JsValue {
    fn wire2api(self) -> bool {
        self.is_truthy()
    }
}
impl Wire2Api<Option<String>> for JsValue {
    fn wire2api(self) -> Option<String> {
        (!self.is_undefined() && !self.is_null()).then(|| self.wire2api())
    }
}
impl Wire2Api<u64> for JsValue {
    fn wire2api(self) -> u64 {
        ::std::convert::TryInto::try_into(self.dyn_into::<js_sys::BigInt>().unwrap()).unwrap()
    }
}
impl Wire2Api<u8> for JsValue {
    fn wire2api(self) -> u8 {
        self.unchecked_into_f64() as _
    }
}
impl Wire2Api<Vec<u8>> for JsValue {
    fn wire2api(self) -> Vec<u8> {
        self.unchecked_into::<js_sys::Uint8Array>().to_vec().into()
    }
}
