import Result "mo:core@1/Result";
import Array "mo:core@1/Array";
import Text "mo:core@1/Text";
import Iter "mo:core@1/Iter";
import Nat "mo:core@1/Nat";
import Char "mo:core@1/Char";
import TextX "mo:xtended-text@2/TextX";
import Map "mo:core@1/Map";
import Runtime "mo:core@1/Runtime";

module {
  public type Domain = {
    name : Text;
    suffix : Text;
    subdomains : [Text];
  };

  public type DomainParser = {
    parse : (domain : Text) -> Result.Result<Domain, Text>;
  };

  public type SuffixEntry = {
    isTerminal : Bool; // Can end here
    childRule : SuffixChildRule;
  };

  public type SuffixChildRule = {
    #none;
    #specific : Map.Map<Text, SuffixEntry>; // Possible sub-suffixes
    #wildcardWithExceptions : [Text]; // Exceptions for wildcard
  };

  /// Parses a domain string into a Domain structure using a custom suffix list.
  /// This allows using a different set of known suffixes than the default.
  /// For all known domain suffixes, use `DomainParser` module.
  ///
  /// ```motoko
  /// let customSuffixes = ["test", "internal.test"];
  /// let domain = Domain.fromTextWithSuffixes("example.test", customSuffixes);
  /// // domain is #ok({ name = "example"; suffix = "test"; subdomains = [] })
  /// ```
  public func fromText(domain : Text, suffixes : [Text]) : Result.Result<Domain, Text> {
    let customSuffixMap = buildSuffixMap(suffixes);
    fromTextAdvanced(domain, customSuffixMap);
  };

  public func fromTextAdvanced(
    domain : Text,
    suffixes : Map.Map<Text, SuffixEntry>,
  ) : Result.Result<Domain, Text> {
    let parts = Text.split(domain, #text("."));
    let partsArray = Iter.toArray(parts);

    if (partsArray.size() < 2) return #err("Must have at least name and suffix");

    // Validate each part
    for (part in partsArray.vals()) {
      if (part.size() == 0) return #err("Contains empty label");
      if (part.size() > 63) return #err("Contains label longer than 63 characters");
    };

    // Normalize to lowercase once
    let normalizedParts = Array.map<Text, Text>(partsArray, Text.toLower);

    // Traverse the tree from TLD backwards, tracking only the length
    var currentEntries = suffixes;
    var longestSuffixLength = 0;
    var currentLength = 0;

    // Iterate backwards through parts (from TLD to subdomain)
    let partsSize = normalizedParts.size();
    var i = partsSize;

    label w while (i > 0) {
      i -= 1;
      let part = normalizedParts[i];

      switch (Map.get(currentEntries, Text.compare, part)) {
        case (?entry) {
          currentLength += 1;

          switch (entry.childRule) {
            case (#none) ();
            case (#specific(childMap)) {
              currentEntries := childMap;
            };
            case (#wildcardWithExceptions(exceptions)) {
              if (i >= 1) {
                // Check if next part is an exception
                switch (Array.indexOf(exceptions, Text.equal, normalizedParts[i - 1])) {
                  case (null) {
                    longestSuffixLength += i; // Can match any wildcard part
                  };
                  case (?_) (); // Exception matched, stop here
                };
                break w;
              };
            };
          };
          // If this entry is terminal, update longest suffix length
          if (entry.isTerminal) {
            longestSuffixLength := currentLength;
          };

          // Continue traversing to children
        };
        case (null) {
          // Part not found in tree, stop traversing
          break w;
        };
      };
    };

    if (longestSuffixLength == 0) return #err("Unrecognized suffix for '" # domain # "'");

    // Ensure we have at least one part left for the domain name
    if (partsArray.size() <= longestSuffixLength) {
      return #err("Domain must have a name part before the suffix");
    };

    // Build suffix string only once at the end
    let suffixStartIndex : Nat = partsArray.size() - longestSuffixLength;
    let suffixParts = Array.sliceToArray(partsArray, suffixStartIndex, suffixStartIndex + longestSuffixLength);
    let suffix = Text.join(".", suffixParts.vals());

    let name = partsArray[partsArray.size() - longestSuffixLength - 1];
    let subdomains = if (partsArray.size() > longestSuffixLength + 1) {
      Array.sliceToArray(partsArray, 0, partsArray.size() - longestSuffixLength - 1 : Nat);
    } else {
      [];
    };
    let d : Domain = {
      name = name;
      suffix = suffix;
      subdomains = subdomains;
    };
    switch (validate(d)) {
      case (#err(err)) #err(err);
      case (#ok) #ok(d);
    };
  };

  public func buildSuffixMap(suffixes : [Text]) : Map.Map<Text, SuffixEntry> {
    let customSuffixMap = Map.empty<Text, SuffixEntry>();
    for (suffix in suffixes.vals()) {
      addToSuffixMap(suffix, customSuffixMap);
    };
    customSuffixMap;
  };

  private func addToSuffixMap(suffix : Text, map : Map.Map<Text, SuffixEntry>) {
    let (suffixPrefixOrNull, suffixSuffix) = splitOnLastDot(suffix);
    let isLast = suffixPrefixOrNull == null;

    let newOrUpdatedEntry = switch (Map.get(map, Text.compare, suffixSuffix)) {
      case (?existing) {
        switch (suffixPrefixOrNull) {
          case (?suffixPrefix) {
            let childRule = buildChildRule(suffixPrefix, ?existing.childRule);
            {
              existing with
              childRule = childRule;
            };
          };
          case (null) {
            // Update terminal status if this is the complete suffix
            {
              existing with
              isTerminal = true;
            };
          };
        };
      };
      case (null) {
        let childRule = switch (suffixPrefixOrNull) {
          case (?suffixPrefix) buildChildRule(suffixPrefix, null);
          case (null) #none;
        };
        {
          isTerminal = isLast;
          childRule = childRule;
        };
      };
    };
    Map.add(
      map,
      Text.compare,
      suffixSuffix,
      newOrUpdatedEntry,
    );
  };

  func buildChildRule(suffixPrefix : Text, existingChildRule : ?SuffixChildRule) : SuffixChildRule {
    if (suffixPrefix == "*") {
      return #wildcardWithExceptions([]);
    };
    if (not Text.contains(suffixPrefix, #char('.')) and Text.startsWith(suffixPrefix, #text("!"))) {
      // Prefix is an exception for a wildcard suffix
      let ?realSuffixPrefix = Text.stripStart(suffixPrefix, #text("!")) else Runtime.unreachable();

      let exceptions = switch (existingChildRule) {
        case (?#wildcardWithExceptions(exceptions)) Array.concat(exceptions, [realSuffixPrefix]);
        case (_) Runtime.trap("Cannot add exception to non-wildcard suffix");
      };
      // Update entry with new exception
      #wildcardWithExceptions(exceptions);
    } else {
      // Regular prefix, add/update child entry
      let childMap = switch (existingChildRule) {
        case (null or ?#none) Map.empty<Text, SuffixEntry>(); // Create new child map
        case (?#specific(childMap)) childMap; // Use existing child map
        case (?#wildcardWithExceptions(_)) Runtime.trap("Cannot add more specific suffixes under a wildcard");
      };
      addToSuffixMap(suffixPrefix, childMap); // Update child map
      #specific(childMap);
    };
  };

  func splitOnLastDot(value : Text) : (?Text, Text) {
    let chars = value.chars();
    var lastDotPos : ?Nat = null;
    var pos : Nat = 0;

    for (c in chars) {
      if (c == '.') {
        lastDotPos := ?pos;
      };
      pos += 1;
    };

    switch (lastDotPos) {
      case null (null, value);
      case (?dotPos) {
        let prefix = Text.fromIter(value.chars() |> Iter.take(_, dotPos));
        let suffix = Text.fromIter(value.chars() |> Iter.drop(_, dotPos + 1));
        (?prefix, suffix);
      };
    };
  };

  /// Converts a Domain structure back to its text representation.
  ///
  /// ```motoko
  /// let domain = { name = "example"; suffix = "com"; subdomains = ["www", "blog"] };
  /// let domainText = Domain.toText(domain);
  /// // domainText is "www.blog.example.com"
  /// ```
  public func toText(domain : Domain) : Text {
    let all = Array.concat(domain.subdomains, [domain.name, domain.suffix]);
    Text.join(".", all.vals());
  };

  /// Normalizes a domain by converting all parts to lowercase.
  ///
  /// ```motoko
  /// let domain = { name = "EXAMPLE"; suffix = "COM"; subdomains = ["WWW"] };
  /// let normalized = Domain.normalize(domain);
  /// // normalized is { name = "example"; suffix = "com"; subdomains = ["www"] }
  /// ```
  public func normalize(domain : Domain) : Domain {
    {
      name = Text.toLower(domain.name);
      suffix = Text.toLower(domain.suffix);
      subdomains = Array.map(domain.subdomains, Text.toLower);
    };
  };

  /// Validates a Domain structure according to RFC domain name rules.
  /// Checks label lengths, character validity, and overall domain constraints.
  ///
  /// ```motoko
  /// let validDomain = { name = "example"; suffix = "com"; subdomains = ["www"] };
  /// let result = Domain.validate(validDomain);
  /// // result is #ok(())
  ///
  /// let invalidDomain = { name = "-example"; suffix = "com"; subdomains = [] };
  /// let result2 = Domain.validate(invalidDomain);
  /// // result2 is #err("domain name cannot start or end with hyphen")
  /// ```
  public func validate(domain : Domain) : Result.Result<(), Text> {
    // Helper function to validate a single label (subdomain part, name, or suffix part)
    func validateLabel(label_ : Text, labelType : Text) : Result.Result<(), Text> {
      if (TextX.isEmptyOrWhitespace(label_)) {
        return #err(labelType # " cannot be empty");
      };

      if (label_.size() > 63) {
        return #err(labelType # " too long: maximum 63 characters, got " # Nat.toText(label_.size()));
      };

      // Check for valid domain characters
      for (char in label_.chars()) {
        if (not isValidLabelChar(char)) {
          return #err("Invalid character in " # labelType # ": " # Char.toText(char));
        };
      };

      // Cannot start or end with hyphen
      if (Text.startsWith(label_, #char('-')) or Text.endsWith(label_, #char('-'))) {
        return #err(labelType # " cannot start or end with hyphen");
      };

      #ok(());
    };

    // Validate domain name
    switch (validateLabel(domain.name, "domain name")) {
      case (#err(err)) return #err(err);
      case (#ok) {};
    };

    // Validate suffix (split by dots and validate each part)
    if (TextX.isEmptyOrWhitespace(domain.suffix)) {
      return #err("Domain suffix cannot be empty");
    };

    let suffixParts = Text.split(domain.suffix, #text("."));
    let suffixPartsArray = Iter.toArray(suffixParts);

    for (i in suffixPartsArray.keys()) {
      let part = suffixPartsArray[i];
      switch (validateLabel(part, "suffix part")) {
        case (#err(err)) return #err(err);
        case (#ok) {};
      };
    };

    // Validate subdomains
    for (i in domain.subdomains.keys()) {
      let subdomain = domain.subdomains[i];
      switch (validateLabel(subdomain, "subdomain")) {
        case (#err(err)) return #err(err);
        case (#ok) {};
      };
    };

    // Check total length constraints
    // Calculate total length including dots
    var totalLength = domain.name.size() + domain.suffix.size() + 1; // +1 for dot between name and suffix

    // Add subdomain lengths and dots
    for (subdomain in domain.subdomains.vals()) {
      totalLength += subdomain.size() + 1; // +1 for dot after each subdomain
    };

    if (totalLength > 253) {
      return #err("Domain too long: maximum 253 characters, got " # Nat.toText(totalLength));
    };

    // Additional checks for the complete domain
    let fullDomain = toText(domain);

    // Check for consecutive dots (shouldn't happen with proper parsing, but good to verify)
    if (Text.contains(fullDomain, #text(".."))) {
      return #err("Domain cannot contain consecutive dots");
    };

    // Check that domain doesn't start or end with dot
    if (Text.startsWith(fullDomain, #char('.')) or Text.endsWith(fullDomain, #char('.'))) {
      return #err("Domain cannot start or end with dot");
    };

    #ok(());
  };

  // Updated character validation - more restrictive for labels (no dots allowed in individual labels)
  private func isValidLabelChar(char : Char) : Bool {
    let code = Char.toNat32(char);
    // Letters, digits, hyphens only (no dots in individual labels)
    (code >= 97 and code <= 122) or // a-z
    (code >= 65 and code <= 90) or // A-Z
    (code >= 48 and code <= 57) or // 0-9
    code == 45; // hyphen only
  };
};
