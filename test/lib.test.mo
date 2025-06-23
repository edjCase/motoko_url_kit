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
