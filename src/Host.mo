import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Array "mo:new-base/Array";
import Nat "mo:new-base/Nat";
import Nat8 "mo:new-base/Nat8";
import Nat32 "mo:new-base/Nat32";
import VarArray "mo:new-base/VarArray";
import Char "mo:new-base/Char";
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

    type IpV6Format = {
        #full; // 2001:0db8:0000:0000:0000:0000:0000:0001
        #compressed; // 2001:db8::1
        #standard; // 2001:db8:0:0:0:0:0:1
    };

    public func fromText(hostAndPort : Text) : Result.Result<(Host, ?Nat16), Text> {
        // Basic validation
        if (TextX.isEmptyOrWhitespace(hostAndPort)) return #err("Host cannot be empty");

        let trimmed = Text.trim(hostAndPort, #text(" "));

        // Handle IPv6 addresses (which may have ports)
        if (Text.startsWith(trimmed, #text("["))) {
            // IPv6 case - look for ]:port pattern
            if (Text.contains(trimmed, #text("]:"))) {
                // IPv6 with port: [2001:db8::1]:8080
                let parts = Text.split(trimmed, #text("]:"));
                let partsArray = Iter.toArray(parts);
                if (partsArray.size() != 2) return #err("Invalid IPv6 host:port format");

                let ipv6Part = partsArray[0] # "]"; // Add back the closing bracket
                let portPart = partsArray[1];

                // Parse the IPv6 host
                let host = switch (fromTextHostOnly(ipv6Part)) {
                    case (#ok(h)) h;
                    case (#err(msg)) return #err(msg);
                };

                // Parse the port
                let port = switch (parsePort(portPart)) {
                    case (#ok(p)) ?p;
                    case (#err(msg)) return #err(msg);
                };

                return #ok((host, port));
            } else if (Text.endsWith(trimmed, #text("]"))) {
                // IPv6 without port: [2001:db8::1]
                let host = switch (fromTextHostOnly(trimmed)) {
                    case (#ok(h)) h;
                    case (#err(msg)) return #err(msg);
                };
                return #ok((host, null));
            } else {
                return #err("Invalid IPv6 format: missing closing bracket");
            };
        };

        // Non-IPv6 case - check for port
        if (Text.contains(trimmed, #text(":"))) {
            let parts = Text.split(trimmed, #text(":"));
            let partsArray = Iter.toArray(parts);

            if (partsArray.size() == 2) {
                // host:port format
                let hostPart = partsArray[0];
                let portPart = partsArray[1];

                let host = switch (fromTextHostOnly(hostPart)) {
                    case (#ok(h)) h;
                    case (#err(msg)) return #err(msg);
                };

                let port = switch (parsePort(portPart)) {
                    case (#ok(p)) ?p;
                    case (#err(msg)) return #err(msg);
                };

                return #ok((host, port));
            } else if (partsArray.size() > 2) {
                // Multiple colons but not IPv6 - invalid
                return #err("Invalid host:port format: multiple colons found");
            };
        };

        // No port, just host
        let host = switch (fromTextHostOnly(trimmed)) {
            case (#ok(h)) h;
            case (#err(msg)) return #err(msg);
        };

        #ok((host, null));
    };

    private func fromTextHostOnly(host : Text) : Result.Result<Host, Text> {
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

    private func parsePort(portText : Text) : Result.Result<Nat16, Text> {
        let ?port = Nat.fromText(portText) else return #err("Invalid port: '" # portText # "' is not a valid number");
        if (port < 1 or port > 65535) {
            return #err("Invalid port: Port must be between 1 and 65535");
        };
        #ok(Nat16.fromNat(port));
    };

    private func isIpV6Format(text : Text) : Bool {
        // IPv6 addresses contain colons
        Text.contains(text, #text(":"));
    };

    private func parseIpV6(text : Text) : Result.Result<IpV6, Text> {
        // Handle IPv4-mapped IPv6 addresses first
        let processedText = switch (handleEmbeddedIpV4(text)) {
            case (#ok(processed)) processed;
            case (#err(msg)) return #err(msg);
        };

        // Handle :: compression
        let doubleColonCount = countSubstring(processedText, "::");
        if (doubleColonCount > 1) return #err("Multiple :: not allowed");

        var expandedText = processedText;
        if (doubleColonCount == 1) {
            expandedText := expandDoubleColon(processedText);
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

    private func handleEmbeddedIpV4(text : Text) : Result.Result<Text, Text> {
        // Find the last colon to check if what follows might be an IPv4 address
        let parts = Text.split(text, #text(":"));
        let partsArray = Iter.toArray(parts);

        if (partsArray.size() == 0) return #ok(text);

        let lastPart = partsArray[partsArray.size() - 1];

        // Check if the last part is an IPv4 address
        if (isIpV4Format(lastPart)) {
            // Parse the IPv4 address
            switch (parseIpV4(lastPart)) {
                case (#ok((a, b, c, d))) {
                    // Convert IPv4 to two 16-bit hex values
                    let high16 = Nat16.fromNat(Nat8.toNat(a) * 256 + Nat8.toNat(b));
                    let low16 = Nat16.fromNat(Nat8.toNat(c) * 256 + Nat8.toNat(d));

                    // Convert to hex strings
                    let high16Hex = nat16ToHex(high16);
                    let low16Hex = nat16ToHex(low16);

                    // Rebuild the IPv6 string with the converted values
                    let prefixParts = Array.sliceToArray(partsArray, 0, partsArray.size() - 1 : Nat);
                    let prefixText = Text.join(":", prefixParts.vals());

                    if (prefixText == "") {
                        #ok(high16Hex # ":" # low16Hex);
                    } else {
                        #ok(prefixText # ":" # high16Hex # ":" # low16Hex);
                    };
                };
                case (#err(msg)) return #err("Invalid embedded IPv4: " # msg);
            };
        } else {
            #ok(text);
        };
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

        // Pad with leading zeros to make it exactly 4 characters (2 bytes)
        // This is needed because BaseX.fromHex expects even-length strings
        let paddedText = switch (text.size()) {
            case (1) "000" # text;
            case (2) "00" # text;
            case (3) "0" # text;
            case (4) text;
            case (_) return #err("Invalid group length");
        };

        let hexValue : [Nat8] = switch (BaseX.fromHex(paddedText, { prefix = #none })) {
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

    public func toText(host : Host, port : ?Nat16) : Text {
        let hostText = switch (host) {
            case (#localhost) "localhost";
            case (#domain(d)) domainToText(d);
            case (#ipv4(ip)) ipv4ToText(ip);
            case (#ipv6(ip)) "[" # ipv6ToText(ip) # "]";
        };

        switch (port) {
            case (?p) hostText # ":" # Nat16.toText(p);
            case (null) hostText;
        };
    };

    public func toTextHostOnly(host : Host) : Text {
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
        ipv6ToTextWithFormat(ip, #compressed);
    };

    private func ipv6ToTextWithFormat(ip : IpV6, format : IpV6Format) : Text {
        let (a, b, c, d, e, f, g, h) = ip;
        let groups = [a, b, c, d, e, f, g, h];

        switch (format) {
            case (#full) {
                // Full format with leading zeros: 2001:0db8:0000:0000:0000:0000:0000:0001
                let paddedGroups = Array.map<Nat16, Text>(
                    groups,
                    func(n : Nat16) : Text {
                        let hex = nat16ToHex(n);
                        switch (hex.size()) {
                            case (1) "000" # hex;
                            case (2) "00" # hex;
                            case (3) "0" # hex;
                            case (4) hex;
                            case (_) hex;
                        };
                    },
                );
                Text.join(":", paddedGroups.vals());
            };
            case (#standard) {
                // Standard format without leading zeros: 2001:db8:0:0:0:0:0:1
                let hexGroups = Array.map<Nat16, Text>(groups, nat16ToHex);
                Text.join(":", hexGroups.vals());
            };
            case (#compressed) {
                // Compressed format with :: notation: 2001:db8::1
                compressIpV6(groups);
            };
        };
    };

    private func compressIpV6(groups : [Nat16]) : Text {
        // Find the longest sequence of consecutive zeros
        var longestStart = -1;
        var longestLength = 0;
        var currentStart = -1;
        var currentLength = 0;

        for (i in groups.keys()) {
            if (groups[i] == 0) {
                if (currentStart == -1) {
                    currentStart := i;
                    currentLength := 1;
                } else {
                    currentLength += 1;
                };
            } else {
                if (currentLength > longestLength) {
                    longestStart := currentStart;
                    longestLength := currentLength;
                };
                currentStart := -1;
                currentLength := 0;
            };
        };

        // Check if the last sequence is the longest
        if (currentLength > longestLength) {
            longestStart := currentStart;
            longestLength := currentLength;
        };

        // Only compress if we have at least 2 consecutive zeros
        if (longestLength < 2) {
            let hexGroups = Array.map<Nat16, Text>(groups, nat16ToHex);
            return Text.join(":", hexGroups.vals());
        };

        // Build the compressed string
        var result = "";
        var i = 0;

        // Add groups before the compressed section
        while (i < longestStart) {
            if (result != "") result #= ":";
            result #= nat16ToHex(groups[i]);
            i += 1;
        };

        // Add the :: compression
        if (longestStart == 0) {
            // Compression starts at the beginning
            result := "::";
        } else {
            result #= "::";
        };

        // Skip the compressed zeros
        i += longestLength;

        // Add groups after the compressed section
        while (i < groups.size()) {
            if (longestStart + longestLength < groups.size()) {
                result #= nat16ToHex(groups[i]);
                if (i < groups.size() - 1) result #= ":";
            };
            i += 1;
        };

        // Handle edge case where compression is at the end
        if (longestStart + longestLength == groups.size() and longestStart > 0) {
            result #= ":";
        };

        result;
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
