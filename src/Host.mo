import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Array "mo:new-base/Array";
import Nat8 "mo:new-base/Nat8";
import Nat32 "mo:new-base/Nat32";
import VarArray "mo:new-base/VarArray";
import Char "mo:new-base/Char";
import Nat "mo:new-base/Nat";
import TextX "mo:xtended-text/TextX";
import Nat16 "mo:base/Nat16";
import BaseX "mo:base-x-encoder";
import NatX "mo:xtended-numbers/NatX";

module {
    public type Host = {
        #localhost;
        #domain : Domain;
        #ipv4 : IpV4;
        #ipv6 : IpV6;
    };

    public type Domain = {
        name : Text;
        tld : Text;
        subdomains : [Text];
    };

    public type IpV4 = (Nat8, Nat8, Nat8, Nat8); // (192, 168, 1, 1)

    public type IpV6 = (Nat16, Nat16, Nat16, Nat16, Nat16, Nat16, Nat16, Nat16); // (0x2001, 0x0db8, 0x85a3, 0x0000, 0x0000, 0x8a2e, 0x0370, 0x7334)

    public func fromText(hostAndPort : Text) : Result.Result<(Host, ?Nat), Text> {
        // Basic validation
        if (TextX.isEmptyOrWhitespace(hostAndPort)) return #err("Host cannot be empty");

        let trimmedHost = Text.trim(hostAndPort, #text(" "));

        // Check for localhost (with optional port)
        if (Text.toLower(trimmedHost) == "localhost") return #ok((#localhost, null));
        if (Text.startsWith(Text.toLower(trimmedHost), #text("localhost:"))) {
            let portText = Text.trimStart(trimmedHost, #text("localhost:"));
            switch (parsePort(portText)) {
                case (#ok(port)) return #ok((#localhost, ?port));
                case (#err(msg)) return #err(msg);
            };
        };

        // Handle IPv6 with brackets [address]:port or [address]
        if (Text.startsWith(trimmedHost, #text("["))) {
            let chars = trimmedHost.chars();
            var bracketContent = "";
            var foundClosing = false;
            var remainingAfterBracket = "";

            // Skip the opening '['
            let _ = chars.next();

            // Collect characters until we find the closing ']'
            label ipv6Loop for (c in chars) {
                if (c == ']') {
                    foundClosing := true;
                    // Collect remaining characters after the bracket
                    for (remaining in chars) {
                        remainingAfterBracket #= Char.toText(remaining);
                    };
                    break ipv6Loop;
                } else {
                    bracketContent #= Char.toText(c);
                };
            };

            if (not foundClosing) {
                return #err("IPv6 address missing closing bracket ']'");
            };

            // Parse the IPv6 address
            switch (parseHostOnly(bracketContent)) {
                case (#ok(host)) {
                    // Check if there's a port after the bracket
                    if (Text.startsWith(remainingAfterBracket, #text(":"))) {
                        let portText = Text.trimStart(remainingAfterBracket, #char(':'));
                        switch (parsePort(portText)) {
                            case (#ok(port)) return #ok((host, ?port));
                            case (#err(msg)) return #err(msg);
                        };
                    } else if (Text.size(remainingAfterBracket) > 0) {
                        return #err("Unexpected characters after IPv6 address: '" # remainingAfterBracket # "'");
                    } else {
                        return #ok((host, null));
                    };
                };
                case (#err(msg)) return #err(msg);
            };
        };

        // Handle regular host:port or just host
        // Split on rightmost colon to handle potential port
        let chars = Iter.toArray(trimmedHost.chars());
        var lastColonIndex : ?Nat = null;

        // Find the rightmost colon
        for (i in chars.keys()) {
            if (chars[i] == ':') {
                lastColonIndex := ?i;
            };
        };

        switch (lastColonIndex) {
            case (?colonIndex) {
                let hostPart = Text.fromIter(Array.sliceToArray(chars, 0, colonIndex).vals());
                let portPart = Text.fromIter(Array.sliceToArray(chars, colonIndex + 1, chars.size()).vals());

                // Try to parse the port part
                switch (parsePort(portPart)) {
                    case (#ok(port)) {
                        // Valid port, parse the host part
                        switch (parseHostOnly(hostPart)) {
                            case (#ok(host)) return #ok((host, ?port));
                            case (#err(msg)) return #err(msg);
                        };
                    };
                    case (#err(_)) {
                        // Not a valid port, treat the whole thing as host
                        switch (parseHostOnly(trimmedHost)) {
                            case (#ok(host)) return #ok((host, null));
                            case (#err(msg)) return #err(msg);
                        };
                    };
                };
            };
            case (null) {
                // No colon found, just parse as host
                switch (parseHostOnly(trimmedHost)) {
                    case (#ok(host)) return #ok((host, null));
                    case (#err(msg)) return #err(msg);
                };
            };
        };
    };

    private func parsePort(portText : Text) : Result.Result<Nat, Text> {
        if (TextX.isEmptyOrWhitespace(portText)) {
            return #err("Empty port");
        };

        switch (Nat.fromText(portText)) {
            case (?port) {
                if (port < 1 or port > 65535) {
                    return #err("Port must be between 1 and 65535");
                };
                #ok(port);
            };
            case (null) return #err("Invalid port: '" # portText # "' is not a valid number");
        };
    };

    private func parseHostOnly(host : Text) : Result.Result<Host, Text> {
        // This is the original fromText logic but without port handling
        if (TextX.isEmptyOrWhitespace(host)) return #err("Host cannot be empty");

        let trimmedHost = Text.trim(host, #text(" "));

        // Check for localhost
        if (Text.toLower(trimmedHost) == "localhost") return #ok(#localhost);

        // For IPv6, don't expect brackets here since they're handled in the main function
        let cleanHost = trimmedHost;

        // Check for IPv6 (contains colons)
        if (isIpV6Format(cleanHost)) {
            switch (parseIpV6(cleanHost)) {
                case (#ok(ipv6)) return #ok(#ipv6(ipv6));
                case (#err(msg)) return #err("Invalid IPv6: " # msg);
            };
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

    private func isIpV6Format(text : Text) : Bool {
        // IPv6 addresses contain colons
        Text.contains(text, #text(":"));
    };

    private func parseIpV6(text : Text) : Result.Result<IpV6, Text> {
        // Handle :: compression
        let doubleColonCount = countSubstring(text, "::");
        if (doubleColonCount > 1) return #err("Multiple '::' not allowed");

        var expandedText = text;
        if (doubleColonCount == 1) {
            expandedText := expandDoubleColon(text);
        };

        // Split by colons
        let parts = Text.split(expandedText, #text(":"));
        let partsArray = Iter.toArray(parts);

        if (partsArray.size() != 8) return #err("IPv6 must have 8 groups");

        var groups : [var Nat16] = VarArray.repeat<Nat16>(0, 8);

        for (i in partsArray.keys()) {
            let part = partsArray[i];
            switch (parseHex16(part)) {
                case (#ok(group)) groups[i] := group;
                case (#err(msg)) return #err("Invalid group '" # part # "': " # msg);
            };
        };

        #ok((groups[0], groups[1], groups[2], groups[3], groups[4], groups[5], groups[6], groups[7]));
    };

    private func countSubstring(text : Text, substring : Text) : Nat {
        let chars = Iter.toArray(text.chars());
        let subChars = Iter.toArray(substring.chars());
        var count = 0;
        var i = 0;

        while (i <= (chars.size() - subChars.size() : Int)) {
            var match = true;
            for (j in subChars.keys()) {
                if (chars[i + j] != subChars[j]) {
                    match := false;
                };
            };
            if (match) {
                count += 1;
                i += subChars.size();
            } else {
                i += 1;
            };
        };
        count;
    };

    private func expandDoubleColon(text : Text) : Text {
        // Split on "::"
        let parts = Text.split(text, #text("::"));
        let partsArray = Iter.toArray(parts);

        if (partsArray.size() != 2) return text;
        // Should not happen if validation is correct

        let leftPart = partsArray[0];
        let rightPart = partsArray[1];

        // Count existing groups
        let leftGroups = if (leftPart == "") 0 else Iter.toArray(Text.split(leftPart, #text(":"))).size();
        let rightGroups = if (rightPart == "") 0 else Iter.toArray(Text.split(rightPart, #text(":"))).size();

        let missingGroups : Nat = 8 - leftGroups - rightGroups;
        let zeros = Array.tabulate<Text>(missingGroups, func(_) = "0");
        let zerosText = Text.join(":", zeros.vals());

        if (leftPart == "" and rightPart == "") {
            // "::" represents all zeros
            "0:0:0:0:0:0:0:0";
        } else if (leftPart == "") {
            // "::1234" format
            zerosText # ":" # rightPart;
        } else if (rightPart == "") {
            // "1234::" format
            leftPart # ":" # zerosText;
        } else {
            // "1234::5678" format
            leftPart # ":" # zerosText # ":" # rightPart;
        };
    };

    private func parseHex16(text : Text) : Result.Result<Nat16, Text> {
        if (text.size() == 0) return #err("Empty group");
        if (text.size() > 4) return #err("Group too long");

        let hexValue : [Nat8] = switch (BaseX.fromHex(text, { prefix = #none })) {
            case (#ok(value)) value;
            case (#err(msg)) return #err("Invalid hex group '" # text # "': " # msg);
        };

        switch (NatX.decodeNat16(hexValue.vals(), #msb)) {
            case (?value) #ok(value);
            case (null) #err("Invalid hex group '" # text # "': Not a valid 16-bit value");
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

    public func toText(host : Host) : Text {
        switch (host) {
            case (#localhost) "localhost";
            case (#domain(d)) domainToText(d);
            case (#ipv4(ip)) ipv4ToText(ip);
            case (#ipv6(ip)) ipv6ToText(ip);
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

    private func ipv6ToText(ip : IpV6) : Text {
        let (a, b, c, d, e, f, g, h) = ip;
        let groups = [a, b, c, d, e, f, g, h];
        let hexGroups = Array.map<Nat16, Text>(groups, nat16ToHex);
        Text.join(":", hexGroups.vals());
    };

    private func nat16ToHex(n : Nat16) : Text {
        let value = Nat16.toNat(n);
        if (value == 0) return "0";

        let hexChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];
        var result = "";
        var remaining = value;

        while (remaining > 0) {
            let digit = remaining % 16;
            result := Char.toText(hexChars[digit]) # result;
            remaining := remaining / 16;
        };

        result;
    };

    public func normalize(host : Host) : Host {
        switch (host) {
            case (#localhost) #localhost;
            case (#domain(d)) #domain(normalizeDomain(d));
            case (#ipv4(ip)) #ipv4(ip);
            case (#ipv6(ip)) #ipv6(ip);
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
