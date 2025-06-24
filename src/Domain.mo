import Result "mo:new-base/Result";
import Array "mo:new-base/Array";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
module {

    public type Domain = {
        name : Text;
        tld : Text;
        subdomains : [Text];
    };

    public func fromText(domain : Text) : Result.Result<Domain, Text> {
        let parts = Text.split(domain, #text("."));
        let partsArray = Iter.toArray(parts);

        if (partsArray.size() < 2) return #err("Invalid domain: Must have at least name and TLD");

        // Validate each part
        for (part in partsArray.vals()) {
            if (part.size() == 0) return #err("Invalid domain: Contains empty label");
            if (part.size() > 63) return #err("Invalid domain: Contains label longer than 63 characters");
        };

        let tld = partsArray[partsArray.size() - 1];
        let name = partsArray[partsArray.size() - 2];
        let subdomains = if (partsArray.size() > 2) {
            Array.sliceToArray(partsArray, 0, partsArray.size() - 2 : Nat);
        } else {
            [];
        };

        #ok({
            name = name;
            tld = tld;
            subdomains = subdomains;
        });
    };

    public func toText(domain : Domain) : Text {
        let all = Array.concat(domain.subdomains, [domain.name, domain.tld]);
        Text.join(".", all.vals());
    };

    public func normalize(domain : Domain) : Domain {
        {
            name = Text.toLower(domain.name);
            tld = Text.toLower(domain.tld);
            subdomains = Array.map(domain.subdomains, Text.toLower);
        };
    };
};
