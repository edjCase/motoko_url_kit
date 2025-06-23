import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Array "mo:new-base/Array";
import Nat8 "mo:new-base/Nat8";
import Nat32 "mo:new-base/Nat32";
import VarArray "mo:new-base/VarArray";
import Char "mo:new-base/Char";
import TextX "mo:xtended-text/TextX";

module {
    public type Host = {
        #localhost;
        #domain : Domain;
        #ipv4 : IpV4;
        // TODO IPv6
    };

    public type Domain = {
        name : Text;
        tld : Text;
        subdomains : [Text];
    };

    public type IpV4 = (Nat8, Nat8, Nat8, Nat8); // (192, 168, 1, 1)

    public type Label = Text;

    public func fromText(host : Text) : Result.Result<Host, Text> {
        // Basic host validation
        if (TextX.isEmptyOrWhitespace(host)) return #err("Host cannot be empty");

        let trimmedHost = Text.trim(host, #text(" "));

        // Check for localhost
        if (Text.toLower(trimmedHost) == "localhost") return #ok(#localhost);

        // Check for IPv6 (contains colons, might be wrapped in brackets)
        let cleanHost = if (Text.startsWith(trimmedHost, #text("[")) and Text.endsWith(trimmedHost, #text("]"))) {
            // Remove brackets for IPv6
            let chars = trimmedHost.chars();
            let arr = Iter.toArray(chars);
            Text.fromIter(Array.sliceToArray(arr, 1, arr.size() - 1 : Nat).vals());
        } else {
            trimmedHost;
        };

        // Check for IPv4 (4 numbers separated by dots)
        if (isIpV4Format(cleanHost)) {
            switch (parseIpV4(cleanHost)) {
                case (#ok(ipv4)) return #ok(#ipv4(ipv4));
                case (#err(msg)) return #err("Invalid IPv4: " # msg);
            };
        };

        // Parse as domain
        switch (parseDomain(cleanHost)) {
            case (#ok(domain)) return #ok(#domain(domain));
            case (#err(msg)) return #err("Invalid domain: " # msg);
        };
    };

    private func isIpV4Format(text : Text) : Bool {
        let parts = Text.split(text, #text("."));
        let partsArray = Iter.toArray(parts);
        if (partsArray.size() != 4) return false;

        for (part in partsArray.vals()) {
            if (part.size() == 0 or part.size() > 3) return false;
            for (char in part.chars()) {
                if (char < '0' or char > '9') return false;
            };
        };
        true;
    };

    private func parseIpV4(text : Text) : Result.Result<IpV4, Text> {
        let parts = Text.split(text, #text("."));
        let partsArray = Iter.toArray(parts);

        if (partsArray.size() != 4) return #err("IPv4 must have 4 octets");

        var octets : [var Nat8] = VarArray.repeat<Nat8>(0, 4);

        for (i in partsArray.keys()) {
            let part = partsArray[i];
            switch (parseNat8(part)) {
                case (#ok(octet)) octets[i] := octet;
                case (#err(msg)) return #err("Invalid octet '" # part # "': " # msg);
            };
        };

        #ok((octets[0], octets[1], octets[2], octets[3]));
    };

    private func parseNat8(text : Text) : Result.Result<Nat8, Text> {
        if (text.size() == 0) return #err("Empty octet");

        var result : Nat = 0;
        for (char in text.chars()) {
            if (char < '0' or char > '9') return #err("Non-numeric character");
            result := result * 10 + (Nat32.toNat(Char.toNat32(char)) - 48);
            if (result > 255) return #err("Value exceeds 255");
        };

        #ok(Nat8.fromNat(result));
    };

    private func parseDomain(text : Text) : Result.Result<Domain, Text> {
        let parts = Text.split(text, #text("."));
        let partsArray = Iter.toArray(parts);

        if (partsArray.size() < 2) return #err("Domain must have at least name and TLD");

        // Validate each part
        for (part in partsArray.vals()) {
            if (part.size() == 0) return #err("Empty domain label");
            if (part.size() > 63) return #err("Domain label too long");
            // Additional validation could be added here
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

    public func toText(host : Host) : Text {
        switch (host) {
            case (#localhost) "localhost";
            case (#domain(d)) domainToText(d);
            case (#ipv4(ip)) ipv4ToText(ip);
        };
    };

    private func domainToText(domain : Domain) : Text {
        let all = Array.concat(domain.subdomains, [domain.name, domain.tld]);
        Text.join(".", all.vals());
    };

    private func ipv4ToText(ip : IpV4) : Text {
        let (a, b, c, d) = ip;
        Nat8.toText(a) # "." # Nat8.toText(b) # "." # Nat8.toText(c) # "." # Nat8.toText(d);
    };

    public func normalize(host : Host) : Host {
        switch (host) {
            case (#localhost) #localhost;
            case (#domain(d)) #domain(normalizeDomain(d));
            case (#ipv4(ip)) #ipv4(ip); // IPv4 already normalized
        };
    };

    private func normalizeDomain(domain : Domain) : Domain {
        {
            name = Text.toLower(domain.name);
            tld = Text.toLower(domain.tld);
            subdomains = Array.map(domain.subdomains, Text.toLower);
        };
    };

    public func equal(host1 : Host, host2 : Host) : Bool {
        let norm1 = normalize(host1);
        let norm2 = normalize(host2);
        norm1 == norm2;
    };
};
