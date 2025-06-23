import UrlKit "../src";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
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

func formatErrorResult<T, E>(testName : Text, input : Text, expectedOk : Bool, result : Result.Result<T, E>) : Text {
  let actualStatus = switch (result) {
    case (#ok(_)) "Ok";
    case (#err(_)) "Error";
  };
  let expectedStatus = if (expectedOk) "Ok" else "Error";

  testName # " failed:\n" #
  "  Input: " # input # "\n" #
  "  Expected: " # expectedStatus # "\n" #
  "  Actual:   " # actualStatus;
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

// ===== fromText SUCCESS TESTS =====
test(
  "fromText - successful URL parsing",
  func() {
    let testCases : [ParseSuccessTestCase] = [
      {
        input = "https://example.com";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = [];
          queryParams = [];
          port = null;
          fragment = null;
        };
      },
      {
        input = "http://localhost:8080";
        expected = {
          scheme = "http";
          host = #localhost;
          path = [];
          queryParams = [];
          port = ?8080;
          fragment = null;
        };
      },
      {
        input = "ftp://files.example.org";
        expected = {
          scheme = "ftp";
          host = #domain({
            name = "example";
            tld = "org";
            subdomains = ["files"];
          });
          path = [];
          queryParams = [];
          port = null;
          fragment = null;
        };
      },
      {
        input = "https://example.com/";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = [""];
          queryParams = [];
          port = null;
          fragment = null;
        };
      },
      {
        input = "https://example.com/path/to/resource";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = ["path", "to", "resource"];
          queryParams = [];
          port = null;
          fragment = null;
        };
      },
      {
        input = "https://example.com?key=value";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = [];
          queryParams = [("key", "value")];
          port = null;
          fragment = null;
        };
      },
      {
        input = "https://example.com?key1=value1&key2=value2";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = [];
          queryParams = [("key1", "value1"), ("key2", "value2")];
          port = null;
          fragment = null;
        };
      },
      {
        input = "https://example.com?key=";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = [];
          queryParams = [("key", "")];
          port = null;
          fragment = null;
        };
      },
      {
        input = "https://example.com?key";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = [];
          queryParams = [("key", "")];
          port = null;
          fragment = null;
        };
      },
      {
        input = "https://example.com?";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = [];
          queryParams = [];
          port = null;
          fragment = null;
        };
      },
      {
        input = "custom-scheme://example.com";
        expected = {
          scheme = "custom-scheme";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = [];
          queryParams = [];
          port = null;
          fragment = null;
        };
      },
      {
        input = "https://sub.domain.example.com:8443/path?q=search";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = ["sub", "domain"];
          });
          path = ["path"];
          queryParams = [("q", "search")];
          port = ?8443;
          fragment = null;
        };
      },
      {
        input = "https://example.com?%E2%82%AC=%E2%82%AC%20value";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = [];
          queryParams = [("€", "€ value")];
          port = null;
          fragment = null;
        };
      },
      {
        input = "https://192.168.1.1:3000/api";
        expected = {
          scheme = "https";
          host = #ipv4((192, 168, 1, 1));
          path = ["api"];
          queryParams = [];
          port = ?3000;
          fragment = null;
        };
      },
      {
        input = "https://example.com/page#section1";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = ["page"];
          queryParams = [];
          port = null;
          fragment = ?"section1";
        };
      },
      {
        input = "https://example.com/path?query=value#fragment";
        expected = {
          scheme = "https";
          host = #domain({
            name = "example";
            tld = "com";
            subdomains = [];
          });
          path = ["path"];
          queryParams = [("query", "value")];
          port = null;
          fragment = ?"fragment";
        };
      },
      {
        input = "https://[2001:db8::1]";
        expected = {
          scheme = "https";
          host = #ipv6((0x2001, 0x0db8, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0001));
          path = [];
          queryParams = [];
          port = null;
          fragment = null;
        };
      },
      {
        input = "http://[::1]:8080";
        expected = {
          scheme = "http";
          host = #ipv6((0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0001));
          path = [];
          queryParams = [];
          port = ?8080;
          fragment = null;
        };
      },
      {
        input = "https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]/path";
        expected = {
          scheme = "https";
          host = #ipv6((0x2001, 0x0db8, 0x85a3, 0x0000, 0x0000, 0x8a2e, 0x0370, 0x7334));
          path = ["path"];
          queryParams = [];
          port = null;
          fragment = null;
        };
      },
      {
        input = "ftp://[2001:db8:85a3::8a2e:370:7334]:2121/files";
        expected = {
          scheme = "ftp";
          host = #ipv6((0x2001, 0x0db8, 0x85a3, 0x0000, 0x0000, 0x8a2e, 0x0370, 0x7334));
          path = ["files"];
          queryParams = [];
          port = ?2121;
          fragment = null;
        };
      },
      {
        input = "https://[::ffff:192.168.1.1]?query=value";
        expected = {
          scheme = "https";
          host = #ipv6((0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0xffff, 0xc0a8, 0x0101));
          path = [];
          queryParams = [("query", "value")];
          port = null;
          fragment = null;
        };
      },
      {
        input = "https://[2001:db8::]:443/secure?auth=token#section";
        expected = {
          scheme = "https";
          host = #ipv6((0x2001, 0x0db8, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000));
          path = ["secure"];
          queryParams = [("auth", "token")];
          port = ?443;
          fragment = ?"section";
        };
      },
      {
        input = "http://[::]:80";
        expected = {
          scheme = "http";
          host = #ipv6((0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000));
          path = [];
          queryParams = [];
          port = ?80;
          fragment = null;
        };
      },
      {
        input = "https://[2001:DB8:85A3::8A2E:370:7334]"; // Mixed case
        expected = {
          scheme = "https";
          host = #ipv6((0x2001, 0x0db8, 0x85a3, 0x0000, 0x0000, 0x8a2e, 0x0370, 0x7334));
          path = [];
          queryParams = [];
          port = null;
          fragment = null;
        };
      },
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.input)) {
        case (#ok(actualUrl)) {
          if (not UrlKit.equal(actualUrl, testCase.expected)) {
            Debug.trap("fromText success test failed for: " # testCase.input);
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
      { input = "" },
      { input = "not-a-url" },
      { input = "https://" },
      { input = "://example.com" },
      { input = "https://example.com?param1=value1?param2=value2" },
      { input = "https://://example.com" },
      { input = "http://" },
      { input = "https://[2001:db8::1::2]" }, // Multiple ::
      { input = "https://[2001:db8:invalid:hex]" }, // Invalid hex
      { input = "https://[2001:db8:85a3:0000:0000:8a2e:0370:7334:extra]" }, // Too many groups
      { input = "https://[2001:db8]" }, // Too few groups
      { input = "https://[2001:db8::gggg]" }, // Invalid hex characters
      { input = "https://[2001:db8::12345]" }, // Group too large
      { input = "https://2001:db8::1" }, // Missing brackets
      { input = "https://[2001:db8::1" }, // Missing closing bracket
      { input = "https://2001:db8::1]" }, // Missing opening bracket
    ];

    for (testCase in testCases.vals()) {
      switch (UrlKit.fromText(testCase.input)) {
        case (#ok(_)) {
          Debug.trap(formatErrorResult("fromText failure", testCase.input, false, #ok("unexpected success")));
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
      { input = "https://example.com" },
      { input = "http://localhost:8080/path" },
      { input = "https://example.com/path/to/resource" },
      { input = "https://example.com?key=value" },
      { input = "https://example.com/path?key1=value1&key2=value2" },
      { input = "ftp://files.example.org/downloads?type=binary" },
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

// Additional test cases to verify bug fixes
// Add these to your existing test file

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
        shouldContainInOutput = "[2001:db8:85a3:0:0:8a2e:370:7334]"; // Normalized format
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
          switch (url.host) {
            case (#ipv6(_)) {}; // Correct
            case _ {
              Debug.trap("Expected IPv6 host type for: " # testCase.input);
            };
          };

          // Verify roundtrip
          let output = UrlKit.toText(url);
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

test(
  "IPv6 - compressed notation handling",
  func() {
    let compressionTestCases = [
      {
        input = "https://[2001:db8:0:0:0:0:0:1]";
        compressed = "https://[2001:db8::1]";
        description = "leading zeros compression";
      },
      {
        input = "https://[2001:0:0:0:0:0:0:1]";
        compressed = "https://[2001::1]";
        description = "middle zeros compression";
      },
      {
        input = "https://[0:0:0:0:0:0:0:1]";
        compressed = "https://[::1]";
        description = "loopback compression";
      },
      {
        input = "https://[0:0:0:0:0:0:0:0]";
        compressed = "https://[::]";
        description = "all zeros compression";
      },
    ];

    for (testCase in compressionTestCases.vals()) {
      // Parse both formats
      switch (UrlKit.fromText(testCase.input), UrlKit.fromText(testCase.compressed)) {
        case (#ok(url1), #ok(url2)) {
          // Should be equal when normalized
          if (not UrlKit.equal(url1, url2)) {
            Debug.trap(
              "IPv6 compression equality failed for " # testCase.description #
              ": " # testCase.input # " should equal " # testCase.compressed
            );
          };
        };
        case (#err(msg), _) {
          Debug.trap("Failed to parse expanded IPv6 " # testCase.input # ": " # msg);
        };
        case (_, #err(msg)) {
          Debug.trap("Failed to parse compressed IPv6 " # testCase.compressed # ": " # msg);
        };
      };
    };
  },
);

test(
  "IPv6 - case insensitivity",
  func() {
    let caseTestCases = [
      {
        lower = "https://[2001:db8:85a3::8a2e:370:7334]";
        upper = "https://[2001:DB8:85A3::8A2E:370:7334]";
        mixed = "https://[2001:Db8:85A3::8a2E:370:7334]";
      },
      {
        lower = "https://[::ffff:c0a8:101]";
        upper = "https://[::FFFF:C0A8:101]";
        mixed = "https://[::FfFf:C0a8:101]";
      },
    ];

    for (testCase in caseTestCases.vals()) {
      switch (
        UrlKit.fromText(testCase.lower),
        UrlKit.fromText(testCase.upper),
        UrlKit.fromText(testCase.mixed),
      ) {
        case (#ok(url1), #ok(url2), #ok(url3)) {
          // All should be equal when normalized
          if (not UrlKit.equal(url1, url2) or not UrlKit.equal(url1, url3)) {
            Debug.trap("IPv6 case insensitivity failed for: " # testCase.lower);
          };

          // Output should be normalized to lowercase
          let output = UrlKit.toText(UrlKit.normalize(url2));
          if (not Text.contains(output, #text(UrlKit.toText(url1)))) {
            Debug.trap("IPv6 case normalization failed");
          };
        };
        case _ {
          Debug.trap("Failed to parse IPv6 case test URLs");
        };
      };
    };
  },
);

test(
  "IPv6 - special addresses",
  func() {
    let specialTestCases = [
      {
        input = "https://[::1]";
        description = "IPv6 loopback";
        expectedEqual = "https://[0:0:0:0:0:0:0:1]";
      },
      {
        input = "https://[::]";
        description = "IPv6 all zeros";
        expectedEqual = "https://[0:0:0:0:0:0:0:0]";
      },
      {
        input = "https://[::ffff:192.168.1.1]";
        description = "IPv4-mapped IPv6";
        expectedEqual = "https://[0:0:0:0:0:ffff:c0a8:101]";
      },
      {
        input = "https://[2001:db8::8a2e:370:7334]";
        description = "documentation prefix";
        expectedEqual = "https://[2001:db8:0:0:0:8a2e:370:7334]";
      },
    ];

    for (testCase in specialTestCases.vals()) {
      switch (UrlKit.fromText(testCase.input), UrlKit.fromText(testCase.expectedEqual)) {
        case (#ok(url1), #ok(url2)) {
          if (not UrlKit.equal(url1, url2)) {
            Debug.trap(
              "IPv6 special address test failed for " # testCase.description #
              ": " # testCase.input # " should equal " # testCase.expectedEqual
            );
          };
        };
        case (#err(msg), _) {
          Debug.trap("Failed to parse " # testCase.description # " " # testCase.input # ": " # msg);
        };
        case (_, #err(msg)) {
          Debug.trap("Failed to parse expected equal " # testCase.expectedEqual # ": " # msg);
        };
      };
    };
  },
);

test(
  "IPv6 - roundtrip with complex URLs",
  func() {
    let complexTestCases = [
      "https://[2001:db8::1]:8443/api/v1/users?filter=active&sort=name#results",
      "http://[::1]:3000/app?redirect=%2Fhome&token=abc123",
      "ftp://[2001:db8:85a3::8a2e:370:7334]:2121/files/document.pdf",
      "https://[::ffff:c0a8:101]/path/to/resource?param=%E2%82%AC&other=value#section1",
    ];

    for (testCase in complexTestCases.vals()) {
      switch (UrlKit.fromText(testCase)) {
        case (#ok(url)) {
          let reconstructed = UrlKit.toText(url);
          switch (UrlKit.fromText(reconstructed)) {
            case (#ok(url2)) {
              if (not UrlKit.equal(url, url2)) {
                Debug.trap(
                  "IPv6 complex roundtrip failed for: " # testCase #
                  "\nReconstructed: " # reconstructed
                );
              };
            };
            case (#err(msg)) {
              Debug.trap("Failed to re-parse reconstructed IPv6 URL: " # reconstructed # " - " # msg);
            };
          };
        };
        case (#err(msg)) {
          Debug.trap("Failed to parse complex IPv6 URL " # testCase # ": " # msg);
        };
      };
    };
  },
);
