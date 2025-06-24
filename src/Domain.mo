import Result "mo:new-base/Result";
import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Nat "mo:new-base/Nat";
import Char "mo:new-base/Char";
import TextX "mo:xtended-text/TextX";
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
