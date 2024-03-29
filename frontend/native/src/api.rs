use anyhow::{bail, Context, Result};
use encoding_rs::Encoding;
use flutter_rust_bridge::frb;
use html5ever::rcdom::RcDom;
use monolith::html::{
    add_favicon, create_metadata_tag, get_base_url, get_charset, has_favicon, html_to_dom,
    serialize_document, set_base_url, set_charset, walk_and_embed_assets,
};
use monolith::url::{create_data_url, resolve_url};
use monolith::utils::retrieve_asset;
use reqwest::blocking::Client;
use reqwest::header::{HeaderMap, HeaderValue, USER_AGENT};
use std::collections::HashMap;
use std::fs;
use std::io::Write;
use std::path::Path;
use std::time::Duration;
use url::Url;

// Re-export the options struct.
pub use monolith::opts::Options;

const DEFAULT_USER_AGENT: &'static str =
    "Mozilla/5.0 (iPhone; CPU iPhone OS 15_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.4 Mobile/15E148 Safari/604.1";

/// This is just the main function yanked from:
/// https://github.com/Y2Z/monolith/blob/master/src/main.rs
///
/// I had to do this due to https://github.com/Y2Z/monolith/issues/72.
/// I've removed some of the functionality I don't need and of course added
/// arguments and cleared out the argparsing stuff.
///
/// You can't return the unit type, hence the bool here.
/// https://github.com/fzyzcjy/flutter_rust_bridge/issues/197
pub fn download_page(options: Options) -> Result<bool> {
    let target: String = options.target.clone();

    // Check if target was provided
    if target.len() == 0 {
        bail!("No target specified");
    }

    // Check if custom charset is valid
    if let Some(custom_charset) = options.charset.clone() {
        if !Encoding::for_label_no_replacement(custom_charset.as_bytes()).is_some() {
            bail!("Unknown encoding: {}", &custom_charset);
        }
    }

    let target_url: Url;

    println!("Downloading target: {}", &target);

    // Determine exact target URL
    match Url::parse(&target.clone()) {
        Ok(parsed_url) => match parsed_url.scheme() {
            "data" | "file" | "http" | "https" => target_url = parsed_url,
            wildcard => bail!("Unsupported target URL scheme: {}", wildcard),
        },
        Err(_err) => {
            // Failed to parse given base URL (perhaps it's a filesystem path?)
            let path: &Path = Path::new(&target);

            if path.exists() {
                if path.is_file() {
                    target_url = Url::from_file_path(
                        fs::canonicalize(&path).expect("Failed to canonicalize path"),
                    )
                    .expect("Could not generate file URL out of given path");
                } else {
                    bail!("Local target is not a file: {}", &options.target);
                }
            } else {
                // Last chance, now we do what browsers do:
                // prepend "http://" and hope it points to a website
                target_url =
                    Url::parse(&format!("http://{hopefully_url}", hopefully_url = &target)).unwrap()
            }
        }
    }

    // Initialize client
    let mut cache = HashMap::new();
    let mut header_map = HeaderMap::new();
    let user_agent = match &options.user_agent {
        Some(u) => u.clone(),
        None => DEFAULT_USER_AGENT.to_string(),
    };
    header_map.insert(
        USER_AGENT,
        HeaderValue::from_str(&user_agent).context("Invalid User-Agent header specified")?,
    );
    let client = if options.timeout > 0 {
        Client::builder().timeout(Duration::from_secs(options.timeout))
    } else {
        // No timeout is default
        Client::builder()
    }
    .danger_accept_invalid_certs(options.insecure)
    .default_headers(header_map)
    .build()
    .context("Failed to initialize HTTP client")?;

    // At first we assume that base URL is the same as target URL
    let mut base_url: Url = target_url.clone();

    let data: Vec<u8>;
    let mut document_encoding: String;
    let mut dom: RcDom;

    // Retrieve target document
    if target_url.scheme() == "file"
        || (target_url.scheme() == "http" || target_url.scheme() == "https")
        || target_url.scheme() == "data"
    {
        match retrieve_asset(&mut cache, &client, &target_url, &target_url, &options, 0) {
            Ok((retrieved_data, final_url, media_type, charset)) => {
                // Make sure the media type is text/html
                if !media_type.eq_ignore_ascii_case("text/html") {
                    bail!("Unsupported document media type");
                }

                if options
                    .base_url
                    .clone()
                    .unwrap_or("".to_string())
                    .is_empty()
                {
                    base_url = final_url;
                }

                data = retrieved_data;
                document_encoding = charset;
            }
            Err(e) => {
                bail!("Could not retrieve target document: {:#}", e);
            }
        }
    } else {
        bail!("Unknown document scheme");
    }

    // Initial parse
    dom = html_to_dom(&data, document_encoding.clone());

    // TODO: investigate if charset from filesystem/data URL/HTTP headers
    //       has say over what's specified in HTML

    // Attempt to determine document's charset
    if let Some(html_charset) = get_charset(&dom.document) {
        if !html_charset.is_empty() {
            // Check if the charset specified inside HTML is valid
            if let Some(encoding) = Encoding::for_label_no_replacement(html_charset.as_bytes()) {
                document_encoding = html_charset;
                dom = html_to_dom(&data, encoding.name().to_string());
            }
        }
    }

    // Use custom base URL if specified, read and use what's in the DOM otherwise
    let custom_base_url: String = options.base_url.clone().unwrap_or("".to_string());
    if custom_base_url.is_empty() {
        // No custom base URL is specified
        // Try to see if document has BASE element
        if let Some(existing_base_url) = get_base_url(&dom.document) {
            base_url = resolve_url(&target_url, &existing_base_url);
        }
    } else {
        // Custom base URL provided
        match Url::parse(&custom_base_url) {
            Ok(parsed_url) => {
                if parsed_url.scheme() == "file" {
                    // File base URLs can only work with
                    // documents saved from filesystem
                    if target_url.scheme() == "file" {
                        base_url = parsed_url;
                    }
                } else {
                    base_url = parsed_url;
                }
            }
            Err(_) => {
                // Failed to parse given base URL, perhaps it's a filesystem path?
                if target_url.scheme() == "file" {
                    // Relative paths could work for documents saved from filesystem
                    let path: &Path = Path::new(&custom_base_url);
                    if path.exists() {
                        match Url::from_file_path(fs::canonicalize(&path).unwrap()) {
                            Ok(file_url) => {
                                base_url = file_url;
                            }
                            Err(_) => {
                                bail!("Could not map given path to base URL: {}", custom_base_url);
                            }
                        }
                    }
                }
            }
        }
    }

    // Traverse through the document and embed remote assets
    walk_and_embed_assets(&mut cache, &client, &base_url, &dom.document, &options, 0);

    // Update or add new BASE element to reroute network requests and hash-links
    if let Some(new_base_url) = options.base_url.clone() {
        dom = set_base_url(&dom.document, new_base_url);
    }

    // Request and embed /favicon.ico (unless it's already linked in the document)
    if !options.no_images
        && (target_url.scheme() == "http" || target_url.scheme() == "https")
        && !has_favicon(&dom.document)
    {
        let favicon_ico_url: Url = resolve_url(&base_url, "/favicon.ico");

        match retrieve_asset(
            &mut cache,
            &client,
            &target_url,
            &favicon_ico_url,
            &options,
            0,
        ) {
            Ok((data, final_url, media_type, charset)) => {
                let favicon_data_url: Url =
                    create_data_url(&media_type, &charset, &data, &final_url);
                dom = add_favicon(&dom.document, favicon_data_url.to_string());
            }
            Err(_) => {
                // Failed to retrieve /favicon.ico
            }
        }
    }

    // Save using specified charset, if given
    if let Some(custom_charset) = options.charset.clone() {
        document_encoding = custom_charset;
        dom = set_charset(dom, document_encoding.clone());
    }

    // Serialize DOM tree
    let mut result: Vec<u8> = serialize_document(dom, document_encoding, &options);

    // Prepend metadata comment tag
    if !options.no_metadata {
        let mut metadata_comment: String = create_metadata_tag(&target_url);
        metadata_comment += "\n";
        result.splice(0..0, metadata_comment.as_bytes().to_vec());
    }

    // Define output
    let mut file = fs::File::create(&options.output).context("Failed to create file")?;

    // Write result into stdout or file
    file.write_all(&result)
        .context("Failed to write output to file")?;

    // Ensure newline at end of output
    if result.last() != Some(&b"\n"[0]) {
        file.write(b"\n")
            .context("Failed to write newline to file")?;
    }

    file.flush().context("Failed to flush file")?;

    Ok(true)
}

// http://cjycode.com/flutter_rust_bridge/feature/lang_external.html#types-in-other-crates
#[frb(mirror(Options))]
#[derive(Default)]
pub struct _Options {
    pub no_audio: bool,
    pub base_url: Option<String>,
    pub blacklist_domains: bool,
    pub no_css: bool,
    pub charset: Option<String>,
    pub domains: Option<Vec<String>>,
    pub ignore_errors: bool,
    pub no_frames: bool,
    pub no_fonts: bool,
    pub no_images: bool,
    pub isolate: bool,
    pub no_js: bool,
    pub insecure: bool,
    pub no_metadata: bool,
    pub output: String,
    pub silent: bool,
    pub timeout: u64,
    pub user_agent: Option<String>,
    pub no_video: bool,
    pub target: String,
    pub no_color: bool,
    pub unwrap_noscript: bool,
}

// Boilerplate stuff.
pub enum Platform {
    Unknown,
    Android,
    Ios,
    Windows,
    Unix,
    MacIntel,
    MacApple,
    Wasm,
}

pub fn platform() -> Platform {
    if cfg!(windows) {
        Platform::Windows
    } else if cfg!(target_os = "android") {
        Platform::Android
    } else if cfg!(target_os = "ios") {
        Platform::Ios
    } else if cfg!(target_arch = "aarch64-apple-darwin") {
        Platform::MacApple
    } else if cfg!(target_os = "macos") {
        Platform::MacIntel
    } else if cfg!(target_family = "wasm") {
        Platform::Wasm
    } else if cfg!(unix) {
        Platform::Unix
    } else {
        Platform::Unknown
    }
}

pub fn rust_release_mode() -> bool {
    cfg!(not(debug_assertions))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_download_page() {
        let options = Options {
            no_audio: false,
            base_url: None,
            blacklist_domains: false,
            no_css: false,
            charset: None,
            domains: None,
            ignore_errors: false,
            no_frames: false,
            no_fonts: false,
            no_images: false,
            isolate: false,
            no_js: false,
            insecure: false,
            no_metadata: false,
            output: "/tmp/test.html".to_string(),
            silent: false,
            timeout: 0,
            user_agent: None,
            no_video: false,
            target: "https://www.rust-lang.org/".to_string(),
            no_color: false,
            unwrap_noscript: false,
        };
        let result = download_page(options);
        assert!(result.is_ok());
    }
}
