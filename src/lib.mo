import Text "mo:new-base/Text";
import Array "mo:new-base/Array";
import Char "mo:new-base/Char";
import Result "mo:new-base/Result";
import List "mo:new-base/List";
import Order "mo:new-base/Order";
import Blob "mo:new-base/Blob";
import Nat "mo:new-base/Nat";
import TextX "mo:xtended-text/TextX";
import Path "./Path";
import Host "./Host";
import BaseX "mo:base-x-encoder";
import PeekableIter "mo:itertools/PeekableIter";

module UrlKit {

    public type Url = {
        scheme : Text;
        host : Host.Host;
        path : Path.Path;
        queryParams : [(Text, Text)];
        port : ?Nat16;
        fragment : ?Text;
    };

    public func fromText(url : Text) : Result.Result<Url, Text> {
        // Extract scheme (http://, https://, etc.)
        let schemeParts = Text.split(url, #text("://"));
        let ?scheme : ?Text = schemeParts.next() else return #err("Invalid URL: Missing scheme");
        if (TextX.isEmptyOrWhitespace(scheme)) {
            return #err("Invalid URL: Empty scheme");
        };

        let ?hostAndPathAndQueryAndFragment = schemeParts.next() else return #err("Invalid URL: Missing host or path");

        if (schemeParts.next() != null) {
            return #err("Invalid URL: Multiple '://' found");
        };

        // Extract fragment (#fragment)
        let fragmentParts = Text.split(hostAndPathAndQueryAndFragment, #char('#'));
        let hostAndPathAndQuery = switch (fragmentParts.next()) {
            case (?part) part;
            case (null) hostAndPathAndQueryAndFragment;
        };

        let fragment : ?Text = switch (fragmentParts.next()) {
            case (?fragmentText) {
                if (TextX.isEmptyOrWhitespace(fragmentText)) {
                    null // Empty fragment is treated as no fragment
                } else {
                    // Decode the fragment
                    switch (decodeValue(fragmentText)) {
                        case (#ok(decoded)) ?decoded;
                        case (#err(errMsg)) return #err("Invalid URL fragment: " # errMsg);
                    };
                };
            };
            case (null) null;
        };

        // Check for multiple '#' characters
        if (fragmentParts.next() != null) {
            return #err("Invalid URL: Multiple '#' found");
        };

        // Extract query parameters (?key=value&key2=value2)
        let queryParts = Text.split(hostAndPathAndQuery, #char('?'));
        let (hostAndPath, queryParams) : (Text, [(Text, Text)]) = switch (queryParts.next()) {
            case (?hostAndPath) {
                switch (queryParts.next()) {
                    case (?queryString) {
                        let queryParams = switch (parseQueryString(queryString)) {
                            case (#ok(parsedParams)) parsedParams;
                            case (#err(errMsg)) return #err("Invalid URL query parameters: " # errMsg);
                        };
                        (hostAndPath, queryParams);
                    };
                    case (null) (hostAndPath, []); // No query parameters
                };
            };
            case (null) (hostAndPathAndQuery, []); // No query parameters
        };

        if (queryParts.next() != null) {
            return #err("Invalid URL: Multiple '?' found");
        };

        // What's left is host + path
        let hostAndPathParts = Text.split(hostAndPath, #char('/'));
        let hostAndPortText : Text = switch (hostAndPathParts.next()) {
            case (?hostPart) hostPart;
            case (null) hostAndPath;
        };

        let (host, port) = switch (Host.fromText(hostAndPortText)) {
            case (#ok(result)) result;
            case (#err(errMsg)) return #err("Invalid URL host: " # errMsg);
        };

        // The rest is the path
        let path = List.empty<Text>();
        for (part in hostAndPathParts) {
            List.add(path, part);
        };

        #ok({
            scheme = scheme;
            host = host;
            path = List.toArray(path);
            queryParams = queryParams;
            port = port;
            fragment = fragment;
        });
    };

    public func toText(url : Url) : Text {
        var result = url.scheme # "://" # Host.toText(url.host, url.port);

        result := result # Path.toText(url.path);

        // Add query
        if (url.queryParams.size() > 0) {
            let queryString = Text.join(
                "&",
                Array.map(
                    url.queryParams,
                    func((k, v) : (Text, Text)) : Text = encodeValue(k) # "=" # encodeValue(v) // Now encoding both key and value
                ).vals(),
            );
            result := result # "?" # queryString;
        };

        // Add fragment
        switch (url.fragment) {
            case (?fragment) result := result # "#" # encodeValue(fragment);
            case (null) {};
        };

        result;
    };

    public func normalize(url : Url) : Url {
        var normalizedPath = Path.normalize(url.path);

        // Sort query parameters
        let sortedQuery = if (url.queryParams.size() > 0) {
            Array.sort(
                url.queryParams,
                func(a : (Text, Text), b : (Text, Text)) : Order.Order {
                    Text.compare(a.0, b.0);
                },
            );
        } else {
            url.queryParams;
        };

        {
            scheme = TextX.toLower(url.scheme);
            host = Host.normalize(url.host);
            path = normalizedPath;
            queryParams = sortedQuery;
            port = url.port; // Port is already a Nat, no need to normalize
            fragment = url.fragment; // Fragment stays as is
        };
    };

    public func addQueryParam(url : Url, param : (Text, Text)) : Url {
        addQueryParamMulti(url, [param]);
    };

    public func addQueryParamMulti(url : Url, params : [(Text, Text)]) : Url {
        let newQuery = Array.concat(url.queryParams, params);
        {
            url with
            queryParams = newQuery;
        };
    };

    public func removeQueryParam(url : Url, key : Text) : Url {
        removeQueryParamMulti(url, [key]);
    };

    public func removeQueryParamMulti(url : Url, keys : [Text]) : Url {
        let filteredQuery = Array.filter(
            url.queryParams,
            func((k, _) : (Text, Text)) : Bool {
                switch (Array.find(keys, func(key : Text) : Bool = k == key)) {
                    case (?_) false;
                    case (null) true;
                };
            },
        );
        {
            url with
            queryParams = filteredQuery;
        };
    };

    public func getQueryParam(url : Url, key : Text) : ?Text {
        switch (Array.find(url.queryParams, func((k, _) : (Text, Text)) : Bool = k == key)) {
            case (?(_, value)) ?value;
            case (null) null;
        };
    };

    // ===== COMPARISON & ANALYSIS =====

    public func equal(url1 : Url, url2 : Url) : Bool {
        let norm1 = normalize(url1);
        let norm2 = normalize(url2);
        norm1 == norm2;
    };

    // ===== ENCODING/DECODING =====

    private func encodeValue(value : Text) : Text {
        func isSafeChar(c : Char) : Bool {
            let nat32_char = Char.toNat32(c);
            (97 <= nat32_char and nat32_char <= 122) or // a-z
            (65 <= nat32_char and nat32_char <= 90) or // A-Z
            (48 <= nat32_char and nat32_char <= 57) or // 0-9
            nat32_char == 95 or nat32_char == 126 or nat32_char == 45 or nat32_char == 46; // _ ~ - .
        };

        var result = "";
        for (c in value.chars()) {
            if (isSafeChar(c)) {
                result := result # Char.toText(c);
            } else {
                let utf8Hex = c
                |> Char.toText(_)
                |> Text.encodeUtf8(_)
                |> BaseX.toHex(_.vals(), { prefix = #perByte("%"); isUpper = false });

                result := result # utf8Hex;
            };
        };
        result;
    };

    private func decodeValue(value : Text) : Result.Result<Text, Text> {
        var result = "";
        let charIter = PeekableIter.fromIter(value.chars());
        label l loop {
            let ?c = charIter.next() else return #ok(result);
            let nextValue = if (c == '%') {
                let ?hex1 = charIter.next() else return #err("Invalid URL encoding: Incomplete hex sequence");
                let ?hex2 = charIter.next() else return #err("Invalid URL encoding: Incomplete hex sequence");
                var hex = Char.toText(hex1) # Char.toText(hex2);

                // Handle multiple percent-encoded characters in a row
                while (charIter.peek() == ?'%') {
                    let _ = charIter.next(); // Skip the '%'
                    let ?nextHex1 = charIter.next() else return #err("Invalid URL encoding: Incomplete hex sequence");
                    let ?nextHex2 = charIter.next() else return #err("Invalid URL encoding: Incomplete hex sequence");
                    hex #= Char.toText(nextHex1) # Char.toText(nextHex2);
                };

                // Decode the hex value
                switch (BaseX.fromHex(hex, { prefix = #none })) {
                    case (#ok(decoded)) switch (Text.decodeUtf8(Blob.fromArray(decoded))) {
                        case (?text) text;
                        case (null) return #err("Invalid URL encoded hex value '" # hex # "': Not a valid UTF-8 sequence");
                    };
                    case (#err(err)) return #err("Invalid URL encoded hex value '" # hex # "': " # err);
                };
            } else {
                Char.toText(c);
            };
            result := result # nextValue;
        };
        #ok(result);
    };

    // ===== PRIVATE HELPER FUNCTIONS =====

    private func parseQueryString(queryString : Text) : Result.Result<[(Text, Text)], Text> {
        if (TextX.isEmptyOrWhitespace(queryString)) {
            return #ok([]);
        };
        let queryParams = List.empty<(Text, Text)>();
        for (param in Text.split(queryString, #char('&'))) {
            if (TextX.isEmptyOrWhitespace(param)) {
                return #err("Invalid query parameter: Empty parameter found");
            };

            let parts = Text.split(param, #char('='));
            let ?key = parts.next() else return #err("Invalid query parameter: Missing key in '" # param # "'");
            let decodedKey = switch (decodeValue(key)) {
                case (#ok(decoded)) decoded;
                case (#err(errMsg)) return #err("Unable to decode query parameter key '" # key # "': " # errMsg);
            };
            let decodedValue = switch (parts.next()) {
                case (?v) switch (decodeValue(v)) {
                    case (#ok(decoded)) decoded;
                    case (#err(errMsg)) return #err("Unable to decode query parameter value '" # v # "': " # errMsg);
                };
                case (null) "";
            };
            List.add(queryParams, (decodedKey, decodedValue));
        };
        #ok(List.toArray(queryParams));
    };

};
