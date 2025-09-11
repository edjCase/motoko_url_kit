import DomainSuffixData "./data/DomainSuffixData";
import Map "mo:core@1/Map";
import Domain "Domain";
import Result "mo:core@1/Result";
import Text "mo:core@1/Text";
import Iter "mo:core@1/Iter";
import Runtime "mo:core@1/Runtime";
import Array "mo:core@1/Array";
import Char "mo:core@1/Char";
import List "mo:core@1/List";

module {

  public class ComprehensiveDomainParser() : Domain.DomainParser {
    var decompressedSuffixes : ?Map.Map<Text, Domain.SuffixEntry> = null;

    public func parse(domain : Text) : Result.Result<Domain.Domain, Text> {
      let suffixes = switch (decompressedSuffixes) {
        case (null) {
          let decompressed = decompressData(DomainSuffixData.value);
          decompressedSuffixes := ?decompressed;
          decompressed;
        };
        case (?s) s;
      };
      Domain.fromTextAdvanced(domain, suffixes);
    };

  };

  public func decompressData(compressed : Text) : Map.Map<Text, Domain.SuffixEntry> {
    let entries = Map.empty<Text, Domain.SuffixEntry>();

    // Split by | to get top-level segments
    let topLevelParts = Text.split(compressed, #char('|'));

    for (part in topLevelParts) {
      let (id, entry) = parseSegment(part);
      Map.add(entries, Text.compare, id, entry);
    };

    entries;
  };
  private func parseSegment(segment : Text) : (Text, Domain.SuffixEntry) {
    if (Text.contains(segment, #char('>'))) {
      // Find first > not inside parentheses
      let ?{ before = parentPart; after = childrenPart } = splitOnFirstTopLevelChar(segment, '>') else Runtime.trap("Invalid compressed format: " # segment);

      // Check if parent is terminal
      let (parentName, isParentTerminal) = switch (Text.stripEnd(parentPart, #char('!'))) {
        case (null) (parentPart, false);
        case (?terminalSegment) (terminalSegment, true);
      };

      // Check if childrenPart is a chain (contains > outside parens) or just children
      if (containsTopLevelChar(childrenPart, '>')) {
        // It's a chain: parse as a single child that itself has children
        let (childId, childEntry) = parseSegment(childrenPart);
        let childMap = Map.empty<Text, Domain.SuffixEntry>();
        Map.add(childMap, Text.compare, childId, childEntry);

        (
          parentName,
          {
            isTerminal = isParentTerminal;
            childRule = #specific(childMap);
          },
        );
      } else {
        // It's direct children (possibly multiple)
        let childRule = parseChildRule(childrenPart);
        (
          parentName,
          {
            isTerminal = isParentTerminal;
            childRule = childRule;
          },
        );
      };
    } else {
      func parseExceptions(splitChar : Char) : (Text, [Text]) {
        let parts = Text.split(segment, #char(splitChar));
        let ?segmentName = parts.next() else Runtime.trap("Invalid wildcard/exception format: " # segment);
        let ?exceptionsText = parts.next() else Runtime.trap("Invalid wildcard/exception format: " # segment);

        (segmentName, Text.split(exceptionsText, #char(',')) |> Iter.toArray(_));
      };
      let (segmentName, isTerminal, childRule) = if (Text.contains(segment, #char('^'))) {
        let (segmentName, exceptions) = parseExceptions('^');
        (segmentName, true, #wildcardWithExceptions(exceptions));
      } else if (Text.contains(segment, #char('*'))) {
        let (segmentName, exceptions) = parseExceptions('*');
        (segmentName, false, #wildcardWithExceptions(exceptions));
      } else {
        (segment, true, #none);
      };
      (
        segmentName,
        {
          isTerminal = isTerminal;
          childRule = childRule;
        },
      );
    };
  };

  // Helper function to check if a character exists at top level (outside parentheses)
  private func containsTopLevelChar(text : Text, char : Char) : Bool {
    let chars = Text.toArray(text);
    var parenDepth = 0;

    for (c in chars.vals()) {
      switch (c) {
        case ('(') parenDepth += 1;
        case (')') parenDepth -= 1;
        case (_) {
          if (c == char and parenDepth == 0) {
            return true;
          };
        };
      };
    };
    false;
  };

  private func splitOnFirstTopLevelChar(text : Text, char : Char) : ?{
    before : Text;
    after : Text;
  } {
    let chars = Text.toArray(text);
    var parenDepth = 0;
    var index = 0;

    for (c in chars.vals()) {
      switch (c) {
        case ('(') {
          parenDepth += 1;
        };
        case (')') {
          parenDepth -= 1;
        };
        case (_) {
          if (c == char and parenDepth == 0) {
            let before = Text.fromArray(Array.sliceToArray(chars, 0, index));
            let after = Text.fromArray(Array.sliceToArray(chars, index + 1, chars.size()));
            return ?{ before = before; after = after };
          };
        };
      };
      index += 1;
    };

    null;
  };

  private func parseChildRule(childrenText : Text) : Domain.SuffixChildRule {
    let children = splitChildren(childrenText);
    if (List.isEmpty(children)) {
      return #none;
    };

    if (List.at(children, 0) == "*") {
      let exceptions = List.empty<Text>();
      for (exception in Iter.drop(List.values(children), 1)) {
        switch (Text.stripStart(exception, #char('!'))) {
          case (null) Runtime.trap("Invalid exception format: " # exception);
          case (?cleaned) List.add(exceptions, cleaned);
        };
      };
      return #wildcardWithExceptions(List.toArray(exceptions));
    };

    let map = Map.empty<Text, Domain.SuffixEntry>();

    for (child in List.values(children)) {

      // Remove parentheses if present
      let cleanChild = if (Text.startsWith(child, #char('(')) and Text.endsWith(child, #char(')'))) {
        let ?withoutStart = Text.stripStart(child, #char('(')) else Runtime.unreachable();
        let ?withoutStartAndEnd = Text.stripEnd(withoutStart, #char(')')) else Runtime.unreachable();
        withoutStartAndEnd;
      } else {
        child;
      };

      let (childId, childEntry) = parseSegment(cleanChild);
      Map.add(map, Text.compare, childId, childEntry);
    };
    #specific(map);
  };

  private func splitChildren(text : Text) : List.List<Text> {
    let chars = Text.toArray(text);
    let result = List.empty<Text>();
    var current = "";
    var parenDepth = 0;

    for (char in chars.vals()) {
      switch (char) {
        case ('(') {
          parenDepth += 1;
          current #= Char.toText(char);
        };
        case (')') {
          parenDepth -= 1;
          current #= Char.toText(char);
        };
        case (',') {
          if (parenDepth == 0) {
            if (current != "") {
              List.add(result, current);
              current := "";
            };
          } else {
            current #= Char.toText(char);
          };
        };
        case (_) {
          current #= Char.toText(char);
        };
      };
    };

    if (current != "") {
      List.add(result, current);
    };

    result;
  };
};
