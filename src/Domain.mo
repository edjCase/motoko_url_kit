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
        fromTextWithSuffixList(domain, DomainSuffixList.value);
    };

    public func fromTextWithSuffixList(domain : Text, suffixList : [Text]) : Result.Result<Domain, Text> {
        let parts = Text.split(domain, #text("."));
        let partsArray = Iter.toArray(parts);

        if (partsArray.size() < 2) return #err("Must have at least name and suffix");

        // Validate each part
        for (part in partsArray.vals()) {
            if (part.size() == 0) return #err("Contains empty label");
            if (part.size() > 63) return #err("Contains label longer than 63 characters");
        };

        // Find the longest matching suffix from DomainSuffixList.value
        var longestSuffix = "";
        var longestSuffixLength = 0;

        // Check all possible suffixes from 1 to max possible length
        let maxSuffixLength : Nat = partsArray.size() - 1; // Need at least one part for name

        for (len in Nat.range(1, maxSuffixLength + 1)) {
            let startIndex : Nat = partsArray.size() - len;
            let candidateParts = Array.sliceToArray(partsArray, startIndex, startIndex + len + 1);
            let candidateSuffix = Text.toLower(Text.join(".", candidateParts.vals()));

            // Check if this suffix exists in DomainSuffixList.value
            switch (Array.find<Text>(suffixList, func(s) = s == candidateSuffix)) {
                case (?_) {
                    if (len > longestSuffixLength) {
                        longestSuffix := candidateSuffix;
                        longestSuffixLength := len;
                    };
                };
                case null {};
            };
        };

        if (longestSuffix == "") return #err("Unrecognized suffix for '" # domain # "'");

        let name = partsArray[partsArray.size() - longestSuffixLength - 1];
        let subdomains = if (partsArray.size() > longestSuffixLength + 1) {
            Array.sliceToArray(partsArray, 0, partsArray.size() - longestSuffixLength - 1 : Nat);
        } else {
            [];
        };

        #ok({
            name = name;
            suffix = longestSuffix;
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
