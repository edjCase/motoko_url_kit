import UrlKit "../src";
import Host "../src/Host";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import { test } "mo:test";
import Bool "mo:base/Bool";

// ===== HELPER FUNCTIONS =====

func formatError(testName : Text, input : Text, expected : Text, actual : Text) : Text {
  testName # " failed:\n" #
  "  Input: " # input # "\n" #
  "  Expected: " # expected # "\n" #
  "  Actual:   " # actual;
};

func formatErrorBool(testName : Text, input : Text, expected : Bool, actual : Bool) : Text {
  testName # " failed:\n" #
  "  Input: " # input # "\n" #
  "  Expected: " # Bool.toText(expected) # "\n" #
  "  Actual:   " # Bool.toText(actual);
};

func formatErrorOptional<T>(testName : Text, input : Text, expectedSome : Bool, actual : ?T) : Text {
  let actualStatus = switch (actual) {
    case (?_) "Some";
    case (null) "None";
  };
  let expectedStatus = if (expectedSome) "Some" else "None";

  testName # " failed:\n" #
  "  Input: " # input # "\n" #
  "  Expected: " # expectedStatus # "\n" #
  "  Actual:   " # actualStatus;
};

// ===== TEST CASE TYPES =====

type ParseSuccessTestCase = {
  input : Text;
  expected : UrlKit.Url;
};

type ParseFailTestCase = {
  input : Text;
};

type RoundtripTestCase = {
  input : Text;
};

type QueryParamTestCase = {
  url : Text;
  key : Text;
  expectedValue : ?Text;
};

type QueryManipulationTestCase = {
  url : Text;
  operation : Text;
  params : [(Text, Text)];
  shouldContain : [Text];
  shouldNotContain : [Text];
};

type EqualityTestCase = {
  url1 : Text;
  url2 : Text;
  shouldBeEqual : Bool;
};

// ===== HOST PARSING TESTS =====

test(
  "Host.fromText - host and port parsing",
  func() {
    let testCases : [{
      input : Text;
      expected : (Host.Host, ?Nat16);
    }] = [
      {
        input = "example.com";
        expected = (
          #domain({
            name = "example";
            suffix = "com";
            subdomains = [];
          }),
          null,
        );
      },
      {
        input = "james.github.io"; // github.io is a suffix
        expected = (
          #domain({
            name = "james";
            suffix = "github.io";
            subdomains = [];
          }),
          null,
        );
      },
      {
        input = "jim.git.io";
        expected = (
          #domain({
            name = "git";
            suffix = "io";
            subdomains = ["jim"];
          }),
          null,
        );
      },
      {
        input = "jim.is.the.best.name.git.io";
        expected = (
          #domain({
            name = "git";
            suffix = "io";
            subdomains = ["jim", "is", "the", "best", "name"];
          }),
          null,
        );
      },
      {
        input = "example.com:8080";
        expected = (
          #domain({
            name = "example";
            suffix = "com";
            subdomains = [];
          }),
          ?8080,
        );
      },
      {
        input = "localhost";
        expected = (
          #hostname("localhost"),
          null,
        );
      },
      {
        input = "localhost:3000";
        expected = (
          #hostname("localhost"),
          ?3000,
        );
      },
      {
        input = "192.168.1.1";
        expected = (
          #ipV4((192, 168, 1, 1)),
          null,
        );
      },
      {
        input = "192.168.1.1:8080";
        expected = (
          #ipV4((192, 168, 1, 1)),
          ?8080,
        );
      },
      {
        input = "[2001:db8::1]";
        expected = (
          #ipV6((0x2001, 0x0db8, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0001)),
          null,
        );
      },
      {
        input = "[2001:db8::1]:8080";
        expected = (
          #ipV6((0x2001, 0x0db8, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0001)),
          ?8080,
        );
      },
      {
        input = "[::1]";
        expected = (
          #ipV6((0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0001)),
          null,
        );
      },
      {
        input = "[::1]:3000";
        expected = (
          #ipV6((0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0001)),
          ?3000,
        );
      },
    ];

    for (testCase in testCases.vals()) {
      switch (Host.fromText(testCase.input)) {
        case (#ok(hostOrNull)) {
          if (hostOrNull != testCase.expected) {
            Debug.trap(
              "Test failed for input: " # testCase.input # "\n" #
              "Expected: " # debug_show (testCase.expected) # "\n" #
              "Actual:   " # debug_show (hostOrNull)
            );
          };
        };
        case (#err(msg)) {
          Debug.trap("Failed to parse host:port " # testCase.input # ": " # msg);
        };
      };
    };
  },
);
// ===== fromText SUCCESS TESTS =====
test(
  "fromText - successful URL parsing",
  func() {
    let testCases : [ParseSuccessTestCase] = [
      // Basic HTTP/HTTPS/FTP URLs
      {
        input = "https://example.com";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = [];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "http://localhost:8080";
        expected = {
          scheme = ?"http";
          authority = ?{
            user = null;
            host = #hostname("localhost");
            port = ?8080;
          };
          path = [];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "ftp://files.example.org";
        expected = {
          scheme = ?"ftp";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "org";
              subdomains = ["files"];
            });
            port = null;
          };
          path = [];
          queryParams = [];
          fragment = null;
        };
      },

      {
        input = "/";
        expected = {
          scheme = null;
          authority = null;
          path = [];
          queryParams = [];
          fragment = null;
        };
      },

      {
        input = "//";
        expected = {
          scheme = null;
          authority = null;
          path = [""];
          queryParams = [];
          fragment = null;
        };
      },

      // Path variations
      {
        input = "https://example.com/";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = [];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "https://example.com/path/to/resource";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = ["path", "to", "resource"];
          queryParams = [];
          fragment = null;
        };
      },

      // Query parameter variations
      {
        input = "https://example.com?key=value";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = [];
          queryParams = [("key", "value")];
          fragment = null;
        };
      },
      {
        input = "https://example.com?key1=value1&key2=value2";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = [];
          queryParams = [("key1", "value1"), ("key2", "value2")];
          fragment = null;
        };
      },
      {
        input = "https://example.com?key=";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = [];
          queryParams = [("key", "")];
          fragment = null;
        };
      },
      {
        input = "https://example.com?key";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = [];
          queryParams = [("key", "")];
          fragment = null;
        };
      },
      {
        input = "https://example.com?";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = [];
          queryParams = [];
          fragment = null;
        };
      },
      // Query parameter edge cases
      {
        input = "https://example.com?param=value&param=other";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = [];
          queryParams = [("param", "value"), ("param", "other")]; // Duplicate keys allowed
          fragment = null;
        };
      },
      {
        input = "https://example.com?param=value&";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = [];
          queryParams = [("param", "value")]; // Trailing & ignored
          fragment = null;
        };
      },

      // Custom schemes
      {
        input = "custom-scheme://example.com";
        expected = {
          scheme = ?"custom-scheme";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = [];
          queryParams = [];
          fragment = null;
        };
      },

      // Complex authority cases
      {
        input = "https://sub.domain.example.com:8443/path?q=search";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = ["sub", "domain"];
            });
            port = ?8443;
          };
          path = ["path"];
          queryParams = [("q", "search")];
          fragment = null;
        };
      },

      // Encoded parameters
      {
        input = "https://example.com?%E2%82%AC=%E2%82%AC%20value";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = [];
          queryParams = [("€", "€ value")];
          fragment = null;
        };
      },

      // IP addresses
      {
        input = "https://192.168.1.1:3000/api";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #ipV4((192, 168, 1, 1));
            port = ?3000;
          };
          path = ["api"];
          queryParams = [];
          fragment = null;
        };
      },

      // Fragments
      {
        input = "https://example.com/page#section1";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = ["page"];
          queryParams = [];
          fragment = ?"section1";
        };
      },
      {
        input = "https://example.com/path?query=value#fragment";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = ["path"];
          queryParams = [("query", "value")];
          fragment = ?"fragment";
        };
      },

      // IPv6 addresses
      {
        input = "https://[2001:db8::1]";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #ipV6((0x2001, 0x0db8, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0001));
            port = null;
          };
          path = [];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "http://[::1]:8080";
        expected = {
          scheme = ?"http";
          authority = ?{
            user = null;
            host = #ipV6((0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0001));
            port = ?8080;
          };
          path = [];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]/path";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #ipV6((0x2001, 0x0db8, 0x85a3, 0x0000, 0x0000, 0x8a2e, 0x0370, 0x7334));
            port = null;
          };
          path = ["path"];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "ftp://[2001:db8:85a3::8a2e:370:7334]:2121/files";
        expected = {
          scheme = ?"ftp";
          authority = ?{
            user = null;
            host = #ipV6((0x2001, 0x0db8, 0x85a3, 0x0000, 0x0000, 0x8a2e, 0x0370, 0x7334));
            port = ?2121;
          };
          path = ["files"];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "https://[::ffff:192.168.1.1]?query=value";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #ipV6((0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0xffff, 0xc0a8, 0x0101));
            port = null;
          };
          path = [];
          queryParams = [("query", "value")];
          fragment = null;
        };
      },
      {
        input = "https://[2001:db8::]:443/secure?auth=token#section";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #ipV6((0x2001, 0x0db8, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000));
            port = ?443;
          };
          path = ["secure"];
          queryParams = [("auth", "token")];
          fragment = ?"section";
        };
      },
      {
        input = "http://[::]:80";
        expected = {
          scheme = ?"http";
          authority = ?{
            user = null;
            host = #ipV6((0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000));
            port = ?80;
          };
          path = [];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "https://[2001:DB8:85A3::8A2E:370:7334]"; // Mixed case
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #ipV6((0x2001, 0x0db8, 0x85a3, 0x0000, 0x0000, 0x8a2e, 0x0370, 0x7334));
            port = null;
          };
          path = [];
          queryParams = [];
          fragment = null;
        };
      },

      // User info cases
      {
        input = "https://user:pass@example.com/path";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = ?{
              username = "user";
              password = "pass";
            };
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = ["path"];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "ftp://john@files.example.org:2121/upload";
        expected = {
          scheme = ?"ftp";
          authority = ?{
            user = ?{
              username = "john";
              password = "";
            };
            host = #domain({
              name = "example";
              suffix = "org";
              subdomains = ["files"];
            });
            port = ?2121;
          };
          path = ["upload"];
          queryParams = [];
          fragment = null;
        };
      },

      // ===== NEW: Non-authority schemes (scheme:path format) =====
      {
        input = "mailto:user@example.com";
        expected = {
          scheme = ?"mailto";
          authority = null;
          path = ["user@example.com"];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "mailto:user@example.com?subject=Hello&body=World";
        expected = {
          scheme = ?"mailto";
          authority = null;
          path = ["user@example.com"];
          queryParams = [("subject", "Hello"), ("body", "World")];
          fragment = null;
        };
      },
      {
        input = "tel:+1-555-123-4567";
        expected = {
          scheme = ?"tel";
          authority = null;
          path = ["+1-555-123-4567"];
          queryParams = [];
          fragment = null;
        };
      },

      // ===== NEW: File URLs =====
      {
        input = "file:///C:/Windows/System32/file.txt";
        expected = {
          scheme = ?"file";
          authority = null;
          path = ["C:", "Windows", "System32", "file.txt"];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "file:///path/to/file.txt";
        expected = {
          scheme = ?"file";
          authority = null;
          path = ["path", "to", "file.txt"];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "file://server/share/file.txt";
        expected = {
          scheme = ?"file";
          authority = ?{
            user = null;
            host = #hostname("server");
            port = null;
          };
          path = ["share", "file.txt"];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "file://localhost/path/to/file";
        expected = {
          scheme = ?"file";
          authority = ?{
            user = null;
            host = #hostname("localhost");
            port = null;
          };
          path = ["path", "to", "file"];
          queryParams = [];
          fragment = null;
        };
      },

      // ===== NEW: More relative URL cases =====
      {
        input = "//example.com/path";
        expected = {
          scheme = null;
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = ["path"];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "/absolute/path";
        expected = {
          scheme = null;
          authority = null;
          path = ["absolute", "path"];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "relative/path";
        expected = {
          scheme = null;
          authority = null;
          path = ["relative", "path"];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "/";
        expected = {
          scheme = null;
          authority = null;
          path = [];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "?query=only";
        expected = {
          scheme = null;
          authority = null;
          path = [];
          queryParams = [("query", "only")];
          fragment = null;
        };
      },
      {
        input = "#fragment-only";
        expected = {
          scheme = null;
          authority = null;
          path = [];
          queryParams = [];
          fragment = ?"fragment-only";
        };
      },

      // ===== NEW: Edge cases for path handling =====
      {
        input = "https://example.com/path/with%20spaces";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = ["path", "with%20spaces"]; // Encoded spaces preserved in path
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "https://example.com/path//double//slashes";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #domain({
              name = "example";
              suffix = "com";
              subdomains = [];
            });
            port = null;
          };
          path = ["path", "", "double", "", "slashes"]; // Empty segments preserved
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "https://";
        expected = {
          scheme = ?"https";
          authority = null;
          path = []; // Empty segments preserved
          queryParams = [];
          fragment = null;
        };
      },

      {
        input = "https://example.c";
        expected = {
          scheme = ?"https";
          authority = ?{
            user = null;
            host = #hostname("example.c"); // invalid tld, so resolved as hostname
            port = null;
          };
          path = [];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = ""; // Empty input
        expected = {
          scheme = null;
          authority = null;
          path = [];
          queryParams = [];
          fragment = null;
        };
      },
      {
        input = "     "; // Whitespace input
        expected = {
          scheme = null;
          authority = null;
          path = [];
          queryParams = [];
          fragment = null;
        };
      },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.input)) {
        case (#ok(actualUrl)) {
          if (not UrlKit.equal(actualUrl, testCase.expected)) {
            Debug.trap(
              "Test failed for input: " # testCase.input # "\n" #
              "Expected: " # debug_show (testCase.expected) # "\n" #
              "Actual:   " # debug_show (actualUrl)
            );
          };
        };
        case (#err(msg)) {
          Debug.trap(formatError("fromText success", testCase.input, "valid URL", "parse error: " # msg));
        };
      };
    };
  },
);

// ===== fromText FAILURE TESTS =====
test(
  "fromText - URL parsing failures",
  func() {
    let testCases : [ParseFailTestCase] = [

      // Authority schemes missing authority
      { input = "://example.com" },

      // Multiple delimiters
      { input = "https://example.com?param1=value1?param2=value2" },
      { input = "https://example.com#fragment#invalid" },

      // Invalid schemes
      { input = "123://example.com" }, // Numeric scheme
      { input = "-https://example.com" }, // Scheme starting with hyphen
      { input = "ht tp://example.com" }, // Space in scheme

      // Domain/Host failures
      { input = "https://-example.com" },
      { input = "https://://example.com" },
      { input = "https://example-.com" }, // Domain ending with hyphen
      { input = "https://.example.com" }, // Domain starting with dot
      { input = "https://example..com" }, // Consecutive dots in domain
      { input = "https://ex ample.com" }, // Space in domain
      { input = "https://example." }, // Empty TLD
      { input = "https://.com" }, // Missing domain name
      { input = "https://example.com-" }, // TLD ending with hyphen
      { input = "https://-example-.com" }, // Multiple hyphen issues

      // IPv6 failures
      { input = "https://[2001:db8::1::2]" }, // Multiple ::
      { input = "https://[2001:db8:invalid:hex]" }, // Invalid hex
      { input = "https://[2001:db8:85a3:0000:0000:8a2e:0370:7334:extra]" }, // Too many groups
      { input = "https://[2001:db8]" }, // Too few groups
      { input = "https://[2001:db8::gggg]" }, // Invalid hex characters
      { input = "https://[2001:db8::12345]" }, // Group too large
      { input = "https://2001:db8::1" }, // Missing brackets
      { input = "https://[2001:db8::1" }, // Missing closing bracket
      { input = "https://2001:db8::1]" }, // Missing opening bracket
      { input = "https://[:::]" }, // Invalid triple colon
      { input = "https://[2001:db8:::1]" }, // Invalid triple colon
      { input = "https://[2001:db8::1::]" }, // Double compression
      { input = "https://[::2001:db8::]" }, // Double compression

      // Port failures
      { input = "https://example.com:abc" }, // Non-numeric port
      { input = "https://example.com:65536" }, // Port too large
      { input = "https://example.com:-1" }, // Negative port
      { input = "https://example.com:" }, // Empty port

      // User info failures
      { input = "https://user@:password@example.com" }, // Multiple @ symbols
      { input = "https://user:pass:extra@example.com" }, // Multiple colons in user info

      // Extremely malformed cases
      { input = "complete garbage" },
      { input = "@#$%^&*()" },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.input)) {
        case (#ok(actual)) {
          Debug.trap(
            "Test failed\n" #
            "  Input: " # testCase.input # "\n" #
            "  Expected Error\n" #
            "  Actual Ok: " # debug_show (actual)
          );
        };
        case (#err(_)) {
          // Expected failure
        };
      };
    };
  },
);

// ===== toText TESTS =====
test(
  "toText - roundtrip conversion",
  func() {
    let testCases : [RoundtripTestCase] = [
      // Basic authority URLs
      { input = "https://example.com" },
      { input = "http://localhost:8080/path" },
      { input = "https://example.com/path/to/resource" },
      { input = "https://example.com?key=value" },
      { input = "https://example.com/path?key1=value1&key2=value2" },
      { input = "ftp://files.example.org/downloads?type=binary" },
      { input = "https://user:pass@example.com/secure" },

      // Relative URLs
      { input = "//example.com/path" },
      { input = "/absolute/path" },
      { input = "relative/path" },

      // ===== NEW: Non-authority schemes =====
      { input = "mailto:user@example.com" },
      { input = "mailto:user@example.com?subject=Hello" },
      { input = "tel:+1-555-123-4567" },
      { input = "data:text/plain,Hello%20World" },
      { input = "javascript:alert('test')" },

      // ===== NEW: File URLs =====
      { input = "file:///path/to/file.txt" },
      { input = "file://server/share/file.txt" },
      { input = "file://localhost/local/file" },

      // ===== NEW: Edge cases =====
      { input = "?query=only" },
      { input = "#fragment-only" },
      { input = "/" },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.input)) {
        case (#ok(url)) {
          let reconstructed = UrlKit.toText(url);
          switch (UrlKit.fromText(reconstructed)) {
            case (#ok(_)) {}; // Success
            case (#err(msg)) {
              Debug.trap(formatError("toText roundtrip", testCase.input, "parseable URL", "unparseable: " # msg));
            };
          };
        };
        case (#err(msg)) {
          Debug.trap(formatError("toText roundtrip setup", testCase.input, "valid URL", "parse error: " # msg));
        };
      };
    };
  },
);

// ===== getQueryParam TESTS =====

test(
  "getQueryParam - parameter retrieval",
  func() {
    let testCases : [QueryParamTestCase] = [
      {
        url = "https://example.com?key1=value1&key2=value2";
        key = "key1";
        expectedValue = ?"value1";
      },
      {
        url = "https://example.com?key1=value1&key2=value2";
        key = "key2";
        expectedValue = ?"value2";
      },
      {
        url = "https://example.com?key1=value1";
        key = "nonexistent";
        expectedValue = null;
      },
      {
        url = "https://example.com?key=";
        key = "key";
        expectedValue = ?"";
      },
      {
        url = "https://example.com?key";
        key = "key";
        expectedValue = ?"";
      },
      {
        url = "https://example.com";
        key = "key";
        expectedValue = null;
      },
      {
        url = "https://example.com?";
        key = "key";
        expectedValue = null;
      },
      {
        url = "https://example.com?a=1&b=2&a=3";
        key = "a";
        expectedValue = ?"1";
      },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.url)) {
        case (#ok(url)) {
          let result = UrlKit.getQueryParam(url, testCase.key);
          switch (testCase.expectedValue, result) {
            case (?expected, ?actual) {
              if (expected != actual) {
                Debug.trap(formatError("getQueryParam", testCase.url # " key=" # testCase.key, expected, actual));
              };
            };
            case (null, null) {}; // Both null, correct
            case (?_, null) {
              Debug.trap(formatErrorOptional("getQueryParam", testCase.url # " key=" # testCase.key, true, result));
            };
            case (null, ?_) {
              Debug.trap(formatErrorOptional("getQueryParam", testCase.url # " key=" # testCase.key, false, result));
            };
          };
        };
        case (#err(msg)) {
          Debug.trap(formatError("getQueryParam setup", testCase.url, "valid URL", "parse error: " # msg));
        };
      };
    };
  },
);

// ===== addQueryParam & addQueryParamMulti TESTS =====

test(
  "addQueryParam - parameter addition",
  func() {
    let testCases : [QueryManipulationTestCase] = [
      {
        url = "https://example.com";
        operation = "addQueryParam";
        params = [("key", "value")];
        shouldContain = ["key=value"];
        shouldNotContain = [];
      },
      {
        url = "https://example.com?existing=param";
        operation = "addQueryParam";
        params = [("new", "param")];
        shouldContain = ["existing=param", "new=param"];
        shouldNotContain = [];
      },
      {
        url = "https://example.com";
        operation = "addQueryParamMulti";
        params = [("key1", "value1"), ("key2", "value2")];
        shouldContain = ["key1=value1", "key2=value2"];
        shouldNotContain = [];
      },
      {
        url = "https://example.com?existing=param";
        operation = "addQueryParamMulti";
        params = [];
        shouldContain = ["existing=param"];
        shouldNotContain = [];
      },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.url)) {
        case (#ok(url)) {
          let updatedUrl = if (testCase.operation == "addQueryParam" and testCase.params.size() > 0) {
            UrlKit.addQueryParam(url, testCase.params[0]);
          } else {
            UrlKit.addQueryParamMulti(url, testCase.params);
          };

          let result = UrlKit.toText(updatedUrl);

          // Check should contain
          for (shouldContain in testCase.shouldContain.vals()) {
            if (not Text.contains(result, #text(shouldContain))) {
              Debug.trap(formatError(testCase.operation, testCase.url, "contains " # shouldContain, result));
            };
          };

          // Check should not contain
          for (shouldNotContain in testCase.shouldNotContain.vals()) {
            if (Text.contains(result, #text(shouldNotContain))) {
              Debug.trap(formatError(testCase.operation, testCase.url, "does not contain " # shouldNotContain, result));
            };
          };
        };
        case (#err(msg)) {
          Debug.trap(formatError(testCase.operation # " setup", testCase.url, "valid URL", "parse error: " # msg));
        };
      };
    };
  },
);

// ===== removeQueryParam & removeQueryParamMulti TESTS =====

test(
  "removeQueryParam - parameter removal",
  func() {
    let testCases : [QueryManipulationTestCase] = [
      {
        url = "https://example.com?key1=value1&key2=value2";
        operation = "removeQueryParam";
        params = [("key1", "")]; // Using key1, value ignored for removal
        shouldContain = ["key2=value2"];
        shouldNotContain = ["key1=value1"];
      },
      {
        url = "https://example.com?key1=value1";
        operation = "removeQueryParam";
        params = [("nonexistent", "")];
        shouldContain = ["key1=value1"];
        shouldNotContain = [];
      },
      {
        url = "https://example.com?only=param";
        operation = "removeQueryParam";
        params = [("only", "")];
        shouldContain = [];
        shouldNotContain = ["?"];
      },
      {
        url = "https://example.com?key1=value1&key2=value2&key3=value3";
        operation = "removeQueryParamMulti";
        params = [("key1", ""), ("key3", "")]; // Keys only
        shouldContain = ["key2=value2"];
        shouldNotContain = ["key1=value1", "key3=value3"];
      },
      {
        url = "https://example.com?key1=value1";
        operation = "removeQueryParamMulti";
        params = [];
        shouldContain = ["key1=value1"];
        shouldNotContain = [];
      },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.url)) {
        case (#ok(url)) {
          let keysToRemove = Array.map(testCase.params, func((k, _) : (Text, Text)) : Text = k);

          let updatedUrl = if (testCase.operation == "removeQueryParam" and keysToRemove.size() > 0) {
            UrlKit.removeQueryParam(url, keysToRemove[0]);
          } else {
            UrlKit.removeQueryParamMulti(url, keysToRemove);
          };

          let result = UrlKit.toText(updatedUrl);

          // Check should contain
          for (shouldContain in testCase.shouldContain.vals()) {
            if (not Text.contains(result, #text(shouldContain))) {
              Debug.trap(formatError(testCase.operation, testCase.url, "contains " # shouldContain, result));
            };
          };

          // Check should not contain
          for (shouldNotContain in testCase.shouldNotContain.vals()) {
            if (Text.contains(result, #text(shouldNotContain))) {
              Debug.trap(formatError(testCase.operation, testCase.url, "does not contain " # shouldNotContain, result));
            };
          };
        };
        case (#err(msg)) {
          Debug.trap(formatError(testCase.operation # " setup", testCase.url, "valid URL", "parse error: " # msg));
        };
      };
    };
  },
);

// ===== equal TESTS =====

test(
  "equal - URL equality",
  func() {
    let testCases : [EqualityTestCase] = [
      // Should be equal
      {
        url1 = "https://example.com";
        url2 = "https://example.com";
        shouldBeEqual = true;
      },
      {
        url1 = "https://example.com/path?key=value";
        url2 = "https://example.com/path?key=value";
        shouldBeEqual = true;
      },
      {
        url1 = "HTTPS://EXAMPLE.COM";
        url2 = "https://example.com";
        shouldBeEqual = true;
      },
      {
        url1 = "https://example.com?z=1&a=2";
        url2 = "https://example.com?a=2&z=1";
        shouldBeEqual = true;
      },
      {
        url1 = "HTTP://EXAMPLE.COM/PATH?z=last&a=first";
        url2 = "http://example.com/path?a=first&z=last";
        shouldBeEqual = true;
      },

      // Should not be equal
      {
        url1 = "https://example.com";
        url2 = "http://example.com";
        shouldBeEqual = false;
      },
      {
        url1 = "https://example.com/path1";
        url2 = "https://example.com/path2";
        shouldBeEqual = false;
      },
      {
        url1 = "https://example.com?key1=value1";
        url2 = "https://example.com?key2=value2";
        shouldBeEqual = false;
      },
      {
        url1 = "https://example1.com";
        url2 = "https://example2.com";
        shouldBeEqual = false;
      },
      {
        url1 = "https://example.com:8080";
        url2 = "https://example.com:9090";
        shouldBeEqual = false;
      },
      {
        url1 = "https://example.com?key=value1";
        url2 = "https://example.com?key=value2";
        shouldBeEqual = false;
      },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.url1)) {
        case (#ok(url1)) {
          switch (UrlKit.fromText(testCase.url2)) {
            case (#ok(url2)) {
              let result = UrlKit.equal(url1, url2);
              if (result != testCase.shouldBeEqual) {
                Debug.trap(formatErrorBool("equal", testCase.url1 # " vs " # testCase.url2, testCase.shouldBeEqual, result));
              };
            };
            case (#err(msg)) {
              Debug.trap(formatError("equal setup url2", testCase.url2, "valid URL", "parse error: " # msg));
            };
          };
        };
        case (#err(msg)) {
          Debug.trap(formatError("equal setup url1", testCase.url1, "valid URL", "parse error: " # msg));
        };
      };
    };
  },
);

// ===== normalize TESTS =====

test(
  "normalize - URL normalization",
  func() {
    let testCases = [
      {
        input = "HTTP://EXAMPLE.COM";
        expected = #startsWith("http://");
      },
      {
        input = "https://example.com?z=1&a=2&m=3";
        expected = #contains("a=2&m=3&z=1");
      },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.input)) {
        case (#ok(url)) {
          let normalized = UrlKit.normalize(url);
          let result = UrlKit.toText(normalized);
          switch (testCase.expected) {
            case (#startsWith(startsWith)) {
              if (not Text.startsWith(result, #text(startsWith))) {
                Debug.trap(formatError("normalize", testCase.input, "starts with " # startsWith, result));
              };
            };
            case (#contains(substring)) {
              if (not Text.contains(result, #text(substring))) {
                Debug.trap(formatError("normalize", testCase.input, "contains " # substring, result));
              };
            };
          };
        };
        case (#err(msg)) {
          Debug.trap(formatError("normalize setup", testCase.input, "valid URL", "parse error: " # msg));
        };
      };
    };
  },
);

// ===== USER INFO TESTS =====

test(
  "User info parsing and encoding",
  func() {
    let userInfoTestCases = [
      {
        input = "https://user:pass@example.com/path";
        expectedUser = ?{ username = "user"; password = "pass" };
        shouldContainInOutput = "user:pass@example.com";
      },
      {
        input = "ftp://john@files.example.org/upload";
        expectedUser = ?{ username = "john"; password = "" };
        shouldContainInOutput = "john@files.example.org";
      },
      {
        input = "https://user%40domain:p%40ss@example.com";
        expectedUser = ?{ username = "user@domain"; password = "p@ss" };
        shouldContainInOutput = "user%40domain:p%40ss@example.com";
      },
    ];

    for (testCase in userInfoTestCases.vals()) {
      switch (UrlKit.fromText(testCase.input)) {
        case (#ok(url)) {
          // Check user info was parsed correctly
          switch (url.authority) {
            case (?authority) {
              switch (authority.user, testCase.expectedUser) {
                case (?actualUser, ?expectedUser) {
                  if (actualUser.username != expectedUser.username or actualUser.password != expectedUser.password) {
                    Debug.trap("User info parsing failed for: " # testCase.input);
                  };
                };
                case (null, null) {}; // Both null, ok
                case _ {
                  Debug.trap("User info presence mismatch for: " # testCase.input);
                };
              };
            };
            case (null) {
              Debug.trap("Expected authority but got null for: " # testCase.input);
            };
          };

          // Check roundtrip encoding
          let output = UrlKit.toText(url);
          if (not Text.contains(output, #text(testCase.shouldContainInOutput))) {
            Debug.trap("User info encoding failed for: " # testCase.input # " - output: " # output);
          };
        };
        case (#err(msg)) {
          Debug.trap("Failed to parse user info URL: " # testCase.input # " - " # msg);
        };
      };
    };
  },
);

// ===== IPv6 TESTS =====

test(
  "IPv6 - comprehensive parsing and formatting",
  func() {
    let ipv6TestCases = [
      {
        input = "https://[2001:db8::1]";
        expectedHostType = "ipv6";
        shouldContainInOutput = "[2001:db8::1]";
      },
      {
        input = "http://[::1]:8080/api";
        expectedHostType = "ipv6";
        shouldContainInOutput = "[::1]:8080";
      },
      {
        input = "https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]";
        expectedHostType = "ipv6";
        shouldContainInOutput = "[2001:db8:85a3::8a2e:370:7334]"; // Normalized format
      },
      {
        input = "ftp://[::ffff:192.168.1.1]:21";
        expectedHostType = "ipv6";
        shouldContainInOutput = "[::ffff:c0a8:101]:21"; // IPv4-mapped IPv6
      },
    ];

    for (testCase in ipv6TestCases.vals()) {
      switch (UrlKit.fromText(testCase.input)) {
        case (#ok(url)) {
          // Verify host type
          switch (url.authority) {
            case (?authority) {
              switch (authority.host) {
                case (#ipV6(_)) {}; // Correct
                case _ {
                  Debug.trap("Expected IPv6 host type for: " # testCase.input);
                };
              };
            };
            case (null) {
              Debug.trap("Expected authority for IPv6 URL: " # testCase.input);
            };
          };

          // Verify roundtrip
          let output = UrlKit.toText(UrlKit.normalize(url));
          if (not Text.contains(output, #text(testCase.shouldContainInOutput))) {
            Debug.trap(
              "IPv6 formatting failed for " # testCase.input #
              ": expected to contain '" # testCase.shouldContainInOutput #
              "' but got: " # output
            );
          };
        };
        case (#err(msg)) {
          Debug.trap("Failed to parse valid IPv6 URL " # testCase.input # ": " # msg);
        };
      };
    };
  },
);

// Additional test cases to verify bug fixes

test(
  "Bug Fix 1: Fragment encoding/decoding",
  func() {
    let testCases = [
      {
        input = "https://example.com#hello%20world";
        expectedFragment = ?"hello world";
        roundtripExpected = "https://example.com#hello%20world";
      },
      {
        input = "https://example.com#section%201%2B2";
        expectedFragment = ?"section 1+2";
        roundtripExpected = "https://example.com#section%201%2b2";
      },
      {
        input = "https://example.com#%E2%82%AC";
        expectedFragment = ?"€";
        roundtripExpected = "https://example.com#%e2%82%ac";
      },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.input)) {
        case (#ok(url)) {
          // Check fragment was decoded properly
          switch (url.fragment, testCase.expectedFragment) {
            case (?actual, ?expected) {
              if (actual != expected) {
                Debug.trap("Fragment decoding failed: expected '" # expected # "' but got '" # actual # "'");
              };
            };
            case (null, null) {}; // Both null, ok
            case _ {
              Debug.trap("Fragment presence mismatch");
            };
          };

          // Check roundtrip encoding
          let reconstructed = UrlKit.toText(url);
          if (reconstructed != testCase.roundtripExpected) {
            Debug.trap("Fragment encoding failed: expected '" # testCase.roundtripExpected # "' but got '" # reconstructed # "'");
          };
        };
        case (#err(msg)) {
          Debug.trap("Failed to parse URL with fragment: " # msg);
        };
      };
    };
  },
);

test(
  "Bug Fix 2: Empty path segments with normalization handling",
  func() {
    let testCases = [
      {
        input = "https://example.com//path";
        expectedPath = ["path"];
      },
      {
        input = "https://example.com///multiple///slashes";
        expectedPath = ["multiple", "slashes"];
      },
      {
        input = "https://example.com/normal/path/";
        expectedPath = ["normal", "path"];
      },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.input)) {
        case (#ok(url)) {
          let normalizedUrl = UrlKit.normalize(url);
          if (normalizedUrl.path != testCase.expectedPath) {
            Debug.trap(
              "Path parsing failed for '" # testCase.input # "': expected " #
              debug_show (testCase.expectedPath) # " but got " # debug_show (normalizedUrl.path)
            );
          };
        };
        case (#err(msg)) {
          Debug.trap("Failed to parse URL with multiple slashes: " # msg);
        };
      };
    };
  },
);

test(
  "Bug Fix 3: Query parameter key encoding",
  func() {
    let testCases = [
      {
        url = "https://example.com";
        params = [("hello world", "value"), ("key+special", "test")];
        expectedInOutput = ["hello%20world=value", "key%2bspecial=test"];
      },
      {
        url = "https://example.com";
        params = [("€", "euro"), ("ñ", "eñe")];
        expectedInOutput = ["%e2%82%ac=euro", "%c3%b1=e%c3%b1e"];
      },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.url)) {
        case (#ok(url)) {
          let urlWithParams = UrlKit.addQueryParamMulti(url, testCase.params);
          let result = UrlKit.toText(urlWithParams);

          for (expected in testCase.expectedInOutput.vals()) {
            if (not Text.contains(result, #text(expected))) {
              Debug.trap(
                "Query key encoding failed: expected '" # expected #
                "' in result but got: " # result
              );
            };
          };
        };
        case (#err(msg)) {
          Debug.trap("Failed to parse base URL: " # msg);
        };
      };
    };
  },
);
