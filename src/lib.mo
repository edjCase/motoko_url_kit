import Text "mo:core@1/Text";
import Array "mo:core@1/Array";
import Char "mo:core@1/Char";
import Result "mo:core@1/Result";
import List "mo:core@1/List";
import Order "mo:core@1/Order";
import Blob "mo:core@1/Blob";
import TextX "mo:xtended-text@2/TextX";
import Path "./Path";
import Host "./Host";
import BaseX "mo:base-x-encoder@2";
import PeekableIter "mo:xtended-iter@1/PeekableIter";
import Domain "./Domain";

module UrlKit {

  public type Url = {
    scheme : ?Text;
    authority : ?Authority;
    path : Path.Path;
    queryParams : [(Text, Text)];
    fragment : ?Text;
  };

  public type Authority = {
    user : ?UserInfo;
    host : Host.Host;
    port : ?Nat16;
  };

  public type UserInfo = {
    username : Text;
    password : Text;
  };

  /// A simple domain parser using a provided list of known suffixes.
  /// Use ComprehensiveDomainParser.ComprehensiveDomainParser for full public suffix list support.
  public class SimpleDomainParser(suffixes : [Text]) : Domain.DomainParser {
    let suffixList = suffixes;

    public func parse(domain : Text) : Result.Result<Domain.Domain, Text> {
      Domain.fromText(domain, suffixList);
    };
  };

  /// Parses a URL string into a structured Url object.
  /// Handles various URL formats including authority-based URLs, relative URLs, and special schemes.
  ///
  /// ```motoko
  /// let urlResult = UrlKit.fromText("https://example.com:8080/path?key=value#section");
  /// // urlResult is #ok({ scheme = ?"https"; authority = ?{...}; path = ["path"]; queryParams = [("key", "value")]; fragment = ?"section" })
  ///
  /// let relativeResult = UrlKit.fromText("/api/users");
  /// // relativeResult is #ok({ scheme = null; authority = null; path = ["api", "users"]; queryParams = []; fragment = null })
  /// ```
  public func fromText(url : Text, domainParser : Domain.DomainParser) : Result.Result<Url, Text> {
    if (TextX.isEmptyOrWhitespace(url)) {
      return #ok({
        scheme = null;
        authority = null;
        path = [];
        queryParams = [];
        fragment = null;
      });
    };

    var remainingUrl = url;
    var scheme : ?Text = null;

    // Look for scheme (first colon)
    let colonParts = Text.split(url, #char(':'));
    switch (colonParts.next()) {
      case (?firstPart) {
        switch (colonParts.next()) {
          case (?restPart) {
            // Found a colon, so we have a scheme
            let schemeText = firstPart;
            if (TextX.isEmptyOrWhitespace(schemeText)) {
              return #err("Invalid URL: Empty scheme");
            };

            // Validate scheme characters
            switch (validateScheme(schemeText)) {
              case (#err(msg)) return #err("Invalid URL scheme: " # msg);
              case (#ok) {};
            };

            scheme := ?schemeText;
            // Reconstruct remaining URL from the rest of the parts
            var remaining = restPart;
            for (part in colonParts) {
              remaining := remaining # ":" # part;
            };
            remainingUrl := remaining;
          };
          case (null) {
            // No colon found, treat entire URL as path
            remainingUrl := url;
          };
        };
      };
      case (null) {
        // Empty URL already handled above
      };
    };

    // Extract fragment (#fragment)
    let fragmentParts = Text.split(remainingUrl, #char('#'));
    let urlWithoutFragment = switch (fragmentParts.next()) {
      case (?part) part;
      case (null) remainingUrl;
    };

    let fragment : ?Text = switch (fragmentParts.next()) {
      case (?fragmentText) {
        if (TextX.isEmptyOrWhitespace(fragmentText)) {
          null;
        } else {
          switch (decodeText(fragmentText)) {
            case (#ok(decoded)) ?decoded;
            case (#err(errMsg)) return #err("Invalid URL fragment: " # errMsg);
          };
        };
      };
      case (null) null;
    };

    if (fragmentParts.next() != null) {
      return #err("Invalid URL: Multiple '#' found");
    };

    // Extract query parameters (?key=value&key2=value2)
    let queryParts = Text.split(urlWithoutFragment, #char('?'));
    let (urlWithoutQuery, queryParams) : (Text, [(Text, Text)]) = switch (queryParts.next()) {
      case (?urlPart) {
        switch (queryParts.next()) {
          case (?queryString) {
            let queryParams = switch (parseQueryString(queryString)) {
              case (#ok(parsedParams)) parsedParams;
              case (#err(errMsg)) return #err("Invalid URL query parameters: " # errMsg);
            };
            (urlPart, queryParams);
          };
          case (null) (urlPart, []);
        };
      };
      case (null) (urlWithoutFragment, []);
    };

    if (queryParts.next() != null) {
      return #err("Invalid URL: Multiple '?' found");
    };

    // Now parse authority and path based on whether we have "//" after scheme
    var authority : ?Authority = null;
    var pathText = urlWithoutQuery;

    if (Text.startsWith(urlWithoutQuery, #text("//"))) {
      // Authority present - schemes like http://, https://, ftp://
      pathText := Text.trimStart(urlWithoutQuery, #text("//"));

      // Find where authority ends (first '/' or end of string)
      let pathParts = Text.split(pathText, #char('/'));
      let (authorityText, remainingPath) = switch (pathParts.next()) {
        case (?firstPart) {
          switch (pathParts.next()) {
            case (?secondPart) {
              // Found a slash, so authority is firstPart
              var remaining = "/" # secondPart;
              for (part in pathParts) {
                remaining := remaining # "/" # part;
              };
              (firstPart, remaining);
            };
            case (null) {
              // No slash found, entire thing is authority
              (firstPart, "");
            };
          };
        };
        case (null) {
          ("", "");
        };
      };

      if (not TextX.isEmptyOrWhitespace(authorityText)) {
        authority := switch (parseAuthority(authorityText, domainParser)) {
          case (#ok(auth)) ?auth;
          case (#err(errMsg)) return #err("Invalid URL authority: " # errMsg);
        };
      };

      pathText := remainingPath;
    } else {
      // No authority - schemes like mailto:, data:, tel:, or relative URLs
      // The entire urlWithoutQuery is the path
    };

    // Parse path
    let path = switch (Path.fromText(pathText)) {
      case (#ok(parsedPath)) parsedPath;
      case (#err(errMsg)) return #err("Invalid URL path: " # errMsg);
    };

    #ok({
      scheme = scheme;
      authority = authority;
      path = path;
      queryParams = queryParams;
      fragment = fragment;
    });
  };

  /// Converts a Url object back to its string representation.
  /// Properly encodes query parameters and fragments, and formats IPv6 addresses with brackets.
  ///
  /// ```motoko
  /// let url = { scheme = ?"https"; authority = ?{...}; path = ["api", "users"]; queryParams = [("id", "123")]; fragment = ?"top" };
  /// let urlText = UrlKit.toText(url);
  /// // urlText is "https://example.com/api/users?id=123#top"
  /// ```
  public func toText(url : Url) : Text {
    var result = "";

    // Add scheme
    switch (url.scheme) {
      case (?scheme) result := scheme # "://";
      case (null) {
        // If no scheme but has authority, use //
        switch (url.authority) {
          case (?_) result := "//";
          case (null) {};
        };
      };
    };

    // Add authority
    switch (url.authority) {
      case (?auth) result := result # authorityToText(auth);
      case (null) {};
    };

    // Add path
    result := result # Path.toText(url.path);

    // Add query
    if (url.queryParams.size() > 0) {
      let queryString = Text.join(
        "&",
        Array.map(
          url.queryParams,
          func((k, v) : (Text, Text)) : Text = encodeText(k) # "=" # encodeText(v),
        ).vals(),
      );
      result := result # "?" # queryString;
    };

    // Add fragment
    switch (url.fragment) {
      case (?fragment) result := result # "#" # encodeText(fragment);
      case (null) {};
    };

    result;
  };

  /// Normalizes a URL by converting schemes and hosts to lowercase, sorting query parameters,
  /// and normalizing path segments. This enables consistent URL comparison.
  ///
  /// ```motoko
  /// let url = { scheme = ?"HTTPS"; authority = ?{...}; path = ["API", "", "Users"]; queryParams = [("z", "1"), ("a", "2")]; fragment = null };
  /// let normalized = UrlKit.normalize(url);
  /// // normalized has scheme = ?"https", path = ["api", "users"], queryParams = [("a", "2"), ("z", "1")]
  /// ```
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
      scheme = switch (url.scheme) {
        case (?scheme) ?Text.toLower(scheme);
        case (null) null;
      };
      authority = switch (url.authority) {
        case (?auth) ?normalizeAuthority(auth);
        case (null) null;
      };
      path = normalizedPath;
      queryParams = sortedQuery;
      fragment = url.fragment; // Fragment stays as is
    };
  };

  /// Adds a single query parameter to a URL.
  ///
  /// ```motoko
  /// let url = { scheme = ?"https"; authority = ?{...}; path = []; queryParams = []; fragment = null };
  /// let urlWithParam = UrlKit.addQueryParam(url, ("key", "value"));
  /// // urlWithParam.queryParams is [("key", "value")]
  /// ```
  public func addQueryParam(url : Url, param : (Text, Text)) : Url {
    addQueryParamMulti(url, [param]);
  };

  /// Adds multiple query parameters to a URL.
  ///
  /// ```motoko
  /// let url = { scheme = ?"https"; authority = ?{...}; path = []; queryParams = [("existing", "param")]; fragment = null };
  /// let newParams = [("key1", "value1"), ("key2", "value2")];
  /// let urlWithParams = UrlKit.addQueryParamMulti(url, newParams);
  /// // urlWithParams.queryParams is [("existing", "param"), ("key1", "value1"), ("key2", "value2")]
  /// ```
  public func addQueryParamMulti(url : Url, params : [(Text, Text)]) : Url {
    let newQuery = Array.concat(url.queryParams, params);
    {
      url with
      queryParams = newQuery;
    };
  };

  /// Removes a single query parameter from a URL by key.
  ///
  /// ```motoko
  /// let url = { scheme = ?"https"; authority = ?{...}; path = []; queryParams = [("key1", "value1"), ("key2", "value2")]; fragment = null };
  /// let urlWithoutParam = UrlKit.removeQueryParam(url, "key1");
  /// // urlWithoutParam.queryParams is [("key2", "value2")]
  /// ```
  public func removeQueryParam(url : Url, key : Text) : Url {
    removeQueryParamMulti(url, [key]);
  };

  /// Removes multiple query parameters from a URL by their keys.
  ///
  /// ```motoko
  /// let url = { scheme = ?"https"; authority = ?{...}; path = []; queryParams = [("key1", "value1"), ("key2", "value2"), ("key3", "value3")]; fragment = null };
  /// let keysToRemove = ["key1", "key3"];
  /// let urlWithoutParams = UrlKit.removeQueryParamMulti(url, keysToRemove);
  /// // urlWithoutParams.queryParams is [("key2", "value2")]
  /// ```
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

  /// Retrieves the value of a query parameter by key. Returns the first matching value if multiple exist.
  ///
  /// ```motoko
  /// let url = { scheme = ?"https"; authority = ?{...}; path = []; queryParams = [("key1", "value1"), ("key2", "value2")]; fragment = null };
  /// let value = UrlKit.getQueryParam(url, "key1");
  /// // value is ?"value1"
  ///
  /// let missing = UrlKit.getQueryParam(url, "nonexistent");
  /// // missing is null
  /// ```
  public func getQueryParam(url : Url, key : Text) : ?Text {
    switch (Array.find(url.queryParams, func((k, _) : (Text, Text)) : Bool = k == key)) {
      case (?(_, value)) ?value;
      case (null) null;
    };
  };

  // ===== COMPARISON & ANALYSIS =====

  /// Compares two URLs for equality after normalization.
  /// This enables case-insensitive comparison and handles query parameter ordering.
  ///
  /// ```motoko
  /// let url1 = UrlKit.fromText("HTTPS://EXAMPLE.COM?b=2&a=1");
  /// let url2 = UrlKit.fromText("https://example.com?a=1&b=2");
  /// let isEqual = UrlKit.equal(url1, url2);
  /// // isEqual is true (after normalization)
  /// ```
  public func equal(url1 : Url, url2 : Url) : Bool {
    let norm1 = normalize(url1);
    let norm2 = normalize(url2);
    norm1 == norm2;
  };

  // ===== ENCODING/DECODING =====

  /// Encodes text for safe use in URLs by percent-encoding unsafe characters.
  /// Safe characters (A-Z, a-z, 0-9, _, ~, -, .) are left unencoded.
  ///
  /// ```motoko
  /// let encoded = UrlKit.encodeText("hello world!");
  /// // encoded is "hello%20world%21"
  ///
  /// let unicodeEncoded = UrlKit.encodeText("café");
  /// // unicodeEncoded is "caf%c3%a9"
  /// ```
  public func encodeText(value : Text) : Text {
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

  /// Decodes percent-encoded text back to its original form.
  /// Handles UTF-8 sequences and validates hex encoding.
  ///
  /// ```motoko
  /// let decoded = UrlKit.decodeText("hello%20world%21");
  /// // decoded is #ok("hello world!")
  ///
  /// let unicodeDecoded = UrlKit.decodeText("caf%c3%a9");
  /// // unicodeDecoded is #ok("café")
  ///
  /// let invalid = UrlKit.decodeText("invalid%ZZ");
  /// // invalid is #err("Invalid URL encoded hex value 'ZZ': ...")
  /// ```
  public func decodeText(value : Text) : Result.Result<Text, Text> {
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

  private func parseAuthority(authorityText : Text, domainParser : Domain.DomainParser) : Result.Result<Authority, Text> {
    // Validate no leading/trailing whitespace in authority
    if (authorityText != Text.trim(authorityText, #text(" "))) {
      return #err("Authority cannot have leading or trailing whitespace");
    };

    var hostAndPort = authorityText;
    var user : ?{ username : Text; password : Text } = null;

    // Check for user info (username:password@)
    if (Text.contains(authorityText, #char('@'))) {
      let userParts = Text.split(authorityText, #char('@'));
      let ?userInfo = userParts.next() else return #err("Invalid authority: Missing user info before @");
      hostAndPort := switch (userParts.next()) {
        case (?hostPart) hostPart;
        case (null) return #err("Invalid authority: Missing host after @");
      };

      if (userParts.next() != null) {
        return #err("Invalid authority: Multiple @ characters found");
      };

      // Parse user info (username:password)
      if (not TextX.isEmptyOrWhitespace(userInfo)) {
        let credentialParts = Text.split(userInfo, #char(':'));
        let ?username = credentialParts.next() else return #err("Invalid authority: Empty username");
        let password = switch (credentialParts.next()) {
          case (?pass) pass;
          case (null) ""; // No password provided
        };

        if (credentialParts.next() != null) {
          return #err("Invalid authority: Multiple : characters in user info");
        };

        // Decode username and password
        let decodedUsername = switch (decodeText(username)) {
          case (#ok(decoded)) decoded;
          case (#err(errMsg)) return #err("Invalid username encoding: " # errMsg);
        };

        let decodedPassword = switch (decodeText(password)) {
          case (#ok(decoded)) decoded;
          case (#err(errMsg)) return #err("Invalid password encoding: " # errMsg);
        };

        user := ?{
          username = decodedUsername;
          password = decodedPassword;
        };
      };
    };

    // Parse host and port
    let (host, port) = switch (Host.fromText(hostAndPort, domainParser)) {
      case (#ok(result)) result;
      case (#err(errMsg)) return #err(errMsg);
    };

    #ok({
      user = user;
      host = host;
      port = port;
    });
  };

  private func authorityToText(authority : Authority) : Text {
    var result = "";

    // Add user info if present
    switch (authority.user) {
      case (?userInfo) {
        result := encodeText(userInfo.username);
        if (userInfo.password != "") {
          result := result # ":" # encodeText(userInfo.password);
        };
        result := result # "@";
      };
      case (null) {};
    };

    // Add host and port
    result := result # Host.toText(authority.host, authority.port);

    result;
  };

  private func normalizeAuthority(authority : Authority) : Authority {
    {
      user = authority.user; // User info stays as is (already decoded)
      host = Host.normalize(authority.host);
      port = authority.port;
    };
  };

  private func validateScheme(scheme : Text) : Result.Result<(), Text> {
    if (scheme.size() == 0) return #err("Empty scheme");

    let chars = scheme.chars();
    let ?firstChar = chars.next() else return #err("Empty scheme");

    // First character must be a letter
    if (not isLetter(firstChar)) {
      return #err("Scheme must start with a letter");
    };

    // Scheme cannot end with hyphen
    if (Text.endsWith(scheme, #char('-'))) {
      return #err("Scheme cannot end with hyphen");
    };

    // Check for consecutive dots
    if (Text.contains(scheme, #text(".."))) {
      return #err("Scheme cannot contain consecutive dots");
    };

    // Remaining characters must be letters, digits, +, -, or .
    for (char in chars) {
      if (not isValidSchemeChar(char)) {
        return #err("Invalid character '" # Char.toText(char) # "' in scheme");
      };
    };

    #ok(());
  };

  private func isLetter(char : Char) : Bool {
    let code = Char.toNat32(char);
    (code >= 65 and code <= 90) or (code >= 97 and code <= 122); // A-Z or a-z
  };

  private func isValidSchemeChar(char : Char) : Bool {
    let code = Char.toNat32(char);
    (code >= 65 and code <= 90) or // A-Z
    (code >= 97 and code <= 122) or // a-z
    (code >= 48 and code <= 57) or // 0-9
    code == 43 or // +
    code == 45 or // -
    code == 46; // .
  };

  private func parseQueryString(queryString : Text) : Result.Result<[(Text, Text)], Text> {
    if (TextX.isEmptyOrWhitespace(queryString)) {
      return #ok([]);
    };
    let queryParams = List.empty<(Text, Text)>();
    label f for (param in Text.split(queryString, #char('&'))) {
      if (TextX.isEmptyOrWhitespace(param)) {
        continue f; // Skip empty parameters
      };

      let parts = Text.split(param, #char('='));
      let ?key = parts.next() else return #err("Invalid query parameter: Missing key in '" # param # "'");
      if (TextX.isEmptyOrWhitespace(key)) {
        return #err("Invalid query parameter: Empty key in '" # param # "'");
      };
      let decodedKey = switch (decodeText(key)) {
        case (#ok(decoded)) decoded;
        case (#err(errMsg)) return #err("Unable to decode query parameter key '" # key # "': " # errMsg);
      };
      let decodedValue = switch (parts.next()) {
        case (?v) switch (decodeText(v)) {
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
