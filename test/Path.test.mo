import Path "../src/Path";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import { test } "mo:test";

// ===== HELPER FUNCTIONS =====

func formatError(testName : Text, input : Text, expected : Text, actual : Text) : Text {
    testName # " failed:\n" #
    "  Input: " # input # "\n" #
    "  Expected: " # expected # "\n" #
    "  Actual:   " # actual;
};

func formatErrorArray(testName : Text, input : Text, expected : [Text], actual : [Text]) : Text {
    testName # " failed:\n" #
    "  Input: " # input # "\n" #
    "  Expected: " # debug_show (expected) # "\n" #
    "  Actual:   " # debug_show (actual);
};

func formatErrorOptional(testName : Text, input : Text, expectedSome : Bool, actual : ?[Text]) : Text {
    let actualStatus = switch (actual) {
        case (?segments) "Some(" # debug_show (segments) # ")";
        case (null) "None";
    };
    let expectedStatus = if (expectedSome) "Some" else "None";

    testName # " failed:\n" #
    "  Input: " # input # "\n" #
    "  Expected: " # expectedStatus # "\n" #
    "  Actual:   " # actualStatus;
};

// ===== TEST CASE TYPES =====

type PathParseTestCase = {
    input : Text;
    expected : ?[Text]; // null means expected to fail/empty
};

type PathToTextTestCase = {
    input : [Text];
    expected : Text;
};

type PathMatchTestCase = {
    prefix : [Text];
    path : [Text];
    expected : ?[Text]; // null means no match
};

type PathJoinTestCase = {
    path : [Text];
    segment : Text;
    expected : [Text];
};

type PathJoinMultiTestCase = {
    path : [Text];
    segments : [Text];
    expected : [Text];
};

type PathNormalizeTestCase = {
    input : [Text];
    expected : [Text];
};

type PathEqualTestCase = {
    path1 : [Text];
    path2 : [Text];
    expected : Bool;
};

// ===== fromText TESTS =====

test(
    "Path.fromText - parsing paths from text",
    func() {
        let testCases : [PathParseTestCase] = [
            {
                input = "/path/to/resource";
                expected = ?["path", "to", "resource"]; // Note: loses absolute info
            },
            {
                input = "/single";
                expected = ?["single"]; // Note: loses absolute info
            },

            // Basic relative paths
            {
                input = "path/to/resource";
                expected = ?["path", "to", "resource"];
            },
            {
                input = "single";
                expected = ?["single"];
            },

            // CRITICAL LIMITATION: These cases expose the design problem
            {
                input = "";
                expected = ?[]; // Empty relative path
            },
            {
                input = "/";
                expected = ?[]; // Root absolute path
            },

            // Current implementation filters empty segments (this may be wrong)
            {
                input = "//double//slashes";
                expected = ?["", "double", "", "slashes"]; // Empty segments filtered out
            },
            {
                input = "/path//with//empty//segments/";
                expected = ?["path", "", "with", "", "empty", "", "segments"]; // Empty segments filtered out
            },

            // Trailing slashes are filtered out by current implementation
            {
                input = "/path/to/resource/";
                expected = ?["path", "to", "resource"]; // Trailing slash filtered
            },
            {
                input = "path/to/resource/";
                expected = ?["path", "to", "resource"]; // Trailing slash filtered
            },

            // Multiple leading slashes all filtered to same result
            {
                input = "////leading/slashes";
                expected = ?["", "", "", "leading", "slashes"]; // All empty segments filtered
            },

            // Complex cases
            {
                input = "/api/v1/users/123/profile";
                expected = ?["api", "v1", "users", "123", "profile"];
            },
            {
                input = "documents/2023/reports/quarterly.pdf";
                expected = ?["documents", "2023", "reports", "quarterly.pdf"];
            },

            // Special characters in segments
            {
                input = "/path/with-dashes/and_underscores";
                expected = ?["path", "with-dashes", "and_underscores"];
            },
            {
                input = "/path/with.dots/file.ext";
                expected = ?["path", "with.dots", "file.ext"];
            },
            {
                input = "/path/with spaces/in segments";
                expected = null;
            },

            // Encoded characters (should be preserved as-is since Path doesn't decode)
            {
                input = "/path/with%20encoded/characters%2F";
                expected = ?["path", "with%20encoded", "characters%2F"];
            },

            // ===== URL-SPECIFIC EDGE CASES =====

            // Dot segments - URLs can have these but they're usually normalized by browsers
            {
                input = "/path/./to/resource";
                expected = ?["path", ".", "to", "resource"]; // Preserved as literal segments
            },
            {
                input = "/path/../to/resource";
                expected = ?["path", "..", "to", "resource"]; // Preserved as literal segments
            },
            {
                input = "./relative/path";
                expected = ?[".", "relative", "path"]; // Relative with dot
            },
            {
                input = "../relative/path";
                expected = ?["..", "relative", "path"]; // Relative with parent
            },
            {
                input = "/./";
                expected = ?["."]; // Single dot segment
            },
            {
                input = "/../";
                expected = ?[".."]; // Single parent segment
            },

            // Query-like segments (valid in URL paths)
            {
                input = "/path/segment?not=query";
                expected = ?["path", "segment?not=query"]; // ? is valid in path segments
            },
            {
                input = "/path/segment#not=fragment";
                expected = ?["path", "segment#not=fragment"]; // # is valid in path segments
            },

            // Unicode and international characters
            {
                input = "/café/naïve/résumé";
                expected = ?["café", "naïve", "résumé"]; // Unicode preserved
            },
            {
                input = "/中文/日本語/한국어";
                expected = ?["中文", "日本語", "한국어"]; // CJK characters
            },

            // Very long segments (URLs can have long paths)
            {
                input = "/very/long/path/with/many/segments/that/goes/on/and/on/and/on/more/segments";
                expected = ?["very", "long", "path", "with", "many", "segments", "that", "goes", "on", "and", "on", "and", "on", "more", "segments"];
            },

            // Numbers and special characters common in URLs
            {
                input = "/api/v2.1/users/123/posts/456-789";
                expected = ?["api", "v2.1", "users", "123", "posts", "456-789"];
            },
            {
                input = "/files/image.jpg.backup.2023-12-25";
                expected = ?["files", "image.jpg.backup.2023-12-25"];
            },

            // Brackets and parentheses (valid in URL paths)
            {
                input = "/path/[bracketed]/segment/(parentheses)";
                expected = ?["path", "[bracketed]", "segment", "(parentheses)"];
            },

            // Tilde paths (common in URLs for user directories)
            {
                input = "/~username/public_html/index.html";
                expected = ?["~username", "public_html", "index.html"];
            },

            // Case sensitivity preservation
            {
                input = "/CamelCase/MixedCASE/lowercase";
                expected = ?["CamelCase", "MixedCASE", "lowercase"];
            },

            // Single character segments
            {
                input = "/a/b/c/d/e";
                expected = ?["a", "b", "c", "d", "e"];
            },

            // Numeric only segments
            {
                input = "/123/456/789";
                expected = ?["123", "456", "789"];
            },

            // ===== POTENTIALLY PROBLEMATIC CASES =====

            // Percent encoding variations
            {
                input = "/path/%2F/segment"; // Encoded slash in middle
                expected = ?["path", "%2F", "segment"]; // Should preserve encoding
            },
            {
                input = "/path/%2f/segment"; // Lowercase hex
                expected = ?["path", "%2f", "segment"]; // Should preserve exact case
            },
            {
                input = "/%41%42%43"; // Encoded "ABC"
                expected = ?["%41%42%43"]; // Should preserve encoding
            },

            // Multiple dots (not navigation, just literal)
            {
                input = "/file...txt";
                expected = ?["file...txt"];
            },
            {
                input = "/...hidden/file";
                expected = ?["...hidden", "file"];
            },

            // Whitespace variations
            {
                input = "/path/ spaced /segment";
                expected = null;
            },
            {
                input = "/tab\tseparated/segments";
                expected = null;
            },

            // Colon in paths (common in URLs)
            {
                input = "/namespace:resource/type:value";
                expected = ?["namespace:resource", "type:value"];
            },

            // Plus signs (common in URLs, sometimes means space)
            {
                input = "/search/term+with+plus";
                expected = ?["search", "term+with+plus"]; // Preserve as literal
            },

            // Equals signs in path segments
            {
                input = "/key=value/param=data";
                expected = ?["key=value", "param=data"];
            },

            // Ampersand in path segments
            {
                input = "/company&co/brand&product";
                expected = ?["company&co", "brand&product"];
            },

            // At symbol in paths
            {
                input = "/user@domain/file@version";
                expected = ?["user@domain", "file@version"];
            },

            // Semicolon in paths
            {
                input = "/path;param=value/segment";
                expected = ?["path;param=value", "segment"];
            },

            // Comma in paths
            {
                input = "/list,of,items/data.csv";
                expected = ?["list,of,items", "data.csv"];
            },

            // Pipe symbol in paths
            {
                input = "/filter|option/value|pair";
                expected = ?["filter|option", "value|pair"];
            },

            // Backslash in paths (should be preserved, not treated as separator)
            {
                input = "/windows\\style/mixed\\slashes";
                expected = ?["windows\\style", "mixed\\slashes"];
            },

            // Single quote and double quote in paths
            {
                input = "/John's/file/\"quoted\"/segment";
                expected = ?["John's", "file", "\"quoted\"", "segment"];
            },
        ];

        label f for (testCase in testCases.vals()) {
            let result = switch (Path.fromText(testCase.input)) {
                case (#ok(parsed)) parsed;
                case (#err(errMsg)) {
                    if (testCase.expected != null) {
                        Debug.trap(formatError("Path.fromText error", testCase.input, "Expected success", debug_show (errMsg)));
                    };
                    continue f; // Valid
                };
            };

            switch (testCase.expected) {
                case (?expectedPath) {
                    if (result != expectedPath) {
                        Debug.trap(formatErrorArray("Path.fromText", testCase.input, expectedPath, result));
                    };
                };
                case (null) {
                    // This test structure expects all cases to succeed since Path.fromText doesn't fail
                    // If we wanted failure cases, we'd need a different function signature
                    Debug.trap("Test case error: null expected value not supported for Path.fromText");
                };
            };
        };
    },
);

// ===== toText TESTS =====

test(
    "Path.toText - converting paths to text",
    func() {
        let testCases : [PathToTextTestCase] = [
            // Basic cases (all treated as absolute by toText)
            {
                input = ["path", "to", "resource"];
                expected = "/path/to/resource"; // Assumes absolute
            },
            {
                input = ["single"];
                expected = "/single"; // Assumes absolute
            },

            // Empty case - the only one that doesn't get leading slash
            {
                input = [];
                expected = ""; // No leading slash for empty
            },

            // Complex paths (all treated as absolute)
            {
                input = ["api", "v1", "users", "123", "profile"];
                expected = "/api/v1/users/123/profile";
            },
            {
                input = ["documents", "2023", "reports", "quarterly.pdf"];
                expected = "/documents/2023/reports/quarterly.pdf";
            },

            // Special characters (all treated as absolute)
            {
                input = ["path", "with-dashes", "and_underscores"];
                expected = "/path/with-dashes/and_underscores";
            },
            {
                input = ["path", "with.dots", "file.ext"];
                expected = "/path/with.dots/file.ext";
            },
            {
                input = ["path", "with spaces", "in segments"];
                expected = "/path/with spaces/in segments";
            },

            // Encoded characters (preserved as-is, treated as absolute)
            {
                input = ["path", "with%20encoded", "characters%2F"];
                expected = "/path/with%20encoded/characters%2F";
            },
        ];

        for (testCase in testCases.vals()) {
            let result = Path.toText(testCase.input);

            if (result != testCase.expected) {
                Debug.trap(formatError("Path.toText", debug_show (testCase.input), testCase.expected, result));
            };
        };
    },
);
// ===== match TESTS =====

test(
    "Path.match - prefix matching",
    func() {
        let testCases : [PathMatchTestCase] = [
            // Exact matches
            {
                prefix = ["api", "v1"];
                path = ["api", "v1", "users", "123"];
                expected = ?["users", "123"];
            },
            {
                prefix = ["documents"];
                path = ["documents", "2023", "report.pdf"];
                expected = ?["2023", "report.pdf"];
            },

            // No remaining path
            {
                prefix = ["api", "v1", "users"];
                path = ["api", "v1", "users"];
                expected = ?[];
            },

            // No match cases
            {
                prefix = ["api", "v2"];
                path = ["api", "v1", "users"];
                expected = null;
            },
            {
                prefix = ["different"];
                path = ["api", "v1", "users"];
                expected = null;
            },
            {
                prefix = ["api", "v1", "users", "123", "extra"];
                path = ["api", "v1", "users", "123"];
                expected = null; // Prefix longer than path
            },

            // Empty cases
            {
                prefix = [];
                path = ["api", "v1", "users"];
                expected = ?["api", "v1", "users"];
            },
            {
                prefix = [];
                path = [];
                expected = ?[];
            },
            {
                prefix = ["something"];
                path = [];
                expected = null;
            },

            // Case sensitivity
            {
                prefix = ["API", "V1"];
                path = ["api", "v1", "users"];
                expected = null; // Should be case sensitive
            },
        ];

        for (testCase in testCases.vals()) {
            let result = Path.match(testCase.prefix, testCase.path);

            switch (testCase.expected, result) {
                case (?expectedMatch, ?actualMatch) {
                    if (expectedMatch != actualMatch) {
                        Debug.trap(
                            formatErrorArray(
                                "Path.match",
                                debug_show (testCase.prefix) # " vs " # debug_show (testCase.path),
                                expectedMatch,
                                actualMatch,
                            )
                        );
                    };
                };
                case (null, null) {
                    // Both null, correct
                };
                case (?_, null) {
                    Debug.trap(
                        formatErrorOptional(
                            "Path.match",
                            debug_show (testCase.prefix) # " vs " # debug_show (testCase.path),
                            true,
                            result,
                        )
                    );
                };
                case (null, ?_) {
                    Debug.trap(
                        formatErrorOptional(
                            "Path.match",
                            debug_show (testCase.prefix) # " vs " # debug_show (testCase.path),
                            false,
                            result,
                        )
                    );
                };
            };
        };
    },
);

// ===== join TESTS =====

test(
    "Path.join - adding single segment",
    func() {
        let testCases : [PathJoinTestCase] = [
            // Basic joins
            {
                path = ["api", "v1"];
                segment = "users";
                expected = ["api", "v1", "users"];
            },
            {
                path = ["documents"];
                segment = "report.pdf";
                expected = ["documents", "report.pdf"];
            },

            // Empty path
            {
                path = [];
                segment = "first";
                expected = ["first"];
            },

            // Special characters
            {
                path = ["path", "with spaces"];
                segment = "and-dashes_underscores.ext";
                expected = ["path", "with spaces", "and-dashes_underscores.ext"];
            },

            // Empty segment
            {
                path = ["existing", "path"];
                segment = "";
                expected = ["existing", "path", ""];
            },
        ];

        for (testCase in testCases.vals()) {
            let result = Path.join(testCase.path, testCase.segment);

            if (result != testCase.expected) {
                Debug.trap(
                    formatErrorArray(
                        "Path.join",
                        debug_show (testCase.path) # " + '" # testCase.segment # "'",
                        testCase.expected,
                        result,
                    )
                );
            };
        };
    },
);

// ===== joinMulti TESTS =====

test(
    "Path.joinMulti - adding multiple segments",
    func() {
        let testCases : [PathJoinMultiTestCase] = [
            // Basic joins
            {
                path = ["api"];
                segments = ["v1", "users", "123"];
                expected = ["api", "v1", "users", "123"];
            },
            {
                path = ["documents", "2023"];
                segments = ["reports", "quarterly.pdf"];
                expected = ["documents", "2023", "reports", "quarterly.pdf"];
            },

            // Empty path
            {
                path = [];
                segments = ["first", "second", "third"];
                expected = ["first", "second", "third"];
            },

            // Empty segments
            {
                path = ["existing"];
                segments = [];
                expected = ["existing"];
            },

            // Both empty
            {
                path = [];
                segments = [];
                expected = [];
            },

            // Mixed with empty segments
            {
                path = ["path"];
                segments = ["", "empty", "", "segments"];
                expected = ["path", "", "empty", "", "segments"];
            },
        ];

        for (testCase in testCases.vals()) {
            let result = Path.joinMulti(testCase.path, testCase.segments);

            if (result != testCase.expected) {
                Debug.trap(
                    formatErrorArray(
                        "Path.joinMulti",
                        debug_show (testCase.path) # " + " # debug_show (testCase.segments),
                        testCase.expected,
                        result,
                    )
                );
            };
        };
    },
);

// ===== normalize TESTS =====

test(
    "Path.normalize - normalizing paths",
    func() {
        let testCases : [PathNormalizeTestCase] = [
            // Basic normalization (case conversion)
            {
                input = ["API", "V1", "Users"];
                expected = ["api", "v1", "users"];
            },
            {
                input = ["Documents", "2023", "REPORTS"];
                expected = ["documents", "2023", "reports"];
            },

            // Remove empty segments
            {
                input = ["path", "", "with", "", "empty"];
                expected = ["path", "with", "empty"];
            },
            {
                input = ["", "leading", "empty"];
                expected = ["leading", "empty"];
            },
            {
                input = ["trailing", "empty", ""];
                expected = ["trailing", "empty"];
            },

            // Mixed case and empty segments
            {
                input = ["API", "", "V1", "", "USERS"];
                expected = ["api", "v1", "users"];
            },

            // All empty segments
            {
                input = ["", "", ""];
                expected = [];
            },

            // Already normalized
            {
                input = ["already", "normalized", "path"];
                expected = ["already", "normalized", "path"];
            },

            // Empty input
            {
                input = [];
                expected = [];
            },

            // Special characters (preserved)
            {
                input = ["Path", "With-DASHES", "And_UNDERSCORES.EXT"];
                expected = ["path", "with-dashes", "and_underscores.ext"];
            },
        ];

        for (testCase in testCases.vals()) {
            let result = Path.normalize(testCase.input);

            if (result != testCase.expected) {
                Debug.trap(
                    formatErrorArray(
                        "Path.normalize",
                        debug_show (testCase.input),
                        testCase.expected,
                        result,
                    )
                );
            };
        };
    },
);

// ===== equal TESTS =====

test(
    "Path.equal - path equality",
    func() {
        let testCases : [PathEqualTestCase] = [
            // Equal cases
            {
                path1 = ["api", "v1", "users"];
                path2 = ["api", "v1", "users"];
                expected = true;
            },
            {
                path1 = [];
                path2 = [];
                expected = true;
            },
            {
                path1 = ["single"];
                path2 = ["single"];
                expected = true;
            },

            // Different cases
            {
                path1 = ["api", "v1", "users"];
                path2 = ["api", "v2", "users"];
                expected = false;
            },
            {
                path1 = ["api", "v1"];
                path2 = ["api", "v1", "users"];
                expected = false;
            },
            {
                path1 = ["api", "v1", "users"];
                path2 = ["api", "v1"];
                expected = false;
            },

            // Case sensitivity
            {
                path1 = ["API", "V1", "Users"];
                path2 = ["api", "v1", "users"];
                expected = false;
            },

            // Empty vs non-empty
            {
                path1 = [];
                path2 = ["something"];
                expected = false;
            },
            {
                path1 = ["something"];
                path2 = [];
                expected = false;
            },

            // With empty segments
            {
                path1 = ["path", "", "with", "empty"];
                path2 = ["path", "", "with", "empty"];
                expected = true;
            },
            {
                path1 = ["path", "", "with"];
                path2 = ["path", "with"];
                expected = false;
            },
        ];

        for (testCase in testCases.vals()) {
            let result = Path.equal(testCase.path1, testCase.path2);

            if (result != testCase.expected) {
                let expectedText = if (testCase.expected) "true" else "false";
                let actualText = if (result) "true" else "false";
                Debug.trap(
                    formatError(
                        "Path.equal",
                        debug_show (testCase.path1) # " vs " # debug_show (testCase.path2),
                        expectedText,
                        actualText,
                    )
                );
            };
        };
    },
);

// ===== ROUNDTRIP TESTS =====

test(
    "Path roundtrip - fromText -> toText consistency",
    func() {
        let testCases = [
            ("/api/v1/users/123", "/api/v1/users/123"), // Perfect roundtrip
            ("/documents/2023/reports/quarterly.pdf", "/documents/2023/reports/quarterly.pdf"), // Perfect roundtrip
            ("/path/with-dashes/and_underscores", "/path/with-dashes/and_underscores"), // Perfect roundtrip
            ("/path/with.dots/file.ext", "/path/with.dots/file.ext"), // Perfect roundtrip
            ("relative/path/to/resource", "/relative/path/to/resource"), // Becomes absolute!
            ("/single", "/single"), // Perfect roundtrip
            ("", ""), // Empty stays empty
            ("/", ""), // ROOT BECOMES EMPTY
        ];

        for ((input, expectedOutput) in testCases.vals()) {
            let parsed = switch (Path.fromText(input)) {
                case (#ok(segments)) segments;
                case (#err(error)) {
                    Debug.trap(
                        formatError("Path.fromText error", input, "Expected success", debug_show (error))
                    );
                };
            };
            let reconstructed = Path.toText(parsed);

            if (reconstructed != expectedOutput) {
                Debug.trap(
                    formatError(
                        "Path roundtrip",
                        input,
                        expectedOutput,
                        reconstructed,
                    )
                );
            };
        };
    },
);
