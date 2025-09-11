# URL Kit

[![MOPS](https://img.shields.io/badge/MOPS-url--kit-blue)](https://mops.one/url-kit)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/edjcase/motoko_url_kit/blob/main/LICENSE)

A comprehensive URL parsing and manipulation library for Motoko on the Internet Computer.

## Overview

URL Kit is a robust library designed to handle all aspects of URL processing in Motoko applications. It provides complete RFC-compliant URL parsing, validation, manipulation, and encoding/decoding capabilities with support for various host types, optional domain parsing, and comprehensive error handling.

Key features:

-   🔍 **Complete URL Parsing**: Parse any URL into structured components (scheme, authority, path, query, fragment)
-   🌐 **Multi-Host Support**: Handle host names, IPv4, and IPv6 addresses with proper validation
-   🏷️ **Flexible Domain Parsing**: Optional domain parsing with comprehensive or custom suffix lists
-   🔗 **URL Manipulation**: Add, remove, and modify query parameters with ease
-   🔄 **Encoding/Decoding**: Proper URL encoding and decoding with UTF-8 support
-   ⚖️ **Normalization**: Normalize URLs for accurate comparison and deduplication
-   🛡️ **Validation**: Comprehensive validation with detailed error messages
-   🎯 **Type Safety**: Strongly typed URL components for compile-time safety
-   📊 **IPv6 Support**: Full IPv6 address parsing with compression and various formats
-   🔧 **Path Handling**: Flexible path parsing with custom separators and normalization

## Package

### MOPS

```bash
mops add url-kit
```

To setup MOPS package manager, follow the instructions from the [MOPS Site](https://mops.one)

## Quick Start

Here's a simple example to get started with URL parsing:

```motoko
import UrlKit "mo:url-kit";

// Parse a URL - no domain parser needed for basic parsing
let urlResult = UrlKit.fromText("https://api.example.com:8080/users?page=1&limit=10#results");

let url = switch (urlResult) {
    case (#ok(url)) url;
    case (#err(errorMsg)) {
        // Handle parsing error
    };
};

// Access URL components
// url = {
     scheme = ?"https";
     authority = ?{
        user = null;
        host = #name("api.example.com");  // Host names are parsed as simple strings
        port = ?8080;
     };
     path = ["users"];
     queryParams = [("page", "1"), ("limit", "10")];
     fragment = ?"results"
// }

// Get specific query parameter
let page = UrlKit.getQueryParam(url, "page"); // ?"1"

// Add query parameters
let urlWithAuth = UrlKit.addQueryParam(url, ("token", "abc123"));

// Convert back to text
let urlText = UrlKit.toText(urlWithAuth);
```

## Comprehensive Example

Here's a more detailed example showing various URL manipulation capabilities:

```motoko
import UrlKit "mo:url-kit";
import Host "mo:url-kit/Host";

// Parse different types of URLs
let examples = [
    "https://user:pass@sub.example.com:8080/api/v1/users?page=1&sort=name#section1",
    "http://192.168.1.1:3000/dashboard",
    "https://[2001:db8::1]:8443/secure",
    "file:///path/to/file.txt",
    "//cdn.example.com/assets/style.css"
];

for (urlText in examples.vals()) {
    switch (UrlKit.fromText(urlText)) {
        case (#ok(url)) {
            // Analyze the URL structure
            switch (url.authority) {
                case (?authority) {
                    // Check host type
                    switch (authority.host) {
                        case (#name(hostName)) {
                            // Host name (domain name, hostname, etc.)
                            // For domain parsing, use the separate domain parsers
                        };
                        case (#ipV4(ip)) {
                            // IPv4 address: (192, 168, 1, 1)
                            let hostText = Host.toText(authority.host);
                        };
                        case (#ipV6(ip)) {
                            // IPv6 address with proper formatting
                            let hostText = Host.toText(authority.host);
                        };
                    };

                    // Check for user authentication
                    switch (authority.user) {
                        case (?userInfo) {
                            let username = userInfo.username;
                            let password = userInfo.password;
                        };
                        case (null) {};
                    };
                };
                case (null) {
                    // No authority (e.g., mailto:, file: schemes)
                };
            };

            // Manipulate query parameters
            let withParams = url
                |> UrlKit.addQueryParam(_, ("timestamp", "123456789"))
                |> UrlKit.addQueryParamMulti(_, [("version", "v2"), ("format", "json")])
                |> UrlKit.removeQueryParam(_, "page");

            // Normalize for comparison
            let normalized = UrlKit.normalize(withParams);

            // Convert back to string
            let finalUrl = UrlKit.toText(normalized);
        };
        case (#err(error)) {
            // Handle parsing errors with detailed messages
        };
    };
};
```

## Core API

### URL Type

The core `Url` type represents a parsed URL with all its components:

```motoko
public type Url = {
    scheme : ?Text;           // "https", "http", "mailto", etc.
    authority : ?Authority;   // Host, port, and user info
    path : [Text];           // Path segments
    queryParams : [(Text, Text)]; // Query parameters as key-value pairs
    fragment : ?Text;        // Fragment identifier
};

public type Authority = {
    user : ?UserInfo;        // Username and password
    host : Host.Host;        // Host name or IP address
    port : ?Nat16;          // Port number
};
```

### Parsing and Conversion

```motoko
// Parse URL from text
UrlKit.fromText(url : Text) : Result.Result<Url, Text>

// Convert URL back to text
UrlKit.toText(url : Url) : Text

// Normalize URL for comparison
UrlKit.normalize(url : Url) : Url

// Compare URLs for equality
UrlKit.equal(url1 : Url, url2 : Url) : Bool
```

### Query Parameter Manipulation

```motoko
// Get query parameter value
UrlKit.getQueryParam(url : Url, key : Text) : ?Text

// Add single query parameter
UrlKit.addQueryParam(url : Url, param : (Text, Text)) : Url

// Add multiple query parameters
UrlKit.addQueryParamMulti(url : Url, params : [(Text, Text)]) : Url

// Remove query parameter by key
UrlKit.removeQueryParam(url : Url, key : Text) : Url

// Remove multiple query parameters
UrlKit.removeQueryParamMulti(url : Url, keys : [Text]) : Url
```

### Encoding and Decoding

```motoko
// URL encode text (percent encoding)
UrlKit.encodeText(value : Text) : Text

// URL decode text
UrlKit.decodeText(value : Text) : Result.Result<Text, Text>
```

## Host Types

URL Kit supports various host types with proper validation:

### Host Names

```motoko
import Host "mo:url-kit/Host";

// Parse host with optional port
let hostResult = Host.fromText("example.com:8080");
// Result: (#name("example.com"), ?8080)

// Convert host to text
let hostText = Host.toText(host);

// Normalize host (lowercase)
let normalized = Host.normalize(host);
```

### IPv4 Addresses

```motoko
import IpV4 "mo:url-kit/IpV4";

// Parse IPv4 address
let ipResult = IpV4.fromText("192.168.1.1");
// Result: (192, 168, 1, 1)

// Convert back to text
let ipText = IpV4.toText(ip); // "192.168.1.1"
```

### IPv6 Addresses

```motoko
import IpV6 "mo:url-kit/IpV6";

// Parse IPv6 address (supports compression and various formats)
let ipResult = IpV6.fromText("2001:db8::1");

// Convert to text with different formats
let full = IpV6.toText(ip, #full);        // "2001:0db8:0000:0000:0000:0000:0000:0001"
let standard = IpV6.toText(ip, #standard); // "2001:db8:0:0:0:0:0:1"
let compressed = IpV6.toText(ip, #compressed); // "2001:db8::1"
```

### Host Parsing and Formatting

```motoko
import Host "mo:url-kit/Host";

// Parse host with port
let hostResult = Host.fromText("example.com:8080");
// Result: (#name("example.com"), ?8080)

// Convert host to text
let hostText = Host.toText(host);

// Normalize host (lowercase)
let normalized = Host.normalize(host);
```

## Path Handling

```motoko
import Path "mo:url-kit/Path";

// Parse path with custom separator
let path = Path.fromText("/api/v1/users");
// Result: ?["api", "v1", "users"]

// Convert path back to text
let pathText = Path.toText(path); // "/api/v1/users"

// Join path segments
let newPath = Path.join(path, "123");
let newNewPath = Path.joinMulti(newPath, ["456", "profile"]);
// Result: ["api", "v1", "users", "123", "profile"]

// Normalize path (removes empty segments)
let normalized = Path.normalize(path);
```

## URL Examples

### Basic HTTP/HTTPS URLs

```motoko
// Simple HTTPS URL
"https://example.com"

// URL with port and path
"https://api.example.com:8080/v1/users"

// URL with query parameters
"https://example.com/search?q=motoko&type=repo"

// URL with fragment
"https://docs.example.com/guide#installation"

// Complete URL with all components
"https://user:pass@api.example.com:8080/v1/users?page=1&limit=10#results"
```

### IP Address URLs

```motoko
// IPv4 address
"http://192.168.1.1:3000/dashboard"

// IPv6 address (note the brackets)
"https://[2001:db8::1]:8443/api"

// IPv6 with embedded IPv4
"http://[::ffff:192.168.1.1]/mixed"
```

### Special Schemes

```motoko

// File URLs
"file:///path/to/file.txt"
"file://server/share/document.pdf"

// Custom schemes
"custom-protocol://data.example.com/resource"
```

### Relative URLs

```motoko
// Protocol-relative URL
"//cdn.example.com/assets/style.css"

// Absolute path
"/api/users/123"

// Query only
"?search=term"

// Fragment only
"#section1"
```

## Domain Parsing

As of v3.0, domain parsing has been separated from basic host parsing. The Host type now simply stores names as strings (`#name`), and domain parsing is handled by dedicated domain parsers when needed.

### Domain Parsers

URL Kit provides two types of domain parsers:

#### Comprehensive Domain Parser (Recommended)

Uses the complete Public Suffix List for accurate domain parsing:

```motoko
import ComprehensiveDomainParser "mo:url-kit/ComprehensiveDomainParser";
import Domain "mo:url-kit/Domain";

// Create a comprehensive domain parser
let domainParser = ComprehensiveDomainParser.ComprehensiveDomainParser();

// Parse a domain name
let domainResult = domainParser.parse("blog.github.io");
// Result: #ok({ name = "github"; suffix = "io"; subdomains = ["blog"] })

switch (domainResult) {
    case (#ok(domain)) {
        let name = domain.name; // "github"
        let suffix = domain.suffix; // "io"
        let subdomains = domain.subdomains; // ["blog"]
    };
    case (#err(msg)) {
        // Handle parsing error
    };
};
```

#### Simple Domain Parser

For custom domain suffix lists:

```motoko
import SimpleDomainParser "mo:url-kit/SimpleDomainParser";

// Create a simple domain parser with custom suffixes
let domainParser = SimpleDomainParser.SimpleDomainParser(["com", "org", "test", "local"]);

// Parse a domain name
let domainResult = domainParser.parse("api.example.com");
// Result: #ok({ name = "example"; suffix = "com"; subdomains = ["api"] })
```

### Domain Operations

```motoko
import Domain "mo:url-kit/Domain";

// Parse domain with specified suffixes
let domainResult = Domain.fromText("blog.github.io", ["github.io", "io"]);

// Validate domain structure
let validation = Domain.validate(domain);

// Convert domain to text
let domainText = Domain.toText(domain);

// Normalize domain (lowercase)
let normalized = Domain.normalize(domain);
```

### Integration with URLs

When you need domain parsing for URLs, extract the host name and parse it separately:

```motoko
import UrlKit "mo:url-kit";
import ComprehensiveDomainParser "mo:url-kit/ComprehensiveDomainParser";

let url = switch (UrlKit.fromText("https://blog.example.com/path")) {
    case (#ok(u)) u;
    case (#err(_)) return; // Handle error
};

// Extract host name for domain parsing
switch (url.authority) {
    case (?authority) {
        switch (authority.host) {
            case (#name(hostName)) {
                // Parse the host name as a domain
                let domainParser = ComprehensiveDomainParser.ComprehensiveDomainParser();
                let domainResult = domainParser.parse(hostName);

                switch (domainResult) {
                    case (#ok(domain)) {
                        // Work with parsed domain components
                        let rootDomain = domain.name # "." # domain.suffix; // "example.com"
                    };
                    case (#err(_)) {
                        // Host name is not a valid domain (e.g., IP address, localhost)
                    };
                };
            };
            case (#ipV4(_) or #ipV6(_)) {
                // IP addresses don't need domain parsing
            };
        };
    };
    case (null) {};
};
```

## Domain Suffix List

URL Kit includes an automatically generated domain suffix list based on the [Public Suffix List](https://publicsuffix.org/) for accurate domain parsing. The suffix list helps distinguish between domain names and subdomains.

The [`ComprehensiveDomainParser`](src/ComprehensiveDomainParser.mo) uses this comprehensive list for accurate domain parsing, while you can also create custom parsers with [`Domain.fromText`](src/Domain.mo) for specific use cases.

### Updating the Suffix List

The domain suffix list should be updated periodically to include new top-level domains and suffixes. Run the provided script to regenerate the list:

```bash
# Requires Python 3 and internet connection
./scripts/rebuild_suffix_list.sh
```

This script:

1. Downloads the latest Public Suffix List from https://publicsuffix.org/
2. Processes and filters the data
3. Generates a new `src/data/DomainSuffixData.mo` file with the current suffixes
4. Structures the data as an efficient tree for fast lookups

The generated file contains a compressed tree structure that allows for efficient suffix matching during domain parsing. You should run this script periodically (e.g., monthly) to keep the suffix list current.

## Performance

URL Kit is designed for performance with:

-   **Efficient Domain Matching**: Tree-based suffix lookup for O(log n) domain validation
-   **Minimal Allocations**: Careful memory management during parsing
-   **Lazy Evaluation**: Components are parsed only when needed
-   **Optimized String Operations**: Efficient text processing for encoding/decoding
-   **Compressed Suffix Data**: Compact representation of the public suffix list

## Testing

Run the comprehensive test suite:

```bash
mops test
```

The test suite covers:

-   URL parsing success and failure cases
-   All host type variations (domains, IPv4, IPv6, hostnames)
-   Query parameter manipulation
-   URL encoding/decoding edge cases
-   Normalization and equality comparison
-   IPv6 address formatting variations
-   Domain parser functionality
-   Error handling scenarios

## Migration Guide

### Breaking Changes in v3.0

1. **Host Type Simplified**: The Host type has been simplified by consolidating `#domain` and `#hostname` variants into a single `#name` variant:

    ```motoko
    // Old (v2.x)
    switch (host) {
        case (#domain(domain)) { /* domain components */ };
        case (#hostname(name)) { /* hostname string */ };
        case (#ipV4(ip)) { /* IPv4 address */ };
        case (#ipV6(ip)) { /* IPv6 address */ };
    };

    // New (v3.0)
    switch (host) {
        case (#name(hostName)) { /* any host name string */ };
        case (#ipV4(ip)) { /* IPv4 address */ };
        case (#ipV6(ip)) { /* IPv6 address */ };
    };
    ```

2. **Domain Parser Removed from URL Parsing**: URL parsing no longer requires a domain parser parameter:

    ```motoko
    // Old (v2.x)
    import ComprehensiveDomainParser "mo:url-kit/ComprehensiveDomainParser";
    let domainParser = ComprehensiveDomainParser.ComprehensiveDomainParser();
    UrlKit.fromText("https://example.com", domainParser)

    // New (v3.0)
    UrlKit.fromText("https://example.com")
    ```

3. **Separate Domain Parsing**: Domain parsing is now a separate step when needed:

    ```motoko
    // Old (v2.x) - automatic domain parsing
    let url = UrlKit.fromText("https://blog.example.com", domainParser);
    switch (url.authority.host) {
        case (#domain(domain)) {
            let name = domain.name; // "example"
            let suffix = domain.suffix; // "com"
            let subdomains = domain.subdomains; // ["blog"]
        };
    };

    // New (v3.0) - explicit domain parsing when needed
    let url = UrlKit.fromText("https://blog.example.com");
    switch (url.authority.host) {
        case (#name(hostName)) {
            let domainParser = ComprehensiveDomainParser.ComprehensiveDomainParser();
            switch (domainParser.parse(hostName)) {
                case (#ok(domain)) {
                    let name = domain.name; // "example"
                    let suffix = domain.suffix; // "com"
                    let subdomains = domain.subdomains; // ["blog"]
                };
                case (#err(_)) { /* not a valid domain */ };
            };
        };
    };
    ```

### Breaking Changes in v2.0

1. **Domain Parser Required**: All URL parsing functions now require a `domainParser` parameter:

    ```motoko
    // Old (v1.x)
    UrlKit.fromText("https://example.com")

    // New (v2.0)
    import ComprehensiveDomainParser "mo:url-kit/ComprehensiveDomainParser";
    let domainParser = ComprehensiveDomainParser.ComprehensiveDomainParser();
    UrlKit.fromText("https://example.com", domainParser)
    ```

2. **Domain Parsing**: Domain parsing is now more flexible with custom suffix support:

    ```motoko
    // Using comprehensive parser (recommended)
    let domainParser = ComprehensiveDomainParser.ComprehensiveDomainParser();
    let result = domainParser.parse("example.com");

    // Using custom suffixes
    let result = Domain.fromText("example.test", ["test", "local"]);
    ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. When contributing:

1. Add tests for new functionality
2. Update documentation for API changes
3. Follow existing code style and patterns
4. Ensure all tests pass

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
