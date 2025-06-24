import Result "mo:new-base/Result";
import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Nat "mo:new-base/Nat";
import DomainSuffixList "./data/DomainSuffixList";

module {
    public type Domain = {
        name : Text;
        suffix : Text;
        subdomains : [Text];
    };

    public func fromText(domain : Text) : Result.Result<Domain, Text> {
        fromTextWithSuffixes(domain, DomainSuffixList.value);
    };

    public func fromTextWithSuffixes(domain : Text, suffixes : [DomainSuffixList.SuffixEntry]) : Result.Result<Domain, Text> {
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

        // Helper function to find a suffix entry by id (case-insensitive)
        func findSuffixEntry(entries : [DomainSuffixList.SuffixEntry], targetId : Text) : ?DomainSuffixList.SuffixEntry {
            Array.find<DomainSuffixList.SuffixEntry>(entries, func(entry) = Text.toLower(entry.id) == targetId);
        };

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

            switch (findSuffixEntry(currentEntries, part)) {
                case (?entry) {
                    currentLength += 1;

                    // If this entry is terminal, update longest suffix length
                    if (entry.isTerminal) {
                        longestSuffixLength := currentLength;
                    };

                    // Continue traversing to children
                    currentEntries := entry.children;
                };
                case null {
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

        #ok({
            name = name;
            suffix = suffix;
            subdomains = subdomains;
        });
    };

    public func toText(domain : Domain) : Text {
        let all = Array.concat(domain.subdomains, [domain.name, domain.suffix]);
        Text.join(".", all.vals());
    };

    public func normalize(domain : Domain) : Domain {
        {
            name = Text.toLower(domain.name);
            suffix = Text.toLower(domain.suffix);
            subdomains = Array.map(domain.subdomains, Text.toLower);
        };
    };

    // TODO validate
    // public func isValid(domain : Text) : Bool {
    //     switch (validate(domain)) {
    //         case (#ok(_)) true;
    //         case (#err(_)) false;
    //     };
    // };

    // public func validate(domain : Domain) : Result.Result<(), Text> {
    //     if (domain == "") {
    //         return #err("Domain cannot be empty");
    //     };

    //     if (domain.size() > 253) {
    //         return #err("Domain too long: maximum 253 characters");
    //     };

    //     // Check for valid domain characters
    //     for (char in domain.chars()) {
    //         if (not isValidDomainChar(char)) {
    //             return #err("Invalid character in domain: " # Char.toText(char));
    //         };
    //     };

    //     // Cannot start or end with hyphen or dot
    //     if (Text.startsWith(domain, #char '-') or Text.endsWith(domain, #char '-')) {
    //         return #err("Domain cannot start or end with hyphen");
    //     };

    //     if (Text.startsWith(domain, #char '.') or Text.endsWith(domain, #char '.')) {
    //         return #err("Domain cannot start or end with dot");
    //     };

    //     #ok(());
    // };

    // // Check if character is valid in domain name
    // private func isValidDomainChar(char : Char) : Bool {
    //     let code = Char.toNat32(char);
    //     // Letters, digits, hyphens, dots
    //     (code >= 97 and code <= 122) or // a-z
    //     (code >= 65 and code <= 90) or // A-Z
    //     (code >= 48 and code <= 57) or // 0-9
    //     code == 45 or // hyphen
    //     code == 46; // dot
    // };
};
