import Result "mo:new-base/Result";
import Text "mo:new-base/Text";
import Iter "mo:new-base/Iter";
import Array "mo:new-base/Array";
import Nat "mo:new-base/Nat";
import TextX "mo:xtended-text/TextX";
import Nat16 "mo:base/Nat16";
import Domain "./Domain";
import IpV4 "./IpV4";
import IpV6 "./IpV6";

module {
    public type Host = {
        #localhost;
        #domain : Domain.Domain;
        #ipV4 : IpV4.IpV4;
        #ipV6 : IpV6.IpV6;
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

        // Check for IPv6
        switch (IpV6.fromText(cleanHost)) {
            case (#ok(ipv6)) return #ok(#ipV6(ipv6));
            case (#err(_)) (); // Try next option
        };
        // Check for IPv4
        switch (IpV4.fromText(cleanHost)) {
            case (#ok(ipv4)) return #ok(#ipV4(ipv4));
            case (#err(_)) (); // Try next option
        };

        // Parse as domain
        switch (Domain.fromText(cleanHost)) {
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

    public func toText(host : Host, port : ?Nat16) : Text {
        let hostText = toTextHostOnly(host);
        let hostTextPlus = switch (host) {
            case (#ipV6(_)) "[" # hostText # "]"; // Wrap IPv6 in brackets
            case (_) hostText;
        };

        switch (port) {
            case (?p) hostTextPlus # ":" # Nat16.toText(p);
            case (null) hostTextPlus;
        };
    };

    private func toTextHostOnly(host : Host) : Text {
        switch (host) {
            case (#localhost) "localhost";
            case (#domain(d)) Domain.toText(d);
            case (#ipV4(ip)) IpV4.toText(ip);
            case (#ipV6(ip)) IpV6.toText(ip, #compressed);
        };
    };

    public func normalize(host : Host) : Host {
        switch (host) {
            case (#localhost) #localhost;
            case (#domain(d)) #domain(Domain.normalize(d));
            case (#ipV4(ip)) #ipV4(ip);
            case (#ipV6(ip)) #ipV6(ip);
        };
    };

    public func equal(host1 : Host, host2 : Host) : Bool {
        let norm1 = normalize(host1);
        let norm2 = normalize(host2);
        norm1 == norm2;
    };
};
