import Text "mo:core@1/Text";
import { test } "mo:test";
import ComprehensiveDomainParser "../src/ComprehensiveDomainParser";
import Map "mo:core@1/Map";
import Domain "../src/Domain";
import Runtime "mo:core@1/Runtime";
import Iter "mo:core@1/Iter";
import Order "mo:core@1/Order";
import Array "mo:core@1/Array";

test(
  "decompressData produces correct Map",
  func() {
    type TestCase = {
      compressed : Text;
      expected : [Entry];
    };
    type Entry = {
      id : Text;
      isTerminal : Bool;
      childRule : ChildRule;
    };
    type ChildRule = {
      #none;
      #specific : [Entry];
      #wildcardWithExceptions : [Text];
    };
    let testCases : [TestCase] = [
      {
        compressed = "aaa|aarp|addd";
        expected = [
          { id = "aaa"; isTerminal = true; childRule = #none },
          { id = "aarp"; isTerminal = true; childRule = #none },
          { id = "addd"; isTerminal = true; childRule = #none },
        ];
      },
      {
        compressed = "ac!>com,drr,edu,feedback*,forms^,gov*www,mil^aaa,net,org";
        expected = [
          {
            id = "ac";
            isTerminal = true;
            childRule = #specific([
              { id = "com"; isTerminal = true; childRule = #none },
              { id = "drr"; isTerminal = true; childRule = #none },
              { id = "edu"; isTerminal = true; childRule = #none },
              {
                id = "feedback";
                isTerminal = false;
                childRule = #wildcardWithExceptions([]);
              },
              {
                id = "forms";
                isTerminal = true;
                childRule = #wildcardWithExceptions([]);
              },
              {
                id = "gov";
                isTerminal = false;
                childRule = #wildcardWithExceptions(["www"]);
              },
              {
                id = "mil";
                isTerminal = true;
                childRule = #wildcardWithExceptions(["aaa"]);
              },
              { id = "net"; isTerminal = true; childRule = #none },
              { id = "org"; isTerminal = true; childRule = #none },
            ]);
          },
        ];
      },
      {
        compressed = "a!>b>c!>(d>e!>(f*www,aaa),z),1";
        expected = [{
          id = "a";
          isTerminal = true;
          childRule = #specific([
            {
              id = "b";
              isTerminal = false;
              childRule = #specific([
                {
                  id = "c";
                  isTerminal = true;
                  childRule = #specific([
                    {
                      id = "d";
                      isTerminal = false;
                      childRule = #specific([
                        {
                          id = "e";
                          isTerminal = true;
                          childRule = #specific([
                            {
                              id = "f";
                              isTerminal = false;
                              childRule = #wildcardWithExceptions(["www", "aaa"]);
                            },
                            {
                              id = "z";
                              isTerminal = true;
                              childRule = #none;
                            },
                          ]);
                        },
                      ]);
                    },
                    {
                      id = "1";
                      isTerminal = true;
                      childRule = #none;
                    },
                  ]);
                },
              ]);
            },
          ]);
        }];
      },
    ];

    func compareChildRulesRecursively(expected : ChildRule, actual : ChildRule, path : Text) : ?Text {
      switch (expected, actual) {
        case (#none, #none) null;
        case (#specific(expEntries), #specific(actEntries)) {
          compareEntriesRecursively(expEntries, actEntries, path);
        };
        case (#wildcardWithExceptions(expEx), #wildcardWithExceptions(actEx)) {

          if (expEx != actEx) {
            return ?(
              "Mismatched wildcard exceptions at path " # path #
              ": expected " # debug_show (expEx) #
              ", got " # debug_show (actEx)
            );
          };
          null;
        };
        case (_) return ?("Mismatched child rule types at path " # path);
      };
    };

    func compareEntriesRecursively(expected : [Entry], actual : [Entry], path : Text) : ?Text {
      // Convert to maps for easier lookup
      let expectedMap = Map.empty<Text, Entry>();
      let actualMap = Map.empty<Text, Entry>();

      for (entry in expected.vals()) {
        Map.add(expectedMap, Text.compare, entry.id, entry);
      };

      for (entry in actual.vals()) {
        Map.add(actualMap, Text.compare, entry.id, entry);
      };

      // Check for missing entries
      for (expectedEntry in expected.vals()) {
        let currentPath = if (path == "") expectedEntry.id else path # "." # expectedEntry.id;
        switch (Map.get(actualMap, Text.compare, expectedEntry.id)) {
          case (null) {
            return ?("Missing entry at path: " # currentPath # " map keys: " # debug_show (Map.keys(actualMap) |> Iter.toArray(_)));
          };
          case (?actualEntry) {
            // Check isTerminal
            if (expectedEntry.isTerminal != actualEntry.isTerminal) {
              return ?(
                "Mismatched isTerminal at path " # currentPath #
                ": expected " # debug_show (expectedEntry.isTerminal) #
                ", got " # debug_show (actualEntry.isTerminal)
              );
            };

            // Recursively check children
            switch (compareChildRulesRecursively(expectedEntry.childRule, actualEntry.childRule, currentPath)) {
              case (?error) { return ?error };
              case (null) {};
            };
          };
        };
      };

      // Check for extra entries
      for (actualEntry in actual.vals()) {
        let currentPath = if (path == "") actualEntry.id else path # "." # actualEntry.id;

        switch (Map.get(expectedMap, Text.compare, actualEntry.id)) {
          case (null) {
            return ?("Extra entry at path: " # currentPath);
          };
          case (?_) {};
        };
      };

      null;
    };

    for (testCase in testCases.vals()) {
      let actual = ComprehensiveDomainParser.decompressData(testCase.compressed);

      func mapMapToEntries(map : Map.Map<Text, Domain.SuffixEntry>) : [Entry] {
        map
        |> Map.entries(_)
        |> Iter.map(
          _,
          func((id, entry) : (Text, Domain.SuffixEntry)) : Entry {
            let childRule = switch (entry.childRule) {
              case (#none) #none;
              case (#specific(children)) #specific(mapMapToEntries(children));
              case (#wildcardWithExceptions(ex)) #wildcardWithExceptions(ex);
            };
            {
              id = id;
              isTerminal = entry.isTerminal;
              childRule = childRule;
            };
          },
        )
        |> Iter.toArray(_);
      };

      let actualArray = mapMapToEntries(actual);
      let expectedArray = Array.sort(
        testCase.expected,
        func(a : Entry, b : Entry) : Order.Order {
          Text.compare(a.id, b.id);
        },
      );

      // Use recursive comparison
      switch (compareEntriesRecursively(expectedArray, actualArray, "")) {
        case (?error) {
          Runtime.trap(
            "Test failed: " # error #
            "\nTotal expected: " # debug_show (expectedArray.size()) #
            ", Total actual: " # debug_show (actualArray.size())
          );
        };
        case (null) {};
      };
    };
  },
);
