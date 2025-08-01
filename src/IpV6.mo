import Result "mo:core/Result";
import Text "mo:core/Text";
import Iter "mo:core/Iter";
import VarArray "mo:core/VarArray";
import Array "mo:core/Array";
import Nat16 "mo:core/Nat16";
import Char "mo:core/Char";
import Nat8 "mo:core/Nat8";
import BaseX "mo:base-x-encoder";
import NatX "mo:xtended-numbers/NatX";
import IpV4 "IpV4";

module {

  public type IpV6 = (Nat16, Nat16, Nat16, Nat16, Nat16, Nat16, Nat16, Nat16); // (0x2001, 0x0db8, 0x85a3, 0x0000, 0x0000, 0x8a2e, 0x0370, 0x7334)

  public type IpV6Format = {
    #full; // 2001:0db8:0000:0000:0000:0000:0000:0001
    #compressed; // 2001:db8::1
    #standard; // 2001:db8:0:0:0:0:0:1
  };

  /// Parses an IPv6 address string into an IpV6 tuple.
  /// Supports standard notation, compressed notation (::), and IPv4-mapped addresses.
  ///
  /// ```motoko
  /// let ipResult1 = IpV6.fromText("2001:db8::1");
  /// // ipResult1 is #ok((0x2001, 0x0db8, 0, 0, 0, 0, 0, 1))
  ///
  /// let ipResult2 = IpV6.fromText("::1");
  /// // ipResult2 is #ok((0, 0, 0, 0, 0, 0, 0, 1))
  ///
  /// let ipResult3 = IpV6.fromText("::ffff:192.168.1.1");
  /// // ipResult3 is #ok((0, 0, 0, 0, 0, 0xffff, 0xc0a8, 0x0101))
  /// ```
  public func fromText(text : Text) : Result.Result<IpV6, Text> {
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

  /// Converts an IpV6 tuple to its string representation in the specified format.
  ///
  /// ```motoko
  /// let ip = (0x2001, 0x0db8, 0, 0, 0, 0, 0, 1);
  ///
  /// let fullFormat = IpV6.toText(ip, #full);
  /// // fullFormat is "2001:0db8:0000:0000:0000:0000:0000:0001"
  ///
  /// let compressedFormat = IpV6.toText(ip, #compressed);
  /// // compressedFormat is "2001:db8::1"
  ///
  /// let standardFormat = IpV6.toText(ip, #standard);
  /// // standardFormat is "2001:db8:0:0:0:0:0:1"
  /// ```
  public func toText(ip : IpV6, format : IpV6Format) : Text {
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

  private func handleEmbeddedIpV4(text : Text) : Result.Result<Text, Text> {
    // Find the last colon to check if what follows might be an IPv4 address
    let parts = Text.split(text, #text(":"));
    let partsArray = Iter.toArray(parts);

    if (partsArray.size() == 0) return #ok(text);

    let lastPart = partsArray[partsArray.size() - 1];

    // Check if the last part is an IPv4 address
    switch (IpV4.fromText(lastPart)) {
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
      case (#err(_)) #ok(text); // Not an IPv4 address, return original text
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

    switch (NatX.fromNat16Bytes(hexValue.vals(), #msb)) {
      case (?value) #ok(value);
      case (null) #err("Invalid hex group '" # text # "': Not a valid 16-bit value");
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
        if (i < (groups.size() - 1 : Nat)) result #= ":";
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

};
