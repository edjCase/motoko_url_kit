import Text "mo:core@1/Text";
import { test } "mo:test";
import Runtime "mo:core@1/Runtime";
import Domain "../src/Domain";
import Map "mo:core@1/Map";
import Iter "mo:core@1/Iter";
import ComprehensiveDomainParser "../src/ComprehensiveDomainParser";

// ===== HOST PARSING TESTS =====

test(
  "Domain.fromText",
  func() {

    let suffixes = Domain.buildSuffixMap([
      "com",
      "org",
      "net",
      "co.uk",
      "github.io",
      "*.mydomain.com",
    ]);

    let testCases : [{
      input : Text;
      expected : Domain.Domain;
    }] = [
      {
        input = "example.com";
        expected = {
          name = "example";
          suffix = "com";
          subdomains = [];
        };
      },
      {
        input = "www.example.com";
        expected = {
          name = "example";
          suffix = "com";
          subdomains = ["www"];
        };
      },
      {
        input = "james.github.io";
        expected = {
          name = "james";
          suffix = "github.io";
          subdomains = [];
        };
      },
      {
        input = "james.mydomain.com";
        expected = {
          name = "james";
          suffix = "mydomain.com";
          subdomains = [];
        };
      },
    ];

    type DebugSuffixEntry = {
      isTerminal : Bool;
      childRule : DebugChildRule;
    };
    type DebugChildRule = {
      #none;
      #specific : [(Text, DebugSuffixEntry)];
      #wildcardWithExceptions : [Text];
    };
    func mapSuffixesToDebug(
      suffixes : Map.Map<Text, Domain.SuffixEntry>
    ) : [(Text, DebugSuffixEntry)] {
      suffixes
      |> Map.entries(_)
      |> Iter.map<(Text, Domain.SuffixEntry), (Text, DebugSuffixEntry)>(
        _,
        func((key, value) : (Text, Domain.SuffixEntry)) : (Text, DebugSuffixEntry) {
          let childRule : DebugChildRule = switch (value.childRule) {
            case (#specific(childMap)) #specific(mapSuffixesToDebug(childMap));
            case (#wildcardWithExceptions(exceptions)) #wildcardWithExceptions(exceptions);
            case (#none) #none;
          };
          (
            key,
            {
              isTerminal = value.isTerminal;
              childRule = childRule;
            },
          );
        },
      ) |> Iter.toArray(_);
    };
    for (testCase in testCases.vals()) {
      switch (Domain.fromTextAdvanced(testCase.input, suffixes)) {
        case (#ok(domain)) {
          if (domain != testCase.expected) {
            Runtime.trap(
              "Test failed for input: " # testCase.input # "\n" #
              "Expected: " # debug_show (testCase.expected) # "\n" #
              "Actual:   " # debug_show (domain) # "\n" #
              "Suffixes: " # debug_show (mapSuffixesToDebug(suffixes))
            );
          };
        };
        case (#err(msg)) {
          Runtime.trap("Failed to parse domain " # testCase.input # ": " # msg);
        };
      };
    };
  },
);

test(
  "ComprehensiveDomainParser.parse",
  func() {

    let comprehensiveDomainParser = ComprehensiveDomainParser.ComprehensiveDomainParser();

    let testCases : [{
      input : Text;
      expected : Domain.Domain;
    }] = [
      {
        input = "google.com";
        expected = {
          name = "google";
          suffix = "com";
          subdomains = [];
        };
      },
      {
        input = "www.google.com";
        expected = {
          name = "google";
          suffix = "com";
          subdomains = ["www"];
        };
      },
      {
        input = "james.github.io";
        expected = {
          name = "james";
          suffix = "github.io";
          subdomains = [];
        };
      },
    ];

    for (testCase in testCases.vals()) {
      switch (comprehensiveDomainParser.parse(testCase.input)) {
        case (#ok(domain)) {
          if (domain != testCase.expected) {
            Runtime.trap(
              "Test failed for input: " # testCase.input # "\n" #
              "Expected: " # debug_show (testCase.expected) # "\n" #
              "Actual:   " # debug_show (domain)
            );
          };
        };
        case (#err(msg)) {
          Runtime.trap("Failed to parse domain " # testCase.input # ": " # msg);
        };
      };
    };
  },
);
